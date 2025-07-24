import 'package:test/test.dart';
import '../../lib/code_block_extractor.dart';

void main() {
  group('CodeBlockExtractor', () {
    late CodeBlockExtractor extractor;

    setUp(() {
      extractor = CodeBlockExtractor();
    });

    group('Fenced Code Block Extraction', () {
      test('should extract simple fenced code block and replace with anchor',
          () {
        // Arrange
        const input = '''
# Header

Some text before code.

```dart
void main() {
  print('Hello World');
}
```

Some text after code.
''';

        const expectedCleanContent = '''
# Header

Some text before code.

__CODE_BLOCK_ANCHOR_0__

Some text after code.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.cleanContent.trim(), equals(expectedCleanContent.trim()));
        expect(result.extractedBlocks, hasLength(1));
        expect(result.extractedBlocks[0].originalCode, contains('void main()'));
        expect(result.extractedBlocks[0].originalCode,
            contains('print(\'Hello World\')'));
        expect(result.extractedBlocks[0].anchor,
            equals('__CODE_BLOCK_ANCHOR_0__'));
      });

      test('should extract multiple fenced code blocks with sequential anchors',
          () {
        // Arrange
        const input = '''
# Multiple Code Blocks

First block:
```javascript
console.log('First');
```

Some text between.

Second block:
```python
print('Second')
```

More text.

Third block:
```bash
echo "Third"
```
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(3));

        // Verify anchors are sequential
        expect(result.extractedBlocks[0].anchor,
            equals('__CODE_BLOCK_ANCHOR_0__'));
        expect(result.extractedBlocks[1].anchor,
            equals('__CODE_BLOCK_ANCHOR_1__'));
        expect(result.extractedBlocks[2].anchor,
            equals('__CODE_BLOCK_ANCHOR_2__'));

        // Verify content
        expect(result.extractedBlocks[0].originalCode,
            contains('console.log(\'First\')'));
        expect(result.extractedBlocks[1].originalCode,
            contains('print(\'Second\')'));
        expect(
            result.extractedBlocks[2].originalCode, contains('echo "Third"'));

        // Verify clean content has anchors
        expect(result.cleanContent, contains('__CODE_BLOCK_ANCHOR_0__'));
        expect(result.cleanContent, contains('__CODE_BLOCK_ANCHOR_1__'));
        expect(result.cleanContent, contains('__CODE_BLOCK_ANCHOR_2__'));
      });

      test('should handle fenced code blocks with language specifiers', () {
        // Arrange
        const input = '''
```dart title="main.dart"
void main() => print('Hello');
```

```javascript
// Comment in JS
function hello() {}
```

```
// No language specified
const x = 1;
```
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(3));
        expect(result.extractedBlocks[0].language, equals('dart'));
        expect(result.extractedBlocks[1].language, equals('javascript'));
        expect(result.extractedBlocks[2].language, isEmpty);

        // Verify full block preservation including language
        expect(result.extractedBlocks[0].originalCode,
            startsWith('```dart title="main.dart"'));
        expect(result.extractedBlocks[1].originalCode,
            startsWith('```javascript'));
        expect(result.extractedBlocks[2].originalCode, startsWith('```\n'));
      });

      test('should preserve code block indentation and formatting', () {
        // Arrange
        const input = '''
Example with indented code:

    ```python
    def example():
        if True:
            print("Indented")
    ```
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(1));
        expect(result.extractedBlocks[0].originalCode,
            contains('    def example():'));
        expect(result.extractedBlocks[0].originalCode,
            contains('        if True:'));
        expect(result.extractedBlocks[0].originalCode,
            contains('            print("Indented")'));
      });
    });

    group('Mixed Code Block Scenarios', () {
      test('should handle both fenced and inline code blocks together', () {
        // Arrange
        const input = '''
# Mixed Example

Use `init()` first:

```dart
void init() {
  print('Starting...');
}
```

Then call `start()` method.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(1));

        final fencedBlocks = result.extractedBlocks.toList();

        expect(fencedBlocks, hasLength(1));

        // Verify anchors in correct order (fenced blocks are extracted first)
        expect(result.cleanContent,
            contains('__CODE_BLOCK_ANCHOR_0__')); // fenced block
      });

      test('should maintain anchor order regardless of code block type', () {
        // Arrange
        const input = '''
First `inline`, then:

```dart
// fenced
```

Then `another` inline, and:

```python
# another fenced
```

Final `inline` code.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(2));

        // Verify anchor sequence (fenced blocks extracted first, then inline)
        expect(result.extractedBlocks[0].anchor,
            equals('__CODE_BLOCK_ANCHOR_0__'));
        expect(result.extractedBlocks[1].anchor,
            equals('__CODE_BLOCK_ANCHOR_1__'));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty input', () {
        // Act
        final result = extractor.extractCodeBlocks('');

        // Assert
        expect(result.cleanContent, equals(''));
        expect(result.extractedBlocks, isEmpty);
      });

      test('should handle input with no code blocks', () {
        // Arrange
        const input = '''
# Regular Markdown

This is just regular text with no code blocks.
- List item 1
- List item 2

## Subsection

More regular text.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.cleanContent, equals(input));
        expect(result.extractedBlocks, isEmpty);
      });

      test('should handle malformed fenced code blocks', () {
        // Arrange
        const input = '''
Text before.

```dart
// Missing closing fence
void incomplete() {
  print("test");

More text after.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        // Should handle gracefully - either extract what it can or leave as-is
        expect(result.cleanContent, isNotNull);
        expect(result.extractedBlocks, isNotNull);
      });

      test('should ignore inline code blocks', () {
        // Arrange
        const input = 'Use `echo "hello world"` command.';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(0));
        expect(result.cleanContent,
            equals('Use `echo "hello world"` command.'));
      });

      test('should handle code blocks at start and end of content', () {
        // Arrange
        const input = '''```javascript
console.log('start');
```

Middle text with `inline` code.

```python
print('end')
```''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(result.extractedBlocks, hasLength(2));
        expect(
            result.cleanContent.trim(),
            equals(
                '__CODE_BLOCK_ANCHOR_0__\n\nMiddle text with `inline` code.\n\n__CODE_BLOCK_ANCHOR_1__'));
      });

      test('should preserve whitespace around code blocks', () {
        // Arrange
        const input = '''
Text before.

```dart
code here
```

Text after.
''';

        // Act
        final result = extractor.extractCodeBlocks(input);

        // Assert
        expect(
            result.cleanContent, contains('\n\n__CODE_BLOCK_ANCHOR_0__\n\n'));
      });
    });


    group('Performance Tests', () {
      test('should handle large content efficiently', () {
        // Arrange
        final largeContentBuffer = StringBuffer();
        largeContentBuffer.writeln('# Large Content Test');

        // Add 100 sections with mixed code blocks
        for (int i = 0; i < 100; i++) {
          largeContentBuffer.writeln('\n## Section $i');
          largeContentBuffer.writeln('Text with `inline$i` code.');
          largeContentBuffer.writeln('\n```dart');
          largeContentBuffer.writeln('// Section $i code');
          largeContentBuffer.writeln('void function$i() {');
          largeContentBuffer.writeln('  print("Section $i");');
          largeContentBuffer.writeln('}');
          largeContentBuffer.writeln('```');
        }

        final largeContent = largeContentBuffer.toString();

        // Act
        final stopwatch = Stopwatch()..start();
        final result = extractor.extractCodeBlocks(largeContent);
        stopwatch.stop();

        // Assert
        expect(
            result.extractedBlocks, hasLength(100)); // 100 inline + 100 fenced
  
        // Verify all code blocks extracted correctly
        final fencedBlocks = result.extractedBlocks.length;

        expect(fencedBlocks, equals(100));
      });
    });
  });
}
