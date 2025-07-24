import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'code_block_translation_pipeline.dart';
import 'translator.dart';

typedef PipelineProgressCallback = void Function(int completed, int total);
typedef ChunkTranslator = Future<String> Function(String chunkContent);
typedef ProgressCallback = void Function(String message);


/// Adapter that integrates the new CodeBlockTranslationPipeline with 
/// the existing EnhancedParallelChunkProcessor interface
class EnhancedParallelChunkProcessorAdapter {
  final CodeBlockTranslationPipeline _pipeline;
  final Translator _translator;
  
  EnhancedParallelChunkProcessorAdapter({
    required Translator translator,
    CodeBlockTranslationPipeline? pipeline,
  }) : _translator = translator,
       _pipeline = pipeline ?? CodeBlockTranslationPipeline();

  /// Process markdown content using the new pipeline
  /// 
  /// This method replaces the old chunking and processing logic with
  /// the new code block anchor system
  Future<String> processMarkdownContent(
    String content,
    String fileName, {
    int maxConcurrentChunks = 10,
    int? maxChunkBytes,
    bool saveDebugInfo = false,
    ProgressCallback? progressCallback,
  }) async {
    // Convert the existing translator interface to the pipeline's ChunkTranslator
    chunkTranslator(String chunkContent) async {
      return await _translator.translate(
        chunkContent,
        onFirstModelError: () {
          progressCallback?.call('Erro no primeiro modelo, tentando novamente...');
        },
      );
    }

    // Create progress callback adapter
    PipelineProgressCallback? pipelineProgressCallback;
    if (progressCallback != null) {
      pipelineProgressCallback = (completed, total) {
        progressCallback('parte $completed/$total traduzida (restam ${total - completed})');
      };
    }

    try {
      // Use the new pipeline for translation
      final result = await _pipeline.translateContentParallel(
        originalContent: content,
        translator: chunkTranslator,
        maxBytes: maxChunkBytes,
        maxConcurrency: maxConcurrentChunks,
        progressCallback: pipelineProgressCallback,
      );

      // Log statistics
      _logStatistics(fileName, result);

      // Check if restoration failed and throw an error
      if (!result.stats.restorationSuccess) {
        throw StateError(
          'Code block restoration failed for $fileName. '
          'Original content had ${result.stats.totalCodeBlocksExtracted} code blocks '
          '(${result.stats.fencedCodeBlocks} fenced, ${result.stats.inlineCodeBlocks} inline), '
          'but restoration validation failed. This indicates that the translator '
          'corrupted or removed code block anchor patterns during translation.'
        );
      }

      return result.translatedContent;
    } catch (error) {
      progressCallback?.call('Erro durante tradução: $error');
      rethrow;
    }
  }

  /// Log translation statistics
  void _logStatistics(String fileName, CodeBlockTranslationResult result) {
    final stats = result.stats;
    
    print('\n=== Translation Statistics for $fileName ===');
    print('Original content: ${stats.originalContentBytes} bytes');
    print('Code blocks extracted: ${stats.totalCodeBlocksExtracted} (${stats.fencedCodeBlocks} fenced, ${stats.inlineCodeBlocks} inline)');
    print('Chunks processed: ${stats.totalChunks} (avg: ${stats.averageChunkBytes} bytes)');
    print('Processing time: ${stats.processingTimeSeconds}s (${stats.bytesPerSecond.toStringAsFixed(0)} bytes/sec)');
    print('Final content: ${stats.finalContentBytes} bytes');
    print('Restoration success: ${stats.restorationSuccess}');
    
    if (!stats.restorationSuccess) {
      stderr.writeln('WARNING: Code block restoration may have failed for $fileName');
    }
  }

  /// Process a file using the new pipeline
  /// 
  /// This method maintains compatibility with the existing file processing interface
  Future<void> processFile({
    required String inputPath,
    required String outputPath,
    required String targetLanguage,
    int maxConcurrentChunks = 10,
    int? maxChunkBytes,
    bool saveDebugInfo = false,
    ProgressCallback? progressCallback,
  }) async {
    progressCallback?.call('Lendo arquivo $inputPath...');
    
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Arquivo não encontrado', inputPath);
    }

    final content = await inputFile.readAsString();
    final fileName = inputPath.split('/').last;

    progressCallback?.call('Iniciando tradução de $fileName...');

    final translatedContent = await processMarkdownContent(
      content,
      fileName,
      maxConcurrentChunks: maxConcurrentChunks,
      maxChunkBytes: maxChunkBytes,
      saveDebugInfo: saveDebugInfo,
      progressCallback: progressCallback,
    );

    progressCallback?.call('Salvando arquivo traduzido...');

    final outputFile = File(outputPath);
    await outputFile.writeAsString(translatedContent);

    progressCallback?.call('✓ Tradução concluída: $outputPath');
  }

  /// Batch process multiple files
  Future<void> processFiles({
    required List<String> inputPaths,
    required String outputDirectory,
    required String targetLanguage,
    int maxConcurrentChunks = 10,
    int maxConcurrentFiles = 3,
    int? maxChunkBytes,
    bool saveDebugInfo = false,
    ProgressCallback? progressCallback,
  }) async {
    final outputDir = Directory(outputDirectory);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final semaphore = _Semaphore(maxConcurrentFiles);
    final futures = inputPaths.map((inputPath) async {
      await semaphore.acquire();
      try {
        final fileName = inputPath.split('/').last;
        final outputPath = '$outputDirectory/$fileName';
        
        progressCallback?.call('Processando $fileName...');
        
        await processFile(
          inputPath: inputPath,
          outputPath: outputPath,
          targetLanguage: targetLanguage,
          maxConcurrentChunks: maxConcurrentChunks,
          maxChunkBytes: maxChunkBytes,
          saveDebugInfo: saveDebugInfo,
          progressCallback: progressCallback,
        );
      } finally {
        semaphore.release();
      }
    });

    await Future.wait(futures);
    progressCallback?.call('✓ Todos os arquivos processados!');
  }
}

/// Simple semaphore for controlling file processing concurrency
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