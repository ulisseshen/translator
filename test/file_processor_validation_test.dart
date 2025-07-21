import 'package:test/test.dart';
import 'dart:io';
import '../bin/src/app.dart';
import 'test_mocks.dart';

void main() {
  group('FileProcessor Markdown Validation Integration', () {
    late FileProcessorImpl fileProcessor;
    late MockTranslator mockTranslator;
    late MarkdownProcessorImpl markdownProcessor;
    
    setUp(() {
      mockTranslator = MockTranslator();
      markdownProcessor = MarkdownProcessorImpl();
      fileProcessor = FileProcessorImpl(mockTranslator, markdownProcessor);
    });

    group('Valid Markdown Files', () {
      test('should process valid markdown file successfully', () async {
        const validMarkdown = '''# Test Document

This is a valid markdown document with proper structure.

## Section 1

- List item 1
- List item 2

[Valid link](https://example.com)

```dart
print('Valid code block');
```
''';

        final tempFile = await _createTempFile('valid_test.md', validMarkdown);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false, // processLargeFiles
            mockTranslator,
            false, // useSecond
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isTrue, reason: 'onComplete should be called for valid markdown');
          expect(onFailedCalled, isFalse, reason: 'onFailed should not be called for valid markdown');
          expect(mockTranslator.translateCallCount, equals(1), reason: 'translate should be called once');
        } finally {
          await tempFile.delete();
        }
      });

      test('should process markdown with warnings but proceed', () async {
        const markdownWithWarnings = '''#Title Without Space

This document has some warnings but should still be processed.

[Empty link text]() - this generates a warning.

- Good list item
- 

Normal content continues.
''';

        final tempFile = await _createTempFile('warnings_test.md', markdownWithWarnings);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isTrue, reason: 'Should complete despite warnings');
          expect(onFailedCalled, isFalse, reason: 'Should not fail for warnings');
          expect(mockTranslator.translateCallCount, equals(1), reason: 'Should translate despite warnings');
        } finally {
          await tempFile.delete();
        }
      });
    });

    group('Invalid Markdown Files', () {
      test('should skip translation for markdown with critical issues', () async {
        const invalidMarkdown = '''# Test Document

This document has critical issues.

```javascript
function test() {
    console.log("Unclosed code block");
// Missing closing fence

[Mismatched brackets and [another one](http://example.com).

[Unmatched bracket here.
''';

        final tempFile = await _createTempFile('invalid_test.md', invalidMarkdown);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isFalse, reason: 'onComplete should not be called for invalid markdown');
          expect(onFailedCalled, isTrue, reason: 'onFailed should be called for invalid markdown');
          expect(mockTranslator.translateCallCount, equals(0), reason: 'translate should not be called for invalid markdown');
        } finally {
          await tempFile.delete();
        }
      });

      test('should skip translation for empty markdown file', () async {
        const emptyMarkdown = '';

        final tempFile = await _createTempFile('empty_test.md', emptyMarkdown);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isFalse, reason: 'Should not complete for empty file');
          expect(onFailedCalled, isTrue, reason: 'Should fail for empty file');
          expect(mockTranslator.translateCallCount, equals(0), reason: 'Should not translate empty file');
        } finally {
          await tempFile.delete();
        }
      });

      test('should skip translation for markdown with broken reference-style links', () async {
        const invalidReferenceLinks = '''# Test Document

This document has broken reference-style links.

Here's a [valid inline link](https://example.com).

Here's a [broken reference link][missing-ref] that has no definition.

Here's another [broken link][undefined] reference.

Here's a properly defined reference link [working link][1].

[1]: https://example.com

And here's [another broken][2] reference without definition.

Normal content continues.
''';

        final tempFile = await _createTempFile('bad_refs_test.md', invalidReferenceLinks);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isFalse, reason: 'Should not complete for broken reference links');
          expect(onFailedCalled, isTrue, reason: 'Should fail for broken reference links');
          expect(mockTranslator.translateCallCount, equals(0), reason: 'Should not translate with broken references');
        } finally {
          await tempFile.delete();
        }
      });
    });

    group('Non-Markdown Files', () {
      test('should skip validation for non-markdown files', () async {
        const textContent = '''This is a plain text file.
It doesn't need markdown validation.

[This would be invalid markdown syntax
But it's not a .md file so it should be processed.
''';

        final tempFile = await _createTempFile('test.txt', textContent);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isTrue, reason: 'Should complete for non-markdown files');
          expect(onFailedCalled, isFalse, reason: 'Should not fail for non-markdown files');
          expect(mockTranslator.translateCallCount, equals(1), reason: 'Should translate non-markdown files without validation');
        } finally {
          await tempFile.delete();
        }
      });

      test('should process .html files without markdown validation', () async {
        const htmlContent = '''<!DOCTYPE html>
<html>
<head>
    <title>Test</title>
</head>
<body>
    <h1>This is HTML</h1>
    <p>It has [markdown-like syntax] but it's not markdown.</p>
    <code>Unclosed code block concepts don't apply here.
</body>
</html>
''';

        final tempFile = await _createTempFile('test.html', htmlContent);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            false,
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isTrue, reason: 'Should complete for HTML files');
          expect(onFailedCalled, isFalse, reason: 'Should not fail for HTML files');
          expect(mockTranslator.translateCallCount, equals(1), reason: 'Should translate HTML files');
        } finally {
          await tempFile.delete();
        }
      });
    });

    group('Large File Processing', () {
      test('should validate large markdown files before splitting', () async {
        // Create a large but valid markdown file
        final validLargeContent = _generateLargeValidMarkdown();

        final tempFile = await _createTempFile('large_valid_test.md', validLargeContent);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            true, // processLargeFiles = true
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isTrue, reason: 'Should complete for valid large markdown');
          expect(onFailedCalled, isFalse, reason: 'Should not fail for valid large markdown');
          // Large files get split and processed in chunks, so multiple translate calls
          expect(mockTranslator.translateCallCount, greaterThan(0), reason: 'Should translate large file');
        } finally {
          await tempFile.delete();
        }
      });

      test('should skip large invalid markdown files', () async {
        // Create a large but invalid markdown file
        final invalidLargeContent = _generateLargeInvalidMarkdown();

        final tempFile = await _createTempFile('large_invalid_test.md', invalidLargeContent);
        bool onCompleteCalled = false;
        bool onFailedCalled = false;

        try {
          await fileProcessor.translateOne(
            FileWrapper(tempFile.path),
            true, // processLargeFiles = true
            mockTranslator,
            false,
            onComplete: () => onCompleteCalled = true,
            onFailed: () => onFailedCalled = true,
          );

          expect(onCompleteCalled, isFalse, reason: 'Should not complete for invalid large markdown');
          expect(onFailedCalled, isTrue, reason: 'Should fail for invalid large markdown');
          expect(mockTranslator.translateCallCount, equals(0), reason: 'Should not translate invalid large file');
        } finally {
          await tempFile.delete();
        }
      });
    });
  });
}

// Helper function to create temporary test files
Future<File> _createTempFile(String filename, String content) async {
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsString(content);
  return tempFile;
}

// Helper function to generate large valid markdown content
String _generateLargeValidMarkdown() {
  final buffer = StringBuffer();
  
  buffer.writeln('# Large Test Document');
  buffer.writeln();
  buffer.writeln('This is a large markdown document for testing validation.');
  buffer.writeln();
  
  // Generate multiple sections to make it large
  for (int i = 1; i <= 50; i++) {
    buffer.writeln('### Section $i');
    buffer.writeln();
    buffer.writeln('This is section $i with some content. ' * 20);
    buffer.writeln();
    buffer.writeln('- List item 1 for section $i');
    buffer.writeln('- List item 2 for section $i');
    buffer.writeln('- List item 3 for section $i');
    buffer.writeln();
    buffer.writeln('[Link for section $i](https://example.com/section$i)');
    buffer.writeln();
    buffer.writeln('```dart');
    buffer.writeln('print("Code block for section $i");');
    buffer.writeln('```');
    buffer.writeln();
  }
  
  return buffer.toString();
}

// Helper function to generate large invalid markdown content
String _generateLargeInvalidMarkdown() {
  final buffer = StringBuffer();
  
  buffer.writeln('# Large Invalid Test Document');
  buffer.writeln();
  buffer.writeln('This document has critical issues.');
  buffer.writeln();
  
  // Add some valid content first
  for (int i = 1; i <= 20; i++) {
    buffer.writeln('### Section $i');
    buffer.writeln('Content for section $i. ' * 15);
    buffer.writeln();
  }
  
  // Add critical issues
  buffer.writeln('```javascript');
  buffer.writeln('function unclosedCodeBlock() {');
  buffer.writeln('    console.log("This code block is not closed");');
  buffer.writeln('// Missing closing fence');
  buffer.writeln();
  
  // Add more content to make it large
  for (int i = 21; i <= 40; i++) {
    buffer.writeln('### Section $i');
    buffer.writeln('More content for section $i. ' * 15);
    buffer.writeln('[Mismatched bracket for section $i');
    buffer.writeln();
  }
  
  return buffer.toString();
}