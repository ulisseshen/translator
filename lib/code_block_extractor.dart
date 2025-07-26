
/// Represents an extracted code block with its metadata
class ExtractedCodeBlock {
  /// The original code content including backticks and language specifier
  final String originalCode;
  
  /// The anchor string used to replace this code block in clean content
  final String anchor;

  
  /// The programming language specified (for fenced blocks), empty for inline
  final String language;

  const ExtractedCodeBlock({
    required this.originalCode,
    required this.anchor,
    this.language = '',
  });

  @override
  String toString() {
    return 'ExtractedCodeBlock(anchor: $anchor, language: $language, code: ${originalCode.length > 50 ? '${originalCode.substring(0, 50)}...' : originalCode})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtractedCodeBlock &&
        other.originalCode == originalCode &&
        other.anchor == anchor &&
        other.language == language;
  }

  @override
  int get hashCode {
    return originalCode.hashCode ^
        anchor.hashCode ^
        language.hashCode;
  }
}

/// Result of code block extraction containing clean content and extracted blocks
class CodeBlockExtractionResult {
  /// The content with code blocks replaced by anchors
  final String cleanContent;
  
  /// List of extracted code blocks with their metadata
  final List<ExtractedCodeBlock> extractedBlocks;

  const CodeBlockExtractionResult({
    required this.cleanContent,
    required this.extractedBlocks,
  });

  @override
  String toString() {
    return 'CodeBlockExtractionResult(extractedBlocks: ${extractedBlocks.length}, cleanContentLength: ${cleanContent.length})';
  }
}

/// Extracts code blocks from markdown content and replaces them with anchors
class CodeBlockExtractor {
  static const String _fencedAnchorPrefix = '__EDOC_';
  static const String _anchorSuffix = '__';

  /// Regular expression for fenced code blocks (```...```)
  /// This regex handles both indented and non-indented code blocks
  static final RegExp _fencedCodeBlockRegex = RegExp(
    r'^( *)```(\w*)[^\n]*\n([\s\S]*?)\n\1```',
    multiLine: true,
  );

  int _anchorCounter = 0;

  /// Extracts all code blocks from the given markdown content
  /// Returns clean content with anchors and list of extracted blocks
  CodeBlockExtractionResult extractCodeBlocks(String content) {
    if (content.isEmpty) {
      return const CodeBlockExtractionResult(
        cleanContent: '',
        extractedBlocks: [],
      );
    }

    // Reset counter for each extraction to ensure consistent anchors
    _anchorCounter = 0;
    final extractedBlocks = <ExtractedCodeBlock>[];
    String cleanContent = content;

    // First, extract fenced code blocks
    cleanContent = _extractFencedCodeBlocks(cleanContent, extractedBlocks);

    return CodeBlockExtractionResult(
      cleanContent: cleanContent,
      extractedBlocks: extractedBlocks,
    );
  }

  /// Extracts fenced code blocks and replaces them with anchors
  String _extractFencedCodeBlocks(String content, List<ExtractedCodeBlock> extractedBlocks) {
    return content.replaceAllMapped(_fencedCodeBlockRegex, (match) {
      final language = match.group(2) ?? '';
      final fullMatch = match.group(0)!;
      final anchor = _generateAnchor(_fencedAnchorPrefix);

      final extractedBlock = ExtractedCodeBlock(
        originalCode: fullMatch,
        anchor: anchor,
        language: language,
      );

      extractedBlocks.add(extractedBlock);
      return anchor;
    });
  }

  /// Generates a unique anchor string
  String _generateAnchor(String prefix) {
    final anchor = '$prefix$_anchorCounter$_anchorSuffix';
    _anchorCounter++;
    return anchor;
  }

  /// Resets the anchor counter (useful for testing)
  void resetCounter() {
    _anchorCounter = 0;
  }
}