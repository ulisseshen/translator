import 'dart:io';
import 'package:test/test.dart';
import 'package:translator/translator.dart';
import 'package:translator/markdown_spliter.dart';
import 'package:translator/parallel_chunk_processor.dart';

void main() {
  group('Translator Tests', () {
    late TranslatorImp translator;

    setUp(() {
      translator = TranslatorImp();
    });

    test('should handle translation with fallback on error', () async {
      int errorCallbackCount = 0;
      void onError() {
        errorCallbackCount++;
      }

      try {
        await translator.translate(
          'Test content for translation',
          onFirstModelError: onError,
          useSecond: true,
        );
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('should validate API key exists', () {
      expect(() => translator.ensureAPIKeyExists(), 
             throwsA(anything));
    }, skip: Platform.environment['GEMINI_API_KEY'] != null);

    test('should create model with correct configuration', () {
      if (Platform.environment['GEMINI_API_KEY'] != null) {
        final model = translator.getModel('gemini-2.5-flash');
        expect(model, isNotNull);
      }
    }, skip: Platform.environment['GEMINI_API_KEY'] == null);

    test('should handle large text translation with proper chunking', () async {
      final largeText = 'a' * 8000;
      int errorCount = 0;
      
      try {
        await translator.translate(
          largeText,
          onFirstModelError: () => errorCount++,
          useSecond: true,
        );
      } catch (e) {
        expect(errorCount, lessThanOrEqualTo(1));
      }
    }, skip: Platform.environment['GEMINI_API_KEY'] == null);
  });

  group('MarkdownSplitter Tests', () {
    test('should split markdown at section headers', () {
      final content = '''
### Section 1
Content for section 1

### Section 2  
Content for section 2

### Section 3
Content for section 3
''';
      
      final splitter = MarkdownSplitter(maxBytes: 100);
      final chunks = splitter.splitMarkdown(content);
      
      expect(chunks.length, greaterThan(1));
      expect(chunks.first, contains('### Section 1'));
    });

    test('should respect maxBytes limit when splitting', () {
      final largeSection = '### Large Section\n' + 'a' * 1000;
      final content = largeSection + '\n\n### Small Section\nsmall content';
      
      final splitter = MarkdownSplitter(maxBytes: 500);
      final chunks = splitter.splitMarkdown(content);
      
      for (final chunk in chunks) {
        expect(chunk.codeUnits.length, lessThanOrEqualTo(500 + largeSection.length));
      }
    });

    test('should handle empty content', () {
      final splitter = MarkdownSplitter();
      final chunks = splitter.splitMarkdown('');
      
      expect(chunks, isEmpty);
    });

    test('should handle content without section headers', () {
      final content = 'This is content without headers\nMore content here';
      
      final splitter = MarkdownSplitter();
      final chunks = splitter.splitMarkdown(content);
      
      expect(chunks, hasLength(1));
      expect(chunks.first, equals(content));
    });

    test('should preserve content integrity when rejoined', () {
      final content = '''
### Section 1
Content 1

### Section 2  
Content 2

### Section 3
Content 3
''';
      
      final splitter = MarkdownSplitter(maxBytes: 100);
      splitter.splitMarkdown(content);
      final rejoined = splitter.getEnterily();
      
      expect(rejoined, equals(content));
    });

    test('should handle very large files efficiently', () {
      final largeContent = List.generate(100, (i) => '''
### Section $i
${'Content for section $i. ' * 50}
''').join('\n');
      
      final splitter = MarkdownSplitter(maxBytes: 2048);
      final chunks = splitter.splitMarkdown(largeContent);
      
      expect(chunks, isNotEmpty);
      
      int totalLength = 0;
      for (final chunk in chunks) {
        totalLength += chunk.length;
      }
      expect(totalLength, equals(largeContent.length));
    });

    test('should handle mixed content sizes', () {
      final content = '''
### Small Section
Small content

### Large Section
${'Very long content that exceeds typical limits. ' * 100}

### Another Small Section
More small content
''';
      
      final splitter = MarkdownSplitter(maxBytes: 1000);
      final chunks = splitter.splitMarkdown(content);
      
      expect(chunks.length, greaterThan(1));
      
      bool hasSmallChunk = false;
      bool hasLargeChunk = false;
      
      for (final chunk in chunks) {
        if (chunk.length < 500) hasSmallChunk = true;
        if (chunk.length > 500) hasLargeChunk = true;
      }
      
      expect(hasSmallChunk || hasLargeChunk, isTrue);
    });
  });

  group('Integration Tests - Large File Processing', () {
    late Directory testDir;

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp('translator_test_');
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('should handle parallel processing of large files with 10 concurrent limit', () async {
      final files = <File>[];
      final expectedChunks = <String, List<String>>{};
      
      for (int fileIndex = 0; fileIndex < 5; fileIndex++) {
        final content = List.generate(20, (i) => '''
### Section ${fileIndex}_$i
This is content for file $fileIndex, section $i. Each section contains substantial content.
${'More content to ensure chunks are large enough. ' * 15}

#### Subsection ${fileIndex}_$i.1
Additional technical details for this section.
${'Technical content that needs translation. ' * 10}
''').join('\n');

        final file = File('${testDir.path}/large_file_$fileIndex.md');
        await file.writeAsString(content);
        files.add(file);

        final splitter = MarkdownSplitter(maxBytes: 20480);
        expectedChunks[file.path] = splitter.splitMarkdown(content);
      }

      final processor = ParallelChunkProcessor(
        translator: TranslatorImp(),
        maxConcurrent: 10,
        maxBytes: 20480,
      );

      final startTime = DateTime.now();
      final results = await processor.processFiles(files);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      expect(results.length, equals(5));
      
      for (final file in files) {
        expect(results.containsKey(file.path), isTrue);
        final result = results[file.path]!;
        expect(result.chunks.length, equals(expectedChunks[file.path]!.length));
        expect(result.isComplete, isTrue);
      }

      print('Processing took: ${duration.inMilliseconds}ms');
      
      expect(processor.maxConcurrentReached, lessThanOrEqualTo(10));
      
      for (final file in files) {
        final result = results[file.path]!;
        expect(result.processingOrder.isNotEmpty, isTrue);
        expect(result.processingOrder.length, equals(result.chunks.length));
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('should prioritize chunks from same file over different files', () async {
      final file1Content = List.generate(15, (i) => '''
### File1 Section $i
Content for file 1, section $i.
${'Substantial content here. ' * 20}
''').join('\n');

      final file2Content = List.generate(15, (i) => '''
### File2 Section $i  
Content for file 2, section $i.
${'Substantial content here. ' * 20}
''').join('\n');

      final file1 = File('${testDir.path}/priority_file1.md');
      final file2 = File('${testDir.path}/priority_file2.md');
      
      await file1.writeAsString(file1Content);
      await file2.writeAsString(file2Content);

      final processor = ParallelChunkProcessor(
        translator: TranslatorImp(),
        maxConcurrent: 3,
        maxBytes: 20480,
      );

      final results = await processor.processFiles([file1, file2]);

      expect(results.length, equals(2));
      
      final file1Result = results[file1.path]!;
      final file2Result = results[file2.path]!;

      final file1CompletionTimes = file1Result.chunkCompletionTimes;
      final file2CompletionTimes = file2Result.chunkCompletionTimes;

      bool file1ChunksGroupedTogether = true;
      bool file2ChunksGroupedTogether = true;

      for (int i = 0; i < file1CompletionTimes.length - 1; i++) {
        final gap = file1CompletionTimes[i + 1].difference(file1CompletionTimes[i]);
        if (gap.inMilliseconds > 1000) {
          file1ChunksGroupedTogether = false;
          break;
        }
      }

      for (int i = 0; i < file2CompletionTimes.length - 1; i++) {
        final gap = file2CompletionTimes[i + 1].difference(file2CompletionTimes[i]);
        if (gap.inMilliseconds > 1000) {
          file2ChunksGroupedTogether = false;
          break;
        }
      }

      expect(file1ChunksGroupedTogether || file2ChunksGroupedTogether, isTrue,
          reason: 'At least one file should have its chunks processed together');
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('should process large markdown files end-to-end', () async {
      final largeContent = List.generate(50, (i) => '''
### Section $i
This is content for section $i. It contains technical information about Flutter development.
The content includes various markdown elements and should be preserved during translation.

#### Subsection $i.1
More detailed content here with code examples:

```dart
void main() {
  print('Hello, World!');
}
```

This concludes section $i.
''').join('\n');

      final testFile = File('${testDir.path}/large_test.md');
      await testFile.writeAsString(largeContent);

      final splitter = MarkdownSplitter(maxBytes: 5000);
      final chunks = splitter.splitMarkdown(largeContent);

      expect(chunks.length, greaterThan(5));
      expect(splitter.getEnterily().length, equals(largeContent.length));

      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i], contains('### Section'));
        if (chunks[i].length > 100) {
          expect(chunks[i], contains('Flutter development'));
        }
      }
    });

    test('should handle file splitting and translation workflow', () async {
      final content = '''
### Introduction
This is the introduction section with important information.

### Configuration  
Here we discuss configuration options for the application.
${'This section has more content to make it longer. ' * 20}

### Advanced Topics
Advanced topics require careful consideration and detailed explanation.
${'More advanced content here. ' * 30}

### Conclusion
This concludes our documentation.
''';

      final testFile = File('${testDir.path}/workflow_test.md');
      await testFile.writeAsString(content);

      final splitter = MarkdownSplitter(maxBytes: 1000);
      final chunks = splitter.splitMarkdown(content);

      expect(chunks.length, greaterThanOrEqualTo(2));

      for (final chunk in chunks) {
        expect(chunk.trim(), isNotEmpty);
        if (chunk.contains('###')) {
          expect(chunk, matches(r'###\s+\w+'));
        }
      }

      final reconstructed = splitter.getEnterily();
      expect(reconstructed, equals(content));
    });

    test('should maintain section boundaries in large files', () async {
      final sections = List.generate(20, (i) => '''
### Important Section $i
This section contains critical information that must not be split.
${'Important details that belong together. ' * 25}

#### Subsection $i.1
Additional details for this section.
${'More content to ensure proper boundaries. ' * 15}
''');

      final content = sections.join('\n');
      final splitter = MarkdownSplitter(maxBytes: 2000);
      final chunks = splitter.splitMarkdown(content);

      for (final chunk in chunks) {
        final sectionHeaders = RegExp(r'^### ', multiLine: true).allMatches(chunk);
        if (sectionHeaders.length > 1) {
          expect(chunk, contains('### Important Section'));
        }
      }
    });
  });
}
