import 'package:test/test.dart';
import 'dart:io';
import 'package:translator/translator.dart';
import 'package:translator/enhanced_parallel_chunk_processor_adapter.dart';

/// Test double for Translator that extends the real implementation
class TestTranslator extends Translator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    return text.trim();
  }
}

/// Test double that simulates translation errors for specific content
class ErrorTestTranslator extends TestTranslator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    if (text.contains('This text will cause translation error')) {
      throw Exception('Translation failed');
    }
    return super.translate(text,
        onFirstModelError: onFirstModelError, useSecond: useSecond);
  }
}

void main() {
  group('Code Block Anchor System - Acceptance Tests', () {
    late TestTranslator testTranslator;
    late EnhancedParallelChunkProcessorAdapter adapter;

    setUp(() {
      testTranslator = TestTranslator();
      adapter =
          EnhancedParallelChunkProcessorAdapter(translator: testTranslator);
    });

    group('End-to-End Pipeline Tests', () {
      test('should preserve fenced code blocks exactly during translation',
          () async {
        // Arrange
        const inputMarkdown = '''
# Test Document

This is some text to translate.

```dart
void main() {
  print('Hello World');
}
```

More text to translate.

```javascript
function hello() {
  return "world";
}
```

Final text to translate.
''';

        const expectedTranslatedText = '''
# Documento de Teste

Este é um texto para traduzir.

```dart
void main() {
  print('Hello World');
}
```

Mais texto para traduzir.

```javascript
function hello() {
  return "world";
}
```

Texto final para traduzir.
''';

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'test.md',
        );

        // Assert - With simple translator, content should be preserved with code blocks intact
        // Verify code blocks are preserved exactly
        expect(result, contains('void main() {\n  print(\'Hello World\');\n}'));
        expect(result, contains('function hello() {\n  return "world";\n}'));

        // Verify original text is preserved (since translator just trims)
        expect(result, contains('This is some text to translate'));
        expect(result, contains('More text to translate'));
        expect(result, contains('Final text to translate'));
      });

      test('should preserve inline code blocks during translation', () async {
        // Arrange
        const inputMarkdown = '''
# Inline Code Test

Use the `print()` function to output text.

The variable `userName` should be set.

Here is a complex example: `const config = { debug: true }`.
''';

        const expectedTranslated = '''
# Teste de Código Inline

Use a função `print()` para exibir texto.

A variável `userName` deve ser definida.

Aqui está um exemplo complexo: `const config = { debug: true }`.
''';

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'test.md',
        );

        // Assert - Verify inline code blocks are preserved
        expect(result, contains('`print()`'));
        expect(result, contains('`userName`'));
        expect(result, contains('`const config = { debug: true }`'));

        // Verify original text is preserved
        expect(result, contains('Use the `print()` function to output text'));
        expect(result, contains('The variable `userName` should be set'));
      });

      test('should handle mixed content with both fenced and inline code',
          () async {
        // Arrange
        const inputMarkdown = '''
# Mixed Code Example

First, use the `init()` method:

```dart
void init() {
  print('Initializing...');
}
```

Then call `start()` to begin processing.

```python
def start():
    return "Processing started"
```

Finally, check the `status` variable.
''';

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'test.md',
        );

        // Assert
        // Verify fenced code blocks preserved
        expect(result,
            contains('void init() {\n  print(\'Initializing...\');\n}'));
        expect(
            result, contains('def start():\n    return "Processing started"'));

        // Verify inline code preserved
        expect(result, contains('`init()`'));
        expect(result, contains('`start()`'));
        expect(result, contains('`status`'));

        // Verify original text is preserved (no translation with simple translator)
        expect(result, contains('First, use the'));
        expect(result, contains('Then call'));
        expect(result, contains('Finally, check the'));
      });

      test(
          'should handle large files with many code blocks and parallel processing',
          () async {
        // Arrange - Create a large markdown file with multiple code blocks
        final largeContent = StringBuffer();
        largeContent.writeln('# Large File Test');

        for (int i = 1; i <= 50; i++) {
          largeContent.writeln('\n## Section $i');
          largeContent.writeln(
              'This is content for section $i that needs translation.');
          largeContent.writeln('\n```dart');
          largeContent.writeln('// Code block $i');
          largeContent.writeln('void function$i() {');
          largeContent.writeln('  print("Function $i executed");');
          largeContent.writeln('}');
          largeContent.writeln('```');
          largeContent.writeln(
              '\nMore text in section $i with inline `code$i` example.');
        }

        // Act
        final result = await adapter.processMarkdownContent(
          largeContent.toString(),
          'large_test.md',
        );

        // Assert
        // Verify all code blocks are preserved
        for (int i = 1; i <= 50; i++) {
          expect(result, contains('// Code block $i'));
          expect(result, contains('void function$i() {'));
          expect(result, contains('print("Function $i executed")'));
          expect(result, contains('`code$i`'));
        }

        // Verify original text is preserved
        expect(result, contains('This is content for section'));
        expect(result, contains('that needs translation'));
        expect(result, contains('Large File Test'));

        // Verify structure is maintained
        expect(result, contains('# Large File Test'));
        for (int i = 1; i <= 50; i++) {
          expect(result, contains('## Section $i'));
        }
      });

      test('should handle nested and complex code block scenarios', () async {
        // Arrange
        const inputMarkdown = '''
# Complex Code Scenarios

Regular text before code.

```markdown
# This is markdown inside code
Use `inline code` inside the markdown.

```dart
// This would be nested, but should be treated as text inside markdown block
void example() {}
```
```

Text between code blocks.

```html
<script>
  const code = `
    // This is template literal inside script
    console.log('Hello');
  `;
</script>
```

Final text after code.
''';

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'complex_test.md',
        );

        // Assert
        // Verify nested content in markdown block is preserved
        expect(result, contains('# This is markdown inside code'));
        expect(result, contains('Use `inline code` inside the markdown.'));
        expect(result, contains('void example() {}'));

        // Verify script content is preserved
        expect(result, contains('<script>'));
        expect(result, contains('const code = `'));
        expect(result, contains('console.log(\'Hello\');'));

        // Verify original text is preserved
        expect(result, contains('Regular text before code'));
        expect(result, contains('Text between code blocks'));
        expect(result, contains('Final text after code'));
      });

      test(
          'should maintain file structure and validation after code block processing',
          () async {
        // Arrange - Use real test file to ensure integration
        final testFile =
            File('test/links/inputs/flutter_3_24_0_release_notes.md');
        if (!testFile.existsSync()) {
          // Skip if test file not available
          return;
        }

        final originalContent = await testFile.readAsString();

        // Act
        final result = await adapter.processMarkdownContent(
          originalContent,
          'flutter_3_24_0_release_notes.md',
        );

        // Assert
        // Verify structure is maintained (header count should be same)
        final originalHeaders = RegExp(r'^#+\s', multiLine: true)
            .allMatches(originalContent)
            .length;
        final resultHeaders =
            RegExp(r'^#+\s', multiLine: true).allMatches(result).length;
        expect(resultHeaders, equals(originalHeaders));

        // Verify code blocks are preserved
        final originalCodeBlocks =
            RegExp(r'```[\s\S]*?```').allMatches(originalContent).length;
        final resultCodeBlocks =
            RegExp(r'```[\s\S]*?```').allMatches(result).length;
        expect(resultCodeBlocks, equals(originalCodeBlocks));

        // Verify inline code is preserved
        final originalInlineCode =
            RegExp(r'`[^`\n]+`').allMatches(originalContent).length;
        final resultInlineCode = RegExp(r'`[^`\n]+`').allMatches(result).length;
        expect(resultInlineCode, equals(originalInlineCode));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle malformed code blocks gracefully', () async {
        // Arrange
        const inputMarkdown = '''
# Malformed Code Test

Normal text.

```dart
// Missing closing fence
void incomplete() {
  print("test");

More text after incomplete code block.

```python
# This one is complete
print("hello")
```

Final text.
''';

        // Act & Assert - Should not throw exception
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'malformed_test.md',
        );

        expect(result, isNotNull);
        expect(result, contains('Normal text'));
        expect(result, contains('Final text'));
      });

      test('should handle empty code blocks', () async {
        // Arrange
        const inputMarkdown = '''
# Empty Code Test

Text before empty code.

```
```

Text after empty code.

```dart
```

Final text.
''';

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'empty_code_test.md',
        );

        // Assert
        expect(result, contains('```\n```'));
        expect(result, contains('```dart\n```'));
        expect(result, contains('Text before empty code'));
        expect(result, contains('Text after empty code'));
      });

      test(
          'should handle translation errors gracefully while preserving code blocks',
          () async {
        // Arrange
        const inputMarkdown = '''
# Error Handling Test

This text will cause translation error.

```dart
void shouldBePreserved() {
  print('Always preserved');
}
```

This text should work fine.
''';

        // Create error translator that fails for specific content
        final errorTranslator = ErrorTestTranslator();
        adapter =
            EnhancedParallelChunkProcessorAdapter(translator: errorTranslator);

        // Act
        final result = await adapter.processMarkdownContent(
          inputMarkdown,
          'error_test.md',
        );

        // Assert
        // Code block should be preserved regardless of translation errors
        expect(result, contains('void shouldBePreserved() {'));
        expect(result, contains('print(\'Always preserved\');'));

        // Failed translation should fall back to original
        expect(result, contains('This text will cause translation error'));

        // Content should be preserved as-is with simple translator
        expect(result, contains('This text should work fine'));
      });
    });
  });
}
