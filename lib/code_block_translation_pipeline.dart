import 'dart:async';
import 'dart:collection';
import 'code_block_extractor.dart';
import 'code_block_restorer.dart';
import 'simplified_markdown_splitter.dart';
import 'simplified_chunk.dart';
import 'translation_statistics.dart';

/// Result of the code block translation pipeline
class CodeBlockTranslationResult {
  /// The final translated content with code blocks restored
  final String translatedContent;

  /// List of chunks that were processed
  final List<SimplifiedChunk> processedChunks;

  /// List of extracted code blocks that were preserved
  final List<ExtractedCodeBlock> extractedCodeBlocks;

  /// Statistics about the pipeline execution
  final TranslationStatistics stats;

  const CodeBlockTranslationResult({
    required this.translatedContent,
    required this.processedChunks,
    required this.extractedCodeBlocks,
    required this.stats,
  });

  @override
  String toString() {
    return 'CodeBlockTranslationResult(chunks: ${processedChunks.length}, '
        'codeBlocks: ${extractedCodeBlocks.length}, '
        'finalLength: ${translatedContent.length})';
  }
}

/// Function type for translating individual chunks
typedef ChunkTranslator = Future<String> Function(String content);

/// Complete translation pipeline that handles code block extraction,
/// splitting, translation, and restoration
class CodeBlockTranslationPipeline {
  final CodeBlockExtractor _extractor;
  final SimplifiedMarkdownSplitter _splitter;
  final CodeBlockRestorer _restorer;

  CodeBlockTranslationPipeline({
    CodeBlockExtractor? extractor,
    SimplifiedMarkdownSplitter? splitter,
    CodeBlockRestorer? restorer,
  })  : _extractor = extractor ?? CodeBlockExtractor(),
        _splitter = splitter ?? SimplifiedMarkdownSplitter(),
        _restorer = restorer ?? CodeBlockRestorer();

  /// Execute the complete translation pipeline
  ///
  /// [originalContent] - The original markdown content
  /// [translator] - Function that translates a chunk of content
  /// [maxBytes] - Maximum bytes per chunk (defaults to 20KB)
  ///
  /// Returns the complete translation result with statistics
  Future<CodeBlockTranslationResult> translateContent({
    required String originalContent,
    required ChunkTranslator translator,
    int? maxBytes,
  }) async {
    final startTime = DateTime.now();

    // Step 1: Extract code blocks and replace with anchors
    final extractionResult = _extractor.extractCodeBlocks(originalContent);
    final cleanContent = extractionResult.cleanContent;

    // Step 2: Split clean content into manageable chunks
    final chunks = _splitter.split(cleanContent, maxBytes: maxBytes);

    // Step 3: Translate all chunks (including anchors)
    final translatedChunks = <SimplifiedChunk>[];
    for (final chunk in chunks) {
      final translatedContent = await translator(chunk.content);
      translatedChunks.add(SimplifiedChunk.fromContent(translatedContent));
    }

    // Step 4: Join translated chunks
    final joinedTranslatedContent = translatedChunks
        .map((chunk) => chunk.content)
        .join('\n\n'); // Use double newline as separator

    // Step 5: Restore code blocks (replace anchors with original code)
    final extractedBlocks = extractionResult.extractedBlocks;
    final finalTranslatedContent = _restorer.restoreCodeBlocks(
      joinedTranslatedContent,
      extractedBlocks,
    );

    // Generate statistics
    final endTime = DateTime.now();
    final stats = _generateStatistics(
      originalContent: originalContent,
      cleanContent: cleanContent,
      chunks: chunks,
      translatedChunks: translatedChunks,
      extractedBlocks: extractedBlocks,
      finalContent: finalTranslatedContent,
      processingTime: endTime.difference(startTime),
    );

    return CodeBlockTranslationResult(
      translatedContent: finalTranslatedContent,
      processedChunks: translatedChunks,
      extractedCodeBlocks: extractedBlocks,
      stats: stats,
    );
  }

  /// Execute the pipeline with parallel chunk processing
  ///
  /// [originalContent] - The original markdown content
  /// [translator] - Function that translates a chunk of content
  /// [maxBytes] - Maximum bytes per chunk (defaults to 20KB)
  /// [maxConcurrency] - Maximum number of concurrent translations (defaults to 10)
  /// [progressCallback] - Optional callback for progress updates
  ///
  /// Returns the complete translation result with statistics
  Future<CodeBlockTranslationResult> translateContentParallel({
    required String originalContent,
    required ChunkTranslator translator,
    int? maxBytes,
    int maxConcurrency = 10,
    void Function(int completed, int total)? progressCallback,
  }) async {
    assert(maxConcurrency > 0, 'maxConcurrency must be greater than 0');
    final startTime = DateTime.now();

    // Step 1: Extract code blocks and replace with anchors
    final extractionResult = _extractor.extractCodeBlocks(originalContent);
    final cleanContent = extractionResult.cleanContent;
    final extractedBlocks = extractionResult.extractedBlocks;

    // Step 2: Split clean content into manageable chunks
    final chunks = _splitter.split(cleanContent, maxBytes: maxBytes);

    // Step 3: Translate chunks in parallel with controlled concurrency
    final translatedChunks = await _translateChunksParallel(
      chunks,
      translator,
      maxConcurrency,
      progressCallback,
    );

    // Step 4: Join translated chunks
    final joinedTranslatedContent = translatedChunks
        .map((chunk) => chunk.content)
        .join('\n\n'); // Use double newline as separator

    // Step 5: Restore code blocks (replace anchors with original code)
    final finalTranslatedContent = _restorer.restoreCodeBlocks(
      joinedTranslatedContent,
      extractedBlocks,
    );

    // Generate statistics
    final endTime = DateTime.now();
    final stats = _generateStatistics(
      originalContent: originalContent,
      cleanContent: cleanContent,
      chunks: chunks,
      translatedChunks: translatedChunks,
      extractedBlocks: extractedBlocks,
      finalContent: finalTranslatedContent,
      processingTime: endTime.difference(startTime),
    );

    return CodeBlockTranslationResult(
      translatedContent: finalTranslatedContent,
      processedChunks: translatedChunks,
      extractedCodeBlocks: extractedBlocks,
      stats: stats,
    );
  }

  /// Translate chunks in parallel with controlled concurrency
  Future<List<SimplifiedChunk>> _translateChunksParallel(
    List<SimplifiedChunk> chunks,
    ChunkTranslator translator,
    int maxConcurrency,
    void Function(int completed, int total)? progressCallback,
  ) async {
    if (chunks.isEmpty) return [];

    final results = List<SimplifiedChunk?>.filled(chunks.length, null);
    final semaphore = _Semaphore(maxConcurrency);
    int completed = 0;

    final futures = chunks.asMap().entries.map((entry) async {
      final index = entry.key;
      final chunk = entry.value;

      await semaphore.acquire();
      try {
        final translatedContent = await translator(chunk.content);
        results[index] = SimplifiedChunk.fromContent(translatedContent);
      } catch (error) {
        // On error, use original content as fallback
        results[index] = chunk;
      } finally {
        semaphore.release();
        completed++;
        progressCallback?.call(completed, chunks.length);
      }
    });

    await Future.wait(futures);

    // Convert nullable list to non-nullable (all should be filled)
    return results.cast<SimplifiedChunk>();
  }

  /// Generate comprehensive statistics about the pipeline execution
  TranslationStatistics _generateStatistics({
    required String originalContent,
    required String cleanContent,
    required List<SimplifiedChunk> chunks,
    required List<SimplifiedChunk> translatedChunks,
    required List<ExtractedCodeBlock> extractedBlocks,
    required String finalContent,
    required Duration processingTime,
  }) {
    final originalStats =
        _splitter.getStatistics([SimplifiedChunk.fromContent(originalContent)]);
    final chunkStats = _splitter.getStatistics(chunks);
    final translatedStats = _splitter.getStatistics(translatedChunks);

    // Count fenced vs inline blocks based on the pattern of originalCode
    final fencedBlocks = extractedBlocks.where((b) => b.originalCode.startsWith('```')).length;
    final inlineBlocks = extractedBlocks.where((b) => !b.originalCode.startsWith('```')).length;
    
    return TranslationStatistics(
      // Original content stats
      originalContentBytes: originalStats['totalBytes'] as int,
      originalContentCodeUnits: originalStats['totalCodeUnits'] as int,

      // Code block extraction stats
      totalCodeBlocksExtracted: extractedBlocks.length,
      fencedCodeBlocks: fencedBlocks,
      inlineCodeBlocks: inlineBlocks,
      cleanContentBytes: SimplifiedChunk.fromContent(cleanContent).utf8ByteSize,

      // Chunking stats
      totalChunks: chunks.length,
      averageChunkBytes: chunkStats['averageBytes'] as int,
      maxChunkBytes: chunkStats['maxBytes'] as int,
      minChunkBytes: chunkStats['minBytes'] as int,

      // Translation stats
      translatedContentBytes: translatedStats['totalBytes'] as int,
      finalContentBytes: SimplifiedChunk.fromContent(finalContent).utf8ByteSize,

      // Performance stats
      processingTimeMs: processingTime.inMilliseconds,
      processingTimeSeconds: processingTime.inSeconds,
      bytesPerSecond: (originalStats['totalBytes'] as int) /
          (processingTime.inMilliseconds / 1000),

      // Pipeline integrity
      codeBlocksRestored: extractedBlocks.length,
      restorationSuccess: _checkRestorationSuccess(finalContent, extractedBlocks),
    );
  }

  /// Check if restoration was successful by verifying code blocks were restored
  bool _checkRestorationSuccess(
      String finalContent, List<ExtractedCodeBlock> extractedBlocks) {
    // If there are no code blocks, restoration is trivially successful
    if (extractedBlocks.isEmpty) {
      return true;
    }

    // Check that no anchor patterns remain in the final content
    final hasRemainingAnchors = finalContent.contains('__CODE_BLOCK_ANCHOR_');

    if (hasRemainingAnchors) {
      return false;
    }

    // Check that all extracted code blocks appear in the final content
    for (final block in extractedBlocks) {
      if (!finalContent.contains(block.originalCode)) {
        return false;
      }
    }
    return true;
  }

  /// Get pipeline component information
  Map<String, String> getComponentInfo() {
    return {
      'extractor': _extractor.runtimeType.toString(),
      'splitter': _splitter.runtimeType.toString(),
      'restorer': _restorer.runtimeType.toString(),
    };
  }
}

/// Simple semaphore implementation for controlling concurrency
class _Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  _Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
