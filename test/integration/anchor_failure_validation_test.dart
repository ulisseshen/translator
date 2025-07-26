import 'package:test/test.dart';
import 'dart:io';
import 'package:translator/translator.dart';
import 'package:translator/enhanced_parallel_chunk_processor_adapter.dart';

/// Test double that intentionally breaks anchor restoration by modifying anchor patterns
class MaliciousAnchorBreakingTranslator extends Translator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    // Intentionally corrupt anchor patterns to simulate restoration failure
    String result = text.trim();
    
    // Break fenced code block anchors by modifying them
    result = result.replaceAll('__EDOC_', '__BROKEN_CODE_ANCHOR_');
    
    // Break inline code anchors by modifying them  
    result = result.replaceAll('__INLINE_CODE_ANCHOR_', '__BROKEN_INLINE_ANCHOR_');
    
    return result;
  }
}

/// Test double that removes anchor patterns entirely
class AnchorRemovingTranslator extends Translator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    String result = text.trim();
    
    // Remove all anchor patterns entirely
    result = result.replaceAll(RegExp(r'__EDOC_\d+__'), '');
    result = result.replaceAll(RegExp(r'__INLINE_CODE_ANCHOR_\d+__'), '');
    
    return result;
  }
}

/// Test double that replaces anchors with wrong content
class WrongContentTranslator extends Translator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    String result = text.trim();
    
    // Replace anchors with wrong content
    result = result.replaceAll(RegExp(r'__EDOC_\d+__'), 'WRONG_CODE');
    result = result.replaceAll(RegExp(r'__INLINE_CODE_ANCHOR_\d+__'), 'WRONG_INLINE');
    
    return result;
  }
}

void main() {
  group('Anchor Failure Validation Tests', () {
    test('should throw exception when code block anchors are corrupted by translator', () async {
      // Arrange
      const inputMarkdown = '''
# Test Document

This is some text to translate.

```dart
void main() {
  print('Hello World');
}
```

More text with `inline code` example.

```javascript
function hello() {
  return "world";
}
```

Final text to translate.
''';

      final maliciousTranslator = MaliciousAnchorBreakingTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: maliciousTranslator);

      // Act & Assert - Should throw exception due to anchor corruption
      expect(
        () async => await adapter.processMarkdownContent(
          inputMarkdown,
          'test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for test.md'),
        )),
      );
      
      print('✅ Successfully detected anchor corruption by malicious translator');
    });

    test('should throw exception when anchors are completely removed by translator', () async {
      // Arrange
      const inputMarkdown = '''
# Anchor Removal Test

Text before code block.

```python
def test_function():
    return "test"
```

Text with `inline` code.

Final text.
''';

      final anchorRemovingTranslator = AnchorRemovingTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: anchorRemovingTranslator);

      // Act & Assert - Should throw exception due to anchor removal
      expect(
        () async => await adapter.processMarkdownContent(
          inputMarkdown,
          'removal_test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for removal_test.md'),
        )),
      );
      
      print('✅ Successfully detected anchor removal by malicious translator');
    });

    test('should throw exception when anchors are replaced with wrong content', () async {
      // Arrange
      const inputMarkdown = '''
# Wrong Content Test

Sample text.

```bash
echo "Hello World"
ls -la
```

Text with `variable` reference.
''';

      final wrongContentTranslator = WrongContentTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: wrongContentTranslator);

      // Act & Assert - Should throw exception due to wrong content replacement
      expect(
        () async => await adapter.processMarkdownContent(
          inputMarkdown,
          'wrong_content_test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for wrong_content_test.md'),
        )),
      );
      
      print('✅ Successfully detected wrong content replacement');
    });

    test('should validate restoration success flag in statistics', () async {
      // Arrange
      const inputMarkdown = '''
# Validation Test

Content with code blocks.

```java
public class Test {
    public static void main(String[] args) {
        System.out.println("Hello");
    }
}
```

Inline `code` example.
''';

      // Test with normal translator (should succeed)
      final normalAdapter = EnhancedParallelChunkProcessorAdapter(translator: TestTranslator());
      
      // Test with malicious translator (should fail restoration)
      final maliciousAdapter = EnhancedParallelChunkProcessorAdapter(translator: MaliciousAnchorBreakingTranslator());

      // Act & Assert - Normal translator should succeed
      final normalResult = await normalAdapter.processMarkdownContent(
        inputMarkdown,
        'normal_test.md',
        saveDebugInfo: true, // This will save statistics we can verify
      );
      
      // Normal result should have proper code blocks
      expect(normalResult, contains('public class Test'));
      expect(normalResult, contains('`code`'));
      expect(normalResult, isNot(contains('__EDOC_')));
      expect(normalResult, isNot(contains('__INLINE_CODE_ANCHOR_')));

      // Act & Assert - Malicious translator should fail with exception
      expect(
        () async => await maliciousAdapter.processMarkdownContent(
          inputMarkdown,
          'malicious_test.md',
          saveDebugInfo: true,
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for malicious_test.md'),
        )),
      );
      
      print('✅ Validation successful: normal translator preserved code, malicious translator failed validation');
    });

    test('should throw exception when using real files and anchor restoration fails', () async {
      // Arrange - Try to use a real file if available
      final testFile = File('test/links/inputs/input.md');
      if (!testFile.existsSync()) {
        markTestSkipped('Real test file not available for anchor failure test');
        return;
      }

      final originalContent = await testFile.readAsString();
      
      // Only test if file has code blocks
      if (!originalContent.contains('```') && !RegExp(r'`[^`]+`').hasMatch(originalContent)) {
        markTestSkipped('Test file has no code blocks for anchor failure test');
        return;
      }

      final maliciousTranslator = MaliciousAnchorBreakingTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: maliciousTranslator);

      // Act & Assert - Should throw exception due to anchor corruption in real file
      expect(
        () async => await adapter.processMarkdownContent(
          originalContent,
          'real_file_anchor_test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for real_file_anchor_test.md'),
        )),
      );
      
      // Count original code blocks for informational purposes
      final originalCodeBlocks = RegExp(r'```[\s\S]*?```').allMatches(originalContent).length;
      final originalInlineCode = RegExp(r'`[^`\n]+`').allMatches(originalContent).length;  
      
      print('📊 Real file anchor failure validation:');
      print('   Original fenced code blocks: $originalCodeBlocks');
      print('   Original inline code blocks: $originalInlineCode');
      print('   Malicious translator would have corrupted all anchors');
      
      print('✅ Successfully demonstrated anchor failure validation on real file');
    });

    test('should throw exception by default when anchors are corrupted', () async {
      // Arrange
      const inputMarkdown = '''
# Fail Test

Text with code.

```python
def hello():
    return "world"
```

Inline `code` example.
''';

      final maliciousTranslator = MaliciousAnchorBreakingTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: maliciousTranslator);

      // Act & Assert - Should throw exception by default when anchors are corrupted
      expect(
        () async => await adapter.processMarkdownContent(
          inputMarkdown,
          'fail_test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for fail_test.md'),
        )),
      );

      print('✅ Successfully demonstrated translation failure with default validation');
    });

    test('should throw exception with anchor removal translator due to default validation', () async {
      // Arrange
      const inputMarkdown = '''
# Removal Test

Text with code.

```javascript
console.log("hello");
```

Inline `variable` example.
''';

      final anchorRemovingTranslator = AnchorRemovingTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: anchorRemovingTranslator);

      // Act & Assert - Should throw exception due to default validation
      expect(
        () async => await adapter.processMarkdownContent(
          inputMarkdown,
          'removal_test.md',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Code block restoration failed for removal_test.md'),
        )),
      );
      
      print('✅ Confirmed that anchor removal causes failure with default validation');
    });

    test('should work normally with proper translator with default validation', () async {
      // Arrange
      const inputMarkdown = '''
# Normal Test

This should work fine.

```dart
void main() {
  print('success');
}
```

With `inline` code.
''';

      final normalTranslator = TestTranslator();
      final adapter = EnhancedParallelChunkProcessorAdapter(translator: normalTranslator);

      // Act - Should work fine with normal translator and default validation
      final result = await adapter.processMarkdownContent(
        inputMarkdown,
        'normal_test.md',
      );

      // Assert - Should preserve all code blocks
      expect(result, contains('void main() {'));
      expect(result, contains('`inline`'));
      expect(result, isNot(contains('__EDOC_')));
      expect(result, isNot(contains('__INLINE_CODE_ANCHOR_')));
      
      print('✅ Confirmed that normal translator works fine with default validation');
    });
  });
}

/// Normal test translator for comparison
class TestTranslator extends Translator {
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    return text.trim();
  }
}