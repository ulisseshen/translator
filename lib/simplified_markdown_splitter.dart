import 'dart:convert';
import 'simplified_chunk.dart';

/// Simple strategy for splitting clean markdown content (without code blocks)
abstract class SimplifiedSplittingStrategy {
  /// Try to split content. Returns null if this strategy can't handle it.
  List<SimplifiedChunk>? trySplit(String content, int maxBytes);
}

/// Strategy for splitting by headers (## to ####)
class SimplifiedHeaderStrategy extends SimplifiedSplittingStrategy {
  @override
  List<SimplifiedChunk>? trySplit(String content, int maxBytes) {
    if (!RegExp(r'^#{2,4} ', multiLine: true).hasMatch(content)) return null;
    
    final sections = content.split(RegExp(r'(?=^#{2,4} )', multiLine: true));
    final List<SimplifiedChunk> result = [];
    
    for (final section in sections) {
      result.add(SimplifiedChunk.fromContent(section));
    }
    
    return result;
  }
}

/// Strategy for splitting by paragraphs (double line breaks)
class SimplifiedParagraphStrategy extends SimplifiedSplittingStrategy {
  @override
  List<SimplifiedChunk>? trySplit(String content, int maxBytes) {
    if (!content.contains('\n\n')) return null;
    
    final paragraphs = content.split('\n\n');
    final List<SimplifiedChunk> result = [];
    String currentGroup = '';
    int currentSize = 0;
    
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = i == 0 ? paragraphs[i] : '\n\n${paragraphs[i]}';
      final paragraphSize = utf8.encode(paragraph).length;
      
      if (currentSize + paragraphSize > maxBytes && currentGroup.isNotEmpty) {
        // Current group would exceed limit, flush it
        result.add(SimplifiedChunk.fromContent(currentGroup));
        currentGroup = paragraphs[i]; // Start new group without separator
        currentSize = utf8.encode(paragraphs[i]).length;
      } else {
        // Add to current group
        currentGroup += paragraph;
        currentSize += paragraphSize;
      }
    }
    
    // Add remaining group
    if (currentGroup.isNotEmpty) {
      result.add(SimplifiedChunk.fromContent(currentGroup));
    }
    
    return result.isEmpty ? null : result;
  }
}

/// Strategy for force splitting content at line boundaries
class SimplifiedLineSplittingStrategy extends SimplifiedSplittingStrategy {
  @override
  List<SimplifiedChunk>? trySplit(String content, int maxBytes) {
    // This strategy always works as a fallback
    final List<SimplifiedChunk> result = [];
    final lines = content.split('\n');

    // If there's only one line (no line breaks), return it as-is even if it exceeds limit
    if (lines.length == 1) {
      return [SimplifiedChunk.fromContent(content)];
    }

    String currentChunk = '';
    int currentSize = 0;  

    for (final line in lines) {
      final lineSize = utf8.encode(line).length;
      final newlineSize = currentChunk.isEmpty ? 0 : 1; // Account for '\n' separator
      
      if (currentSize + newlineSize + lineSize > maxBytes && currentChunk.isNotEmpty) {
        // Current chunk would exceed limit, flush it
        result.add(SimplifiedChunk.fromContent(currentChunk));
        currentChunk = line; // Start new chunk with current line
        currentSize = lineSize;
      } else {
        // Add to current chunk
        currentChunk += (currentChunk.isEmpty ? '' : '\n') + line;
        currentSize += newlineSize + lineSize;
      }
    }
    
    // Add the final chunk if it has content
    if (currentChunk.isNotEmpty) {
      result.add(SimplifiedChunk.fromContent(currentChunk));
    }
    
    return result;
  }
}

/// Simplified markdown splitter that works with clean content (code blocks already extracted)
class SimplifiedMarkdownSplitter {
  static const int defaultMaxBytes = 20 * 1024; // 20KB

  final List<SimplifiedSplittingStrategy> _strategies = [
    SimplifiedHeaderStrategy(),
    SimplifiedParagraphStrategy(),
    SimplifiedLineSplittingStrategy(),
  ];

  /// Split clean markdown content into chunks
  /// [content] - Content with code blocks already extracted and replaced with anchors
  /// [maxBytes] - Maximum size per chunk in UTF-8 bytes
  List<SimplifiedChunk> split(String content, {int? maxBytes}) {
    maxBytes ??= defaultMaxBytes;
    
    if (content.isEmpty) {
      return [];
    }

    final contentSize = utf8.encode(content).length;
    if (contentSize <= maxBytes) {
      return [SimplifiedChunk.fromContent(content)];
    }

    return _splitRecursively(content, maxBytes, 0);
  }

  List<SimplifiedChunk> _splitRecursively(String content, int maxBytes, int strategyIndex) {
    final contentSize = utf8.encode(content).length;
    
    // If content fits within limit, return as single chunk
    if (contentSize <= maxBytes) {
      return [SimplifiedChunk.fromContent(content)];
    }

    // Try strategies in order
    for (int i = strategyIndex; i < _strategies.length; i++) {
      final chunks = _strategies[i].trySplit(content, maxBytes);
      if (chunks != null) {
        // Strategy worked, now recursively split any oversized chunks
        final List<SimplifiedChunk> result = [];
        
        for (final chunk in chunks) {
          if (chunk.utf8ByteSize > maxBytes) {
            // This chunk is still too big, try next strategies
            // If we're already at the last strategy, accept the oversized chunk
            if (i + 1 >= _strategies.length) {
              result.add(chunk);
            } else {
              result.addAll(_splitRecursively(chunk.content, maxBytes, i + 1));
            }
          } else {
            result.add(chunk);
          }
        }
        
        return result;
      }
    }

    // This should never happen since SimplifiedLineSplittingStrategy always returns results
    throw StateError('All splitting strategies failed, which should not be possible');
  }


  /// Get statistics about the splitting process
  Map<String, dynamic> getStatistics(List<SimplifiedChunk> chunks) {
    if (chunks.isEmpty) {
      return {
        'totalChunks': 0,
        'totalBytes': 0,
        'totalCodeUnits': 0,
        'averageBytes': 0,
        'maxBytes': 0,
        'minBytes': 0,
      };
    }

    final totalBytes = chunks.fold(0, (sum, chunk) => sum + chunk.utf8ByteSize);
    final totalCodeUnits = chunks.fold(0, (sum, chunk) => sum + chunk.codeUnitsSize);
    final byteSizes = chunks.map((chunk) => chunk.utf8ByteSize).toList();

    return {
      'totalChunks': chunks.length,
      'totalBytes': totalBytes,
      'totalCodeUnits': totalCodeUnits,
      'averageBytes': totalBytes ~/ chunks.length,
      'maxBytes': byteSizes.reduce((a, b) => a > b ? a : b),
      'minBytes': byteSizes.reduce((a, b) => a < b ? a : b),
    };
  }
}