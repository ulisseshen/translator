import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:translator/translator.dart';
import 'package:translator/markdown_spliter.dart';
import 'package:translator/parallel_chunk_processor.dart';

class MockTranslator implements Translator {
  final Duration delay;
  final bool shouldFail;
  final Map<String, String> translations;
  int callCount = 0;
  final List<String> processedTexts = [];

  MockTranslator({
    this.delay = const Duration(milliseconds: 100),
    this.shouldFail = false,
    Map<String, String>? translations,
  }) : translations = translations ?? <String, String>{};

  @override
  Future<String> translate(String text, {
    required Function onFirstModelError,
    bool useSecond = false,
  }) async {
    callCount++;
    processedTexts.add(text);
    
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    
    if (shouldFail && !useSecond) {
      onFirstModelError();
      throw Exception('Translation failed on first attempt');
    }
    
    return translations[text] ?? 'Translated: $text';
  }
}

void main() {
  group('Split File Translation Tests', () {
    late Directory testDir;

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp('split_translation_test_');
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('Single File Translation', () {
      test('should translate single small file without splitting', () async {
        final content = '''
### Introduction
This is a small markdown file that fits in one chunk.
It contains basic content that should be translated as a single unit.
''';

        final file = File('${testDir.path}/small_file.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 5,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.chunks.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        expect(mockTranslator.callCount, equals(1));
        expect(results[file.path]!.translatedChunks.first, contains('Translated:'));
      });

      test('should split and translate large single file', () async {
        final sections = List.generate(50, (i) => '''
### Section $i
This is section $i with substantial content to ensure file splitting.
${'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 20}

#### Subsection $i.1
Additional content for subsection $i.1.
${'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ' * 15}

#### Subsection $i.2
More content for subsection $i.2.
${'Ut enim ad minim veniam, quis nostrud exercitation ullamco. ' * 12}
''');

        final content = sections.join('\n');
        final file = File('${testDir.path}/large_file.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator(delay: const Duration(milliseconds: 50));
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 3,
          maxBytes: 5000,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.chunks.length, greaterThan(5));
        expect(results[file.path]!.isComplete, isTrue);
        expect(mockTranslator.callCount, equals(results[file.path]!.chunks.length));
        
        for (final translated in results[file.path]!.translatedChunks) {
          expect(translated, contains('Translated:'));
        }
      });

      test('should handle file with complex markdown structure', () async {
        final content = '''
# Main Title

## Introduction
This is the introduction section.

### Code Examples
Here are some code examples:

```dart
void main() {
  print('Hello, World!');
}
```

```yaml
name: my_app
dependencies:
  flutter:
    sdk: flutter
```

### Lists and Tables

#### Unordered List
- Item 1
- Item 2
  - Nested item 2.1
  - Nested item 2.2
- Item 3

#### Ordered List
1. First step
2. Second step
3. Third step

#### Table
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
| Data 4   | Data 5   | Data 6   |

### Links and Images
[Link text](https://example.com)
![Alt text](image.png)

### Conclusion
This concludes the complex markdown document.
''';

        final file = File('${testDir.path}/complex_markdown.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 2000,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        
        final translatedContent = results[file.path]!.translatedChunks.join('');
        expect(translatedContent, contains('```dart'));
        expect(translatedContent, contains('```yaml'));
        expect(translatedContent, contains('| Column'));
        expect(translatedContent, contains('[Link text]'));
      });
    });

    group('Multiple Files Translation', () {
      test('should translate multiple small files concurrently', () async {
        final files = <File>[];
        final expectedTranslations = <String>[];

        for (int i = 0; i < 5; i++) {
          final content = '''
### File $i Content
This is content for file number $i.
It contains unique information specific to file $i.
''';
          
          final file = File('${testDir.path}/file_$i.md');
          await file.writeAsString(content);
          files.add(file);
          expectedTranslations.add(content);
        }

        final mockTranslator = MockTranslator(delay: const Duration(milliseconds: 200));
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 3,
          maxBytes: 20480,
        );

        final startTime = DateTime.now();
        final results = await processor.processFiles(files);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        expect(results.length, equals(5));
        expect(duration.inMilliseconds, lessThan(2000));
        expect(mockTranslator.callCount, equals(5));

        for (final file in files) {
          expect(results[file.path]!.isComplete, isTrue);
          expect(results[file.path]!.chunks.length, equals(1));
        }
      });

      test('should handle mixed file sizes with proper prioritization', () async {
        final smallFile = File('${testDir.path}/small.md');
        await smallFile.writeAsString('''
### Small File
This is a small file with minimal content.
''');

        final mediumContent = List.generate(10, (i) => '''
### Medium Section $i
This is section $i of a medium-sized file.
${'Content for section $i. ' * 10}
''').join('\n');
        
        final mediumFile = File('${testDir.path}/medium.md');
        await mediumFile.writeAsString(mediumContent);

        final largeContent = List.generate(30, (i) => '''
### Large Section $i
This is section $i of a large file.
${'Extensive content for section $i. ' * 25}

#### Subsection $i.1
Additional details for subsection $i.1.
${'More detailed content here. ' * 20}
''').join('\n');

        final largeFile = File('${testDir.path}/large.md');
        await largeFile.writeAsString(largeContent);

        final mockTranslator = MockTranslator(delay: const Duration(milliseconds: 100));
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 4,
          maxBytes: 3000,
        );

        final results = await processor.processFiles([smallFile, mediumFile, largeFile]);

        expect(results.length, equals(3));
        expect(results[smallFile.path]!.chunks.length, equals(1));
        expect(results[mediumFile.path]!.chunks.length, greaterThanOrEqualTo(1));
        expect(results[largeFile.path]!.chunks.length, greaterThan(5));

        for (final result in results.values) {
          expect(result.isComplete, isTrue);
        }
      });
    });

    group('Error Handling', () {
      test('should handle translation failures gracefully', () async {
        final content = '''
### Test Content
This content will cause translation to fail initially.
''';

        final file = File('${testDir.path}/fail_test.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator(
          shouldFail: true,
          delay: const Duration(milliseconds: 50),
        );
        
        mockTranslator.translations[content] = content;

        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        expect(results[file.path]!.translatedChunks.first, equals(content));
      });

      test('should handle mixed success and failure scenarios', () async {
        final files = <File>[];
        
        for (int i = 0; i < 3; i++) {
          final content = '''
### Content $i
This is content for file $i.
Some files will succeed, others will fail.
''';
          
          final file = File('${testDir.path}/mixed_$i.md');
          await file.writeAsString(content);
          files.add(file);
        }

        final mockTranslator = MockTranslator(
          shouldFail: true,
          delay: const Duration(milliseconds: 30),
        );

        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles(files);

        expect(results.length, equals(3));
        
        for (final result in results.values) {
          expect(result.isComplete, isTrue);
        }
      });

      test('should handle file read errors', () async {
        final nonExistentFile = File('${testDir.path}/nonexistent.md');
        
        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        expect(() => processor.processFiles([nonExistentFile]), throwsA(isA<FileSystemException>()));
      });
    });

    group('Edge Cases', () {
      test('should handle empty file', () async {
        final file = File('${testDir.path}/empty.md');
        await file.writeAsString('');

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.chunks.isEmpty, isTrue);
        expect(results[file.path]!.isComplete, isTrue);
        expect(mockTranslator.callCount, equals(0));
      });

      test('should handle file with only whitespace', () async {
        final content = '   \n\n\t\t\n   ';
        final file = File('${testDir.path}/whitespace.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
      });

      test('should handle file without section headers', () async {
        final content = '''
This is a markdown file without any section headers.
It contains paragraphs of text that should still be processed.

Another paragraph here with some more content.
And yet another paragraph to make it substantial.
''';

        final file = File('${testDir.path}/no_headers.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.chunks.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        expect(mockTranslator.callCount, equals(1));
      });

      test('should handle very large single section', () async {
        final largeSection = '''
### Massive Section
${'This is a very large section with lots of content. ' * 1000}
''';

        final file = File('${testDir.path}/huge_section.md');
        await file.writeAsString(largeSection);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 10000,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        expect(mockTranslator.callCount, greaterThan(0));
      });
    });

    group('Concurrent Limits and Resource Management', () {
      test('should respect concurrent processing limits', () async {
        final files = <File>[];
        
        for (int i = 0; i < 15; i++) {
          final content = '''
### File $i
This is content for file $i that will be processed.
${'Content line for file $i. ' * 10}
''';
          
          final file = File('${testDir.path}/concurrent_$i.md');
          await file.writeAsString(content);
          files.add(file);
        }

        final mockTranslator = MockTranslator(delay: const Duration(milliseconds: 200));
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 5,
          maxBytes: 20480,
        );

        final results = await processor.processFiles(files);

        expect(results.length, equals(15));
        expect(processor.maxConcurrentReached, lessThanOrEqualTo(5));
        
        for (final result in results.values) {
          expect(result.isComplete, isTrue);
        }
      });

      test('should handle zero concurrent limit gracefully', () async {
        final content = '''
### Test Content
This should still work with zero concurrent limit.
''';

        final file = File('${testDir.path}/zero_concurrent.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator();

        expect(() => ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 0,
          maxBytes: 20480,
        ), throwsArgumentError);
      });

      test('should process files with different chunk sizes efficiently', () async {
        final files = <File>[];
        
        final smallContent = '### Small\nSmall content.';
        final smallFile = File('${testDir.path}/small_chunks.md');
        await smallFile.writeAsString(smallContent);
        files.add(smallFile);

        final largeContent = List.generate(20, (i) => '''
### Large Section $i
${'Large content for section $i. ' * 50}
''').join('\n');
        
        final largeFile = File('${testDir.path}/large_chunks.md');
        await largeFile.writeAsString(largeContent);
        files.add(largeFile);

        final mockTranslator = MockTranslator(delay: const Duration(milliseconds: 100));
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 8,
          maxBytes: 5000,
        );

        final results = await processor.processFiles(files);

        expect(results.length, equals(2));
        expect(results[smallFile.path]!.chunks.length, equals(1));
        expect(results[largeFile.path]!.chunks.length, greaterThan(3));

        for (final result in results.values) {
          expect(result.isComplete, isTrue);
        }
      });
    });

    group('Content Integrity', () {
      test('should preserve content order after translation', () async {
        final sections = List.generate(10, (i) => '''
### Section $i
This is section $i with order $i.
Content order should be preserved.
''');

        final content = sections.join('\n');
        final file = File('${testDir.path}/order_test.md');
        await file.writeAsString(content);

        final mockTranslator = MockTranslator(
          delay: const Duration(milliseconds: 50),
          translations: Map.fromEntries(
            sections.asMap().entries.map((entry) => 
              MapEntry(entry.value, 'TRANSLATED_${entry.key}: ${entry.value}')
            )
          ),
        );

        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 3,
          maxBytes: 500,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);

        final translatedContent = results[file.path]!.translatedChunks.join('');
        
        // Check that all sections were translated and are in the correct order
        for (int i = 0; i < 10; i++) {
          expect(translatedContent, contains('Section $i'));
        }
        
        // Verify that the content maintains order (Section 0 before Section 1, etc.)
        final section0Index = translatedContent.indexOf('Section 0');
        final section9Index = translatedContent.indexOf('Section 9');
        expect(section0Index, lessThan(section9Index));
      });

      test('should handle special characters and encoding properly', () async {
        final content = '''
### Special Characters Test
This content contains special characters: áéíóú ñ ü ç
Chinese: 中文测试
Japanese: 日本語テスト
Emoji: 🚀 🎉 💻 🌟
Mathematical symbols: ∑ ∆ π ∞ ≠ ≤ ≥
Currency: \$ € £ ¥ ₹
''';

        final file = File('${testDir.path}/special_chars.md');
        await file.writeAsString(content, encoding: utf8);

        final mockTranslator = MockTranslator();
        final processor = ParallelChunkProcessor(
          translator: mockTranslator,
          maxConcurrent: 2,
          maxBytes: 20480,
        );

        final results = await processor.processFiles([file]);

        expect(results.length, equals(1));
        expect(results[file.path]!.isComplete, isTrue);
        
        final translatedContent = results[file.path]!.translatedChunks.first;
        expect(translatedContent, contains('áéíóú'));
        expect(translatedContent, contains('中文测试'));
        expect(translatedContent, contains('🚀'));
        expect(translatedContent, contains('∑'));
      });
    });
  });
}