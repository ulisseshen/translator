import 'large_file_config.dart';

class AppArguments {
  final bool showHelp;
  final bool translateGreater;
  final bool useSecond;
  final bool translateOneFile;
  final bool collectLinks;
  final bool showInfo;
  final bool cleanMarkdown;
  final bool replaceLinks;
  final bool useV2;
  final bool saveSent;
  final bool saveReceived;
  final String directoryPath;
  final String extension;
  final String? filePath;
  final bool? multiFiles;
  final List<String>? multipleFilePaths;
  final int maxConcurrentChunks;
  final int maxConcurrentFiles;

  AppArguments._({
    required this.showHelp,
    required this.translateGreater,
    required this.useSecond,
    required this.translateOneFile,
    required this.collectLinks,
    required this.showInfo,
    required this.cleanMarkdown,
    required this.replaceLinks,
    required this.useV2,
    required this.saveSent,
    required this.saveReceived,
    required this.directoryPath,
    required this.extension,
    this.multiFiles,
    this.filePath,
    this.multipleFilePaths,
    this.maxConcurrentChunks = 10, // LargeFileConfig.defaultMaxConcurrentChunks
    this.maxConcurrentFiles = 3, // LargeFileConfig.defaultMaxConcurrentFiles
  });

  factory AppArguments.parse(List<String> arguments) {
    if (arguments.isEmpty ||
        arguments.contains('-h') ||
        arguments.contains('--help')) {
      return AppArguments._(
        showHelp: true,
        translateGreater: false,
        useSecond: false,
        translateOneFile: false,
        collectLinks: false,
        showInfo: false,
        cleanMarkdown: false,
        replaceLinks: false,
        useV2: false,
        saveSent: false,
        saveReceived: false,
        directoryPath: '',
        extension: '.md',
        filePath: null,
        multiFiles: false
      );
    }

    final translateGreater = arguments.contains('-g');
    final useSecond = arguments.contains('-s');
    final translateOneFile = arguments.contains('-f');
    final collectLinks = arguments.contains('-cl');
    final showInfo = arguments.contains('--info');
    final cleanMarkdown = arguments.contains('-c');
    final replaceLinks = arguments.contains('-l');
    final useV2 = arguments.contains('-v2');
    final saveSent = arguments.contains('--save-sent') || arguments.contains('-ss');
    final saveReceived = arguments.contains('--save-received') || arguments.contains('-sr');
    final multiFiles = arguments.contains('-mf');
     final mfIndex = arguments.indexOf('-mf');

     List<String> multiPaths=[];
    if (mfIndex != -1 && mfIndex + 1 < arguments.length) {
      final files = arguments.sublist(mfIndex + 1);
      multiPaths.addAll(files);
    }

    String extension = '.md'; // Valor padrão
    final extensionArgIndex = arguments.indexOf('-e');
    if (extensionArgIndex != -1 && extensionArgIndex + 1 < arguments.length) {
      extension = '.${arguments[extensionArgIndex + 1]}';
    }

    String? filePath;
    if (translateOneFile) {
      final fileIndex = arguments.indexWhere((arg) => arg.endsWith('.md'));
      if (fileIndex != -1) {
        filePath = arguments[fileIndex];
      }
    }

    final directoryPath =
        arguments.firstWhere((arg) => !arg.startsWith('-'), orElse: () => '');

    // Parse parallel processing parameters
    int maxConcurrentChunks = LargeFileConfig.defaultMaxConcurrentChunks;
    final concurrentIndex = arguments.indexOf('--concurrent');
    if (concurrentIndex != -1 && concurrentIndex + 1 < arguments.length) {
      maxConcurrentChunks = int.tryParse(arguments[concurrentIndex + 1]) ?? LargeFileConfig.defaultMaxConcurrentChunks;
    }
    
    int maxConcurrentFiles = LargeFileConfig.defaultMaxConcurrentFiles;
    final filesConcurrentIndex = arguments.indexOf('--files-concurrent');
    if (filesConcurrentIndex != -1 && filesConcurrentIndex + 1 < arguments.length) {
      maxConcurrentFiles = int.tryParse(arguments[filesConcurrentIndex + 1]) ?? LargeFileConfig.defaultMaxConcurrentFiles;
    }

    // Configure chunk size globally if specified
    final chunkSizeIndex = arguments.indexOf('--chunk-size');
    if (chunkSizeIndex != -1 && chunkSizeIndex + 1 < arguments.length) {
      final chunkMaxBytes = int.tryParse(arguments[chunkSizeIndex + 1]) ?? LargeFileConfig.defaultChunkMaxBytes;
      LargeFileConfig.configureForTesting(chunkMaxBytesOverride: chunkMaxBytes);
    }

    return AppArguments._(
      showHelp: false,
      translateGreater: translateGreater,
      useSecond: useSecond,
      translateOneFile: translateOneFile,
      collectLinks: collectLinks,
      showInfo: showInfo,
      cleanMarkdown: cleanMarkdown,
      replaceLinks: replaceLinks,
      useV2: useV2,
      saveSent: saveSent,
      saveReceived: saveReceived,
      directoryPath: directoryPath,
      extension: extension,
      filePath: filePath,
      multiFiles: multiFiles,
      multipleFilePaths: multiPaths,
      maxConcurrentChunks: maxConcurrentChunks,
      maxConcurrentFiles: maxConcurrentFiles,
    );
  }

  void printHelp() {
    print('Usage: app [options] <directory>');
    print('Options:');
    print('-h, --help            Show this help message');
    print('-g                    Translate greater files');
    print('-s                    Use second translation');
    print('-f                    Translate a single file');
    print('-cl                   Collect links');
    print('--info                Show directory info');
    print('--concurrent <n>      Max concurrent chunk translations (default: ${LargeFileConfig.defaultMaxConcurrentChunks})');
    print('--files-concurrent <n> Max concurrent file translations (default: ${LargeFileConfig.defaultMaxConcurrentFiles})');
    print('--chunk-size <bytes>  Max chunk size in bytes (default: ${LargeFileConfig.defaultChunkMaxBytes})');
    print('-c                  Clean Markdown files');
    print('-l                  Replace links');
    print('-v2                 Use the second version of the tool');
    print('-ss, --save-sent    Save original content as sent{index}.md');
    print('-sr, --save-received Save translated content as received{index}.md');
    print('-e <extension>      Specify file extension (default: .md)');
  }
}
