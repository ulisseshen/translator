import 'package:test/test.dart';
import '../bin/src/app.dart';
import 'test_mocks.dart';

void main() {
  group('FileProcessor Structure Validation', () {
    test('validates FileProcessorImpl correctly rejects broken markdown structure', () async {
      // Original markdown with clear structure
      const originalMarkdown = '''
# Flutter Widget Guide
## State Management
### Using setState
Follow these steps:
- Create a StatefulWidget
- Override createState()
- Call setState() to update

### Best Practices
**Important**: Always dispose controllers.
*Remember*: Use const constructors when possible.

#### Example Code
```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}
```

## Resources
- [Flutter Documentation](https://flutter.dev)
- [Dart Guide](https://dart.dev)

> Always test your widgets thoroughly!
''';

      // Simulated broken translation - missing structure elements
      const brokenTranslation = '''
Guia de Widget Flutter

Gerenciamento de Estado
Usando setState
Siga estes passos:
Crie um StatefulWidget
Sobrescreva createState()
Chame setState() para atualizar

Melhores Práticas
Importante: Sempre descarte controladores.
Lembre-se: Use construtores const quando possível.

Exemplo de Código
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

Recursos
Flutter Documentation
Dart Guide

Sempre teste seus widgets completamente!
''';

      // Verify structure is actually broken for test setup
      final isStructureBroken = !MarkdownStructureValidator.validateStructureConsistency(
        originalMarkdown,
        brokenTranslation
      );
      
      expect(isStructureBroken, isTrue, 
        reason: 'Test setup validation: broken structure should be detected');

      // Create mocks with file operation tracking
      final fileTracker = TestFileOperationTracker();
      final mockTranslator = MockBrokenStructureTranslator(brokenTranslation);
      final mockFile = MockFileWrapper('/test/file.md', originalMarkdown, tracker: fileTracker);
      final mockMarkdownProcessor = MarkdownProcessorImpl();
      
      // Create FileProcessorImpl
      final fileProcessor = FileProcessorImpl(
        mockTranslator,
        mockMarkdownProcessor,
      );

      // Track completion/failure
      bool translationCompleted = false;
      bool translationFailed = false;

      // Call translateOne - should now fail due to structure validation
      await fileProcessor.translateOne(
        mockFile,
        false, // processLargeFiles
        mockTranslator,
        false, // useSecond
        onComplete: () {
          translationCompleted = true;
        },
        onFailed: () {
          translationFailed = true;
        },
      );

      // Verify structure validation works correctly
      expect(translationCompleted, isFalse, 
        reason: 'Translation should not complete when structure is broken');
      expect(translationFailed, isTrue, 
        reason: 'Translation should fail when structure validation detects issues');
      
      // Verify file operations are prevented when structure is broken
      expect(mockFile.writeWasCalled, isFalse, 
        reason: 'File should not be written when structure validation fails');
      expect(fileTracker.hasWrites, isFalse, 
        reason: 'No file writes should occur when structure validation fails');
      
      // Verify no content was written
      expect(mockFile.writtenContent, isNull, 
        reason: 'No content should be written when structure validation fails');
    });

    test('validates structure detection across multiple scenarios', () async {
      // Single test case: Missing header levels
      const original = '''
# Main Title
## Subtitle
### Subsubtitle
Content here
''';
      const broken = '''
Main Title
Subtitle
Subsubtitle
Content here
''';
      const name = 'Missing header levels';

      // Verify this test case actually has broken structure
      final isActuallyBroken = !MarkdownStructureValidator.validateStructureConsistency(original, broken);
      expect(isActuallyBroken, isTrue, reason: 'Test case "$name" should have broken structure');

      // Test with FileProcessorImpl and file tracking
      final fileTracker = TestFileOperationTracker();
      final mockTranslator = MockBrokenStructureTranslator(broken);
      final mockFile = MockFileWrapper('/test/$name.md', original, tracker: fileTracker);
      final mockMarkdownProcessor = MarkdownProcessorImpl();

      final fileProcessor = FileProcessorImpl(mockTranslator, mockMarkdownProcessor);

      bool completed = false;
      bool failed = false;
      await fileProcessor.translateOne(
        mockFile,
        false,
        mockTranslator,
        false,
        onComplete: () => completed = true,
        onFailed: () => failed = true,
      );

      // Verify structure validation correctly rejects broken translations
      expect(completed, isFalse, reason: 'Test case "$name" should not complete when structure is broken');
      expect(failed, isTrue, reason: 'Test case "$name" should fail when structure validation detects issues');
      expect(mockFile.writeWasCalled, isFalse, reason: 'File should not be written for "$name" when structure is broken');
      expect(fileTracker.hasWrites, isFalse, reason: 'No file writes should occur for "$name" when structure validation fails');
    });

    test('validates FileProcessorImpl correctly rejects broken reference links', () async {
      // Original markdown with reference-style links
      const originalMarkdown = '''
# API Documentation
## Authentication
To authenticate, visit [our docs][auth-docs] and follow the [setup guide][setup].

### Getting Started
1. Read [the introduction][intro]
2. Check [examples][examples]

[auth-docs]: https://api.example.com/auth
[setup]: https://api.example.com/setup
[intro]: https://api.example.com/intro
[examples]: https://api.example.com/examples
''';

      // Simulated translation where AI translated reference labels but not definitions
      const brokenLinkTranslation = '''
# Documentação da API
## Autenticação
Para autenticar, visite [nossa documentação][nossa-doc] e siga o [guia de configuração][configuracao].

### Começando
1. Leia [a introdução][introducao]
2. Confira [exemplos][exemplos]

[auth-docs]: https://api.example.com/auth
[setup]: https://api.example.com/setup
[intro]: https://api.example.com/intro
[examples]: https://api.example.com/examples
''';

      // Verify links are actually broken for test setup
      final areLinksBroken = !MarkdownStructureValidator.validateStructureAndLinks(
        originalMarkdown,
        brokenLinkTranslation
      );
      
      expect(areLinksBroken, isTrue, 
        reason: 'Test setup validation: broken reference links should be detected');

      // Create mocks with file operation tracking
      final fileTracker = TestFileOperationTracker();
      final mockTranslator = MockBrokenStructureTranslator(brokenLinkTranslation);
      final mockFile = MockFileWrapper('/test/api-docs.md', originalMarkdown, tracker: fileTracker);
      final mockMarkdownProcessor = MarkdownProcessorImpl();
      
      // Create FileProcessorImpl
      final fileProcessor = FileProcessorImpl(
        mockTranslator,
        mockMarkdownProcessor,
      );

      // Track completion/failure
      bool translationCompleted = false;
      bool translationFailed = false;

      // Call translateOne - should fail due to broken reference links
      await fileProcessor.translateOne(
        mockFile,
        false, // processLargeFiles
        mockTranslator,
        false, // useSecond
        onComplete: () {
          translationCompleted = true;
        },
        onFailed: () {
          translationFailed = true;
        },
      );

      // Verify link validation works correctly in file processor
      expect(translationCompleted, isFalse, 
        reason: 'Translation should not complete when reference links are broken');
      expect(translationFailed, isTrue, 
        reason: 'Translation should fail when link validation detects broken references');
      
      // Verify file operations are prevented when links are broken
      expect(mockFile.writeWasCalled, isFalse, 
        reason: 'File should not be written when reference link validation fails');
      expect(fileTracker.hasWrites, isFalse, 
        reason: 'No file writes should occur when reference link validation fails');
      
      // Verify no content was written
      expect(mockFile.writtenContent, isNull, 
        reason: 'No content should be written when reference link validation fails');
    });

    test('validates FileProcessorImpl accepts correct reference links', () async {
      // Original markdown with reference-style links
      const originalMarkdown = '''
# User Guide
Visit [our website][website] for more information.

[website]: https://example.com
''';

      // Properly translated version maintaining link functionality
      const correctTranslation = '''
# Guia do Usuário
Visite [nosso site][website] para mais informações.

[website]: https://example.com
''';

      // Verify links are valid for test setup
      final areLinksValid = MarkdownStructureValidator.validateStructureAndLinks(
        originalMarkdown,
        correctTranslation
      );
      
      expect(areLinksValid, isTrue, 
        reason: 'Test setup validation: correct reference links should be valid');

      // Create mocks
      final fileTracker = TestFileOperationTracker();
      final mockTranslator = MockBrokenStructureTranslator(correctTranslation);
      final mockFile = MockFileWrapper('/test/user-guide.md', originalMarkdown, tracker: fileTracker);
      final mockMarkdownProcessor = MarkdownProcessorImpl();
      
      final fileProcessor = FileProcessorImpl(
        mockTranslator,
        mockMarkdownProcessor,
      );

      bool translationCompleted = false;
      bool translationFailed = false;

      // Call translateOne - should succeed with correct links
      await fileProcessor.translateOne(
        mockFile,
        false,
        mockTranslator,
        false,
        onComplete: () {
          translationCompleted = true;
        },
        onFailed: () {
          translationFailed = true;
        },
      );

      // Verify correct links allow translation to proceed
      expect(translationCompleted, isTrue, 
        reason: 'Translation should complete when reference links are correct');
      expect(translationFailed, isFalse, 
        reason: 'Translation should not fail when link validation passes');
      
      // Verify file was written
      expect(mockFile.writeWasCalled, isTrue, 
        reason: 'File should be written when reference link validation passes');
      expect(mockFile.writtenContent, contains(correctTranslation.trim()), 
        reason: 'Correct translated content should be written');
      expect(mockFile.writtenContent, contains('<!-- ia-translate: true -->'), 
        reason: 'Should contain the ia-translate marker');
    });

    test('validates FileProcessorImpl correctly identifies both structure and link errors', () async {
      // Original markdown with structure and reference links
      const originalMarkdown = '''
# API Guide
## Setup
Follow [our guide][setup-guide].

[setup-guide]: https://example.com/setup
''';

      // Translation with BOTH structure issues (missing headers) AND broken links
      const brokenBothTranslation = '''
API Guide
Setup
Follow [nosso guia][nosso-guia].

[setup-guide]: https://example.com/setup
''';

      // Verify both structure and links are broken
      final validationResult = MarkdownStructureValidator.validateStructureAndLinksDetailed(
        originalMarkdown,
        brokenBothTranslation
      );
      expect(validationResult.isValid, isFalse);
      
      final structureValid = MarkdownStructureValidator.validateStructureConsistency(originalMarkdown, brokenBothTranslation);
      expect(structureValid, isFalse, reason: 'Structure should be broken (missing headers)');
      expect(validationResult.linkValidation.isValid, isFalse, reason: 'Links should be broken');

      // Create mocks
      final fileTracker = TestFileOperationTracker();
      final mockTranslator = MockBrokenStructureTranslator(brokenBothTranslation);
      final mockFile = MockFileWrapper('/test/both-broken.md', originalMarkdown, tracker: fileTracker);
      final mockMarkdownProcessor = MarkdownProcessorImpl();
      
      final fileProcessor = FileProcessorImpl(
        mockTranslator,
        mockMarkdownProcessor,
      );

      bool translationCompleted = false;
      bool translationFailed = false;

      // Call translateOne - should fail with both errors
      await fileProcessor.translateOne(
        mockFile,
        false,
        mockTranslator,
        false,
        onComplete: () {
          translationCompleted = true;
        },
        onFailed: () {
          translationFailed = true;
        },
      );

      // Verify both errors are detected
      expect(translationCompleted, isFalse, 
        reason: 'Translation should not complete when both structure and links are broken');
      expect(translationFailed, isTrue, 
        reason: 'Translation should fail when both validation types detect issues');
      
      expect(mockFile.writeWasCalled, isFalse, 
        reason: 'File should not be written when both validations fail');
      expect(fileTracker.hasWrites, isFalse, 
        reason: 'No file writes should occur when both validations fail');
    });
  });
}