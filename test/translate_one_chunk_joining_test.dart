import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../bin/src/app.dart';
import '../bin/src/large_file_config.dart';
import 'package:translator/markdown_spliter.dart';
import 'package:translator/code_block_extractor.dart';
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
      );

      final originalHeaders = _countHeaders(content);

      await processor.translateOne(
        mockFile,
        true,
        mockTranslator,
        false,
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

      // Check for problematic merge patterns deterministically
      final mergePatterns = [
        'inicial.### Header',
        'meio.### Segunda',
        'Principal### Segunda'
      ];

      final foundPatterns = <String>[];
      for (final pattern in mergePatterns) {
        final hasPattern = cleanResult.contains(pattern);
        print('Pattern "$pattern": ${hasPattern ? "FOUND" : "not found"}');
        hasPattern ? foundPatterns.add(pattern) : null;
      }

      print('Content merged patterns found: $foundPatterns');

      // Verify processing results
      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after processing');

      // Verify proper joining prevents content merge
      expect(foundPatterns.isEmpty, isTrue,
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
      );

      final originalHeaders = _countHeaders(content);

      // This should trigger the large file processing code path
      await processor.translateOne(
        mockFile,
        true, // MUST be true to trigger large file processing
        mockTranslator,
        false,
      );

      final result = mockFile.content;
      final cleanResult =
          result.replaceAll('<!-- ia-translate: true -->\n', '');
      final resultHeaders = _countHeaders(cleanResult);

      // Verify processing succeeded - no conditionals needed

      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after large file processing');

      expect(resultHeaders, equals(originalHeaders),
          reason: 'All headers should be preserved in large file processing');
    });

    test('should handle real large file with code blocks - split, translate only text, and rejoin correctly', 
        () async {
      // Load the actual test.md file that we know has large code blocks
      final testFile = File('/Users/ulisses.hen/projects/translator/test/split/test.md');
      final originalContent = await testFile.readAsString();
      
      // Set up configuration for realistic large file processing - matching UTF8 test approach
      LargeFileConfig.configureForTesting(
        maxKbSizeOverride: 20, // 20KB threshold
        chunkMaxBytesOverride: 20480, // 20KB chunks - same as UTF8 test
      );
      
      const chunkSize = 20480; // 20KB - matching UTF8 test
      final totalFileSize = utf8.encode(originalContent).length;
      print('Total file size: $totalFileSize UTF-8 bytes');
      print('Chunk size limit: $chunkSize bytes (20KB)');
      
      // IMPORTANT: With our new fenced code block extraction approach, we need to test 
      // chunking on the CLEAN content (after fenced blocks are extracted) to match 
      // the actual translation workflow
      
      // First, extract fenced code blocks like the production code does
      final extractor = CodeBlockExtractor();
      final extractionResult = extractor.extractCodeBlocks(originalContent);
      final cleanContent = extractionResult.cleanContent;
      final extractedBlocks = extractionResult.extractedBlocks;
      
      print('Fenced code blocks extracted: ${extractedBlocks.length}');
      
      // Now test chunking on the clean content (this matches the actual workflow)
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      final chunks = splitter.splitMarkdown(cleanContent);
      
      final cleanContentSize = utf8.encode(cleanContent).length;
      print('Clean content size (after extraction): $cleanContentSize UTF-8 bytes');
      print('Total chunks created: ${chunks.length}');
      print('Expected chunks (if perfectly split): ${(cleanContentSize / chunkSize).ceil()}');
      print('');
      
      // All chunks from clean content are translatable (fenced blocks already extracted)
      int translatableChunks = chunks.length; // All chunks are translatable now
      int codeBlockChunks = 0; // No code block chunks in clean content
      
      print('Summary: $translatableChunks translatable, $codeBlockChunks non-translatable');

      // Verify all chunks are properly sized (no conditionals - just validate the data)
      final oversizedChunks = chunks.where((chunk) => chunk.utf8ByteSize > chunkSize).length;
      print('Oversized chunks: $oversizedChunks out of ${chunks.length}');
      
      // Verify chunks can be rejoined correctly - matching UTF8 test approach
      final rejoinedContent = chunks.map((chunk) => chunk.content).join('');
      expect(rejoinedContent.trim(), equals(cleanContent.trim()),
          reason: 'Clean content should be preserved after splitting and rejoining');
      
      // Now test the actual translation workflow
      final originalfile = File('/Users/ulisses.hen/projects/translator/test/split/test.md');
      final mockFile = SimpleMockFileWrapper(originalfile.path, originalContent);
      final mockTranslator = StructurePreservingMockTranslator();
      
      final processor = FileProcessorImpl(
        mockTranslator,
        MarkdownProcessorImpl(),
        maxConcurrentChunks: 2, // Allow some parallel processing
      );
      
      final originalHeaders = _countHeaders(originalContent);
      final originalCodeBlocks = _countCodeBlocks(originalContent);
      
      // Process the large file - deterministic execution
      await processor.translateOne(
        mockFile,
        true, // processLargeFiles = true
        mockTranslator,
        false,
      );

      final resultHeaders = _countHeaders(mockFile.content);
      final resultCodeBlocks = _countCodeBlocks(mockFile.content);

      print('Translation completed:');
      print('  Original headers: $originalHeaders, result headers: $resultHeaders');
      print('  Original code blocks: $originalCodeBlocks, result code blocks: $resultCodeBlocks');
      print('  Translation calls made: ${mockTranslator.translationCallCount}');
      print('  Expected calls: $translatableChunks (only translatable chunks)');
      
      // Verify processing results - no conditionals, just assertions
      expect(mockFile.writeCalled, isTrue,
          reason: 'File should be written after processing');
      
      // Verify structure preservation
      expect(resultHeaders, equals(originalHeaders),
          reason: 'All markdown headers should be preserved');
      
      expect(resultCodeBlocks, equals(originalCodeBlocks),
          reason: 'All code blocks should be preserved unchanged');
      
      // Verify translation efficiency - should only translate translatable chunks
      expect(mockTranslator.translationCallCount, translatableChunks,
          reason: 'Should only translate translatable chunks, not code blocks');
      
      print('✅ Large file translation with code block separation successful!');
    });
  });
}

/// Counts markdown headers in content
int _countHeaders(String content) {
  final headerRegex = RegExp(r'^#{1,6}\s+.*$', multiLine: true);
  return headerRegex.allMatches(content).length;
}

/// Counts code blocks in content
int _countCodeBlocks(String content) {
  final codeBlockRegex = RegExp(r'```[\s\S]*?```');
  return codeBlockRegex.allMatches(content).length;
}
