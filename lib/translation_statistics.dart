/// Statistics about the pipeline execution
class TranslationStatistics {
  // Original content stats
  final int originalContentBytes;
  final int originalContentCodeUnits;
  
  // Code block extraction stats
  final int totalCodeBlocksExtracted;
  final int fencedCodeBlocks;
  final int inlineCodeBlocks;
  final int cleanContentBytes;
  
  // Chunking stats
  final int totalChunks;
  final int averageChunkBytes;
  final int maxChunkBytes;
  final int minChunkBytes;
  
  // Translation stats
  final int translatedContentBytes;
  final int finalContentBytes;
  
  // Performance stats
  final int processingTimeMs;
  final int processingTimeSeconds;
  final double bytesPerSecond;
  
  // Pipeline integrity
  final int codeBlocksRestored;
  final bool restorationSuccess;

  const TranslationStatistics({
    required this.originalContentBytes,
    required this.originalContentCodeUnits,
    required this.totalCodeBlocksExtracted,
    required this.fencedCodeBlocks,
    required this.inlineCodeBlocks,
    required this.cleanContentBytes,
    required this.totalChunks,
    required this.averageChunkBytes,
    required this.maxChunkBytes,
    required this.minChunkBytes,
    required this.translatedContentBytes,
    required this.finalContentBytes,
    required this.processingTimeMs,
    required this.processingTimeSeconds,
    required this.bytesPerSecond,
    required this.codeBlocksRestored,
    required this.restorationSuccess,
  });

  /// Convert to Map for backward compatibility
  Map<String, dynamic> toMap() {
    return {
      'originalContentBytes': originalContentBytes,
      'originalContentCodeUnits': originalContentCodeUnits,
      'totalCodeBlocksExtracted': totalCodeBlocksExtracted,
      'fencedCodeBlocks': fencedCodeBlocks,
      'inlineCodeBlocks': inlineCodeBlocks,
      'cleanContentBytes': cleanContentBytes,
      'totalChunks': totalChunks,
      'averageChunkBytes': averageChunkBytes,
      'maxChunkBytes': maxChunkBytes,
      'minChunkBytes': minChunkBytes,
      'translatedContentBytes': translatedContentBytes,
      'finalContentBytes': finalContentBytes,
      'processingTimeMs': processingTimeMs,
      'processingTimeSeconds': processingTimeSeconds,
      'bytesPerSecond': bytesPerSecond,
      'codeBlocksRestored': codeBlocksRestored,
      'restorationSuccess': restorationSuccess,
    };
  }

  /// Create from Map for backward compatibility
  factory TranslationStatistics.fromMap(Map<String, dynamic> map) {
    return TranslationStatistics(
      originalContentBytes: map['originalContentBytes'] as int,
      originalContentCodeUnits: map['originalContentCodeUnits'] as int,
      totalCodeBlocksExtracted: map['totalCodeBlocksExtracted'] as int,
      fencedCodeBlocks: map['fencedCodeBlocks'] as int? ?? 0,
      inlineCodeBlocks: map['inlineCodeBlocks'] as int? ?? 0,
      cleanContentBytes: map['cleanContentBytes'] as int,
      totalChunks: map['totalChunks'] as int,
      averageChunkBytes: map['averageChunkBytes'] as int,
      maxChunkBytes: map['maxChunkBytes'] as int,
      minChunkBytes: map['minChunkBytes'] as int,
      translatedContentBytes: map['translatedContentBytes'] as int,
      finalContentBytes: map['finalContentBytes'] as int,
      processingTimeMs: map['processingTimeMs'] as int,
      processingTimeSeconds: map['processingTimeSeconds'] as int,
      bytesPerSecond: map['bytesPerSecond'] as double,
      codeBlocksRestored: map['codeBlocksRestored'] as int,
      restorationSuccess: map['restorationSuccess'] as bool,
    );
  }

  @override
  String toString() {
    return 'TranslationStatistics(originalBytes: $originalContentBytes, '
           'codeBlocks: $totalCodeBlocksExtracted, chunks: $totalChunks, '
           'processingTime: ${processingTimeMs}ms, '
           'restoration: $restorationSuccess)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranslationStatistics &&
        other.originalContentBytes == originalContentBytes &&
        other.originalContentCodeUnits == originalContentCodeUnits &&
        other.totalCodeBlocksExtracted == totalCodeBlocksExtracted &&
        other.fencedCodeBlocks == fencedCodeBlocks &&
        other.inlineCodeBlocks == inlineCodeBlocks &&
        other.cleanContentBytes == cleanContentBytes &&
        other.totalChunks == totalChunks &&
        other.averageChunkBytes == averageChunkBytes &&
        other.maxChunkBytes == maxChunkBytes &&
        other.minChunkBytes == minChunkBytes &&
        other.translatedContentBytes == translatedContentBytes &&
        other.finalContentBytes == finalContentBytes &&
        other.processingTimeMs == processingTimeMs &&
        other.processingTimeSeconds == processingTimeSeconds &&
        other.bytesPerSecond == bytesPerSecond &&
        other.codeBlocksRestored == codeBlocksRestored &&
        other.restorationSuccess == restorationSuccess;
  }

  @override
  int get hashCode {
    return Object.hash(
      originalContentBytes,
      originalContentCodeUnits,
      totalCodeBlocksExtracted,
      fencedCodeBlocks,
      inlineCodeBlocks,
      cleanContentBytes,
      totalChunks,
      averageChunkBytes,
      maxChunkBytes,
      minChunkBytes,
      translatedContentBytes,
      finalContentBytes,
      processingTimeMs,
      processingTimeSeconds,
      bytesPerSecond,
      codeBlocksRestored,
      restorationSuccess,
    );
  }
}