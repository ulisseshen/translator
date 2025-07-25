import 'package:test/test.dart';
import 'dart:async';
import 'dart:math';
import 'package:translator/translator.dart';

import '../bin/src/app.dart';

/// Mock file wrapper that implements IFileWrapper interface
class MockIFileWrapper implements IFileWrapper {
  final String _path;
  final String _content;
  final double _sizeKB;
  String _storedContent;

  MockIFileWrapper(this._path, this._content, this._sizeKB)
      : _storedContent = _content;

  @override
  String get path => _path;

  @override
  Future<String> readAsString() async => _storedContent;

  @override
  Future<void> writeAsString(String content) async {
    _storedContent = content;
  }

  @override
  Future<int> length() async => (_sizeKB * 1024).round();

  @override
  bool exists() => true;
  
  @override
  Future<List<String>> readAsLines() {
    return Future.value(_storedContent.split('\n'));
  }
}


/// Mock translator that tracks file-level concurrency during batch processing
class BatchTrackingTranslator implements Translator {
  int _currentConcurrentFiles = 0;
  int _maxConcurrentFiles = 0;
  final List<int> _concurrencySnapshots = [];
  final int _delayMs;
  final List<String> _processedFiles = [];
  final Map<String, DateTime> _fileStartTimes = {};
  final Map<String, DateTime> _fileEndTimes = {};

  BatchTrackingTranslator({int delayMs = 50}) : _delayMs = delayMs;

  @override
  Future<String> translate(String content,
      {required Function onFirstModelError, bool useSecond = false}) async {
    // Extract filename from content for tracking (simplified approach)
    final fileName = _extractFileName(content);

    if (!_fileStartTimes.containsKey(fileName)) {
      _currentConcurrentFiles++;
      _maxConcurrentFiles = max(_maxConcurrentFiles, _currentConcurrentFiles);
      _concurrencySnapshots.add(_currentConcurrentFiles);
      _fileStartTimes[fileName] = DateTime.now();
    }

    try {
      // Simulate translation work
      await Future.delayed(Duration(milliseconds: _delayMs));

      // Track successful processing
      if (!_processedFiles.contains(fileName)) {
        _processedFiles.add(fileName);
      }

      return 'TRANSLATED: $content';
    } finally {
      if (!_fileEndTimes.containsKey(fileName)) {
        _fileEndTimes[fileName] = DateTime.now();
        _currentConcurrentFiles--;
      }
    }
  }

  String _extractFileName(String content) {
    // Simple heuristic to identify files by content patterns
    if (content.contains('File 0')) return 'file0.md';
    if (content.contains('File 1')) return 'file1.md';
    if (content.contains('File 2')) return 'file2.md';
    if (content.contains('File 3')) return 'file3.md';
    if (content.contains('File 4')) return 'file4.md';
    if (content.contains('File 5')) return 'file5.md';
    if (content.contains('File 6')) return 'file6.md';
    if (content.contains('File 7')) return 'file7.md';
    return 'unknown.md';
  }

  // Statistics getters
  int get maxConcurrentFiles => _maxConcurrentFiles;
  List<int> get concurrencySnapshots =>
      List.unmodifiable(_concurrencySnapshots);
  List<String> get processedFiles => List.unmodifiable(_processedFiles);
  Map<String, DateTime> get fileStartTimes => Map.unmodifiable(_fileStartTimes);
  Map<String, DateTime> get fileEndTimes => Map.unmodifiable(_fileEndTimes);

  void reset() {
    _currentConcurrentFiles = 0;
    _maxConcurrentFiles = 0;
    _concurrencySnapshots.clear();
    _processedFiles.clear();
    _fileStartTimes.clear();
    _fileEndTimes.clear();
  }

  void printBatchStatistics() {
    print('   📊 Batch Processing Statistics:');
    print('   - Max concurrent files: $_maxConcurrentFiles');
    print('   - Total files processed: ${_processedFiles.length}');
    print(
        '   - Concurrency snapshots: ${_concurrencySnapshots.take(10).toList()}...');

    if (_fileStartTimes.isNotEmpty && _fileEndTimes.isNotEmpty) {
      final processingTimes = _processedFiles
          .map((file) {
            final start = _fileStartTimes[file];
            final end = _fileEndTimes[file];
            if (start != null && end != null) {
              return end.difference(start).inMilliseconds;
            }
            return 0;
          })
          .where((time) => time > 0)
          .toList();

      if (processingTimes.isNotEmpty) {
        final avgTime =
            processingTimes.reduce((a, b) => a + b) / processingTimes.length;
        print(
            '   - Average file processing time: ${avgTime.toStringAsFixed(1)}ms');
      }
    }
  }
}

/// ATDD Integration Test for FileProcessorImpl batch processing with concurrency limits
/// This test validates the actual CLI behavior using real FileProcessorImpl.translateFiles
void main() {
  group('FileProcessor ATDD Integration Tests', () {
    group('Batch Processing with File Concurrency Limits', () {
      test('should respect maxConcurrentFiles=2 when processing 6 files',
          () async {
        final mockTranslator = BatchTrackingTranslator(delayMs: 100);
        const maxConcurrentFilesLimit = 2;

        final fileProcessor = FileProcessorImpl(
          mockTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 5,
          maxConcurrentFiles: maxConcurrentFilesLimit,
        );

        // Create 6 files for batch processing
        final files = List.generate(
            6,
            (i) => MockIFileWrapper(
                  'test_file_$i.md',
                  'ia-translate: true\n\nFile $i content for batch processing test\n\nThis is test content.',
                  2.0, // 2KB each file
                ));

        print(
            '🎯 ATDD Test: Processing ${files.length} files with maxConcurrentFiles=$maxConcurrentFilesLimit');

        final stopwatch = Stopwatch()..start();

        final result = await fileProcessor.translateFiles(
          files,
          false, // processLargeFiles
          useSecond: false,
        );

        stopwatch.stop();

        // Verify batch processing results
        expect(result.successCount, equals(6),
            reason: 'All 6 files should be processed successfully');
        expect(result.failureCount, equals(0), reason: 'No files should fail');

        // Critical ATDD assertion: File concurrency limit must be respected
        expect(mockTranslator.maxConcurrentFiles,
            lessThanOrEqualTo(maxConcurrentFilesLimit),
            reason:
                'FileProcessor must respect maxConcurrentFiles limit of $maxConcurrentFilesLimit');
        expect(mockTranslator.maxConcurrentFiles, greaterThan(1),
            reason: 'Should actually use parallel processing');

        // Verify all files were processed
        expect(mockTranslator.processedFiles.length, equals(6),
            reason: 'All files should be tracked as processed');

        mockTranslator.printBatchStatistics();
        print('   ✅ Total processing time: ${stopwatch.elapsedMilliseconds}ms');
        print('   ✅ ATDD Test Passed: Batch concurrency limit respected');
      });

      test('should demonstrate batch size effect: 1 vs 3 vs 5 concurrent files',
          () async {
        print('\n🔬 ATDD Performance Analysis: Batch Size Impact');

        final testFiles = List.generate(
            8,
            (i) => MockIFileWrapper(
                  'perf_test_$i.md',
                  'ia-translate: true\n\nFile $i performance test content\n\nTesting batch processing.',
                  1.5, // 1.5KB each
                ));

        // Test 1: Sequential processing (maxConcurrentFiles = 1)
        print('\n   Test 1: Sequential (maxConcurrentFiles=1)');
        final sequentialTranslator = BatchTrackingTranslator(delayMs: 80);
        final sequentialProcessor = FileProcessorImpl(
          sequentialTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 5,
          maxConcurrentFiles: 1,
        );

        final stopwatch1 = Stopwatch()..start();
        final result1 =
            await sequentialProcessor.translateFiles(testFiles, false);
        stopwatch1.stop();

        // Test 2: Moderate parallelism (maxConcurrentFiles = 3)
        print('\n   Test 2: Moderate Parallel (maxConcurrentFiles=3)');
        final moderateTranslator = BatchTrackingTranslator(delayMs: 80);
        final moderateProcessor = FileProcessorImpl(
          moderateTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 5,
          maxConcurrentFiles: 3,
        );

        final stopwatch2 = Stopwatch()..start();
        final result2 =
            await moderateProcessor.translateFiles(testFiles, false);
        stopwatch2.stop();

        // Test 3: High parallelism (maxConcurrentFiles = 5)
        print('\n   Test 3: High Parallel (maxConcurrentFiles=5)');
        final highTranslator = BatchTrackingTranslator(delayMs: 80);
        final highProcessor = FileProcessorImpl(
          highTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 5,
          maxConcurrentFiles: 5,
        );

        final stopwatch3 = Stopwatch()..start();
        final result3 = await highProcessor.translateFiles(testFiles, false);
        stopwatch3.stop();

        // ATDD Assertions: Verify concurrency limits
        expect(sequentialTranslator.maxConcurrentFiles, equals(1),
            reason: 'Sequential should process exactly 1 file at a time');
        expect(moderateTranslator.maxConcurrentFiles, lessThanOrEqualTo(3),
            reason: 'Moderate should respect limit of 3');
        expect(highTranslator.maxConcurrentFiles, lessThanOrEqualTo(5),
            reason: 'High should respect limit of 5');

        // All should succeed
        expect(
            result1.successCount + result2.successCount + result3.successCount,
            equals(24),
            reason: 'All files in all tests should succeed');

        // Performance analysis
        print('\n   📈 Performance Results:');
        print('   - Sequential (1): ${stopwatch1.elapsedMilliseconds}ms');
        print('   - Moderate (3): ${stopwatch2.elapsedMilliseconds}ms');
        print('   - High (5): ${stopwatch3.elapsedMilliseconds}ms');

        final speedup3 =
            stopwatch1.elapsedMilliseconds / stopwatch2.elapsedMilliseconds;
        final speedup5 =
            stopwatch1.elapsedMilliseconds / stopwatch3.elapsedMilliseconds;

        print('   - Speedup (3 vs 1): ${speedup3.toStringAsFixed(2)}x');
        print('   - Speedup (5 vs 1): ${speedup5.toStringAsFixed(2)}x');

        // High parallelism should be faster
        expect(stopwatch3.elapsedMilliseconds,
            lessThan(stopwatch1.elapsedMilliseconds),
            reason: 'High parallelism should be faster than sequential');
      });

      test('should handle mixed file sizes with appropriate batching',
          () async {
        print('\n🎯 ATDD Test: Mixed File Sizes with Batch Processing');

        final mockTranslator = BatchTrackingTranslator(delayMs: 60);
        const batchLimit = 3;

        final fileProcessor = FileProcessorImpl(
          mockTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 4,
          maxConcurrentFiles: batchLimit,
        );

        // Create mixed file sizes
        final mixedFiles = [
          // Small files (will not be chunked)
          MockIFileWrapper(
              'small1.md', 'ia-translate: true\n\nFile 0 small content', 1.0),
          MockIFileWrapper(
              'small2.md', 'ia-translate: true\n\nFile 1 small content', 1.2),

          // Medium files (might be chunked)
          MockIFileWrapper(
              'medium1.md',
              'ia-translate: true\n\n' +
                  List.generate(
                          15, (i) => 'File 2 medium line $i with more content')
                      .join('\n'),
              8.0),
          MockIFileWrapper(
              'medium2.md',
              'ia-translate: true\n\n' +
                  List.generate(12, (i) => 'File 3 medium line $i with content')
                      .join('\n'),
              6.5),

          // Large files (will definitely be chunked if processLargeFiles=true)
          MockIFileWrapper(
              'large1.md',
              'ia-translate: true\n\n' +
                  List.generate(
                          40,
                          (i) =>
                              'File 4 large line $i with substantial content for testing')
                      .join('\n'),
              25.0),
          MockIFileWrapper(
              'large2.md',
              'ia-translate: true\n\n' +
                  List.generate(35,
                          (i) => 'File 5 large line $i with extensive content')
                      .join('\n'),
              22.0),
        ];

        print(
            '   Processing ${mixedFiles.length} mixed-size files with batch limit $batchLimit');

        // Test with large file processing enabled
        final result = await fileProcessor.translateFiles(
          mixedFiles,
          true, // processLargeFiles = true to enable chunking for large files
          useSecond: false,
        );

        // ATDD Assertions
        expect(result.successCount, equals(6),
            reason: 'All mixed-size files should process successfully');
        expect(result.failureCount, equals(0),
            reason: 'No files should fail with mixed sizes');

        expect(mockTranslator.maxConcurrentFiles, lessThanOrEqualTo(batchLimit),
            reason:
                'Mixed file processing must respect batch concurrency limit');

        // Verify all files were processed
        expect(mockTranslator.processedFiles.length, equals(6),
            reason: 'All 6 mixed files should be tracked');

        mockTranslator.printBatchStatistics();
        print('   ✅ Mixed file sizes processed successfully with batching');
      });

      test(
          'should handle processing errors while maintaining batch concurrency',
          () async {
        print('\n🎯 ATDD Test: Error Handling in Batch Processing');

        // Create error-injecting translator
        final errorTranslator = _ErrorInjectingBatchTranslator(delayMs: 40);
        const batchLimit = 2;

        final fileProcessor = FileProcessorImpl(
          errorTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: 3,
          maxConcurrentFiles: batchLimit,
        );

        final testFiles = [
          MockIFileWrapper(
              'good1.md', 'ia-translate: true\n\nFile 0 good content', 2.0),
          MockIFileWrapper('error1.md',
              'ia-translate: true\n\nFile 1 ERROR_TRIGGER content', 2.0),
          MockIFileWrapper(
              'good2.md', 'ia-translate: true\n\nFile 2 good content', 2.0),
          MockIFileWrapper('error2.md',
              'ia-translate: true\n\nFile 3 ERROR_TRIGGER content', 2.0),
          MockIFileWrapper(
              'good3.md', 'ia-translate: true\n\nFile 4 good content', 2.0),
        ];

        print(
            '   Processing ${testFiles.length} files (some will error) with batch limit $batchLimit');

        final result = await fileProcessor.translateFiles(
          testFiles,
          false, // processLargeFiles
        );

        // ATDD Assertions for error handling
        expect(result.successCount + result.failureCount, equals(5),
            reason:
                'All files should be attempted (success + failure = total)');
        expect(result.failureCount, greaterThan(0),
            reason: 'Some files should fail due to error injection');
        expect(result.successCount, greaterThan(0),
            reason: 'Some files should succeed despite errors');

        // Critical: Concurrency limits must be maintained even during errors
        expect(
            errorTranslator.maxConcurrentFiles, lessThanOrEqualTo(batchLimit),
            reason:
                'Batch concurrency limit must be respected even with errors');

        errorTranslator.printBatchStatistics();
        print('   ✅ Error handling maintained batch concurrency limits');
        print(
            '   - Success: ${result.successCount}, Failures: ${result.failureCount}');
      });
    });

    group('CLI Parameter Integration', () {
      test('should demonstrate full CLI parameter integration', () async {
        print('\n🎯 ATDD Test: Full CLI Parameter Integration');
        print(
            '   Simulating: translator /docs --concurrent 3 --files-concurrent 2 --chunk-size 1000');

        // Simulate CLI parameters
        const cliChunkConcurrency = 3; // --concurrent 3
        const cliFileConcurrency = 2; // --files-concurrent 2
        // const cliChunkSize = 1000;     // --chunk-size 1000 (handled in LargeFileConfig)

        final mockTranslator = BatchTrackingTranslator(delayMs: 70);

        final fileProcessor = FileProcessorImpl(
          mockTranslator,
          MarkdownProcessorImpl(),
          maxConcurrentChunks: cliChunkConcurrency,
          maxConcurrentFiles: cliFileConcurrency,
        );

        // Create realistic documentation files
        final docFiles = List.generate(
            6,
            (i) => MockIFileWrapper(
                  'doc_$i.md',
                  'ia-translate: true\n\n# Documentation File $i\n\n' +
                      List.generate(
                              10,
                              (j) =>
                                  'File $i section $j with documentation content.')
                          .join('\n\n'),
                  4.0, // 4KB each - realistic doc size
                ));

        print('   Processing ${docFiles.length} documentation files...');

        final stopwatch = Stopwatch()..start();
        final result = await fileProcessor.translateFiles(
          docFiles,
          false, // Small docs, no chunking needed
        );
        stopwatch.stop();

        // ATDD Assertions: CLI parameters must be respected
        expect(result.successCount, equals(6),
            reason: 'CLI integration should process all documentation files');
        expect(mockTranslator.maxConcurrentFiles,
            lessThanOrEqualTo(cliFileConcurrency),
            reason: '--files-concurrent parameter must be respected');

        print('   📊 CLI Integration Results:');
        print(
            '   - Files processed: ${result.successCount}/${docFiles.length}');
        print(
            '   - Max concurrent files: ${mockTranslator.maxConcurrentFiles} (limit: $cliFileConcurrency)');
        print('   - Total time: ${stopwatch.elapsedMilliseconds}ms');
        print('   ✅ CLI parameters correctly integrated');

        // Verify realistic performance
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Batch processing should be reasonably fast');
      });
    });
  });
}

/// Error-injecting translator for testing error handling in batch processing
class _ErrorInjectingBatchTranslator extends BatchTrackingTranslator {
  _ErrorInjectingBatchTranslator({int delayMs = 50}) : super(delayMs: delayMs);

  @override
  Future<String> translate(String content,
      {required Function onFirstModelError, bool useSecond = false}) async {
    if (content.contains('ERROR_TRIGGER')) {
      // Still track concurrency even for failing translations
      final fileName = _extractFileName(content);
      if (!_fileStartTimes.containsKey(fileName)) {
        _currentConcurrentFiles++;
        _maxConcurrentFiles = max(_maxConcurrentFiles, _currentConcurrentFiles);
        _concurrencySnapshots.add(_currentConcurrentFiles);
        _fileStartTimes[fileName] = DateTime.now();
      }

      try {
        await Future.delayed(
            Duration(milliseconds: _delayMs ~/ 2)); // Faster failure
        onFirstModelError();
        throw Exception('Simulated batch processing error');
      } finally {
        if (!_fileEndTimes.containsKey(fileName)) {
          _fileEndTimes[fileName] = DateTime.now();
          _currentConcurrentFiles--;
        }
      }
    }

    return await super.translate(content,
        onFirstModelError: onFirstModelError, useSecond: useSecond);
  }
}
