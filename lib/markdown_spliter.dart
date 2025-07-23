import 'dart:convert';
import 'dart:io';

enum ChunkType {
  text,        // Translatable text content
  codeBlock,   // Code blocks that should not be translated
  mixed,       // Content with both text and code blocks
}

class SplittedChunk {
  final String content;
  final int utf8ByteSize;
  final int codeUnitsSize;
  final ChunkType type;

  SplittedChunk({
    required this.content,
    required this.utf8ByteSize,
    required this.codeUnitsSize,
    this.type = ChunkType.text,
  });

  /// Returns true if this chunk should be translated
  bool get isTranslatable {
    switch (type) {
      case ChunkType.codeBlock:
        return false;
      default:
        return true; // Will need special handling to extract only text parts
    }
  }

  @override
  String toString() {
    return 'SplittedChunk(type: $type, translatable: $isTranslatable, utf8Bytes: $utf8ByteSize, codeUnits: $codeUnitsSize, content: ${content.length} chars)';
  }
}

class MarkdownSplitter {
  final int maxBytes;

  MarkdownSplitter({this.maxBytes = 20480}); // Tamanho padrão de 20 KB

  /// Divide o texto Markdown em partes respeitando os cabeçalhos ### e ##.
  /// Retorna uma lista de SplittedChunk com conteúdo e tamanhos.
  List<SplittedChunk> splitMarkdown(String content) {
    final List<SplittedChunk> result = [];
    
    // First, split by ### sections
    final List<String> primarySections =
        content.split(RegExp(r'(?=^### )', multiLine: true));

    for (final section in primarySections) {
      final sectionSize = utf8.encode(section).length;

      if (sectionSize > maxBytes) {
        // Section is oversized - try to split it further
        final splitSections = _splitOversizedSection(section);
        result.addAll(splitSections);
      } else {
        // Section fits - create chunk with proper type
        final chunkType = _determineChunkType(section);
        result.add(SplittedChunk(
          content: section,
          utf8ByteSize: sectionSize,
          codeUnitsSize: section.codeUnits.length,
          type: chunkType,
        ));
      }
    }
    
    return _combineSmallChunks(result);
  }

  /// Splits oversized sections by ## headers when possible
  List<SplittedChunk> _splitOversizedSection(String section) {
    final List<SplittedChunk> result = [];
    
    // If this starts with ###, it's a single section - try to separate code blocks
    if (section.trim().startsWith('###')) {
      //TODO use strategy pattern to handle this
      final separatedChunks = _separateCodeBlocks(section);
      return separatedChunks;
    }
    
    // This is pre-section content - try splitting by ## headers
    final List<String> subSections = section.split(RegExp(r'(?=^## )', multiLine: true));
    
    for (final subSection in subSections) {
      final subSectionSize = utf8.encode(subSection).length;
      
      if (subSectionSize > maxBytes) {
        // Even ## subsection is too large - try to separate code blocks
        final separatedChunks = _separateCodeBlocks(subSection);
        result.addAll(separatedChunks);
      } else {
        // Subsection fits within limit - determine its type
        final chunkType = _determineChunkType(subSection);
        result.add(SplittedChunk(
          content: subSection,
          utf8ByteSize: subSectionSize,
          codeUnitsSize: subSection.codeUnits.length,
          type: chunkType,
        ));
      }
    }
    
    return result;
  }

  /// Combines small adjacent chunks to optimize size usage
  List<SplittedChunk> _combineSmallChunks(List<SplittedChunk> chunks) {
    if (chunks.isEmpty) return chunks;
    
    final List<SplittedChunk> result = [];
    String currentContent = '';
    int currentSize = 0;
    
    for (final chunk in chunks) {
      // Check if we can combine this chunk with current accumulated content
      if (currentSize + chunk.utf8ByteSize <= maxBytes && currentContent.isNotEmpty) {
        // Combine with current content
        currentContent += chunk.content;
        currentSize += chunk.utf8ByteSize;
      } else {
        // Save current accumulated content if any
        if (currentContent.isNotEmpty) {
          final combinedType = _determineChunkType(currentContent);
          result.add(SplittedChunk(
            content: currentContent,
            utf8ByteSize: currentSize,
            codeUnitsSize: currentContent.codeUnits.length,
            type: combinedType,
          ));
        }
        
        // Start new accumulation with current chunk
        currentContent = chunk.content;
        currentSize = chunk.utf8ByteSize;
      }
    }
    
    // Add final accumulated content
    if (currentContent.isNotEmpty) {
      final finalType = _determineChunkType(currentContent);
      result.add(SplittedChunk(
        content: currentContent,
        utf8ByteSize: currentSize,
        codeUnitsSize: currentContent.codeUnits.length,
        type: finalType,
      ));
    }
    
    return result;
  }

  /// Determines the type of content in a chunk
  ChunkType _determineChunkType(String content) {
    final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(content);
    final totalCodeSize = codeBlocks.fold(0, (sum, match) => sum + utf8.encode(match.group(0)!).length);
    final totalSize = utf8.encode(content).length;
    
    if (totalCodeSize == 0) {
      return ChunkType.text;
    } else if (totalCodeSize >= totalSize * 0.95) {
      // If >95% is code, consider it a code block
      return ChunkType.codeBlock;
    } else {
      return ChunkType.mixed;
    }
  }

  /// Separates code blocks from text content for oversized sections
  List<SplittedChunk> _separateCodeBlocks(String section) {
    final List<SplittedChunk> result = [];
    final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(section);
    
    if (codeBlocks.isEmpty) {
      // No code blocks - just add as text (even if oversized)
      result.add(SplittedChunk(
        content: section,
        utf8ByteSize: utf8.encode(section).length,
        codeUnitsSize: section.codeUnits.length,
        type: ChunkType.text,
      ));
      return result;
    }
    
    int lastEnd = 0;
    
    for (final codeBlock in codeBlocks) {
      // Add text content before this code block
      if (codeBlock.start > lastEnd) {
        final textPart = section.substring(lastEnd, codeBlock.start);
        if (textPart.trim().isNotEmpty) {
          final textSize = utf8.encode(textPart).length;
          result.add(SplittedChunk(
            content: textPart,
            utf8ByteSize: textSize,
            codeUnitsSize: textPart.codeUnits.length,
            type: ChunkType.text,
          ));
        }
      }
      
      // Add the code block separately
      final codeContent = codeBlock.group(0)!;
      final codeSize = utf8.encode(codeContent).length;
      result.add(SplittedChunk(
        content: codeContent,
        utf8ByteSize: codeSize,
        codeUnitsSize: codeContent.codeUnits.length,
        type: ChunkType.codeBlock,
      ));
      
      lastEnd = codeBlock.end;
    }
    
    // Add remaining text after last code block
    if (lastEnd < section.length) {
      final remainingText = section.substring(lastEnd);
      if (remainingText.trim().isNotEmpty) {
        final remainingSize = utf8.encode(remainingText).length;
        result.add(SplittedChunk(
          content: remainingText,
          utf8ByteSize: remainingSize,
          codeUnitsSize: remainingText.codeUnits.length,
          type: ChunkType.text,
        ));
      }
    }
    
    return result;
  }

  String getEnterily(List<SplittedChunk> chunks) {
    return chunks.map((chunk) => chunk.content).join();
  }
}

void main() async {
  final filePath = './site.md';
  final file = File(filePath);

  if (!file.existsSync()) {
    print('Arquivo não encontrado: $filePath');
    exit(1);
  }

  final content = await file.readAsString();
  final splitter = MarkdownSplitter(maxBytes: 20480); // 20 KB

  final chunks = splitter.splitMarkdown(content);

  print('Divisão concluída: ${chunks.length} partes.');

  for (int i = 0; i < chunks.length; i++) {
    final chunk = chunks[i];
    final outputFile = File('${filePath}_part_$i.md');
    await outputFile.writeAsString(chunk.content);
    print('Parte $i salva em: ${outputFile.path}');
    print('  UTF-8 bytes: ${chunk.utf8ByteSize}');
    print('  Code units: ${chunk.codeUnitsSize}');
    print('  Diferença: ${chunk.utf8ByteSize - chunk.codeUnitsSize} bytes extras');
  }

  final full = File('${filePath}_full.md');
  full.writeAsString(splitter.getEnterily(chunks));
}
