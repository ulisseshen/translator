/// Configuration for translation-related settings
class TranslationConfig {
  final List<String> models;
  final int retryAttempts;
  final Duration timeout;
  final String? apiKey;
  
  const TranslationConfig({
    required this.models,
    this.retryAttempts = 3,
    this.timeout = const Duration(seconds: 30),
    this.apiKey,
  });
  
  factory TranslationConfig.fromEnvironment() {
    return TranslationConfig(
      models: [
        'gemini-2.5-flash-lite-preview-06-17',
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemma-3-27b-it',
        'gemini-2.0-flash',
      ],
      apiKey: _getEnvironmentVariable('GOOGLE_API_KEY'),
    );
  }
  
  static String? _getEnvironmentVariable(String key) {
    // In a real app, this would read from environment variables
    // For now, return null to use the existing API key loading mechanism
    return null;
  }
}

/// Configuration for file processing settings
class ProcessingConfig {
  final int maxConcurrentChunks;
  final int maxConcurrentFiles;
  final int maxChunkBytes;
  final int maxKbSize;
  final int batchSize;
  final Duration batchDelay;
  
  const ProcessingConfig({
    required this.maxConcurrentChunks,
    required this.maxConcurrentFiles,
    required this.maxChunkBytes,
    required this.maxKbSize,
    required this.batchSize,
    required this.batchDelay,
  });
  
  factory ProcessingConfig.fromDefaults() {
    return ProcessingConfig(
      maxConcurrentChunks: 10,
      maxConcurrentFiles: 3,
      maxChunkBytes: 20480, // 20KB
      maxKbSize: 20,
      batchSize: 5,
      batchDelay: Duration.zero,
    );
  }
  
  /// Create configuration from CLI arguments
  factory ProcessingConfig.fromArguments({
    int? maxConcurrentChunks,
    int? maxConcurrentFiles,
    int? maxChunkBytes,
  }) {
    final defaults = ProcessingConfig.fromDefaults();
    return ProcessingConfig(
      maxConcurrentChunks: maxConcurrentChunks ?? defaults.maxConcurrentChunks,
      maxConcurrentFiles: maxConcurrentFiles ?? defaults.maxConcurrentFiles,
      maxChunkBytes: maxChunkBytes ?? defaults.maxChunkBytes,
      maxKbSize: defaults.maxKbSize,
      batchSize: defaults.batchSize,
      batchDelay: defaults.batchDelay,
    );
  }
}

/// Configuration for application-wide settings
class AppConfig {
  final String defaultExtension;
  final List<String> supportedExtensions;
  final bool enableDebugOutput;
  final bool enableStatistics;
  
  const AppConfig({
    required this.defaultExtension,
    required this.supportedExtensions,
    this.enableDebugOutput = false,
    this.enableStatistics = true,
  });
  
  factory AppConfig.fromDefaults() {
    return AppConfig(
      defaultExtension: '.md',
      supportedExtensions: ['.md', '.txt', '.rst'],
    );
  }
}

