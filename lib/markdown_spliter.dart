import 'dart:convert';
import 'dart:io';

enum ChunkType {
  text,        // Translatable text content
  codeBlock,   // Code blocks that should not be translated
  mixed,       // Content with both text and code blocks
}

/// Simple strategy for splitting markdown content
abstract class SplittingStrategy {
  /// Try to split content. Returns null if this strategy can't handle it.
  List<SplittedChunk>? trySplit(String content, int maxBytes);
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

/// Strategy for splitting by headers (## to ####)
class HeaderStrategy extends SplittingStrategy {
  @override
  List<SplittedChunk>? trySplit(String content, int maxBytes) {
    if (!RegExp(r'^#{2,4} ', multiLine: true).hasMatch(content)) return null;
    
    final sections = content.split(RegExp(r'(?=^#{2,4} )', multiLine: true));
    final List<SplittedChunk> result = [];
    
    for (final section in sections) {
      final size = utf8.encode(section).length;
      result.add(SplittedChunk(
        content: section,
        utf8ByteSize: size,
        codeUnitsSize: section.codeUnits.length,
        type: _determineType(section),
      ));
    }
    
    return result;
  }
  
  ChunkType _determineType(String content) {
    final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(content);
    final totalCodeSize = codeBlocks.fold(0, (sum, match) => sum + utf8.encode(match.group(0)!).length);
    final totalSize = utf8.encode(content).length;
    
    if (totalCodeSize == 0) {
      return ChunkType.text;
    } else if (totalCodeSize >= totalSize * 0.95) {
      return ChunkType.codeBlock;
    } else {
      return ChunkType.mixed;
    }
  }
}

/// Strategy for separating code blocks from text
class CodeBlockStrategy extends SplittingStrategy {
  @override
  List<SplittedChunk>? trySplit(String content, int maxBytes) {
    final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(content);
    if (codeBlocks.isEmpty) return null;
    
    final List<SplittedChunk> result = [];
    int lastEnd = 0;
    
    for (final codeBlock in codeBlocks) {
      // Add text before code block
      if (codeBlock.start > lastEnd) {
        final textPart = content.substring(lastEnd, codeBlock.start);
        if (textPart.trim().isNotEmpty) {
          result.add(SplittedChunk(
            content: textPart,
            utf8ByteSize: utf8.encode(textPart).length,
            codeUnitsSize: textPart.codeUnits.length,
            type: ChunkType.text,
          ));
        }
      }
      
      // Add code block
      final codeContent = codeBlock.group(0)!;
      result.add(SplittedChunk(
        content: codeContent,
        utf8ByteSize: utf8.encode(codeContent).length,
        codeUnitsSize: codeContent.codeUnits.length,
        type: ChunkType.codeBlock,
      ));
      
      lastEnd = codeBlock.end;
    }
    
    // Add remaining text
    if (lastEnd < content.length) {
      final remainingText = content.substring(lastEnd);
      if (remainingText.trim().isNotEmpty) {
        result.add(SplittedChunk(
          content: remainingText,
          utf8ByteSize: utf8.encode(remainingText).length,
          codeUnitsSize: remainingText.codeUnits.length,
          type: ChunkType.text,
        ));
      }
    }
    
    return result;
  }
}

/// Strategy for splitting by paragraphs (double line breaks)
class ParagraphStrategy extends SplittingStrategy {
  @override
  List<SplittedChunk>? trySplit(String content, int maxBytes) {
    if (!content.contains('\n\n')) return null;
    
    final paragraphs = content.split('\n\n');
    final List<SplittedChunk> result = [];
    String currentGroup = '';
    int currentSize = 0;
    
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = i == 0 ? paragraphs[i] : '\n\n${paragraphs[i]}';
      final paragraphSize = utf8.encode(paragraph).length;
      
      if (paragraphSize > maxBytes) {
        // Save current group
        if (currentGroup.isNotEmpty) {
          result.add(_createChunk(currentGroup, currentSize));
          currentGroup = '';
          currentSize = 0;
        }
        // Add oversized paragraph as-is
        result.add(_createChunk(paragraph, paragraphSize));
      } else if (currentSize + paragraphSize <= maxBytes) {
        currentGroup += paragraph;
        currentSize += paragraphSize;
      } else {
        // Save current and start new
        if (currentGroup.isNotEmpty) {
          result.add(_createChunk(currentGroup, currentSize));
        }
        currentGroup = paragraph;
        currentSize = paragraphSize;
      }
    }
    
    // Add final group
    if (currentGroup.isNotEmpty) {
      result.add(_createChunk(currentGroup, currentSize));
    }
    
    return result;
  }
  
  SplittedChunk _createChunk(String content, int size) {
    return SplittedChunk(
      content: content,
      utf8ByteSize: size,
      codeUnitsSize: content.codeUnits.length,
      type: ChunkType.text,
    );
  }
}


class MarkdownSplitter {
  final int maxBytes;
  final List<SplittingStrategy> _strategies;

  MarkdownSplitter({this.maxBytes = 20480})
      : _strategies = [
          HeaderStrategy(),
          CodeBlockStrategy(),
          ParagraphStrategy(),
        ];

  /// Divide o texto Markdown em partes respeitando os cabeçalhos ### e ##.
  /// Retorna uma lista de SplittedChunk com conteúdo e tamanhos.
  List<SplittedChunk> splitMarkdown(String content) {
    final chunks = _splitContent(content);
    return _combineSmallChunks(chunks);
  }

  /// Try each strategy in order, handling oversized chunks recursively
  List<SplittedChunk> _splitContent(String content, [int depth = 0]) {
    const maxDepth = 5;
    if (depth >= maxDepth) {
      // Max recursion depth reached, return as-is
      return [SplittedChunk(
        content: content,
        utf8ByteSize: utf8.encode(content).length,
        codeUnitsSize: content.codeUnits.length,
        type: ChunkType.text,
      )];
    }
    
    for (int i = 0; i < _strategies.length; i++) {
      final strategy = _strategies[i];
      final result = strategy.trySplit(content, maxBytes);
      if (result != null) {
        // Strategy worked, but check for oversized chunks
        final List<SplittedChunk> finalResult = [];
        for (final chunk in result) {
          if (chunk.utf8ByteSize > maxBytes) {
            // Chunk is still too big, try remaining strategies only
            final remainingStrategies = _strategies.skip(i + 1).toList();
            if (remainingStrategies.isNotEmpty) {
              final subSplitter = MarkdownSplitter(maxBytes: maxBytes);
              subSplitter._strategies.clear();
              subSplitter._strategies.addAll(remainingStrategies);
              finalResult.addAll(subSplitter._splitContent(chunk.content, depth + 1));
            } else {
              // No more strategies, accept the oversized chunk
              finalResult.add(chunk);
            }
          } else {
            finalResult.add(chunk);
          }
        }
        return finalResult;
      }
    }
    
    // No strategy worked, return as single chunk
    return [SplittedChunk(
      content: content,
      utf8ByteSize: utf8.encode(content).length,
      codeUnitsSize: content.codeUnits.length,
      type: ChunkType.text,
    )];
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
          result.add(SplittedChunk(
            content: currentContent,
            utf8ByteSize: currentSize,
            codeUnitsSize: currentContent.codeUnits.length,
            type: ChunkType.mixed, // Combined chunks are mixed by nature
          ));
        }
        
        // Start new accumulation with current chunk
        currentContent = chunk.content;
        currentSize = chunk.utf8ByteSize;
      }
    }
    
    // Add final accumulated content
    if (currentContent.isNotEmpty) {
      result.add(SplittedChunk(
        content: currentContent,
        utf8ByteSize: currentSize,
        codeUnitsSize: currentContent.codeUnits.length,
        type: ChunkType.mixed, // Combined chunks are mixed by nature
      ));
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
