import 'package:get_it/get_it.dart';
import 'package:translator/translator.dart';

import 'app.dart';
import 'header_tools_service.dart';
import 'models.dart';
import 'translator_app.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Sets up all dependencies for production environment
Future<void> setupProductionDependencies() async {
  // Production-specific registrations first
  getIt.registerSingleton<Translator>(TranslatorImp());
  
  await _setupCommonDependencies();
  
  print('✅ Production dependencies configured');
}

/// Sets up all dependencies for testing environment  
Future<void> setupTestDependencies({
  Translator? mockTranslator,
  MarkdownProcessor? mockMarkdownProcessor,
  DirectoryProcessor? mockDirectoryProcessor,
  FileCleaner? mockFileCleaner,
  HeaderToolsService? mockHeaderToolsService,
}) async {
  // Clear any existing registrations
  await getIt.reset();
  
  // Register test-specific implementations (mocks) first
  if (mockTranslator != null) {
    getIt.registerSingleton<Translator>(mockTranslator);
  }
  
  await _setupCommonDependencies();
  
  // Override common dependencies with mocks if provided
  if (mockMarkdownProcessor != null) {
    getIt.unregister<MarkdownProcessor>();
    getIt.registerSingleton<MarkdownProcessor>(mockMarkdownProcessor);
  }
  
  if (mockDirectoryProcessor != null) {
    getIt.unregister<DirectoryProcessor>();
    getIt.registerSingleton<DirectoryProcessor>(mockDirectoryProcessor);
  }
  
  if (mockFileCleaner != null) {
    getIt.unregister<FileCleaner>();
    getIt.registerSingleton<FileCleaner>(mockFileCleaner);
  }

  if (mockHeaderToolsService != null) {
    getIt.unregister<HeaderToolsService>();
    getIt.registerSingleton<HeaderToolsService>(mockHeaderToolsService);
  }
  
  print('✅ Test dependencies configured with mocks');
}

/// Common dependencies shared between all environments
Future<void> _setupCommonDependencies() async {
  // Configuration objects
  getIt.registerSingleton<TranslationConfig>(
    TranslationConfig.fromEnvironment(),
  );
  
  getIt.registerSingleton<ProcessingConfig>(
    ProcessingConfig.fromDefaults(),
  );
  
  getIt.registerSingleton<AppConfig>(
    AppConfig.fromDefaults(),
  );
  
  // Core services - using factory to get fresh config each time
  getIt.registerSingleton<MarkdownProcessor>(
    MarkdownProcessorImpl(),
  );
  
  getIt.registerSingleton<DirectoryProcessor>(
    DirectoryProcessorImpl(),
  );
  
  getIt.registerSingleton<FileCleaner>(
    FileCleanerImpl(),
  );

  // Header tools service with dependency injection
  getIt.registerSingleton<HeaderToolsService>(
    HeaderToolsServiceImpl(getIt<DirectoryProcessor>()),
  );
  
  // File processor with dependency injection
  getIt.registerFactory<FileProcessor>(() {
    final processingConfig = getIt<ProcessingConfig>();
    return FileProcessorImpl(
      getIt<Translator>(),
      getIt<MarkdownProcessor>(),
      maxConcurrentChunks: processingConfig.maxConcurrentChunks,
      maxConcurrentFiles: processingConfig.maxConcurrentFiles,
    );
  });
  
  // Main application facade
  getIt.registerSingleton<TranslatorApp>(
    TranslatorApp(
      fileProcessor: getIt<FileProcessor>(),
      directoryProcessor: getIt<DirectoryProcessor>(),
      fileCleaner: getIt<FileCleaner>(),
      headerToolsService: getIt<HeaderToolsService>(),
      appConfig: getIt<AppConfig>(),
    ),
  );
}

