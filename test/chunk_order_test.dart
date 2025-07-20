import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:translator/translator.dart';
import 'package:translator/parallel_chunk_processor.dart';

class DelayedMockTranslator implements Translator {
  final Map<int, Duration> chunkDelays;
  final Map<String, String> translations;
  int callCount = 0;
  final List<int> completionOrder = [];

  DelayedMockTranslator({
    required this.chunkDelays,
    this.translations = const {},
  });

  @override
  Future<String> translate(String text, {
    required Function onFirstModelError,
    bool useSecond = false,
  }) async {
    callCount++;
    
    // Determine chunk index based on content
    int chunkIndex = _getChunkIndex(text);
    
    // Apply deliberate delay to simulate different completion times
    final delay = chunkDelays[chunkIndex] ?? const Duration(milliseconds: 100);
    await Future.delayed(delay);
    
    completionOrder.add(chunkIndex);
    
    return translations[text] ?? 'TRANSLATED_CHUNK_$chunkIndex: $text';
  }
  
  int _getChunkIndex(String text) {
    // Use call count as index since we can't predict how chunks will be split
    return callCount - 1; // callCount is incremented before this call
  }
}

void main() {
  group('Chunk Order Preservation Tests', () {
    late Directory testDir;

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp('chunk_order_test_');
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('should maintain correct chunk order despite out-of-order completion', () async {
      // Create a test file with clearly identifiable sections
      final content = '''
### CHUNK_0 - First Section
This is the first chunk that should appear at the beginning.
Content of first section with unique identifier CHUNK_0.
This content must remain at the start of the file.

### CHUNK_1 - Second Section  
This is the second chunk in the sequence.
Content of second section with unique identifier CHUNK_1.
This content must appear after CHUNK_0.

### CHUNK_2 - Third Section
This is the third chunk in the document.
Content of third section with unique identifier CHUNK_2.
This content must appear after CHUNK_1.

### CHUNK_3 - Fourth Section
This is the fourth chunk in the sequence.
Content of fourth section with unique identifier CHUNK_3.
This content must appear after CHUNK_2.

### CHUNK_4 - Fifth Section
This is the final chunk of the document.
Content of fifth section with unique identifier CHUNK_4.
This content must appear at the end of the file.
''';

      final file = File('${testDir.path}/order_test.md');
      await file.writeAsString(content);

      // Create mock translator with deliberate delays to force out-of-order completion
      // Make later chunks complete faster than earlier ones
      final mockTranslator = DelayedMockTranslator(
        chunkDelays: {
          0: const Duration(milliseconds: 300), // Slowest
          1: const Duration(milliseconds: 100), // Fastest  
          2: const Duration(milliseconds: 200), // Middle
        },
      );

      final processor = ParallelChunkProcessor(
        translator: mockTranslator,
        maxConcurrent: 5,
        maxBytes: 500, // Small chunks to ensure splitting
      );

      final results = await processor.processFiles([file]);
      final result = results[file.path]!;

      // Verify that chunks completed out of order
      print('Completion order: ${mockTranslator.completionOrder}');
      print('Expected sequential order: [0, 1, 2]');
      expect(mockTranslator.completionOrder, isNot(equals([0, 1, 2])));
      
      // Debug: Print actual content
      final reassembledContent = result.translatedChunks.join('');
      print('');
      print('Individual chunks in array order:');
      for (int i = 0; i < result.translatedChunks.length; i++) {
        final preview = result.translatedChunks[i].length > 80 
            ? '${result.translatedChunks[i].substring(0, 80)}...'
            : result.translatedChunks[i];
        print('Chunk $i: $preview');
      }
      
      // The key test: verify that despite out-of-order completion, 
      // the content is reassembled in the correct chunk order
      // Chunk 0 should contain CHUNK_0, Chunk 1 should contain what comes after, etc.
      
      // Find the original markers in the reassembled content
      final chunk0Marker = 'CHUNK_0 - First Section';
      final chunk2Marker = 'CHUNK_2 - Third Section';  
      final chunk4Marker = 'CHUNK_4 - Fifth Section';
      
      final pos0 = reassembledContent.indexOf(chunk0Marker);
      final pos1 = reassembledContent.indexOf('CHUNK_1 - Second Section');
      final pos2 = reassembledContent.indexOf(chunk2Marker);
      final pos4 = reassembledContent.indexOf(chunk4Marker);

      expect(pos0, greaterThanOrEqualTo(0), reason: 'CHUNK_0 should be present');
      expect(pos2, greaterThanOrEqualTo(0), reason: 'CHUNK_2 should be present');
      expect(pos4, greaterThanOrEqualTo(0), reason: 'CHUNK_4 should be present');
      
      // Most importantly: verify the order is preserved
      expect(pos0, lessThan(pos1), reason: 'CHUNK_0 should appear before CHUNK_1');
      expect(pos1, lessThan(pos2), reason: 'CHUNK_1 should appear before CHUNK_2');
      expect(pos2, lessThan(pos4), reason: 'CHUNK_2 should appear before CHUNK_4');

      print('✅ Content order verification passed');
      print('CHUNK_0 at position: $pos0');
      print('CHUNK_1 at position: $pos1');
      print('CHUNK_2 at position: $pos2');
      print('CHUNK_4 at position: $pos4');
    });

    test('should preserve markdown structure across chunk boundaries', () async {
      final content = '''
### Section A - Beginning
This section starts the document.
It contains important introductory content.

#### Subsection A.1
Detailed information about topic A.
This has multiple paragraphs.

More content in subsection A.1.

### Section B - Middle
This is the middle section of the document.
It contains technical details.

#### Subsection B.1
Technical specifications here.

#### Subsection B.2
More technical details.

### Section C - End
This is the final section.
It contains concluding remarks.

Final paragraph of the document.
''';

      final file = File('${testDir.path}/structure_test.md');
      await file.writeAsString(content);

      // Create translator with random delays
      final mockTranslator = DelayedMockTranslator(
        chunkDelays: {
          0: const Duration(milliseconds: 300),
          1: const Duration(milliseconds: 100),
          2: const Duration(milliseconds: 200),
        },
      );

      final processor = ParallelChunkProcessor(
        translator: mockTranslator,
        maxConcurrent: 10,
        maxBytes: 800,
      );

      final results = await processor.processFiles([file]);
      final result = results[file.path]!;

      final reassembledContent = result.translatedChunks.join('');

      // Verify structure is preserved
      expect(reassembledContent, contains('### Section A - Beginning'));
      expect(reassembledContent, contains('### Section B - Middle'));
      expect(reassembledContent, contains('### Section C - End'));
      
      // Verify subsections are in correct order
      final sectionAPos = reassembledContent.indexOf('### Section A');
      final sectionBPos = reassembledContent.indexOf('### Section B');
      final sectionCPos = reassembledContent.indexOf('### Section C');
      
      expect(sectionAPos, lessThan(sectionBPos));
      expect(sectionBPos, lessThan(sectionCPos));

      print('✅ Markdown structure preservation verified');
    });

    test('should handle edge case with very small chunks', () async {
      final content = '''
### A
Small chunk A content.

### B  
Small chunk B content.

### C
Small chunk C content.

### D
Small chunk D content.

### E
Small chunk E content.
''';

      final file = File('${testDir.path}/small_chunks_test.md');
      await file.writeAsString(content);

      final mockTranslator = DelayedMockTranslator(
        chunkDelays: {
          0: const Duration(milliseconds: 400),
          1: const Duration(milliseconds: 100),
          2: const Duration(milliseconds: 300),
          3: const Duration(milliseconds: 150),
          4: const Duration(milliseconds: 250),
        },
      );

      final processor = ParallelChunkProcessor(
        translator: mockTranslator,
        maxConcurrent: 5,
        maxBytes: 100, // Very small chunks
      );

      final results = await processor.processFiles([file]);
      final result = results[file.path]!;

      final reassembledContent = result.translatedChunks.join('');

      // Verify sections appear in alphabetical order
      final posA = reassembledContent.indexOf('### A');
      final posB = reassembledContent.indexOf('### B');
      final posC = reassembledContent.indexOf('### C');
      final posD = reassembledContent.indexOf('### D');
      final posE = reassembledContent.indexOf('### E');

      expect(posA, lessThan(posB));
      expect(posB, lessThan(posC));
      expect(posC, lessThan(posD));
      expect(posD, lessThan(posE));

      print('✅ Small chunks order verification passed');
      print('Completion order was: ${mockTranslator.completionOrder}');
    });

    test('should handle single chunk file correctly', () async {
      final content = '''
### Single Section
This file has only one section and should not be split.
It should be processed as a single chunk.
The content should remain intact.
''';

      final file = File('${testDir.path}/single_chunk_test.md');
      await file.writeAsString(content);

      final mockTranslator = DelayedMockTranslator(
        chunkDelays: {0: const Duration(milliseconds: 100)},
      );

      final processor = ParallelChunkProcessor(
        translator: mockTranslator,
        maxConcurrent: 3,
        maxBytes: 20480, // Large enough to prevent splitting
      );

      final results = await processor.processFiles([file]);
      final result = results[file.path]!;

      expect(result.chunks.length, equals(1));
      expect(result.translatedChunks.length, equals(1));
      expect(result.isComplete, isTrue);

      final reassembledContent = result.translatedChunks.join('');
      expect(reassembledContent, contains('Single Section'));

      print('✅ Single chunk processing verified');
    });

    test('should maintain content integrity with complex markdown', () async {
      final content = '''
### Complex Section 1
This section contains various markdown elements:

#### Code Block
```dart
void main() {
  print('Hello, World!');
}
```

#### List Items
- Item 1
- Item 2
  - Nested item 2.1
  - Nested item 2.2
- Item 3

### Complex Section 2
This section has tables:

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
| Data 4   | Data 5   | Data 6   |

### Complex Section 3
This section has links and references:

[Link text](https://example.com)
![Alt text](image.png)

References and footnotes should be preserved.
''';

      final file = File('${testDir.path}/complex_test.md');
      await file.writeAsString(content);

      final mockTranslator = DelayedMockTranslator(
        chunkDelays: {
          0: const Duration(milliseconds: 200),
          1: const Duration(milliseconds: 50),
          2: const Duration(milliseconds: 150),
        },
      );

      final processor = ParallelChunkProcessor(
        translator: mockTranslator,
        maxConcurrent: 3,
        maxBytes: 1000,
      );

      final results = await processor.processFiles([file]);
      final result = results[file.path]!;

      final reassembledContent = result.translatedChunks.join('');

      // Verify complex elements are preserved
      expect(reassembledContent, contains('```dart'));
      expect(reassembledContent, contains('| Column 1 |'));
      expect(reassembledContent, contains('[Link text]'));
      expect(reassembledContent, contains('![Alt text]'));

      // Verify sections are in correct order
      final section1Pos = reassembledContent.indexOf('Complex Section 1');
      final section2Pos = reassembledContent.indexOf('Complex Section 2');
      final section3Pos = reassembledContent.indexOf('Complex Section 3');

      expect(section1Pos, lessThan(section2Pos));
      expect(section2Pos, lessThan(section3Pos));

      print('✅ Complex markdown integrity verified');
    });
  });
}