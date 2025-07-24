
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
