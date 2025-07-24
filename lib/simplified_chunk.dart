import 'dart:convert';

/// Simplified chunk for markdown content after code block extraction
/// This replaces the complex ChunkType system with a simpler approach
class SimplifiedChunk {
  final String content;
  final int utf8ByteSize;
  final int codeUnitsSize;

  SimplifiedChunk({
    required this.content,
    required this.utf8ByteSize,
    required this.codeUnitsSize,
  });

  /// Factory constructor that calculates sizes automatically
  factory SimplifiedChunk.fromContent(String content) {
    return SimplifiedChunk(
      content: content,
      utf8ByteSize: utf8.encode(content).length,
      codeUnitsSize: content.codeUnits.length,
    );
  }

  /// All simplified chunks are translatable since code blocks are handled separately
  bool get isTranslatable => true;

  @override
  String toString() {
    return 'SimplifiedChunk(utf8Bytes: $utf8ByteSize, codeUnits: $codeUnitsSize, content: ${content.length} chars)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimplifiedChunk &&
        other.content == content &&
        other.utf8ByteSize == utf8ByteSize &&
        other.codeUnitsSize == codeUnitsSize;
  }

  @override
  int get hashCode {
    return content.hashCode ^ utf8ByteSize.hashCode ^ codeUnitsSize.hashCode;
  }
}