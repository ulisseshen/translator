import 'dart:io';
import "package:path/path.dart" show dirname, join;

import 'app.dart';

/// Interface for header tools operations
abstract class HeaderToolsService {
  /// Ensures header linking across markdown files
  Future<void> ensureHeaderLinking(List<String> arguments);
  
  /// Performs text substitution operations on files
  Future<void> substitute(List<String> arguments);
}

/// Implementation of header tools service
class HeaderToolsServiceImpl implements HeaderToolsService {
  final DirectoryProcessor _directoryProcessor;

  HeaderToolsServiceImpl(this._directoryProcessor);

  @override
  Future<void> ensureHeaderLinking(List<String> arguments) async {
    final directoryPath = arguments.first;
    final directory = Directory(directoryPath);

    if (!directory.existsSync() && !arguments.contains('-f')) {
      print('Directory does not exist: ${directory.path}');
      exit(1);
    }

    final replaceOneFile = arguments.contains('-f');

    if (replaceOneFile) {
      final fileArgIndex = arguments.indexOf('-f');
      final filePath = arguments[fileArgIndex + 1];
      final file = FileWrapper(filePath);

      if (!file.exists()) {
        print('File does not exist: $filePath');
        exit(1);
      }
      await _processMarkdownFile(file);
      print('Atualização concluída para o arquivo!');
      return;
    }

    // Coletando todos os arquivos .md
    final allFiles = await _directoryProcessor.collectAllFiles(directory, '.md');

    // Processando cada arquivo Markdown
    for (var file in allFiles) {
      await _processMarkdownFile(file);
    }

    print('Atualização concluída para todos os arquivos!');
  }

  @override
  Future<void> substitute(List<String> arguments) async {
    final directoryPath = arguments.first;
    final directory = Directory(directoryPath);
    if (!directory.existsSync() && !arguments.contains('-f')) {
      print('Directory does not exist: ${directory.path}');
      exit(1);
    }

    final files = await File(join(dirname(Platform.script.toFilePath()),'matches.txt')).readAsString();

    // Convertendo a string para um mapa
    final translations = _convertToMap(files);

    final replaceOneFile = arguments.contains('-f');

    if (replaceOneFile) {
      final fileArgIndex = arguments.indexOf('-f');
      final filePath = arguments[fileArgIndex + 1];
      final file = FileWrapper(filePath);

      if (!file.exists()) {
        print('File does not exist: $filePath');
        exit(1);
      }
      await _replaceTextInFile(file, translations);
      print('Substituições concluídas!');
      return;
    }

    // Coletando todos os arquivos
    final allFiles = await _directoryProcessor.collectAllFiles(directory, '.md');

    // Realizando a substituição em todos os arquivos
    for (var file in allFiles) {
      await _replaceTextInFile(file, translations);
    }

    print('Substituições concluídas!');
  }

  /// Processes a single markdown file for header linking
  Future<void> _processMarkdownFile(IFileWrapper file) async {
    try {
      // Lendo o conteúdo do arquivo
      final content = await file.readAsLines();

      final updatedContent = content.map((line) {
        if (line.startsWith('#')) {
          return _processHeaderLine(line);
        }
        return line;
      }).toList();

      // Gravando o conteúdo atualizado de volta no arquivo
      await file.writeAsString(updatedContent.join('\n'));
      print('Arquivo processado: ${file.path}');
    } catch (e) {
      print('Erro ao processar o arquivo ${file.path}: $e');
    }
  }

  /// Processes a header line to add automatic linking
  String _processHeaderLine(String line) {
    final headerPattern = RegExp(r'^(#{1,6})\s+(.+?)(\s+\{.*\})?$');
    final match = headerPattern.firstMatch(line);

    if (match != null) {
      final hashes = match.group(1)!;
      final headerText = match.group(2)!;
      final existingAttributes = match.group(3) ?? '';

      // Verificar se já existe um link {:#...} nos atributos
      if (existingAttributes.contains(RegExp(r'\{:#'))) {
        return line; // Mantém a linha original
      }

      // Gerando o link automático baseado no texto do cabeçalho
      final generatedLink = headerText
          .toLowerCase()
          .replaceAll(RegExp(r"[^a-z0-9_']+"), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '')
          .replaceAll(RegExp(r"'"), '');

      // Preservando atributos existentes e adicionando o link
      final updatedAttributes = existingAttributes.isNotEmpty
          ? '$existingAttributes {:#$generatedLink}'
          : '{:#$generatedLink}';

      return '$hashes $headerText $updatedAttributes';
    }

    //TODO deve verificar se o header gerará um link duplicado, se sim evitar linkar
    //TODO existe uma linkagem deferente feito no arquivo glossary.md junto ocm glossary.yml
    // na documentação do DART

    return line; // Retorna a linha original se não for um cabeçalho
  }

  /// Performs text replacement in a file
  Future<void> _replaceTextInFile(IFileWrapper file, Map<String, String> translations) async {
    try {
      // Lendo o conteúdo do arquivo
      final content = await file.readAsString();

      // Substituindo as palavras
      var updatedContent = content;
      translations.forEach((left, right) {
        updatedContent = updatedContent.replaceAll(left, right);
      });

      // Gravando o conteúdo atualizado de volta no arquivo
      await file.writeAsString(updatedContent);

      print('Arquivo atualizado: ${file.path}');
    } catch (e) {
      print('Erro ao processar o arquivo ${file.path}: $e');
    }
  }

  /// Converts pipe-separated string pairs to a map
  Map<String, String> _convertToMap(String input) {
    final map = <String, String>{};
    final pairs = input.trim().split('\n');

    for (var pair in pairs) {
      final parts = pair.split('|');
      if (parts.length == 2) {
        map[parts[0].trim()] = parts[1].trim();
      }
    }

    return map;
  }
}