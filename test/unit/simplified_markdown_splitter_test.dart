import 'package:test/test.dart';
import '../../lib/simplified_markdown_splitter.dart';
import '../../lib/simplified_chunk.dart';

void main() {
  group('SimplifiedMarkdownSplitter', () {
    late SimplifiedMarkdownSplitter splitter;

    setUp(() {
      splitter = SimplifiedMarkdownSplitter();
    });

    group('Basic Splitting', () {
      test('should return single chunk for small content', () {
        const content = 'This is a small piece of content.';
        final chunks = splitter.split(content);

        expect(chunks, hasLength(1));
        expect(chunks.first.content, equals(content));
        expect(chunks.first.isTranslatable, isTrue);
      });

      test('should return empty list for empty content', () {
        const content = '';
        final chunks = splitter.split(content);

        expect(chunks, isEmpty);
      });

      test('should respect default max bytes limit for content with line breaks', () {
        // Create content with line breaks so it can be split
        final largeContent = List.generate(1000, (i) => 'Large content line $i with some text').join('\n');
        final chunks = splitter.split(largeContent);

        expect(chunks.length, greaterThan(1));
        for (final chunk in chunks) {
          expect(chunk.utf8ByteSize, lessThanOrEqualTo(SimplifiedMarkdownSplitter.defaultMaxBytes));
        }
      });

      test('should respect custom max bytes limit for content with line breaks', () {
        const content = 'Short line 1\nShort line 2\nShort line 3\nShort line 4';
        final chunks = splitter.split(content, maxBytes: 25);

        expect(chunks.length, greaterThan(1));
        for (final chunk in chunks) {
          expect(chunk.utf8ByteSize, lessThanOrEqualTo(25));
        }
      });

      test('should handle content without line breaks that exceeds limit', () {
        final largeContentNoBreaks = 'Very long content without any line breaks ' * 100;
        final chunks = splitter.split(largeContentNoBreaks, maxBytes: 500);

        // Should create a single chunk even if it exceeds the limit (cannot split)
        expect(chunks.length, equals(1));
        expect(chunks.first.utf8ByteSize, greaterThan(500));
        expect(chunks.first.content, equals(largeContentNoBreaks));
      });
    });

    group('Header Strategy', () {
      test('should split by headers when present', () {
        const content = '''
# Main Title

Some introductory text.

## Section 1

Content for section 1.

## Section 2

Content for section 2.

### Subsection 2.1

More detailed content.
''';

        final chunks = splitter.split(content, maxBytes: 100);

        expect(chunks.length, greaterThan(1));
        
        // Verify that headers are preserved at the beginning of chunks
        final headerChunks = chunks.where((chunk) => chunk.content.contains(RegExp(r'^#+\s', multiLine: true))).toList();
        expect(headerChunks.length, greaterThan(0));
      });

      test('should handle content without headers', () {
        const content = '''
This is just regular content without any headers.
It should be handled by other strategies.

Maybe split by paragraphs instead.
''';

        final chunks = splitter.split(content, maxBytes: 50);

        expect(chunks, isNotEmpty);
        // Should work even without headers
      });

      test('should preserve header formatting', () {
        const content = '''
## Important Section

This section has important information.

### Subsection

More details here.
''';

        final chunks = splitter.split(content);

        expect(chunks, hasLength(1)); // Should fit in one chunk
        expect(chunks.first.content, contains('## Important Section'));
        expect(chunks.first.content, contains('### Subsection'));
      });
    });

    group('Paragraph Strategy', () {
      test('should split by paragraphs when no headers present', () {
        const content = '''
This is the first paragraph with some content.

This is the second paragraph with different content.

This is the third paragraph with even more content.
''';

        final chunks = splitter.split(content, maxBytes: 80);

        expect(chunks.length, greaterThan(1));
        
        // Verify paragraphs are preserved
        for (final chunk in chunks) {
          expect(chunk.content.trim(), isNotEmpty);
        }
      });

      test('should group small paragraphs together', () {
        const content = '''
Short para 1.

Short para 2.

Short para 3.

Short para 4.
''';

        final chunks = splitter.split(content, maxBytes: 100);

        // Should group multiple small paragraphs into single chunks
        expect(chunks.length, lessThan(4));
      });
    });

    group('Recursive Strategy Application', () {
      test('should apply strategies recursively for oversized chunks', () {
        const content = '''
## Large Section

This is a very large section that will exceed the byte limit and needs to be split further using paragraph strategy.

This is another paragraph in the same section that should be separated.

And another paragraph that might end up in a different chunk.

## Another Section

This section might fit in its own chunk.
''';

        final chunks = splitter.split(content, maxBytes: 150);

        expect(chunks.length, greaterThan(2));
        
        // Verify that section headers are preserved
        final headerChunks = chunks.where((chunk) => chunk.content.contains('##')).toList();
        expect(headerChunks, isNotEmpty);
      });

      test('should maintain content integrity across strategy transitions', () {
        const content = '''
## Section with Mixed Content

First paragraph in this section.

Second paragraph in this section.

### Subsection

Content in subsection.

More subsection content.
''';

        final chunks = splitter.split(content, maxBytes: 100);
        
        // Verify all content is preserved
        final reconstructed = chunks.map((c) => c.content).join();
        final normalizedOriginal = content.replaceAll(RegExp(r'\n+'), '\n');
        final normalizedReconstructed = reconstructed.replaceAll(RegExp(r'\n+'), '\n');
        
        expect(normalizedReconstructed.trim(), equals(normalizedOriginal.trim()));
      });
    });

    group('Statistics', () {
      test('should provide accurate statistics for chunks', () {
        const content = '''
## Section 1

Content for section 1.

## Section 2

Content for section 2.
''';

        final chunks = splitter.split(content, maxBytes: 50);
        final stats = splitter.getStatistics(chunks);

        expect(stats['totalChunks'], equals(chunks.length));
        expect(stats['totalBytes'], equals(chunks.fold<int>(0, (sum, chunk) => sum + chunk.utf8ByteSize)));
        expect(stats['totalCodeUnits'], equals(chunks.fold<int>(0, (sum, chunk) => sum + chunk.codeUnitsSize)));
        expect(stats['averageBytes'], isA<int>());
        expect(stats['maxBytes'], greaterThanOrEqualTo(stats['minBytes']));
      });

      test('should handle empty chunk list in statistics', () {
        final stats = splitter.getStatistics([]);

        expect(stats['totalChunks'], equals(0));
        expect(stats['totalBytes'], equals(0));
        expect(stats['totalCodeUnits'], equals(0));
        expect(stats['averageBytes'], equals(0));
        expect(stats['maxBytes'], equals(0));
        expect(stats['minBytes'], equals(0));
      });

      test('should provide statistics for single chunk', () {
        final chunk = SimplifiedChunk.fromContent('Test content');
        final stats = splitter.getStatistics([chunk]);

        expect(stats['totalChunks'], equals(1));
        expect(stats['totalBytes'], equals(chunk.utf8ByteSize));
        expect(stats['averageBytes'], equals(chunk.utf8ByteSize));
        expect(stats['maxBytes'], equals(chunk.utf8ByteSize));
        expect(stats['minBytes'], equals(chunk.utf8ByteSize));
      });
    });

    group('Edge Cases', () {
      test('should handle content with only whitespace', () {
        const content = '   \n\n\t  \n  ';
        final chunks = splitter.split(content);

        expect(chunks, hasLength(1));
        expect(chunks.first.content, equals(content));
      });

      test('should handle content with mixed line endings', () {
        const content = 'Line 1\nLine 2\r\nLine 3\rLine 4';
        final chunks = splitter.split(content);

        expect(chunks, isNotEmpty);
        expect(chunks.first.content, contains('Line 1'));
        expect(chunks.first.content, contains('Line 4'));
      });

      test('should handle content with code block anchors', () {
        const content = '''
# Section with Code

Some text before code.

__CODE_BLOCK_ANCHOR_0__

Some text after code.

Another paragraph with __INLINE_CODE_ANCHOR_1__ inline anchor.
''';

        final chunks = splitter.split(content, maxBytes: 100);

        expect(chunks, isNotEmpty);
        
        // Verify anchors are preserved
        final allContent = chunks.map((c) => c.content).join();
        expect(allContent, contains('__CODE_BLOCK_ANCHOR_0__'));
        expect(allContent, contains('__INLINE_CODE_ANCHOR_1__'));
      });
    });

    group('Performance', () {
      test('should handle large content efficiently', () {
        final largeContent = StringBuffer();
        for (int i = 0; i < 1000; i++) {
          largeContent.writeln('## Section $i');
          largeContent.writeln('Content for section $i with some text.');
          largeContent.writeln('');
        }

        final stopwatch = Stopwatch()..start();
        final chunks = splitter.split(largeContent.toString());
        stopwatch.stop();

        expect(chunks, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast
        
        // Verify all chunks are within size limits
        for (final chunk in chunks) {
          expect(chunk.utf8ByteSize, lessThanOrEqualTo(SimplifiedMarkdownSplitter.defaultMaxBytes));
        }
      });

      test('should handle deeply nested content', () {
        final deepContent = StringBuffer();
        for (int i = 1; i <= 6; i++) {
          deepContent.writeln('${'#' * i} Heading Level $i');
          deepContent.writeln('Content at level $i.');
          deepContent.writeln('');
        }

        final chunks = splitter.split(deepContent.toString(), maxBytes: 50);

        expect(chunks, isNotEmpty);
        // Should handle nested headers correctly
      });
    });

    group('Line-Based Force Splitting', () {
      test('should split content by lines when force splitting', () {
        const content = '''Line 1 with some content
Line 2 with different content that is longer
Line 3 that is much longer and exceeds the byte limit significantly with more text to make it bigger''';

        final chunks = splitter.split(content, maxBytes: 50);

        // Should split at line boundaries, not within lines
        for (final chunk in chunks) {
          // Each chunk should contain complete lines, not partial lines
          final lines = chunk.content.split('\n');
          for (final line in lines) {
            expect(line, isNot(contains('Line 1 with some contentLine 2')),
                reason: 'Lines should not be merged without proper newline separation');
          }
        }

        // Reconstruct content should match original
        final reconstructed = chunks.map((c) => c.content).join('\n\n');
        final normalizedOriginal = content.replaceAll(RegExp(r'\n+'), '\n');
        final normalizedReconstructed = reconstructed.replaceAll(RegExp(r'\n+'), '\n');
        expect(normalizedReconstructed.trim(), equals(normalizedOriginal.trim()));
      });

      test('should handle single very long line that exceeds byte limit', () {
        final veryLongLine = 'This is a very long line without any newlines that goes on and on and should exceed the byte limit but cannot be split because there are no line breaks to split at in this content. ' * 5;
        
        final chunks = splitter.split(veryLongLine, maxBytes: 200);

        // Should create a single chunk even if it exceeds limit (can't split within line)
        expect(chunks.length, equals(1));
        expect(chunks.first.content, equals(veryLongLine));
        expect(chunks.first.utf8ByteSize, greaterThan(200),
            reason: 'Single long line should remain as one chunk even if exceeding limit');
      });

      test('should preserve line structure when splitting at line boundaries', () {
        const content = '''Short line 1
This is a much longer line that will likely exceed the small byte limit we set for testing
Short line 2
Another longer line that should also exceed the byte limit and force splitting
Short line 3''';

        final chunks = splitter.split(content, maxBytes: 80);
        
        // Each chunk should maintain complete lines
        for (final chunk in chunks) {
          final lines = chunk.content.split('\n');
          // No line should be empty (except for intentional blank lines)
          for (final line in lines) {
            if (line.isNotEmpty) {
              expect(line.trim(), isNotEmpty);
            }
          }
        }

        // Original line count should be preserved
        final originalLines = content.split('\n').where((line) => line.trim().isNotEmpty).length;
        final reconstructedLines = chunks
            .map((c) => c.content.split('\n'))
            .expand((lines) => lines)
            .where((line) => line.trim().isNotEmpty)
            .length;
        expect(reconstructedLines, equals(originalLines));
      });

      test('should handle content with mixed line lengths efficiently', () {
        const content = '''# Header
Short
A much longer line that definitely exceeds our small limit
Tiny
Another very long line with lots of text that should be in its own chunk due to the byte limit
End''';

        final chunks = splitter.split(content, maxBytes: 60);

        // Verify no lines are split within themselves
        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          expect(chunk.content, isNot(contains('Shorta much longer')),
              reason: 'Lines should not be concatenated without proper separation');
          
          // Each line should be complete
          final lines = chunk.content.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              expect(line, isNot(startsWith('much longer line that definitely')),
                  reason: 'Lines should not start mid-sentence unless that\'s the original content');
            }
          }
        }
      });

      test('should handle empty lines correctly in force splitting', () {
        const content = '''Line 1

Line 3 with content

Line 5 with more content''';

        final chunks = splitter.split(content, maxBytes: 30);

        // Empty lines should be preserved in structure
        bool foundEmptyLine = false;
        for (final chunk in chunks) {
          if (chunk.content.contains('\n\n')) {
            foundEmptyLine = true;
          }
        }
        
        expect(foundEmptyLine, isTrue, 
            reason: 'Empty lines should be preserved in the splitting process');
      });
    });
  });
}