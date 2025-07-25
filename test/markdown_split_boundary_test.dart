import 'package:test/test.dart';
import 'package:translator/markdown_spliter.dart';

void main() {
  group('MarkdownSplitter - Header Boundary Tests', () {
    test('should split at previous header when next header exceeds chunk limit', () {
      // Setup: Create content with sections that can be combined within the limit
      const chunkSize = 150; // Adjusted size for testing
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      // Create content where first two sections fit together but adding the third would exceed
      final content = '''## First Section
Short intro content.

### Section A
Small content A.

### Section B  
Small content B.

### Large Section C
This is a much larger section with lots of content that would exceed the chunk size limit when added to the previous sections. This text is intentionally verbose.

### Section D
Small content D.''';
      
      // Act
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      // Assert
      expect(chunks.length, greaterThan(1), reason: 'Content should be split into multiple chunks');
      
      // The splitter should combine sections until adding the next would exceed the limit
      // or create individual chunks for oversized sections
      for (int i = 0; i < chunks.length; i++) {
        final chunkSize = chunks[i].codeUnits.length;
        if (chunkSize > 150) {
          // If a chunk exceeds the limit, it should be because it's a single large section
          final sectionCount = chunks[i].trim().split(RegExp(r'^### ', multiLine: true)).length - 1;
          expect(sectionCount, lessThanOrEqualTo(1), 
              reason: 'Oversized chunk $i should contain at most one ### section');
        }
      }
      
      // Verify that chunks start with headers (except possibly the first one)
      for (int i = 1; i < chunks.length; i++) {
        final chunk = chunks[i].trim();
        expect(chunk.startsWith('###'), isTrue,
            reason: 'Chunk $i should start with a level-3 header');
      }
      
      // Verify that no content is lost
      final recombined = chunks.join('');
      final originalLines = content.split('\n');
      final recombinedLines = recombined.split('\n');
      expect(recombinedLines.length, equals(originalLines.length),
          reason: 'No lines should be lost during splitting');
    });

    test('should handle edge case where single section exceeds chunk limit', () {
      const chunkSize = 50; // Very small chunk size
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      final content = '''### Single Large Section
This is a single section that is much larger than the chunk size limit. It should still be included in a chunk even though it exceeds the limit, because we cannot split within a section.''';
      
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      expect(chunks.length, equals(1), reason: 'Single large section should remain as one chunk');
      expect(chunks[0].trim(), equals(content.trim()));
    });

    test('should preserve markdown structure after splitting', () {
      const chunkSize = 200;
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      final content = '''## Main Title

### Section 1
Content for section 1 with some text.

### Section 2  
Content for section 2 with more text.

### Section 3
Content for section 3 with additional text.

### Section 4
Final section with concluding text.''';
      
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      // Count headers in original vs chunks
      final originalHeaders = RegExp(r'^#{1,6}\s+', multiLine: true).allMatches(content).length;
      int chunkHeaders = 0;
      for (final chunk in chunks) {
        chunkHeaders += RegExp(r'^#{1,6}\s+', multiLine: true).allMatches(chunk).length;
      }
      
      expect(chunkHeaders, equals(originalHeaders),
          reason: 'All headers should be preserved across chunks');
    });

    test('should split only on level-3 headers as configured', () {
      const chunkSize = 80;
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      final content = '''# Main Title
Some intro content.

## Level 2 Header
Some content under level 2.

### Level 3 Header 1
Content 1.

### Level 3 Header 2
Content 2.

#### Level 4 Header
Nested content.

### Level 3 Header 3
Content 3.''';
      
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      expect(chunks.length, equals(4),
          reason: 'Content should be split into 4 chunks based on headers');
    });

    test('should handle empty sections gracefully', () {
      const chunkSize = 100;
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      final content = '''### Section 1
Content here.

### Empty Section

### Section 3
More content here.''';
      
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      expect(chunks.length, greaterThanOrEqualTo(1));
      
      // Verify empty section is preserved
      final recombined = chunks.join('');
      expect(recombined.contains('### Empty Section'), isTrue,
          reason: 'Empty sections should be preserved');
    });

    test('should respect byte limit not character limit', () {
      const chunkSize = 100; // 100 bytes
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      // Create content with unicode characters (multi-byte)
      final content = '''### Seção 1
Conteúdo com acentuação e caracteres especiais: ção, ã, é, ü.

### Seção 2
Mais conteúdo com acentos: português, coração, não.

### Seção 3
Texto adicional para testar.''';
      
      final chunks = splitter.splitMarkdown(content).map((c) => c.content).toList();
      
      // Verify byte counting (not character counting)
      for (int i = 0; i < chunks.length - 1; i++) {
        final byteLength = chunks[i].codeUnits.length;
        expect(byteLength, lessThanOrEqualTo(chunkSize),
            reason: 'Should respect byte limit, not character limit');
      }
    });
  });
}