import 'package:test/test.dart';
import 'package:translator/translator.dart';
import '../bin/src/app.dart';
import 'markdown_structure_test.dart'; // For MarkdownStructureValidator

/// Mock translator that returns content with broken markdown structure
class MockBrokenStructureTranslator implements Translator {
  final String brokenResponse;
  
  MockBrokenStructureTranslator(this.brokenResponse);
  
  @override
  Future<String> translate(String text, {
    required Function onFirstModelError, 
    bool useSecond = false
  }) async {
    // Return content with intentionally broken structure
    return brokenResponse;
  }
}

/// Interface to track file operations for testing
abstract class IFileOperationTracker {
  void onFileRead(String path, String content);
  void onFileWrite(String path, String content);
}

/// Mock file wrapper that tracks write operations
class MockFileWrapper implements IFileWrapper {
  final String _content;
  String? writtenContent;
  final String _path;
  final int _length;
  final IFileOperationTracker? _tracker;
  bool _writeWasCalled = false;
  
  MockFileWrapper(this._path, this._content, {int? length, IFileOperationTracker? tracker}) 
    : _length = length ?? _content.length,
      _tracker = tracker;
  
  @override
  Future<String> readAsString() async {
    _tracker?.onFileRead(_path, _content);
    return _content;
  }
  
  @override
  Future<void> writeAsString(String content) async {
    _writeWasCalled = true;
    writtenContent = content;
    _tracker?.onFileWrite(_path, content);
  }
  
  @override
  String get path => _path;
  
  @override
  Future<int> length() async => _length;
  
  @override
  Future<List<String>> readAsLines() async => _content.split('\n');
  
  @override
  bool exists() => true;
  
  /// Check if writeAsString was called (for test assertions)
  bool get writeWasCalled => _writeWasCalled;
}

/// Test tracker to monitor file operations
class TestFileOperationTracker implements IFileOperationTracker {
  final List<String> readOperations = [];
  final List<String> writeOperations = [];
  
  @override
  void onFileRead(String path, String content) {
    readOperations.add('READ: $path');
  }
  
  @override
  void onFileWrite(String path, String content) {
    writeOperations.add('WRITE: $path');
  }
  
  bool get hasWrites => writeOperations.isNotEmpty;
  int get writeCount => writeOperations.length;
}

void main() {
  group('FileProcessor Structure Validation', () {
    test('demonstrates FileProcessorImpl saves broken markdown structure as successful', () async {
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

      // Verify structure is actually broken
      final isStructureBroken = !MarkdownStructureValidator.validateStructureConsistency(
        originalMarkdown,
        brokenTranslation
      );
      
      expect(isStructureBroken, isTrue, 
        reason: 'Test setup should have broken structure for demonstration');

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

      // Call translateOne - this should complete successfully despite broken structure
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

      // DEMONSTRATION: FileProcessorImpl currently treats broken structure as SUCCESS
      // This test should FAIL to demonstrate the issue
      expect(translationCompleted, isFalse, 
        reason: 'This test should FAIL - FileProcessorImpl incorrectly marks broken structure as successful');
      expect(translationFailed, isTrue, 
        reason: 'This test should FAIL - FileProcessorImpl should detect broken structure and call onFailed');
      
      // CRITICAL TEST: Verify that writeAsString was called (this is the problem!)
      expect(mockFile.writeWasCalled, isFalse, 
        reason: 'writeAsString should NOT be called when structure is broken, but it currently is!');
      expect(fileTracker.hasWrites, isFalse, 
        reason: 'No file writes should occur when structure validation fails');
      
      // This assertion will fail, demonstrating the issue
      expect(mockFile.writtenContent, isNull, 
        reason: 'No content should be written when structure is broken');
      
      // Show the actual problem in the output
      if (mockFile.writeWasCalled) {
        final writtenContent = mockFile.writtenContent!;
        
        // Extract the actual translated content (remove metadata)
        final contentWithoutMetadata = writtenContent
            .replaceFirst(RegExp(r'---\nia-translate: true\n'), '')
            .replaceFirst(RegExp(r'<!-- ia-translate: true -->\n'), '');
        
        print('\n=== ISSUE DEMONSTRATION ===');
        print('❌ writeAsString WAS CALLED when structure is broken!');
        print('❌ File writes occurred: ${fileTracker.writeCount}');
        print('❌ Original structure elements: ${MarkdownStructureValidator.extractStructure(originalMarkdown).length}');
        print('❌ Saved structure elements: ${MarkdownStructureValidator.extractStructure(contentWithoutMetadata).length}');
        print('❌ Translation marked as completed: $translationCompleted');
        print('This demonstrates the core issue: FileProcessor saves broken structure as successful!');
      }
    });

    test('shows different scenarios where structure breaks but translation succeeds', () async {
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

        // These tests should FAIL to demonstrate the issue
        expect(completed, isFalse, reason: 'Test case "$name" should FAIL - broken structure incorrectly marked as successful');
        expect(failed, isTrue, reason: 'Test case "$name" should call onFailed when structure is broken');
        expect(mockFile.writeWasCalled, isFalse, reason: 'writeAsString should NOT be called for "$name" when structure is broken');
        expect(fileTracker.hasWrites, isFalse, reason: 'No file writes should occur for "$name" when structure validation fails');
        
        if (mockFile.writeWasCalled) {
          print('❌ Test case "$name": writeAsString was called despite broken structure!');
        }
      }
    });
  });
}