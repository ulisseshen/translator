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
      final testCases = [
        {
          'name': 'Missing header levels',
          'original': '''
# Main Title
## Subtitle
### Subsubtitle
Content here
''',
          'broken': '''
Main Title
Subtitle
Subsubtitle
Content here
''',
        },
        {
          'name': 'Lost list formatting',
          'original': '''
# Instructions
- Step 1
- Step 2
- Step 3
''',
          'broken': '''
# Instructions
Step 1
Step 2  
Step 3
''',
        },
        {
          'name': 'Missing code blocks',
          'original': '''
# Code Example
```dart
void main() {
  print('Hello');
}
```
''',
          'broken': '''
# Code Example
void main() {
  print('Hello');
}
''',
        },
      ];

      for (final testCase in testCases) {
        final original = testCase['original'] as String;
        final broken = testCase['broken'] as String;
        final name = testCase['name'] as String;
        
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
      }
    });
  });
}