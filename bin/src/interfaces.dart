import 'dart:io';

import 'package:translator/markdown_spliter.dart';
import 'package:translator/translator.dart';

class TranslationResult {
  final int successCount;
  final int failureCount;

  TranslationResult(this.successCount, this.failureCount);
}

abstract class IFileWrapper {
  Future<String> readAsString();
  Future<void> writeAsString(String content);
  String get path;
  Future<int> length();
  Future<List<String>> readAsLines();
  bool exists();
}

abstract class FileCleaner {
  Future<List<IFileWrapper>> collectFilesToClean(
      Directory directory, String extension);

  String ensureDontHaveMarkdown(String content);
}

abstract class DirectoryProcessor {
  Future<List<IFileWrapper>> collectFilesToTranslate(
    Directory directory,
    int maxKbSize,
    bool translateLargeFiles,
    String extension,
  );
  Future<void> displayDirectoryInfo(
      Directory directory, int maxKbSize, String extension);
  Future<List<IFileWrapper>> collectAllFiles(
      Directory directory, String extension);
}

abstract class FileProcessor {
  Future<String> readFile(IFileWrapper file);
  Future<void> writeFile(IFileWrapper file, String content);
  Future<void> translateOne(
    IFileWrapper file,
    bool processLargeFiles,
    Translator translator,
    bool useSecond, {
    int? currentFileIndex,
    int? totalFiles,
    Function()? onComplete,
    Function()? onFailed,
    bool saveSent = false,
    bool saveReceived = false,
  });
  Future<TranslationResult> translateFiles(
    List<IFileWrapper> filesToTranslate,
    bool processLargeFiles, {
    bool useSecond = false,
    bool saveSent = false,
    bool saveReceived = false,
  });
}

abstract class LinkProcessor {
  Future<List<String>> collectLinks(IFileWrapper file);
  Future<void> replaceLinksInFile(IFileWrapper file);
  Future<List<String>> collectAllAnchors(IFileWrapper file);
  Future<void> replaceLinksInAllFiles(Directory directory, String extension);
}

abstract class MarkdownProcessor {
  List<SplittedChunk> splitMarkdownContent(String content, {required int maxBytes});

  /// Remove as marcações \`\`\`markdown da primeira linha e ``` da última ou penúltima linha do conteúdo.
  String removeMarkdownSyntax(String content);
}
