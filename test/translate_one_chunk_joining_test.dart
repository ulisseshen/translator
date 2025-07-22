import 'package:test/test.dart';
import '../bin/src/app.dart';
import '../bin/src/large_file_config.dart';
import 'test_mocks.dart';

void main() {
  group('TranslateOne Chunk Joining Tests', () {
    setUp(() {
      // Configure for testing with small thresholds to trigger chunking
      LargeFileConfig.configureForTesting(
        maxKbSizeOverride: 1, // 1KB threshold for large files
        chunkMaxBytesOverride: 50, // Very small chunks to force splitting
      );
    });

    tearDown(() {
      // Reset configuration after each test
      LargeFileConfig.resetToDefaults();
    });

    test(
        'should demonstrate header loss bug in translateOne with join double newlines',
        () async {
      // Simple test content that will trigger the chunking bug
      final content = '''Esta seção.

### Especializando 

O Flutter oferece.

### Outra seção importante

Conteúdo.''';

      final mockFile = SimpleMockFileWrapper('test.md', content);
      final mockTranslator = StructurePreservingMockTranslator();

      final processor = FileProcessorImpl(
        mockTranslator,
        MarkdownProcessorImpl(),
        maxConcurrentChunks: 1,
        chunkMaxBytes: 50, // Small chunks to force multiple splits
      );

      // Count original headers before processing
      final originalHeaders = _countHeaders(content);

      // Process the file through translateOne - this triggers the bug
      await processor.translateOne(
        mockFile,
        true, // processLargeFiles = true
        mockTranslator,
        false,
      );

      final result = mockFile.content;

      // Remove ia-translate prefix to examine core content
      final cleanResult =
          result.replaceAll('<!-- ia-translate: true -->\n', '');

      // Count headers after processing
      final resultHeaders = _countHeaders(cleanResult);

      // Verify file was written
      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after processing');

      expect(resultHeaders, equals(originalHeaders),
          reason: 'All headers should be preserved after translation');
    });

    test('should preserve headers when joining translated chunks properly',
        () async {
      // Test content designed to verify proper chunk joining
      final content = '''Texto inicial.

### Header Principal

Conteúdo do meio.

### Segunda Seção

Texto final.''';

      final mockFile = SimpleMockFileWrapper('minimal_test.md', content);
      final mockTranslator = StructurePreservingMockTranslator();

      final processor = FileProcessorImpl(
        mockTranslator,
        MarkdownProcessorImpl(),
        maxConcurrentChunks: 1,
        chunkMaxBytes: 40, // Force aggressive chunking
      );

      final originalHeaders = _countHeaders(content);

      bool onFailedCalled = false;
      await processor.translateOne(
        mockFile,
        true,
        mockTranslator,
        false,
        onFailed: () {
          onFailedCalled = true;
        },
      );

      final result = mockFile.content;
      final cleanResult =
          result.replaceAll('<!-- ia-translate: true -->\n', '');
      final resultHeaders = _countHeaders(cleanResult);

      // Debug output
      print('Original content:');
      print('"${content.replaceAll('\n', '\\n')}"');
      print('\nProcessed result:');
      print('"${cleanResult.replaceAll('\n', '\\n')}"');
      print('\nOriginal headers: $originalHeaders');
      print('Result headers: $resultHeaders');

      // Look for problematic merge patterns
      final mergePatterns = [
        'inicial.### Header',
        'meio.### Segunda',
        'Principal### Segunda'
      ];

      final foundPattern = mergePatterns
          .where((pattern) => cleanResult.contains(pattern))
          .toList();

      print('Content merged patterns found: $foundPattern');

      // Verify processing succeeded
      expect(onFailedCalled, isFalse,
          reason: 'Translation should not fail for minimal content');

      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after processing');

      // Verify proper joining prevents content merge
      expect(foundPattern.isEmpty, isTrue,
          reason:
              'Proper join separator should prevent content merging with headers');

      expect(resultHeaders, equals(originalHeaders),
          reason: 'Headers should be preserved with proper chunk joining');
    });

    test('should handle large file processing with correct chunk separation',
        () async {
      // Test content to ensure large file processing path works correctly
      final content = '''Primeira seção com conteúdo.

### Cabeçalho Importante

Conteúdo da seção principal.

### Segunda Seção

Mais conteúdo aqui.''';

      final mockFile = SimpleMockFileWrapper('large_file_test.md', content);
      final mockTranslator = StructurePreservingMockTranslator();

      // Configure to definitely trigger large file processing
      final processor = FileProcessorImpl(
        mockTranslator,
        MarkdownProcessorImpl(),
        maxConcurrentChunks: 1,
        chunkMaxBytes: 30, // Very small to ensure chunking
      );

      final originalHeaders = _countHeaders(content);

      bool onFailedCalled = false;
      // This should trigger the large file processing code path
      await processor.translateOne(
        mockFile,
        true, // MUST be true to trigger large file processing
        mockTranslator,
        false,
        onFailed: () {
          onFailedCalled = true;
        },
      );

      final result = mockFile.content;
      final cleanResult =
          result.replaceAll('<!-- ia-translate: true -->\n', '');
      final resultHeaders = _countHeaders(cleanResult);

      // Verify processing succeeded
      expect(onFailedCalled, isFalse,
          reason: 'Large file translation should not fail');

      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after large file processing');

      expect(resultHeaders, equals(originalHeaders),
          reason: 'All headers should be preserved in large file processing');
    });
  });
}

/// Counts markdown headers in content
int _countHeaders(String content) {
  final headerRegex = RegExp(r'^#{1,6}\s+.*$', multiLine: true);
  return headerRegex.allMatches(content).length;
}

/// Extracts markdown headers from content
List<String> _extractHeaders(String content) {
  final headerRegex = RegExp(r'^#{1,6}\s+.*$', multiLine: true);
  return headerRegex
      .allMatches(content)
      .map((match) => match.group(0)!)
      .toList();
}
