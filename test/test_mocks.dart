import 'package:translator/translator.dart';
import '../bin/src/app.dart';

/// Interface to track file operations for testing
abstract class IFileOperationTracker {
  void onFileRead(String path, String content);
  void onFileWrite(String path, String content);
}

/// Mock translator for general testing
class MockTranslator implements Translator {
  int translateCallCount = 0;
  String? lastTranslatedText;
  String Function(String)? responseProvider;
  
  MockTranslator({this.responseProvider});
  
  @override
  Future<String> translate(String text, {
    required Function onFirstModelError, 
    bool useSecond = false
  }) async {
    translateCallCount++;
    lastTranslatedText = text;
    
    if (responseProvider != null) {
      return responseProvider!(text);
    }
    
    // Default: return the same text to preserve structure for testing
    // In real translation, the structure should be preserved by the AI model
    return text;
  }
}

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

/// Simple mock file wrapper for basic testing
class SimpleMockFileWrapper implements IFileWrapper {
  String content;
  final String _path;
  bool writeCalled = false;
  
  SimpleMockFileWrapper(this._path, this.content);
  
  @override
  String get path => _path;
  
  @override
  Future<String> readAsString() async => content;
  
  @override
  Future<void> writeAsString(String contents) async {
    content = contents;
    writeCalled = true;
  }
  
  @override
  Future<int> length() async => 2048; // Force large file processing
  
  @override
  Future<List<String>> readAsLines() async => content.split('\n');
  
  @override
  bool exists() => true;
}

/// Mock translator that simulates preserving structure for chunk joining tests
class StructurePreservingMockTranslator implements Translator {
  @override
  Future<String> translate(
    String content, {
    required Function onFirstModelError,
    bool useSecond = false,
  }) async {
    // Return content as-is but trim to simulate real AI behavior
    // This isolates the chunk joining bug from translation artifacts
    return content.trim();
  }
}

/// Mock translator that adds artifacts to simulate problematic real AI behavior
class MockTranslatorWithArtifacts implements Translator {
  @override
  Future<String> translate(
    String content, {
    required Function onFirstModelError,
    bool useSecond = false,
  }) async {
    // Simulate AI translator that adds prefixes or artifacts
    return '[TRANSLATED] $content';
  }
}

/// Mock translator that simulates real AI behavior - strips newlines and structure
class RealAIBehaviorMockTranslator implements Translator {
  @override
  Future<String> translate(
    String content, {
    required Function onFirstModelError,
    bool useSecond = false,
  }) async {
    // Simulate real AI translator that:
    // 1. Strips trailing newlines
    // 2. Sometimes removes blank lines
    // 3. Doesn't preserve exact formatting
    String result = content.trim(); // Remove leading/trailing whitespace
    
    // Simulate AI removing some blank lines (common AI behavior)
    result = result.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n'); // Multiple newlines -> double newline
    
    // Most importantly: AI often doesn't end chunks with newlines
    // This is the key difference from our previous mocks!
    return result; // No trailing newline!
  }
}