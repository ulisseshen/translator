import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:translator/markdown_spliter.dart';
import 'package:translator/translator.dart';
import 'package:translator/parallel_chunk_processor.dart';

import 'app.dart';
import 'large_file_config.dart';

class EnhancedParallelChunkProcessor {
  final Translator translator;
  final int maxConcurrent;
  final int maxBytes;
  final String fileName;
  
  int _completedChunks = 0;
  int _totalChunks = 0;

  EnhancedParallelChunkProcessor({
    required this.translator,
    required this.maxConcurrent,
    required this.fileName,
    this.maxBytes = 20480, // Use const default, can be overridden
  });

  Future<ProcessingResult> processChunks(String filePath, List<String> chunks) async {
    _totalChunks = chunks.length;
    _completedChunks = 0;
    
    final translatedChunks = await _processChunksWithProgress(filePath, chunks);
    
    return ProcessingResult(
      filePath: filePath,
      chunks: chunks,
      translatedChunks: translatedChunks,
      processingOrder: List.generate(chunks.length, (index) => index),
      chunkCompletionTimes: List.generate(chunks.length, (index) => DateTime.now()),
      isComplete: true,
    );
  }

  Future<List<String>> _processChunksWithProgress(String filePath, List<String> chunks) async {
    final translatedChunks = List<String>.filled(chunks.length, '');
    final futures = <Future<void>>[];
    final semaphore = Semaphore(maxConcurrent);

    for (int i = 0; i < chunks.length; i++) {
      final future = semaphore.acquire().then((_) async {
        try {
          final translatedContent = await translator.translate(
            chunks[i],
            onFirstModelError: () {
              print('🚨 Erro ao traduzir parte ${i + 1} do arquivo: $fileName');
            },
            useSecond: true,
          );

          translatedChunks[i] = translatedContent;
          _completedChunks++;

          // Show progress like directory translation
          final remaining = _totalChunks - _completedChunks;
          print('✅ $fileName - parte ${i + 1}/$_totalChunks traduzida ($_completedChunks/$_totalChunks concluídas, $remaining restantes) 🔥⚡');
        } catch (e) {
          translatedChunks[i] = chunks[i]; // Fallback to original content
          _completedChunks++;
          
          final remaining = _totalChunks - _completedChunks;
          print('❌ $fileName - erro na parte ${i + 1}/$_totalChunks ($_completedChunks/$_totalChunks concluídas, $remaining restantes)');
        } finally {
          semaphore.release();
        }
      });
      
      futures.add(future);
    }

    await Future.wait(futures);
    return translatedChunks;
  }
}

class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

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

class FileProcessorImpl implements FileProcessor {
  final Translator translator;
  final MarkdownProcessor markdownProcessor;
  final int maxConcurrentChunks;

  FileProcessorImpl(
    this.translator, 
    this.markdownProcessor, {
    this.maxConcurrentChunks = 10, // LargeFileConfig.defaultMaxConcurrentChunks
  });


  @override
  Future<String> readFile(IFileWrapper file) async {
    return await file.readAsString();
  }

  @override
  Future<void> writeFile(IFileWrapper file, String content) async {
    await file.writeAsString(content);
  }

  @override
  Future<void> translateOne(
    IFileWrapper file,
    bool processLargeFiles,
    Translator translator,
    bool useSecond, {
    int? currentFileIndex,
    int? totalFiles,
    Function()? onComplete,
    Function()? onFailed,
  }) async {
    final fileSizeKB = (await file.length()) / 1024;

    //TODO mover para outro método
    // final swipeLink = arguments.contains('-l');

    // if (swipeLink) {
    //   int countLinks = await LinkProcessorImpl().replaceLinksInFile(file);
    //   print('\n📊 Estatísticas de Links Substituídos:');
    //   print('Total de links substituídos: $countLinks');
    //   return;
    // }

    // Verifica se deve traduzir arquivos grandes
    if (LargeFileConfig.shouldSkipFile(fileSizeKB, processLargeFiles)) {
      print(LargeFileConfig.getSkipMessage());
      return;
    }

    print('🏁 Iniciando tradução: ${Utils.getFileName(file)} - ${fileSizeKB}KB');

    final stopwatchFile = Stopwatch()..start();
    try {
      final content = await file.readAsString();
      String translatedContent;

      if (processLargeFiles && fileSizeKB > LargeFileConfig.maxKbSize) {
        print(LargeFileConfig.getLargeFileDetectedMessage(Utils.getFileName(file)));
        
        // Split the file once
        final splitter = MarkdownSplitter(maxBytes: LargeFileConfig.defaultChunkMaxBytes);
        final chunks = splitter.splitMarkdown(content);
        
        if (chunks.length > 1) {
          print('✂️ Arquivo dividido em ${chunks.length} partes:');
          print('🚀 Iniciando tradução paralela das ${chunks.length} partes...\n');
        }

        
        // Use parallel chunk processor with pre-split chunks
        final processor = EnhancedParallelChunkProcessor(
          translator: translator,
          maxConcurrent: maxConcurrentChunks,
          maxBytes: LargeFileConfig.defaultChunkMaxBytes,
          fileName: Utils.getFileName(file),
        );

        final result = await processor.processChunks(file.path, chunks);
        translatedContent = result.translatedChunks.join('\n\n');
      } else {
        // Single translation for small files
        try {
          translatedContent = await translator.translate(
            content,
            onFirstModelError: () {
              print(
                  '🚨 Erro ao traduzir arquivo:  ${Utils.getFileName(file)}');
            },
            useSecond: useSecond,
          );
        } catch (e) {
          print(
              '❌ Error translating file ${Utils.getFileName(file)}: $e');
          rethrow;
        }
      }
      
      // Validate markdown structure and reference links consistency before saving
      final validationResult = MarkdownStructureValidator.validateStructureAndLinksDetailed(
        content, 
        translatedContent
      );
      
      if (!validationResult.isValid) {
        final fileName = Utils.getFileName(file);
        
        // Check if it's a structure issue or link issue
        final structureValid = MarkdownStructureValidator.validateStructureConsistency(content, translatedContent);
        final linksValid = validationResult.linkValidation.isValid;
        
        if (!structureValid && !linksValid) {
          print('🚫❗ [STRUCTURE & LINKS MISMATCH] File skipped: $fileName ❗🚫');
        } else if (!structureValid) {
          print('🚫❗ [STRUCTURE MISMATCH] File skipped: $fileName ❗🚫');
        } else {
          print('🚫❗ [LINKS MISMATCH] File skipped: $fileName ❗🚫');
        }
        
        // Print detailed information
        if (!structureValid) {
          print('   Original structure: ${MarkdownStructureValidator.countHeaders(content)} elements');
          print('   Translated structure: ${MarkdownStructureValidator.countHeaders(translatedContent)} elements');
        }
        
        if (!linksValid) {
          for (final issue in validationResult.linkValidation.issues) {
            print('   Link issue: $issue');
            //save the file with suffix link_invalid.mad
            final invalidFileName = file.path.replaceFirst('.md', '_link_invalid.md');
            await file.writeAsString(translatedContent);
            print('   Invalid file saved as: $invalidFileName');
          }
        }
        
        if (onFailed != null) {
          onFailed();
        }
        return; // Skip saving the file
      }
      
      String cleanedContent =
          FileCleanerImpl().ensureDontHaveMarkdown(translatedContent);

      String updatedContent;
      if (cleanedContent.contains('---')) {
        updatedContent = cleanedContent.replaceFirst(
          '---',
          '---\nia-translate: true',
        );
      } else {
        updatedContent = '<!-- ia-translate: true -->\n$cleanedContent';
      }

      await file.writeAsString(updatedContent);
      // Execute callback after successful completion or print directly
      if (onComplete != null) {
        onComplete();
      } else {
        String progressText = '';
        if (currentFileIndex != null && totalFiles != null) {
          progressText = ' (${currentFileIndex + 1}/$totalFiles)';
        }
        print(
            '✅🚀 File translated successfully$progressText: ${Utils.getFileName(file)}, em ${stopwatchFile.elapsedMilliseconds}ms 🔥🔥');
      }
    } catch (e) {
      print('❌❌ Error translating file ${Utils.getFileName(file)}: ❌❌ $e');
      // Execute failure callback
      if (onFailed != null) {
        onFailed();
      }
    } finally {
      stopwatchFile.stop();
    }
  }

  @override
  Future<TranslationResult> translateFiles(
    List<IFileWrapper> filesToTranslate,
    bool processLargeFiles, {
    bool useSecond = false,
  }) async {
    int completedCount = 0;
    int failedCount = 0;
    const batchSize = LargeFileConfig.defaultBatchSize; // Reduced batch size for better parallel processing

    print('🚀 Starting parallel translation of ${filesToTranslate.length} files...');

    for (var i = 0; i < filesToTranslate.length; i += batchSize) {
      final batch = filesToTranslate.skip(i).take(batchSize).toList();
      final stopwatchBatch = Stopwatch()..start();

      try {
        // Process files in parallel without artificial delays
        await Future.wait(
          batch.map((file) async {
            final stopwatchFile = Stopwatch()..start();
            try {
              await FileProcessorImpl(
                translator,
                MarkdownProcessorImpl(),
                maxConcurrentChunks: maxConcurrentChunks,
              ).translateOne(
                file,
                processLargeFiles,
                translator,
                useSecond,
                totalFiles: filesToTranslate.length,
                onComplete: () {
                  final currentIndex = ++completedCount;
                  print('✅🚀 File translated successfully ($currentIndex/${filesToTranslate.length}): ${Utils.getFileName(file)}, em ${stopwatchFile.elapsedMilliseconds}ms 🔥🔥');
                  stopwatchFile.stop();
                },
                onFailed: () {
                  final currentFailedIndex = ++failedCount;
                  print('❌ File translation failed ($currentFailedIndex failed of ${filesToTranslate.length}): ${Utils.getFileName(file)}, em ${stopwatchFile.elapsedMilliseconds}ms');
                  stopwatchFile.stop();
                },
              );
              // fileCount removed - we use completedCount and failedCount instead
            } catch (e) {
              final currentFailedIndex = ++failedCount;
              print('❌ File translation failed ($currentFailedIndex failed of ${filesToTranslate.length}): ${Utils.getFileName(file)}, em ${stopwatchFile.elapsedMilliseconds}ms - Error: $e');
              stopwatchFile.stop();
            }
          })
        );

        print('🎯 Batch ${(i ~/ batchSize) + 1} processed in ${stopwatchBatch.elapsedMilliseconds}ms');
      } catch (e) {
        print('❌❌❌ Error in batch processing: ❌❌❌ $e');
      } finally {
        stopwatchBatch.stop();
      }
    }

    return TranslationResult(completedCount, failedCount);
  }
}
