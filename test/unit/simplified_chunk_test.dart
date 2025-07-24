import 'package:test/test.dart';
import '../../lib/simplified_chunk.dart';

void main() {
  group('SimplifiedChunk', () {
    group('Construction', () {
      test('should create chunk with manual size calculation', () {
        const content = 'Hello, World!';
        final chunk = SimplifiedChunk(
          content: content,
          utf8ByteSize: 13,
          codeUnitsSize: 13,
        );

        expect(chunk.content, equals(content));
        expect(chunk.utf8ByteSize, equals(13));
        expect(chunk.codeUnitsSize, equals(13));
      });

      test('should create chunk with automatic size calculation', () {
        const content = 'Hello, World!';
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content, equals(content));
        expect(chunk.utf8ByteSize, equals(13));
        expect(chunk.codeUnitsSize, equals(13));
      });

      test('should handle UTF-8 multibyte characters correctly', () {
        const content = 'Olá, Mundo! 🌍'; // Contains accented chars and emoji
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content, equals(content));
        expect(chunk.utf8ByteSize, equals(17)); // More bytes than code units due to UTF-8
        expect(chunk.codeUnitsSize, equals(14)); // Number of UTF-16 code units
      });

      test('should handle empty content', () {
        const content = '';
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content, equals(''));
        expect(chunk.utf8ByteSize, equals(0));
        expect(chunk.codeUnitsSize, equals(0));
      });
    });

    group('Properties', () {
      test('should always be translatable', () {
        final chunk1 = SimplifiedChunk.fromContent('Regular text');
        final chunk2 = SimplifiedChunk.fromContent('Text with anchors __CODE_BLOCK_ANCHOR_0__');
        final chunk3 = SimplifiedChunk.fromContent('Mixed content __INLINE_CODE_ANCHOR_1__ here');

        expect(chunk1.isTranslatable, isTrue);
        expect(chunk2.isTranslatable, isTrue);
        expect(chunk3.isTranslatable, isTrue);
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when all properties match', () {
        final chunk1 = SimplifiedChunk.fromContent('Test content');
        final chunk2 = SimplifiedChunk.fromContent('Test content');

        expect(chunk1, equals(chunk2));
        expect(chunk1.hashCode, equals(chunk2.hashCode));
      });

      test('should not be equal when content differs', () {
        final chunk1 = SimplifiedChunk.fromContent('Test content 1');
        final chunk2 = SimplifiedChunk.fromContent('Test content 2');

        expect(chunk1, isNot(equals(chunk2)));
      });

      test('should not be equal when sizes differ (manual construction)', () {
        final chunk1 = SimplifiedChunk(
          content: 'Test',
          utf8ByteSize: 4,
          codeUnitsSize: 4,
        );
        final chunk2 = SimplifiedChunk(
          content: 'Test',
          utf8ByteSize: 5, // Different size
          codeUnitsSize: 4,
        );

        expect(chunk1, isNot(equals(chunk2)));
      });
    });

    group('String Representation', () {
      test('should provide informative toString', () {
        final chunk = SimplifiedChunk.fromContent('Hello, World!');
        final stringRep = chunk.toString();

        expect(stringRep, contains('SimplifiedChunk'));
        expect(stringRep, contains('utf8Bytes: 13'));
        expect(stringRep, contains('codeUnits: 13'));
        expect(stringRep, contains('content: 13 chars'));
      });

      test('should handle long content in toString', () {
        final longContent = 'A' * 1000;
        final chunk = SimplifiedChunk.fromContent(longContent);
        final stringRep = chunk.toString();

        expect(stringRep, contains('content: 1000 chars'));
        expect(stringRep, contains('utf8Bytes: 1000'));
      });
    });

    group('Edge Cases', () {
      test('should handle content with only whitespace', () {
        const content = '   \n\n\t  ';
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content, equals(content));
        expect(chunk.utf8ByteSize, equals(content.length));
        expect(chunk.isTranslatable, isTrue);
      });

      test('should handle content with newlines and special characters', () {
        const content = 'Line 1\nLine 2\n\nWith\ttabs\rand\r\ncarriage returns';
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content, equals(content));
        expect(chunk.isTranslatable, isTrue);
      });

      test('should handle very long single-line content', () {
        final content = 'Long content ' * 1000;
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.content.length, equals(13000));
        expect(chunk.isTranslatable, isTrue);
      });
    });

    group('Size Calculations', () {
      test('should correctly calculate UTF-8 byte size for ASCII', () {
        const content = 'Hello World';
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.utf8ByteSize, equals(11));
        expect(chunk.codeUnitsSize, equals(11));
      });

      test('should correctly calculate UTF-8 byte size for Latin characters', () {
        const content = 'Café résumé naïve'; // Characters with accents
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.utf8ByteSize, greaterThan(chunk.codeUnitsSize));
        expect(chunk.codeUnitsSize, equals(17)); // Number of UTF-16 code units
      });

      test('should correctly calculate UTF-8 byte size for emoji', () {
        const content = 'Hello 👋 World 🌍'; // Emoji characters
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.utf8ByteSize, equals(21)); // UTF-8 bytes for emoji
        expect(chunk.codeUnitsSize, equals(17)); // String length in code units
      });

      test('should correctly calculate UTF-8 byte size for mixed content', () {
        const content = 'ASCII + Café + 🌍 + 中文'; // Mixed character types
        final chunk = SimplifiedChunk.fromContent(content);

        expect(chunk.utf8ByteSize, greaterThan(chunk.codeUnitsSize));
        expect(chunk.content.length, equals(chunk.codeUnitsSize));
      });
    });
  });
}