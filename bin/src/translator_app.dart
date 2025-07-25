import 'dart:io';
import 'package:translator/translator.dart';
import 'app.dart';
import 'dependency_injection.dart';
import 'header_tools_service.dart';

/// Main application facade that coordinates all operations
class TranslatorApp {
  final FileProcessor _fileProcessor;
  final DirectoryProcessor _directoryProcessor;
  final FileCleaner _fileCleaner;
  final HeaderToolsService _headerToolsService;
  final AppConfig _appConfig;
  late ProcessingConfig _processingConfig;
  
  TranslatorApp({
    required FileProcessor  fileProcessor,
    required DirectoryProcessor directoryProcessor,
    required FileCleaner fileCleaner,
    required HeaderToolsService headerToolsService,
    required AppConfig appConfig,
  }) : _fileProcessor = fileProcessor,
       _directoryProcessor = directoryProcessor,
       _fileCleaner = fileCleaner,
       _headerToolsService = headerToolsService,
       _appConfig = appConfig;
  
  /// Main entry point for the application
  Future<void> run(List<String> arguments) async {
    print('🚀 TranslatorApp starting with DI-injected dependencies...');
    
    final args = AppArguments.parse(arguments);

    if (args.showHelp) {
      args.printHelp();
      return;
    }

    // Update processing config based on CLI arguments
    _updateProcessingConfigFromArgs(args);

    if (args.useV2) {
      return await _headerToolsService.ensureHeaderLinking(arguments.where((a) => a != '-v2').toList());
    }

    if (args.translateOneFile) {
      await _handleSingleFileTranslation(args);
      return;
    }

    final directoryPath = arguments.first;
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      print('Directory does not exist: ${directory.path}');
      return;
    }

    String extension = _appConfig.defaultExtension;
    final extensionArgIndex = arguments.indexOf('-e');
    if (extensionArgIndex != -1 && extensionArgIndex + 1 < arguments.length) {
      extension = '.${arguments[extensionArgIndex + 1]}';
      print('Nova extension: $extension');
    }

    if (args.collectLinks) {
      await _handleLinkCollection(directory, extension);
      return;
    }

    if (args.showInfo) {
      await _printDirectoryInfo(directory, extension);
      return;
    }

    if (arguments.contains('-l')) {
      await _handleLinkReplacement(directory, extension);
      return;
    }

    if (args.cleanMarkdown) {
      await _handleMarkdownCleaning(directory, extension);
      return;
    }

    // Main translation workflow
    await _handleDirectoryTranslation(directory, extension, args);
  }

  /// Update processing configuration from CLI arguments
  void _updateProcessingConfigFromArgs(AppArguments args) {
    _processingConfig = ProcessingConfig.fromArguments(
      maxConcurrentChunks: args.maxConcurrentChunks,
      maxConcurrentFiles: args.maxConcurrentFiles,
    );
  }

  /// Handle single file translation
  Future<void> _handleSingleFileTranslation(AppArguments args) async {
    final file = _getFileFromArgs(args);
    
    if (!file.exists()) {
      print('File does not exist: ${file.path}');
      exit(1);
    }
    
    final translator = getIt<Translator>();
    await _fileProcessor.translateOne(
      file, args.translateGreater, translator, args.useSecond,
      saveSent: args.saveSent,
      saveReceived: args.saveReceived);
  }

  /// Handle link collection workflow
  Future<void> _handleLinkCollection(Directory directory, String extension) async {
    final allFiles = await _directoryProcessor.collectAllFiles(directory, extension);
    List<String> matches = [];
    
    // Note: LinkProcessorImpl would need to be injected too, but keeping existing pattern for now
    final linkProcessor = LinkProcessorImpl();
    for (var file in allFiles) {
      final m = await linkProcessor.collectAllAnchors(file);
      matches.addAll(m);
    }

    final outputFile = File('./matches_encontrados.txt');
    matches.sort((a, b) => b.length.compareTo(a.length));
    final excluded = Set.from(matches).toList();
    await outputFile.writeAsString(excluded.join('\n'), mode: FileMode.write);

    print('Matches encontrados e salvos em ${outputFile.path}');
    print('Finalizado collectAllAnchors');
  }

  /// Handle directory info display
  Future<void> _printDirectoryInfo(Directory directory, String extension) async {
   
    print('Listing files in directory: ${directory.path}');
    
    await for (var entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith(extension)) {
        final fileSizeKB = (await entity.length()) / 1024;
        if (fileSizeKB > _processingConfig.maxKbSize) {
          print('File: ${entity.path}, Size: ${fileSizeKB.toStringAsFixed(2)} KB');
        }
      }
    }
  }

  /// Handle link replacement workflow
  Future<void> _handleLinkReplacement(Directory directory, String extension) async {
    final linkProcessor = LinkProcessorImpl();
    await linkProcessor.replaceLinksInAllFiles(directory, extension);
  }

  /// Handle markdown cleaning workflow
  Future<void> _handleMarkdownCleaning(Directory directory, String extension) async {
    final all = await _fileCleaner.collectFilesToClean(directory, extension);
    for (var i = 0; i < all.length; i++) {
      final file = all[i];
      final content = await file.readAsString();
      final cleanedContent = _fileCleaner.ensureDontHaveMarkdown(content);
      await file.writeAsString(cleanedContent);
    }

    final singularOrPlural = all.isEmpty || all.length > 1 ? 'S' : '';
    print('🧹 ${all.length} ARQUIVO$singularOrPlural LIMPO$singularOrPlural');
  }

  /// Handle main directory translation workflow
  Future<void> _handleDirectoryTranslation(Directory directory, String extension, AppArguments args) async {
    final filesToTranslate = await _directoryProcessor.collectFilesToTranslate(
      directory,
      _processingConfig.maxKbSize,
      args.translateGreater,
      extension,
    );

    final stopwatchTotal = Stopwatch()..start();

    TranslationResult result = await _fileProcessor.translateFiles(
      filesToTranslate,
      args.translateGreater,
      useSecond: args.useSecond,
      saveSent: args.saveSent,
      saveReceived: args.saveReceived,
    );

    stopwatchTotal.stop();

    final durationIsSeconds = stopwatchTotal.elapsed.inSeconds;
    print('\n📔 Resumo da Tradução:');
    print('---------------------');
    print('Arquivos traduzidos com sucesso: ${result.successCount}');
    print('Arquivos com erro: ${result.failureCount}');
    print('Tempo total de tradução: $durationIsSeconds segundos');
    print('Tradução concluída para o diretório: ${directory.path}');
  }

  /// Extract file from CLI arguments (helper method)
  IFileWrapper _getFileFromArgs(AppArguments args) {
    // This would need to be refactored to use the injected file system abstraction
    // For now, keeping the existing pattern similar to the original main()
    if (args.filePath != null) {
      return FileWrapper(args.filePath!);
    }
    throw ArgumentError('File path not found in arguments');
  }
}