import 'package:test/test.dart';
import 'dart:async';
import 'dart:math';
import '../bin/src/app.dart';
import 'package:translator/translator.dart';
import 'package:translator/markdown_spliter.dart';

/// Simple ATDD test to validate FileProcessorImpl batch processing behavior
void main() {
  group('Batch Processing Concurrency ATDD Tests', () {
    
    test('should demonstrate actual FileProcessor.translateFiles respects concurrency limits', () async {
      print('\n🎯 ATDD: Testing FileProcessor.translateFiles with batch concurrency');
      
      // Create a tracking translator that records concurrent operations
      int maxConcurrent = 0;
      int currentConcurrent = 0;
      final List<String> processOrder = [];
      
      final trackingTranslator = TestTranslator(
        onTranslateStart: (content) {
          currentConcurrent++;
          maxConcurrent = max(maxConcurrent, currentConcurrent);
          processOrder.add('START: ${content.substring(0, min(20, content.length))}');
        },
        onTranslateEnd: (content) {
          currentConcurrent--;
          processOrder.add('END: ${content.substring(0, min(20, content.length))}');
        },
      );
      
      // Configure FileProcessor with concurrency limit of 2
      const maxConcurrentFiles = 2;
      final fileProcessor = FileProcessorImpl(
        trackingTranslator,
        TestMarkdownProcessor(),
        maxConcurrentChunks: 5,
        maxConcurrentFiles: maxConcurrentFiles,
      );
      
      // Create test files
      final testFiles = <IFileWrapper>[
        TestFileWrapper('file1.md', 'ia-translate: true\n\nContent for file 1'),
        TestFileWrapper('file2.md', 'ia-translate: true\n\nContent for file 2'),
        TestFileWrapper('file3.md', 'ia-translate: true\n\nContent for file 3'),
        TestFileWrapper('file4.md', 'ia-translate: true\n\nContent for file 4'),
        TestFileWrapper('file5.md', 'ia-translate: true\n\nContent for file 5'),
      ];
      
      print('   Processing ${testFiles.length} files with maxConcurrentFiles=$maxConcurrentFiles');
      
      // Execute the actual FileProcessor.translateFiles method
      final stopwatch = Stopwatch()..start();  
      final result = await fileProcessor.translateFiles(
        testFiles,
        false, // processLargeFiles
        useSecond: false,
      );
      stopwatch.stop();
      
      // ATDD Assertions: Core business requirements
      expect(result.successCount, equals(5), 
          reason: 'All 5 files should be processed successfully');
      expect(result.failureCount, equals(0), 
          reason: 'No files should fail in normal operation');
      
      // Critical ATDD assertion: Concurrency limit must be respected
      expect(maxConcurrent, lessThanOrEqualTo(maxConcurrentFiles),
          reason: 'FileProcessor MUST respect maxConcurrentFiles=$maxConcurrentFiles limit');
      expect(maxConcurrent, greaterThan(1),
          reason: 'Should actually use parallel processing for efficiency');
          
      // Verify batch processing behavior
      expect(processOrder.length, equals(10), // 5 starts + 5 ends
          reason: 'Should track all file processing events');
      
      print('   📊 ATDD Results:');
      print('   - Files processed: ${result.successCount}/${testFiles.length}');
      print('   - Max concurrent files observed: $maxConcurrent (limit: $maxConcurrentFiles)');
      print('   - Total processing time: ${stopwatch.elapsedMilliseconds}ms');
      print('   - Process order: ${processOrder.take(6).join(', ')}...');
      print('   ✅ ATDD PASSED: Batch concurrency correctly enforced');
    });
    
    test('should demonstrate batch processing performance with different limits', () async {
      print('\n🔬 ATDD: Batch Processing Performance Analysis');
      
      final testFiles = <IFileWrapper>[
        TestFileWrapper('perf1.md', 'ia-translate: true\n\nPerformance test file 1'),
        TestFileWrapper('perf2.md', 'ia-translate: true\n\nPerformance test file 2'),
        TestFileWrapper('perf3.md', 'ia-translate: true\n\nPerformance test file 3'),
        TestFileWrapper('perf4.md', 'ia-translate: true\n\nPerformance test file 4'),
        TestFileWrapper('perf5.md', 'ia-translate: true\n\nPerformance test file 5'),
        TestFileWrapper('perf6.md', 'ia-translate: true\n\nPerformance test file 6'),
      ];
      
      // Test 1: Sequential processing (limit = 1)
      print('\\n   Testing sequential processing (maxConcurrentFiles=1)');
      int maxConcurrent1 = 0;
      int currentConcurrent1 = 0;
      
      final sequential = FileProcessorImpl(
        TestTranslator(
          delayMs: 50,
          onTranslateStart: (_) => maxConcurrent1 = max(maxConcurrent1, ++currentConcurrent1),
          onTranslateEnd: (_) => currentConcurrent1--,
        ),
        TestMarkdownProcessor(),
        maxConcurrentFiles: 1,
      );
      
      final stopwatch1 = Stopwatch()..start();
      final result1 = await sequential.translateFiles(testFiles, false);
      stopwatch1.stop();
      
      // Test 2: Parallel processing (limit = 3)
      print('   Testing parallel processing (maxConcurrentFiles=3)');
      int maxConcurrent3 = 0;
      int currentConcurrent3 = 0;
      
      final parallel = FileProcessorImpl(
        TestTranslator(
          delayMs: 50,
          onTranslateStart: (_) => maxConcurrent3 = max(maxConcurrent3, ++currentConcurrent3),
          onTranslateEnd: (_) => currentConcurrent3--,
        ),
        TestMarkdownProcessor(),
        maxConcurrentFiles: 3,
      );
      
      final stopwatch3 = Stopwatch()..start();
      final result3 = await parallel.translateFiles(testFiles, false);
      stopwatch3.stop();
      
      // ATDD Performance Assertions
      expect(result1.successCount, equals(6), reason: 'Sequential should process all files');
      expect(result3.successCount, equals(6), reason: 'Parallel should process all files');
      expect(maxConcurrent1, equals(1), reason: 'Sequential should use exactly 1 concurrent file');
      expect(maxConcurrent3, lessThanOrEqualTo(3), reason: 'Parallel should respect limit of 3');
      expect(maxConcurrent3, greaterThan(1), reason: 'Parallel should actually use parallelism');
      
      // Performance should improve with parallelism
      final speedup = stopwatch1.elapsedMilliseconds / stopwatch3.elapsedMilliseconds;
      
      print('   📈 Performance Results:');
      print('   - Sequential (1): ${stopwatch1.elapsedMilliseconds}ms');
      print('   - Parallel (3): ${stopwatch3.elapsedMilliseconds}ms');
      print('   - Speedup: ${speedup.toStringAsFixed(2)}x');
      print('   ✅ ATDD PASSED: Parallel processing provides performance benefit');
      
      expect(stopwatch3.elapsedMilliseconds, lessThan(stopwatch1.elapsedMilliseconds),
          reason: 'Parallel processing should be faster than sequential');
    });
    
    test('should handle CLI parameter simulation correctly', () async {
      print('\n🎯 ATDD: CLI Parameter Simulation');
      print('   Command: translator /docs --concurrent 4 --files-concurrent 2');
      
      // Simulate CLI parameters from actual usage
      const cliChunkConcurrency = 4;  // --concurrent 4
      const cliFileConcurrency = 2;   // --files-concurrent 2
      
      int observedMaxConcurrentFiles = 0;
      int currentFiles = 0;
      
      final cliSimulationProcessor = FileProcessorImpl(
        TestTranslator(
          delayMs: 40,
          onTranslateStart: (_) {
            currentFiles++;
            observedMaxConcurrentFiles = max(observedMaxConcurrentFiles, currentFiles);
          },
          onTranslateEnd: (_) => currentFiles--,
        ),
        TestMarkdownProcessor(),
        maxConcurrentChunks: cliChunkConcurrency,
        maxConcurrentFiles: cliFileConcurrency,
      );
      
      final cliTestFiles = <IFileWrapper>[
        TestFileWrapper('doc1.md', 'ia-translate: true\n\n# Documentation 1\n\nContent for doc 1'),
        TestFileWrapper('doc2.md', 'ia-translate: true\n\n# Documentation 2\n\nContent for doc 2'),
        TestFileWrapper('doc3.md', 'ia-translate: true\n\n# Documentation 3\n\nContent for doc 3'),
        TestFileWrapper('doc4.md', 'ia-translate: true\n\n# Documentation 4\n\nContent for doc 4'),
      ];
      
      final result = await cliSimulationProcessor.translateFiles(cliTestFiles, false);
      
      // ATDD CLI Assertions
      expect(result.successCount, equals(4), reason: 'CLI simulation should process all docs');
      expect(observedMaxConcurrentFiles, lessThanOrEqualTo(cliFileConcurrency),
          reason: 'CLI --files-concurrent parameter must be enforced');
      
      print('   📊 CLI Simulation Results:');
      print('   - Files processed: ${result.successCount}/${cliTestFiles.length}');
      print('   - Observed max concurrent files: $observedMaxConcurrentFiles (CLI limit: $cliFileConcurrency)');
      print('   - Chunk concurrency configured: $cliChunkConcurrency');
      print('   ✅ ATDD PASSED: CLI parameters correctly implemented');
    });
  });
}

/// Test translator that tracks concurrency
class TestTranslator implements Translator {
  final int delayMs;
  final void Function(String)? onTranslateStart;
  final void Function(String)? onTranslateEnd;
  
  TestTranslator({
    this.delayMs = 100,
    this.onTranslateStart,
    this.onTranslateEnd,
  });
  
  @override
  Future<String> translate(String text, {required Function onFirstModelError, bool useSecond = false}) async {
    onTranslateStart?.call(text);
    
    try {
      await Future.delayed(Duration(milliseconds: delayMs));
      return 'TRANSLATED: $text';
    } finally {
      onTranslateEnd?.call(text);
    }
  }
}

/// Test markdown processor
class TestMarkdownProcessor implements MarkdownProcessor {

  @override  
  List<SplittedChunk> splitMarkdownContent(String content, {required int maxBytes}) {
    return [SplittedChunk(
      content: content,
      utf8ByteSize: content.length,
      codeUnitsSize: content.length,
    )];
  }
  
  @override
  String removeMarkdownSyntax(String content) => content;
}

/// Test file wrapper
class TestFileWrapper implements IFileWrapper {
  final String _path;
  String _content;
  
  TestFileWrapper(this._path, this._content);
  
  @override
  String get path => _path;
  
  @override
  Future<String> readAsString() async => _content;
  
  @override
  Future<void> writeAsString(String content) async {
    _content = content;
  }
  
  @override
  Future<int> length() async => _content.length;
  
  @override
  Future<List<String>> readAsLines() async => _content.split('\n');
  
  @override
  bool exists() => true;
}