/// Centralized configuration for large file processing
class LargeFileConfig {
  /// Maximum file size in KB before considering it a "large file"
  /// Can be overridden for testing
  static int get maxKbSize => _maxKbSize;
  static int _maxKbSize = 20;

  /// Default maximum number of concurrent chunk translations
  static const int defaultMaxConcurrentChunks = 10;
  
  /// Default maximum chunk size in bytes (20KB)
  static const int _originalDefaultChunkMaxBytes = 20480;
  static int _currentDefaultChunkMaxBytes = _originalDefaultChunkMaxBytes;
  static int get defaultChunkMaxBytes => _currentDefaultChunkMaxBytes;
  
  /// Default batch size for parallel file processing
  static const int defaultBatchSize = 5;
  
  /// Default delay between batches in milliseconds
  static const int defaultBatchDelayMs = 0;
  
  /// Whether to process large files by default
  static const bool defaultProcessLargeFiles = false;
  
  /// Check if a file should be processed based on its size and settings
  static bool shouldProcessFile(double fileSizeKB, bool processLargeFiles) {
    return processLargeFiles || fileSizeKB <= maxKbSize;
  }
  
  /// Check if a file should be skipped due to size constraints
  static bool shouldSkipFile(double fileSizeKB, bool processLargeFiles) {
    return !processLargeFiles && fileSizeKB > maxKbSize;
  }
  
  /// Get the appropriate processing message for a file
  static String getSkipMessage() {
    return 'Skipping file > ${maxKbSize}KB. Use the -g flag to translate large files.';
  }
  
  /// Get the large file detection message
  static String getLargeFileDetectedMessage(String fileName) {
    return '📜 Large file detected. 🚀 Parallel processing: $fileName';
  }
  
  /// Reset configuration to defaults (useful for testing)
  static void resetToDefaults() {
    _maxKbSize = 20;
    _currentDefaultChunkMaxBytes = _originalDefaultChunkMaxBytes;
  }
  
  /// Configure for testing with smaller thresholds
  static void configureForTesting({
    int? maxKbSizeOverride,
    int? chunkMaxBytesOverride,
  }) {
    if (maxKbSizeOverride != null) {
      _maxKbSize = maxKbSizeOverride;
    }
    if (chunkMaxBytesOverride != null) {
      _currentDefaultChunkMaxBytes = chunkMaxBytesOverride;
    }
  }
}