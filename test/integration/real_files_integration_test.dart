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

void main() {
  group('Real Files Integration Tests - Code Block Anchor System', () {
    late TestTranslator testTranslator;
    late EnhancedParallelChunkProcessorAdapter adapter;
    late Directory inputDir;

    setUp(() {
      testTranslator = TestTranslator();
      adapter =
          EnhancedParallelChunkProcessorAdapter(translator: testTranslator);
      inputDir = Directory('test/doc_files');
    });

    test(
        'should preserve code blocks in swiftui-devs.md with real Swift and Dart code',
        () async {
      // Arrange
      final testFile = File('test/doc_files/swiftui-devs.md');
      if (!testFile.existsSync()) {
        markTestSkipped('Test file swiftui-devs.md not found');
        return;
      }

      final originalContent = await testFile.readAsString();

      // Act
      final result = await adapter.processMarkdownContent(
        originalContent,
        'swiftui-devs.md',
      );

      // Assert - Verify Swift code blocks are preserved exactly
      expect(result, contains('''```swift
Text("Hello, World!") // <-- This is a View
  .padding(10)        // <-- This is a modifier of that View
```'''));

      // Verify Dart code blocks are preserved exactly
      expect(result, contains('''```dart
Padding(                         // <-- This is a Widget
  padding: EdgeInsets.all(10.0), // <-- So is this
  child: Text("Hello, World!"),  // <-- This, too
)));
```'''));

      // Verify inline code is preserved (check for any inline code)
      final inlineCodeMatches = RegExp(r'`[^`\n]+`').allMatches(result);
      expect(inlineCodeMatches.length, greaterThan(0),
          reason: 'Should contain inline code blocks');

      // Verify some specific inline code that should be present
      expect(
          result, contains('`App`')); // Check for a simple inline code example

      // Verify structure is maintained
      final originalHeaders =
          RegExp(r'^#+\s', multiLine: true).allMatches(originalContent).length;
      final resultHeaders =
          RegExp(r'^#+\s', multiLine: true).allMatches(result).length;
      expect(resultHeaders, equals(originalHeaders));

      // Verify YAML frontmatter is preserved
      expect(result, contains('title: Flutter for SwiftUI Developers'));
      expect(
          result,
          contains(
              'description: Learn how to apply SwiftUI developer knowledge'));
    });

    test('should preserve code blocks across multiple real files', () async {
      // Arrange - Get all markdown files in the input directory
      final mdFiles = inputDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>()
          .toList();

      if (mdFiles.isEmpty) {
        markTestSkipped('No markdown files found in test/doc_files');
        return;
      }

      for (final file in mdFiles) {
        final fileName = file.path.split('/').last;
        final originalContent = await file.readAsString();

        // Skip empty files
        if (originalContent.trim().isEmpty) continue;

        // Act
        final result = await adapter.processMarkdownContent(
          originalContent,
          fileName,
        );

        // Assert - Count original vs result code blocks
        final originalFencedBlocks =
            RegExp(r'```[\s\S]*?```').allMatches(originalContent).length;
        final resultFencedBlocks =
            RegExp(r'```[\s\S]*?```').allMatches(result).length;

        final originalInlineCode =
            RegExp(r'`[^`\n]+`').allMatches(originalContent).length;
        final resultInlineCode = RegExp(r'`[^`\n]+`').allMatches(result).length;

        // Verify code blocks are preserved
        expect(resultFencedBlocks, equals(originalFencedBlocks),
            reason: 'Fenced code blocks not preserved in $fileName');
        expect(resultInlineCode, equals(originalInlineCode),
            reason: 'Inline code blocks not preserved in $fileName');

        // Verify basic structure is maintained
        final originalHeaders = RegExp(r'^#+\s', multiLine: true)
            .allMatches(originalContent)
            .length;
        final resultHeaders =
            RegExp(r'^#+\s', multiLine: true).allMatches(result).length;
        expect(resultHeaders, equals(originalHeaders),
            reason: 'Header structure not preserved in $fileName');

        // Verify content length is approximately the same (within 10% due to trimming)
        final lengthDifference = (result.length - originalContent.length).abs();
        final maxAllowedDifference = (originalContent.length * 0.1).round();
        expect(lengthDifference, lessThanOrEqualTo(maxAllowedDifference),
            reason:
                'Content length changed significantly in $fileName (original: ${originalContent.length}, result: ${result.length})');
      }
    });

    test('should handle files with complex code block scenarios', () async {
      // Arrange - Look for files that likely contain complex code patterns
      final complexFiles = inputDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>()
          .where((file) {
            final name = file.path.split('/').last;
            return name.contains('release-notes') || name.contains('input');
          })
          .take(2)
          .toList();

      if (complexFiles.isEmpty) {
        markTestSkipped('No complex markdown files found');
        return;
      }

      for (final file in complexFiles) {
        final fileName = file.path.split('/').last;
        final originalContent = await file.readAsString();

        // Skip if file doesn't have code blocks
        if (!originalContent.contains('```') &&
            !RegExp(r'`[^`]+`').hasMatch(originalContent)) {
          continue;
        }

        // Act
        final result = await adapter.processMarkdownContent(
          originalContent,
          fileName,

          maxChunkBytes: 5000, // Force chunking for complex content
        );

        // Assert - Verify no content corruption occurred
        expect(result, isNotNull);
        expect(result.trim(), isNotEmpty);

        // Verify no anchor patterns leaked through
        expect(result, isNot(contains('__EDOC_')));
        expect(result, isNot(contains('__INLINE_CODE_ANCHOR_')));

        // If original had code blocks, result should too
        if (originalContent.contains('```')) {
          expect(result, contains('```'),
              reason: 'Fenced code blocks missing in processed $fileName');
        }

        // Verify Jekyll/frontmatter is preserved if present
        if (originalContent.startsWith('---')) {
          expect(result.startsWith('---'), isTrue,
              reason: 'YAML frontmatter not preserved in $fileName');
        }

        print(
            '✅ Successfully processed $fileName: ${originalContent.length} → ${result.length} bytes');
      }
    });

    test(
        'should maintain file integrity with parallel processing on large files',
        () async {
      // Arrange - Find the largest file to test parallel processing
      final allFiles = inputDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>()
          .toList();

      if (allFiles.isEmpty) {
        markTestSkipped('No markdown files found');
        return;
      }

      // Sort by size and take the largest
      allFiles.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
      final largestFile = allFiles.first;
      final fileName = largestFile.path.split('/').last;
      final originalContent = await largestFile.readAsString();

      // Only test if file is reasonably large
      if (originalContent.length < 1000) {
        markTestSkipped(
            'Largest file is too small for parallel processing test');
        return;
      }

      // Act - Process with small chunk size to force parallel processing
      final result = await adapter.processMarkdownContent(
        originalContent,
        fileName,

        maxConcurrentChunks: 3,
        maxChunkBytes: 2000, // Small chunks to test parallel processing
      );

      // Assert - Verify integrity
      expect(result, isNotNull);
      expect(result.trim(), isNotEmpty);

      // Count structural elements
      final originalHeaders =
          RegExp(r'^#+\s', multiLine: true).allMatches(originalContent).length;
      final resultHeaders =
          RegExp(r'^#+\s', multiLine: true).allMatches(result).length;
      expect(resultHeaders, equals(originalHeaders));

      final originalCodeBlocks =
          RegExp(r'```[\s\S]*?```').allMatches(originalContent).length;
      final resultCodeBlocks =
          RegExp(r'```[\s\S]*?```').allMatches(result).length;
      expect(resultCodeBlocks, equals(originalCodeBlocks));

      // Verify no processing artifacts
      expect(result, isNot(contains('__EDOC_')));
      expect(result, isNot(contains('__INLINE_CODE_ANCHOR_')));

      print(
          '✅ Parallel processing test passed for $fileName: ${originalContent.length} bytes, $originalCodeBlocks code blocks');
    });

    test('should handle edge cases from real markdown files', () async {
      // Arrange - Look for files that might have edge cases
      final files = inputDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .cast<File>()
          .toList();

      var filesProcessed = 0;
      var totalCodeBlocks = 0;
      var totalHeaders = 0;

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final originalContent = await file.readAsString();

        if (originalContent.trim().isEmpty) continue;

        try {
          // Act
          final result = await adapter.processMarkdownContent(
            originalContent,
            fileName,
          );

          // Assert - Basic validation
          expect(result, isNotNull);
          expect(result, isNot(contains('__EDOC_')));
          expect(result, isNot(contains('__INLINE_CODE_ANCHOR_')));

          // Count elements for summary
          totalCodeBlocks +=
              RegExp(r'```[\s\S]*?```').allMatches(result).length;
          totalHeaders +=
              RegExp(r'^#+\s', multiLine: true).allMatches(result).length;
          filesProcessed++;
        } catch (e) {
          fail('Failed to process $fileName: $e');
        }
      }

      // Summary assertions
      expect(filesProcessed, greaterThan(0), reason: 'No files were processed');
      print('✅ Successfully processed $filesProcessed real markdown files');
      print('   Total code blocks preserved: $totalCodeBlocks');
      print('   Total headers preserved: $totalHeaders');
    });
  });
}
