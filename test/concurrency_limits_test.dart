import 'package:test/test.dart';
import 'dart:async';
import 'dart:math';
import 'package:translator/code_block_translation_pipeline.dart';

/// Mock translator that tracks concurrency and simulates translation delay
class ConcurrencyTrackingTranslator {
  int _currentConcurrentTranslations = 0;
  int _maxConcurrentTranslations = 0;
  final List<int> _concurrencyHistory = [];
  final int _delayMs;
  
  ConcurrencyTrackingTranslator({int delayMs = 100}) : _delayMs = delayMs;
  
  Future<String> translate(String content, {void Function()? onFirstModelError}) async {
    _currentConcurrentTranslations++;
    _maxConcurrentTranslations = max(_maxConcurrentTranslations, _currentConcurrentTranslations);
    _concurrencyHistory.add(_currentConcurrentTranslations);
    
    try {
      // Simulate translation work
      await Future.delayed(Duration(milliseconds: _delayMs));
      
      // Simple mock translation - just add "TRANSLATED: " prefix
      return 'TRANSLATED: $content';
    } finally {
      _currentConcurrentTranslations--;
    }
  }
  
  int get maxConcurrentTranslations => _maxConcurrentTranslations;
  List<int> get concurrencyHistory => List.unmodifiable(_concurrencyHistory);
  
  void reset() {
    _currentConcurrentTranslations = 0;
    _maxConcurrentTranslations = 0;
    _concurrencyHistory.clear();
  }
}

void main() {
  group('Concurrency Limits Tests', () {
    late ConcurrencyTrackingTranslator mockTranslator;
    late CodeBlockTranslationPipeline pipeline;
    
    setUp(() {
      mockTranslator = ConcurrencyTrackingTranslator(delayMs: 50);
      pipeline = CodeBlockTranslationPipeline();
    });
    
    group('Chunk-Level Concurrency', () {
      test('should respect chunk concurrency limit of 3', () async {
        // Create content that will be split into many small chunks
        final largeContent = List.generate(20, (i) => 'Line $i with some content to make it longer').join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent,
          translator: mockTranslator.translate,
          maxBytes: 50, // Force many small chunks
          maxConcurrency: 3, // Limit to 3 concurrent translations
        );
        
        expect(result.processedChunks.length, greaterThan(5), 
            reason: 'Should create multiple chunks to test concurrency');
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(3),
            reason: 'Should never exceed the specified concurrency limit of 3');
        expect(mockTranslator.maxConcurrentTranslations, greaterThan(1),
            reason: 'Should actually use parallel processing');
            
        print('Chunks created: ${result.processedChunks.length}');
        print('Max concurrent translations: ${mockTranslator.maxConcurrentTranslations}');
        print('Concurrency history: ${mockTranslator.concurrencyHistory.take(10)}...');
      });
      
      test('should respect chunk concurrency limit of 1 (sequential)', () async {
        mockTranslator.reset();
        
        final largeContent = List.generate(10, (i) => 'Line $i with content').join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent,
          translator: mockTranslator.translate,
          maxBytes: 30, // Force multiple chunks
          maxConcurrency: 1, // Force sequential processing
        );
        
        expect(result.processedChunks.length, greaterThan(3),
            reason: 'Should create multiple chunks');
        expect(mockTranslator.maxConcurrentTranslations, equals(1),
            reason: 'Should never exceed the specified concurrency limit of 1');
            
        // Verify that translations were truly sequential
        expect(mockTranslator.concurrencyHistory.every((count) => count == 1), isTrue,
            reason: 'All translations should be sequential with concurrency of 1');
            
        print('Sequential processing - Chunks: ${result.processedChunks.length}');
        print('Max concurrent: ${mockTranslator.maxConcurrentTranslations}');
      });
      
      test('should respect chunk concurrency limit of 5', () async {
        mockTranslator.reset();
        
        final largeContent = List.generate(30, (i) => 'Line $i with some content here').join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent,
          translator: mockTranslator.translate,
          maxBytes: 40, // Force many chunks
          maxConcurrency: 5, // Test with limit of 5
        );
        
        expect(result.processedChunks.length, greaterThan(8),
            reason: 'Should create many chunks to test concurrency');
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(5),
            reason: 'Should never exceed the specified concurrency limit of 5');
        expect(mockTranslator.maxConcurrentTranslations, greaterThan(2),
            reason: 'Should use parallel processing effectively');
            
        print('Limit 5 test - Chunks: ${result.processedChunks.length}');
        print('Max concurrent: ${mockTranslator.maxConcurrentTranslations}');
      });
      
      test('should handle more chunks than concurrency limit', () async {
        mockTranslator.reset();
        
        // Create content that will result in exactly 15 chunks
        final largeContent = List.generate(15, (i) => 'Chunk $i content that is exactly sized').join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent,
          translator: mockTranslator.translate,
          maxBytes: 35, // Size to get approximately 15 chunks
          maxConcurrency: 4, // Much less than number of chunks
        );
        
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(4),
            reason: 'Should never exceed the specified concurrency limit');
        expect(mockTranslator.maxConcurrentTranslations, greaterThan(1),
            reason: 'Should use parallel processing');
            
        // Verify all content was translated
        expect(result.translatedContent, contains('TRANSLATED:'));
        
        print('15 chunks with limit 4 - Max concurrent: ${mockTranslator.maxConcurrentTranslations}');
        print('Total chunks processed: ${result.processedChunks.length}');
      });
      
      test('should track progress callback with concurrency limits', () async {
        mockTranslator.reset();
        
        final progressUpdates = <String>[];
        int totalChunks = 0;
        
        final largeContent = List.generate(12, (i) => 'Progress test line $i with content').join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent,
          translator: mockTranslator.translate,
          maxBytes: 45,
          maxConcurrency: 3,
          progressCallback: (completed, total) {
            totalChunks = total;
            progressUpdates.add('$completed/$total');
          },
        );
        
        expect(progressUpdates, isNotEmpty, reason: 'Should report progress');
        expect(progressUpdates.last, equals('$totalChunks/$totalChunks'),
            reason: 'Final progress should show completion');
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(3),
            reason: 'Should respect concurrency limit during progress tracking');
            
        print('Progress updates: ${progressUpdates.take(5)}...');
        print('Total chunks with progress: $totalChunks');
      });
    });
    
    group('Edge Cases and Error Handling', () {
      test('should handle translation errors without exceeding concurrency', () async {
        mockTranslator.reset();
        
        int errorCount = 0;
        errorTranslator(String content) async {
          mockTranslator._currentConcurrentTranslations++;
          mockTranslator._maxConcurrentTranslations = max(mockTranslator._maxConcurrentTranslations, mockTranslator._currentConcurrentTranslations);
          
          try {
            await Future.delayed(Duration(milliseconds: 30));
            
            // Simulate errors in some chunks
            if (content.contains('error')) {
              errorCount++;
              throw Exception('Mock translation error');
            }
            
            return 'TRANSLATED: $content';
          } finally {
            mockTranslator._currentConcurrentTranslations--;
          }
        }
        
        final contentWithErrors = [
          'Normal line 1',
          'This line has error keyword',
          'Normal line 2', 
          'Another error line',
          'Normal line 3',
          'Final error line',
          'Normal line 4'
        ].join('\n');
        
        final result = await pipeline.translateContentParallel(
          originalContent: contentWithErrors,
          translator: errorTranslator,
          maxBytes: 30,
          maxConcurrency: 2,
        );
        
        expect(errorCount, greaterThan(0), reason: 'Should have encountered errors');
        expect(mockTranslator.maxConcurrentTranslations, lessThanOrEqualTo(2),
            reason: 'Should respect concurrency limit even with errors');
        expect(result.translatedContent, contains('TRANSLATED:'),
            reason: 'Should translate non-error chunks successfully');
            
        print('Errors encountered: $errorCount');
        print('Max concurrent with errors: ${mockTranslator.maxConcurrentTranslations}');
      });
      
      test('should handle zero concurrency gracefully', () async {
        mockTranslator.reset();
        
        final content = 'Simple content for zero concurrency test';
        
        final result =  pipeline.translateContentParallel(
          originalContent: content,
          translator: mockTranslator.translate,
          maxConcurrency: 0, // Edge case: zero concurrency
        );
        
        // Should still work but with minimal processing
        expect(() => result, throwsA(isA<AssertionError>()),
            reason: 'Zero concurrency should throw an error'); 
      });
    });
    
    group('Performance Validation', () {
      test('should show performance benefit of parallel processing', () async {
        final content = List.generate(20, (i) => 'Performance test line $i').join('\n');
        
        // Test sequential processing (concurrency = 1)
        final sequentialTranslator = ConcurrencyTrackingTranslator(delayMs: 25);
        final stopwatchSequential = Stopwatch()..start();
        
        await pipeline.translateContentParallel(
          originalContent: content,
          translator: sequentialTranslator.translate,
          maxBytes: 30,
          maxConcurrency: 1,
        );
        
        stopwatchSequential.stop();
        final sequentialTime = stopwatchSequential.elapsedMilliseconds;
        
        // Test parallel processing (concurrency = 4)
        final parallelTranslator = ConcurrencyTrackingTranslator(delayMs: 25);
        final stopwatchParallel = Stopwatch()..start();
        
        await pipeline.translateContentParallel(
          originalContent: content,
          translator: parallelTranslator.translate,
          maxBytes: 30,
          maxConcurrency: 4,
        );
        
        stopwatchParallel.stop();
        final parallelTime = stopwatchParallel.elapsedMilliseconds;
        
        print('Sequential time (concurrency=1): ${sequentialTime}ms');
        print('Parallel time (concurrency=4): ${parallelTime}ms');
        print('Performance improvement: ${(sequentialTime / parallelTime).toStringAsFixed(2)}x');
        
        // Parallel should be significantly faster (allowing some variance for test environment)
        expect(parallelTime, lessThan(sequentialTime * 0.8),
            reason: 'Parallel processing should be significantly faster');
        expect(parallelTranslator.maxConcurrentTranslations, greaterThan(1),
            reason: 'Should actually use parallel processing');
      });
    });
  });
}