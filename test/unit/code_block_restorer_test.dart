import 'package:test/test.dart';
import 'package:translator/code_block_extractor.dart';
import 'package:translator/code_block_restorer.dart';

void main() {
  group('CodeBlockRestorer', () {
    late CodeBlockExtractor extractor;
    late CodeBlockRestorer restorer;

    setUp(() {
      extractor = CodeBlockExtractor();
      restorer = CodeBlockRestorer();
    });

    group('Fenced Code Block Restoration', () {
      test('should restore single fenced code block correctly', () {
        // Arrange
        const originalContent = '''
# Header

Text before code.

```dart
void main() {
  print('Hello World');
}
```

Text after code.
''';

        const translatedCleanContent = '''
# Cabeçalho

Texto antes do código.

__EDOC_0__

Texto após o código.
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedCleanContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        expect(restoredContent, contains('```dart'));
        expect(restoredContent, contains('void main() {'));
        expect(restoredContent, contains('print(\'Hello World\');'));
        expect(restoredContent, contains('```'));
        expect(restoredContent, contains('Texto antes do código'));
        expect(restoredContent, contains('Texto após o código'));
        expect(restoredContent, isNot(contains('__EDOC_0__')));
      });

      test('should restore multiple fenced code blocks in correct order', () {
        // Arrange
        const originalContent = '''
# Multiple Blocks

First block:
```javascript
console.log('First');
```

Text between.

Second block:
```python
print('Second')
```

Final text.
''';

        const translatedCleanContent = '''
# Múltiplos Blocos

Primeiro bloco:
__EDOC_0__

Texto entre.

Segundo bloco:
__EDOC_1__

Texto final.
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedCleanContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        expect(restoredContent, contains('```javascript'));
        expect(restoredContent, contains('console.log(\'First\')'));
        expect(restoredContent, contains('```python'));
        expect(restoredContent, contains('print(\'Second\')'));
        expect(restoredContent, contains('Primeiro bloco'));
        expect(restoredContent, contains('Segundo bloco'));
        expect(restoredContent, isNot(contains('__EDOC_0__')));
        expect(restoredContent, isNot(contains('__EDOC_1__')));
      });

      test('should preserve code block formatting and indentation', () {
        // Arrange
        const originalContent = '''
Example:

    ```python
    def example():
        if True:
            print("Indented")
            return {
                'key': 'value',
                'nested': {
                    'deep': 'structure'
                }
            }
    ```
''';

        const translatedCleanContent = '''
Exemplo:

__EDOC_0__
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedCleanContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        expect(restoredContent, contains('    def example():'));
        expect(restoredContent, contains('        if True:'));
        expect(restoredContent, contains('            print("Indented")'));
        expect(restoredContent, contains('            return {'));
        expect(
            restoredContent, contains('                \'key\': \'value\','));
        expect(restoredContent, contains('                \'nested\': {'));
        expect(restoredContent,
            contains('                    \'deep\': \'structure\''));
      });
    });

    group('Mixed Code Block Restoration', () {
      test('should restore both fenced and inline code blocks correctly', () {
        // Arrange
        const originalContent = '''
# Mixed Example

Use `init()` first:

```dart
void init() {
  print('Starting...');
}
```

Then call `start()` method.
''';

        const translatedCleanContent = '''
# Exemplo Misto

Use `init()` primeiro:

__EDOC_0__

Então chame o método `start()`.
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedCleanContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        expect(restoredContent, contains('Use `init()` primeiro'));
        expect(restoredContent, contains('```dart'));
        expect(restoredContent, contains('void init() {'));
        expect(restoredContent, contains('print(\'Starting...\');'));
        expect(restoredContent, contains('Então chame o método `start()`.'));
        expect(restoredContent, isNot(contains('__EDOC_')));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle missing anchors gracefully', () {
        // Arrange
        const translatedContent = 'Text without any anchors to restore.';
        final emptyBlocks = <ExtractedCodeBlock>[];

        // Act
        final restoredContent =
            restorer.restoreCodeBlocks(translatedContent, emptyBlocks);

        // Assert
        expect(restoredContent, equals(translatedContent));
      });


     

      

      test('should preserve whitespace around restored code blocks', () {
        // Arrange
        const originalContent = '''
Text before.

```code
content
```

Text after.
''';

        const translatedContent = '''
Texto antes.

__EDOC_0__

Texto depois.
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        expect(restoredContent,
            contains('Texto antes.\n\n```code\ncontent\n```\n\nTexto depois.'));
      });
    });

    group('Integration with Real-World Scenarios', () {
      test('should handle complex markdown document structure', () {
        // Arrange
        const originalContent = '''
# API Documentation

## Authentication

Use the `Authorization` header:

```http
GET /api/users
Authorization: Bearer your-token-here
```

## User Management

### Create User

Call `POST /users` with:

```json
{
  "name": "John Doe",
  "email": "john@example.com"
}
```

Response includes `user.id` field.

### Update User

Use `PUT /users/{id}` endpoint:

```javascript
const response = await fetch('/users/123', {
  method: 'PUT',
  body: JSON.stringify(userData)
});
```

The `response.status` indicates success.
''';

        const translatedContent = '''
# Documentação da API

## Autenticação

Use o cabeçalho `Authorization`:

__EDOC_0__

## Gerenciamento de Usuários

### Criar Usuário

Chame `POST /users` com:

__EDOC_1__

A resposta inclui o campo `user.id`.

### Atualizar Usuário

Use o endpoint `PUT /users/{id}`:

```javascript
const response = await fetch('/users/123', {
  method: 'PUT',
  body: JSON.stringify(userData)
});
```

O `response.status` indica sucesso.
__EDOC_2__

O `response.status` indica sucesso.
''';

        final extractionResult = extractor.extractCodeBlocks(originalContent);

        // Act
        final restoredContent = restorer.restoreCodeBlocks(
          translatedContent,
          extractionResult.extractedBlocks,
        );

        // Assert
        // Verify structure maintained
        expect(restoredContent, contains('# Documentação da API'));
        expect(restoredContent, contains('## Autenticação'));
        expect(restoredContent, contains('### Criar Usuário'));

        // Verify inline code restored
        expect(restoredContent, contains('Use o cabeçalho `Authorization`:'));
        expect(restoredContent, contains('Chame `POST /users` com:'));
        expect(restoredContent, contains('campo `user.id`.'));
        expect(restoredContent, contains('endpoint `PUT /users/{id}`:'));
        expect(restoredContent, contains('O `response.status` indica'));

        // Verify fenced code blocks restored
        expect(restoredContent, contains('```http'));
        expect(restoredContent, contains('GET /api/users'));
        expect(
            restoredContent, contains('Authorization: Bearer your-token-here'));
        expect(restoredContent, contains('```json'));
        expect(restoredContent, contains('"name": "John Doe"'));
        expect(restoredContent, contains('```javascript'));
        expect(restoredContent, contains('const response = await fetch'));

        // Verify no anchors remain
        expect(restoredContent, isNot(contains('__EDOC_')));
      });
    });
  });
}
