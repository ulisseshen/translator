import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'translator.dart';
import 'markdown_spliter.dart';

class ChunkTask {
  final String filePath;
  final String content;
  final int chunkIndex;
  final DateTime createdAt;

  ChunkTask({
    required this.filePath,
    required this.content,
    required this.chunkIndex,
  }) : createdAt = DateTime.now();
}

class ProcessingResult {
  final String filePath;
  final List<String> chunks;
  final List<String> translatedChunks;
  final List<int> processingOrder;
  final List<DateTime> chunkCompletionTimes;
  final bool isComplete;

  ProcessingResult({
    required this.filePath,
    required this.chunks,
    required this.translatedChunks,
    required this.processingOrder,
    required this.chunkCompletionTimes,
    required this.isComplete,
  });
}

class ParallelChunkProcessor {
  final Translator translator;
  final int maxConcurrent;
  final int maxBytes;
  
  int _currentConcurrent = 0;
  int _maxConcurrentReached = 0;
  final Queue<ChunkTask> _taskQueue = Queue<ChunkTask>();
  final Map<String, List<String>> _fileChunks = {};
  final Map<String, List<String>> _translatedChunks = {};
  final Map<String, List<int>> _processingOrder = {};
  final Map<String, List<DateTime>> _completionTimes = {};
  final Map<String, int> _completedChunks = {};

  int get maxConcurrentReached => _maxConcurrentReached;

  ParallelChunkProcessor({
    required this.translator,
    required this.maxConcurrent,
    this.maxBytes = 20480,
  }) {
    if (maxConcurrent <= 0) {
      throw ArgumentError('maxConcurrent must be greater than 0, got: $maxConcurrent');
    }
  }

  Future<Map<String, ProcessingResult>> processFiles(List<File> files) async {
    await _prepareFiles(files);
    await _processAllChunks();
    return _buildResults();
  }

  Future<void> _prepareFiles(List<File> files) async {
    for (final file in files) {
      final content = await file.readAsString();
      final splitter = MarkdownSplitter(maxBytes: maxBytes);
      final chunks = splitter.splitMarkdown(content);
      
      _fileChunks[file.path] = chunks;
      _translatedChunks[file.path] = List.filled(chunks.length, '');
      _processingOrder[file.path] = [];
      _completionTimes[file.path] = [];
      _completedChunks[file.path] = 0;

      for (int i = 0; i < chunks.length; i++) {
        _taskQueue.add(ChunkTask(
          filePath: file.path,
          content: chunks[i],
          chunkIndex: i,
        ));
      }
    }
  }

  Future<void> _processAllChunks() async {
    final List<Future<void>> activeTasks = [];

    while (_taskQueue.isNotEmpty || activeTasks.isNotEmpty) {
      while (_currentConcurrent < maxConcurrent && _taskQueue.isNotEmpty) {
        final task = _getNextPriorityTask();
        if (task != null) {
          final future = _processTask(task);
          activeTasks.add(future);
          _currentConcurrent++;
          _maxConcurrentReached = 
              _maxConcurrentReached < _currentConcurrent 
                  ? _currentConcurrent 
                  : _maxConcurrentReached;
        } else {
          break;
        }
      }

      if (activeTasks.isNotEmpty) {
        await Future.any(activeTasks.map((future) async {
          await future;
          activeTasks.remove(future);
          _currentConcurrent--;
        }));
      }
    }

    await Future.wait(activeTasks);
  }

  ChunkTask? _getNextPriorityTask() {
    if (_taskQueue.isEmpty) return null;

    final filesWithIncompleteChunks = _fileChunks.keys
        .where((filePath) => _completedChunks[filePath]! < _fileChunks[filePath]!.length)
        .toList();

    for (final filePath in filesWithIncompleteChunks) {
      final nextChunkIndex = _completedChunks[filePath]!;
      
      for (int i = 0; i < _taskQueue.length; i++) {
        final task = _taskQueue.elementAt(i);
        if (task.filePath == filePath && task.chunkIndex == nextChunkIndex) {
          _taskQueue.remove(task);
          return task;
        }
      }
    }

    return _taskQueue.removeFirst();
  }

  Future<void> _processTask(ChunkTask task) async {
    try {
      final translatedContent = await translator.translate(
        task.content,
        onFirstModelError: () {},
        useSecond: true,
      );

      _translatedChunks[task.filePath]![task.chunkIndex] = translatedContent;
      _processingOrder[task.filePath]!.add(task.chunkIndex);
      _completionTimes[task.filePath]!.add(DateTime.now());
      _completedChunks[task.filePath] = _completedChunks[task.filePath]! + 1;
    } catch (e) {
      _translatedChunks[task.filePath]![task.chunkIndex] = task.content;
      _processingOrder[task.filePath]!.add(task.chunkIndex);
      _completionTimes[task.filePath]!.add(DateTime.now());
      _completedChunks[task.filePath] = _completedChunks[task.filePath]! + 1;
    }
  }

  Map<String, ProcessingResult> _buildResults() {
    final Map<String, ProcessingResult> results = {};

    for (final filePath in _fileChunks.keys) {
      results[filePath] = ProcessingResult(
        filePath: filePath,
        chunks: _fileChunks[filePath]!,
        translatedChunks: _translatedChunks[filePath]!,
        processingOrder: _processingOrder[filePath]!,
        chunkCompletionTimes: _completionTimes[filePath]!,
        isComplete: _completedChunks[filePath] == _fileChunks[filePath]!.length,
      );
    }

    return results;
  }
}