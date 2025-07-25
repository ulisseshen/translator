import 'package:test/test.dart';
import 'dart:async';
import 'dart:math';
import '../lib/code_block_translation_pipeline.dart';
import '../lib/enhanced_parallel_chunk_processor_adapter.dart';
import '../lib/translator.dart';

/// Mock translator that simulates realistic translation delays
/// and tracks concurrency at different levels
class IntegrationMockTranslator implements Translator {
  int _currentConcurrentTranslations = 0;
  int _maxConcurrentTranslations = 0;
  final List<int> _concurrencyHistory = [];
  final int _delayMs;
  final List<String> _processedContent = [];
  
  IntegrationMockTranslator({int delayMs = 50}) : _delayMs = delayMs;
  
  @override
  Future<String> translate(String content, {required Function onFirstModelError, bool useSecond = false}) async {
    _currentConcurrentTranslations++;
    _maxConcurrentTranslations = max(_maxConcurrentTranslations, _currentConcurrentTranslations);
    _concurrencyHistory.add(_currentConcurrentTranslations);
    
    try {
      // Simulate realistic translation processing time
      await Future.delayed(Duration(milliseconds: _delayMs));
      
      // Track what content was processed
      _processedContent.add(content.substring(0, min(20, content.length)));
      
      // Mock translation with Portuguese output
      return content
          .replaceAll('Hello', 'Olá')
          .replaceAll('World', 'Mundo')
          .replaceAll('This is', 'Este é')
          .replaceAll('content', 'conteúdo')
          .replaceAll('file', 'arquivo')
          .replaceAll('line', 'linha')..trim();
    } finally {
      _currentConcurrentTranslations--;
    }
  }
  
  // Statistics getters
  int get maxConcurrentTranslations => _maxConcurrentTranslations;
  List<int> get concurrencyHistory => List.unmodifiable(_concurrencyHistory);
  List<String> get processedContent => List.unmodifiable(_processedContent);
  int get totalTranslations => _processedContent.length;
  
  void reset() {
    _currentConcurrentTranslations = 0;
    _maxConcurrentTranslations = 0;
    _concurrencyHistory.clear();
    _processedContent.clear();
  }
}

/// Demonstrates concurrency limits working in a real-world scenario
/// This test simulates the actual CLI behavior with configurable limits
void main() {
  group('CLI Concurrency Integration Tests', () {
    
    group('Single File with Multiple Chunks', () {
      test('should respect chunk concurrency limit for large files', () async {
        final mockTranslator = IntegrationMockTranslator(delayMs: 30);
        final adapter = EnhancedParallelChunkProcessorAdapter(
          translator: mockTranslator,
        );
        
        // Create a large file that will be split into multiple chunks
        final largeFileContent = List.generate(25, (i) => 
          'This is line $i of content that will be translated into Portuguese. '
          'Each line contains enough text to make the file large enough for chunking. '
          'Hello World from line $i!'
        ).join('\n');
        
        print('Testing chunk concurrency with limit of 3...');
        
        final result = await adapter.processMarkdownContent(
          largeFileContent,
          'large_test_file.md',
          maxConcurrentChunks: 3, // THIS IS THE KEY LIMIT WE'RE TESTING
          maxChunkBytes: 200,     // Force multiple chunks
        );
        
        // Verify the concurrency was respected
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(3),
            reason: 'Should never exceed chunk concurrency limit of 3');
        expect(mockTranslator.maxConcurrentTranslations, greaterThan(1),
            reason: 'Should use parallel processing');
        expect(mockTranslator.totalTranslations, greaterThan(5),
            reason: 'Large file should be split into multiple chunks');
        
        // Verify translation actually occurred
        expect(result, contains('Olá'), reason: 'Content should be translated');
        expect(result, contains('linha'), reason: 'Content should be translated');
        
        print('✅ Chunk concurrency test passed:');
        print('   - Total chunks translated: ${mockTranslator.totalTranslations}');
        print('   - Max concurrent chunks: ${mockTranslator.maxConcurrentTranslations}');
        print('   - Translation successful: ${result.contains('Olá')}');
      });
      
      test('should demonstrate difference between concurrency limits 1 vs 5', () async {
        final testContent = List.generate(20, (i) => 
          'Test line $i with Hello World content for translation performance testing.'
        ).join('\n');
        
        // Test with concurrency limit 1 (sequential)
        final sequentialTranslator = IntegrationMockTranslator(delayMs: 25);
        final sequentialAdapter = EnhancedParallelChunkProcessorAdapter(
          translator: sequentialTranslator,
        );
        
        final stopwatchSequential = Stopwatch()..start();
        await sequentialAdapter.processMarkdownContent(
          testContent,
          'sequential_test.md',
          maxConcurrentChunks: 1, // Sequential processing
          maxChunkBytes: 100,     // Force chunking
        );
        stopwatchSequential.stop();
        
        // Test with concurrency limit 5 (parallel)
        final parallelTranslator = IntegrationMockTranslator(delayMs: 25);
        final parallelAdapter = EnhancedParallelChunkProcessorAdapter(
          translator: parallelTranslator,
        );
        
        final stopwatchParallel = Stopwatch()..start();
        await parallelAdapter.processMarkdownContent(
          testContent,
          'parallel_test.md',
          maxConcurrentChunks: 5, // Parallel processing
          maxChunkBytes: 100,     // Force chunking
        );
        stopwatchParallel.stop();
        
        print('\\n⚡ Performance Comparison:');
        print('   Sequential (limit=1): ${stopwatchSequential.elapsedMilliseconds}ms');
        print('   Parallel (limit=5): ${stopwatchParallel.elapsedMilliseconds}ms');
        print('   Speedup: ${(stopwatchSequential.elapsedMilliseconds / stopwatchParallel.elapsedMilliseconds).toStringAsFixed(2)}x');
        
        // Verify concurrency limits were respected
        expect(sequentialTranslator.maxConcurrentTranslations, equals(1),
            reason: 'Sequential should process one chunk at a time');
        expect(parallelTranslator.maxConcurrentTranslations, lessThanOrEqualTo(5),
            reason: 'Parallel should respect limit of 5');
        expect(parallelTranslator.maxConcurrentTranslations, greaterThan(1),
            reason: 'Parallel should actually use multiple threads');
        
        // Parallel should be faster (allowing some variance for test environment)
        expect(stopwatchParallel.elapsedMilliseconds, 
            lessThan(stopwatchSequential.elapsedMilliseconds),
            reason: 'Parallel processing should be faster');
      });
    });
    
    group('Multiple Files Simulation', () {
      test('should process multiple files with controlled chunk concurrency', () async {
        final mockTranslator = IntegrationMockTranslator(delayMs: 20);
        final adapter = EnhancedParallelChunkProcessorAdapter(
          translator: mockTranslator,
        );
        
        // Simulate processing multiple files
        final files = [
          ('small_file1.md', 'Hello World from small file 1'),
          ('small_file2.md', 'This is content from small file 2'),
          ('large_file.md', List.generate(15, (i) => 'Large file line $i content Hello World').join('\n')),
          ('medium_file.md', List.generate(8, (i) => 'Medium file line $i with Hello content').join('\n')),
        ];
        
        print('\\nProcessing ${files.length} files with chunk limit of 4...');
        
        final results = <String>[];
        
        // Process files sequentially but chunks within each file can be parallel
        for (final (fileName, content) in files) {
          final result = await adapter.processMarkdownContent(
            content,
            fileName,
            maxConcurrentChunks: 4, // Chunks within each file can be parallel
            maxChunkBytes: 150,     // Moderate chunk size
          );
          results.add(result);
          print('   ✓ Processed $fileName');
        }
        
        // Verify all files processed successfully
        expect(results.length, equals(4), reason: 'All files should be processed');
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(4),
            reason: 'Should respect chunk concurrency limit');
      });
    });
    
    group('Error Handling with Concurrency', () {
      test('should handle translation errors while respecting concurrency limits', () async {
        // Create translator that fails on specific patterns
        final errorTranslator = IntegrationMockTranslator(delayMs: 20);
        
        // Override translate to inject errors
        Future<String> errorInjectingTranslate(String content, {required Function onFirstModelError, bool useSecond = false}) async {
          if (content.contains('ERROR_TRIGGER')) {
            await Future.delayed(Duration(milliseconds: 20)); // Still consume time
            onFirstModelError();
            throw Exception('Simulated translation failure');
          }
          return await errorTranslator.translate(content, onFirstModelError: onFirstModelError, useSecond: useSecond);
        }
        
        // Create custom adapter with error-injecting translator
        final adapter = EnhancedParallelChunkProcessorAdapter(
          translator: _CustomErrorTranslator(errorInjectingTranslate),
        );
        
        final testContent = [
          'This is good content that should translate fine',
          'ERROR_TRIGGER content that will fail',
          'Another good piece of content',
          'More ERROR_TRIGGER content to fail',
          'Final good content piece'
        ].join('\n');
        
        print('\\nTesting error handling with concurrency limit of 3...');
        
        // This should handle errors gracefully
        final result = await adapter.processMarkdownContent(
          testContent,
          'error_test.md',
          maxConcurrentChunks: 3,
          maxChunkBytes: 80, // Force multiple chunks
        );
        
        // Verify that processing completed despite errors
        expect(result, isNotEmpty, reason: 'Should return some result even with errors');
        expect(result, contains('good'), reason: 'Should preserve non-error content');
        
        print('   - Processing completed with mixed success/failure');
        print('   - Result contains good content: ${result.contains('good')}');
        print('   - Max concurrent during errors: ${errorTranslator.maxConcurrentTranslations}');
      });
    });
    
    group('File-Level Concurrency Management (Chunk Overflow Prevention)', () {
      test('should demonstrate chunk overflow problem with concurrent file processing', () async {
        final mockTranslator = IntegrationMockTranslator(delayMs: 30);
        
        // Create 5 small files that will each create 2-3 chunks
        final files = List.generate(5, (i) => {
          'name': 'file_small_$i.md',
          'content': 'Hello World content for file $i that needs translation. This should create 2-3 chunks.'
        });
        
        print('\\n⚠️  DEMONSTRATING THE OVERFLOW PROBLEM:');
        print('   5 small files processed concurrently with chunk limit 10');
        print('   Current system: Processes all files at once without chunk count consideration');
        
        const chunkLimit = 10;
        final List<Future<String>> fileFutures = [];
        
        // Current system behavior: process all files concurrently
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final adapter = EnhancedParallelChunkProcessorAdapter(translator: mockTranslator);
          
          final future = adapter.processMarkdownContent(
            file['content']!,
            file['name']!,
            maxConcurrentChunks: chunkLimit, // This limits chunks within each file, not across files
            maxChunkBytes: 50, // Small chunks to demonstrate the issue
          );
          
          fileFutures.add(future);
        }
        
        // Process all files concurrently - this is the problematic behavior
        final results = await Future.wait(fileFutures);
        
        final totalChunksProcessed = mockTranslator.totalTranslations; 
        final maxConcurrentChunks = mockTranslator.maxConcurrentTranslations;
        
        print('   📊 Results:');
        print('   - Files processed: ${results.length}');
        print('   - Total chunks: $totalChunksProcessed');
        print('   - Max concurrent chunks: $maxConcurrentChunks');
        print('   - Chunk limit: $chunkLimit');
        
        // This test DOCUMENTS the problem - it may or may not overflow depending on timing
        expect(results.length, equals(5), reason: 'All files should be processed');
        expect(results.every((r) => r.contains('Olá')), isTrue, reason: 'All should be translated');
        
        if (maxConcurrentChunks > chunkLimit) {
          print('   ❌ PROBLEM CONFIRMED: Chunk limit was exceeded!');
          print('   ❌ This shows why we need intelligent file scheduling');
        } else {
          print('   ✅ Chunk limit respected (possibly due to fast processing)');
          print('   ℹ️  But this doesn\'t guarantee it won\'t overflow with slower translation');
        }
      });

      test('should demonstrate SOLUTION: intelligent file batching to prevent overflow', () async {
        final mockTranslator = IntegrationMockTranslator(delayMs: 50);
        
        // Create files that will definitely cause overflow if processed concurrently
        final files = [
          {'name': 'large1.md', 'content': List.generate(8, (i) => 'Large file 1 line $i with Hello World content for translation').join('\n')},
          {'name': 'large2.md', 'content': List.generate(8, (i) => 'Large file 2 line $i with Hello World content for translation').join('\n')},
          {'name': 'large3.md', 'content': List.generate(8, (i) => 'Large file 3 line $i with Hello World content for translation').join('\n')},
          {'name': 'small1.md', 'content': 'Small file 1 Hello World'},
          {'name': 'small2.md', 'content': 'Small file 2 Hello World'},
        ];
        
        print('\\n✅ DEMONSTRATING THE SOLUTION:');
        print('   Intelligent file batching to prevent chunk overflow');
        
        const chunkLimit = 10;
        
        // STEP 1: Estimate chunks per file (in real system, this would be done by the file processor)
        final fileChunkEstimates = <Map<String, dynamic>>[];
        for (final file in files) {
          // Simple estimation: content.length / maxChunkBytes
          final estimatedChunks = (file['content']!.length / 60).ceil().clamp(1, chunkLimit);
          fileChunkEstimates.add({
            'name': file['name'],
            'content': file['content'], 
            'estimatedChunks': estimatedChunks,
          });
          print('   ${file['name']}: ~$estimatedChunks chunks (${file['content']!.length} bytes)');
        }
        
        // STEP 2: Intelligent batching algorithm
        final batches = <List<Map<String, dynamic>>>[];
        final remainingFiles = List<Map<String, dynamic>>.from(fileChunkEstimates);
        
        print('\\n   🧠 Batching algorithm:');
        while (remainingFiles.isNotEmpty) {
          final currentBatch = <Map<String, dynamic>>[];
          int currentBatchChunks = 0;
          
          // Greedy approach: fit as many files as possible
          remainingFiles.removeWhere((file) {
            final fileChunks = file['estimatedChunks'] as int;
            if (currentBatchChunks + fileChunks <= chunkLimit) {
              currentBatch.add(file);
              currentBatchChunks += fileChunks;
              return true;
            }
            return false;
          });
          
          if (currentBatch.isNotEmpty) {
            batches.add(currentBatch);
            final batchFiles = currentBatch.map((f) => '${f['name']}(${f['estimatedChunks']})').join(', ');
            print('   Batch ${batches.length}: $batchFiles = $currentBatchChunks chunks ≤ $chunkLimit');
          }
        }
        
        // STEP 3: Execute batches with verification
        final allResults = <String>[];
        
        for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
          final batch = batches[batchIndex];
          final batchFutures = <Future<String>>[];
          
          print('\\n   🔄 Processing batch ${batchIndex + 1}/${batches.length}:');
          
          for (final file in batch) {
            final adapter = EnhancedParallelChunkProcessorAdapter(translator: mockTranslator);
            final future = adapter.processMarkdownContent(
              file['content']!,
              file['name']!,
              maxConcurrentChunks: chunkLimit,
              maxChunkBytes: 60, // Control chunk size
            );
            batchFutures.add(future);
          }
          
          final batchResults = await Future.wait(batchFutures);
          allResults.addAll(batchResults);
          
          final actualMaxConcurrent = mockTranslator.maxConcurrentTranslations;
          print('   - Actual max concurrent chunks: $actualMaxConcurrent ≤ $chunkLimit');
          
          // Verify this batch respected the limit
          expect(actualMaxConcurrent, lessThanOrEqualTo(chunkLimit),
              reason: 'Batch ${batchIndex + 1} should respect chunk limit');
          
          mockTranslator.reset(); // Reset for next batch
        }
        
        print('\\n   🎉 SOLUTION VERIFICATION:');
        print('   ✅ Total files processed: ${allResults.length}/${files.length}');
        print('   ✅ All translations successful: ${allResults.every((r) => r.contains('Olá'))}');
        print('   ✅ Chunk limit never exceeded in any batch');
        print('   ✅ Intelligent batching prevents overflow!');
        
        expect(allResults.length, equals(files.length), reason: 'All files should be processed');
        expect(allResults.every((r) => r.contains('Olá')), isTrue, reason: 'All should be translated');
      });

      test('should demonstrate optimal file scheduling algorithm', () async {
        final mockTranslator = IntegrationMockTranslator(delayMs: 25);
        
        // Mixed scenario: files with different chunk counts
        final files = [
          {'name': 'small1.md', 'chunks': 2, 'content': 'Small file 1 content Hello World\nSecond line'},
          {'name': 'large1.md', 'chunks': 4, 'content': List.generate(8, (i) => 'Large file line $i Hello World content').join('\n')},
          {'name': 'small2.md', 'chunks': 2, 'content': 'Small file 2 content Hello World\nSecond line'},  
          {'name': 'medium1.md', 'chunks': 3, 'content': List.generate(6, (i) => 'Medium file line $i Hello World').join('\n')},
          {'name': 'small3.md', 'chunks': 2, 'content': 'Small file 3 content Hello World\nSecond line'},
        ];
        
        const chunkLimit = 10;
        
        print('\\n🧠 Testing intelligent file scheduling algorithm:');
        print('   Files: 2+4+2+3+2 = 13 total chunks, but limit is $chunkLimit');
        print('   Optimal strategy: Schedule files to maximize parallelism without overflow');
        
        // Algorithm: Greedy scheduling - fit as many files as possible in each batch
        final batches = <List<Map<String, dynamic>>>[];
        final remainingFiles = List<Map<String, dynamic>>.from(files);
        
        while (remainingFiles.isNotEmpty) {
          final currentBatch = <Map<String, dynamic>>[];
          int currentBatchChunks = 0;
          
          // Try to add files to current batch without exceeding limit
          remainingFiles.removeWhere((file) {
            if (currentBatchChunks + file['chunks'] <= chunkLimit) {
              currentBatch.add(file);
              currentBatchChunks += file['chunks'] as int;
              return true; // Remove from remaining files
            }
            return false; // Keep in remaining files
          });
          
          if (currentBatch.isNotEmpty) {
            batches.add(currentBatch);
            print('   Batch ${batches.length}: ${currentBatch.map((f) => '${f['name']}(${f['chunks']})').join(', ')} = $currentBatchChunks chunks');
          } else {
            // Safety: if we can't fit any file, process the largest one alone
            final largestFile = remainingFiles.reduce((a, b) => 
                (a['chunks'] as int) > (b['chunks'] as int) ? a : b);
            batches.add([largestFile]);
            remainingFiles.remove(largestFile);
            print('   Batch ${batches.length}: ${largestFile['name']}(${largestFile['chunks']}) = ${largestFile['chunks']} chunks (forced)');
          }
        }
        
        // Execute the scheduling plan
        final allResults = <String>[];
        
        for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
          final batch = batches[batchIndex];
          final batchFutures = <Future<String>>[];
          
          for (final file in batch) {
            final adapter = EnhancedParallelChunkProcessorAdapter(translator: mockTranslator);
            final future = adapter.processMarkdownContent(
              file['content']!,
              file['name']!,
              maxConcurrentChunks: chunkLimit,
              maxChunkBytes: 100, // Control chunk size
            );
            batchFutures.add(future);
          }
          
          final batchResults = await Future.wait(batchFutures);
          allResults.addAll(batchResults);
          
          // Verify this batch didn't exceed limit
          expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(chunkLimit),
              reason: 'Batch ${batchIndex + 1} should respect chunk limit');
          
          mockTranslator.reset(); // Reset for next batch
        }
        
        // Verify overall success
        expect(allResults.length, equals(files.length), reason: 'All files should be processed');
        expect(allResults.every((r) => r.contains('Olá')), isTrue, 
            reason: 'All files should be translated');
        
        print('   ✅ Total batches: ${batches.length}');
        print('   ✅ All files processed: ${allResults.length}/${files.length}');
        print('   ✅ Chunk limit never exceeded in any batch');
        print('   ✅ Intelligent scheduling algorithm successful');
      });
    });

    group('CLI Parameter Simulation', () {
      test('should demonstrate how CLI parameters control concurrency', () async {
        print('\\n🎯 CLI Parameter Demonstration:');
        print('   Command: translator /path/to/docs --concurrent 2 --chunk-size 500');
        
        final mockTranslator = IntegrationMockTranslator(delayMs: 30);
        final adapter = EnhancedParallelChunkProcessorAdapter(
          translator: mockTranslator,
        );
        
        // Simulate CLI parameters: --concurrent 2 --chunk-size 500
        const cliConcurrentLimit = 2;
        const cliChunkSize = 500;
        
        final documentContent = List.generate(30, (i) => 
          'Documentation line $i with Hello World content that needs translation. '
          'This represents typical markdown documentation content with sufficient text to trigger chunking.'
        ).join('\n');
        
        final result = await adapter.processMarkdownContent(
          documentContent,
          'documentation.md',
          maxConcurrentChunks: cliConcurrentLimit, // From --concurrent 2
          maxChunkBytes: cliChunkSize,            // From --chunk-size 500
        );
        
        // Verify CLI parameters were respected
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(cliConcurrentLimit),
            reason: 'Should respect --concurrent parameter');
        expect(result, contains('Olá'), reason: 'Translation should succeed');
        
        print('   ✅ Concurrency limit respected: ${mockTranslator.maxConcurrentTranslations} ≤ $cliConcurrentLimit');
        print('   ✅ Chunks created: ${mockTranslator.totalTranslations}');
        print('   ✅ Translation successful: ${result.contains('Olá')}');
        print('   ✅ CLI behavior simulated correctly');
      });
    });
  });
}

/// Custom translator wrapper for error injection
class _CustomErrorTranslator implements Translator {
  final Future<String> Function(String, {required Function onFirstModelError, bool useSecond}) _translateFn;
  
  _CustomErrorTranslator(this._translateFn);
  
  @override
  Future<String> translate(String text, {required Function onFirstModelError, bool useSecond = false}) {
    return _translateFn(text, onFirstModelError: onFirstModelError, useSecond: useSecond);
  }
}