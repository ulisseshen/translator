import 'code_block_extractor.dart';

/// Restores code blocks from translated content by replacing anchors with original code
class CodeBlockRestorer {
  /// Restores code blocks in the translated content by replacing anchors with original code
  /// 
  /// [translatedContent] - The translated content containing anchors
  /// [extractedBlocks] - List of extracted code blocks with their anchors and original code
  /// 
  /// Returns the final content with all anchors replaced by their original code blocks
  String restoreCodeBlocks(String translatedContent, List<ExtractedCodeBlock> extractedBlocks) {
    if (translatedContent.isEmpty || extractedBlocks.isEmpty) {
      return translatedContent;
    }

    String restoredContent = translatedContent;

    // Replace each anchor with its corresponding original code
    for (final block in extractedBlocks) {
      restoredContent = restoredContent.replaceAll(block.anchor, block.originalCode);
    }

    return restoredContent;
  }

  /// Validates that all expected anchors are present in the translated content
  /// 
  /// Returns a list of missing anchors that should be present but are not found
  List<String> validateAnchors(String translatedContent, List<ExtractedCodeBlock> extractedBlocks) {
    final missingAnchors = <String>[];

    for (final block in extractedBlocks) {
      if (!translatedContent.contains(block.anchor)) {
        missingAnchors.add(block.anchor);
      }
    }

    return missingAnchors;
  }

  /// Finds any unexpected anchors in the translated content
  /// 
  /// Returns a list of anchor-like strings that don't correspond to any extracted blocks
  List<String> findUnexpectedAnchors(String translatedContent, List<ExtractedCodeBlock> extractedBlocks) {
    final expectedAnchors = extractedBlocks.map((block) => block.anchor).toSet();
    final unexpectedAnchors = <String>[];

    // Look for anchor patterns in the content
    final anchorPattern = RegExp(r'__(?:CODE_BLOCK_ANCHOR_)\d+__');
    final foundAnchors = anchorPattern.allMatches(translatedContent);

    for (final match in foundAnchors) {
      final anchor = match.group(0)!;
      if (!expectedAnchors.contains(anchor)) {
        unexpectedAnchors.add(anchor);
      }
    }

    return unexpectedAnchors;
  }

  /// Provides a comprehensive report on anchor restoration
  /// 
  /// Returns a map with statistics about the restoration process
  //TODO trocar por TranslationStatistics
  Map<String, dynamic> getRestorationReport(String translatedContent, List<ExtractedCodeBlock> extractedBlocks) {
    final missingAnchors = validateAnchors(translatedContent, extractedBlocks);
    final unexpectedAnchors = findUnexpectedAnchors(translatedContent, extractedBlocks);
    
    final totalExpectedAnchors = extractedBlocks.length;
    return {
      'totalExpectedAnchors': totalExpectedAnchors,
      'missingAnchors': missingAnchors,
      'missingAnchorsCount': missingAnchors.length,
      'unexpectedAnchors': unexpectedAnchors,
      'unexpectedAnchorsCount': unexpectedAnchors.length,
      'restorationSuccess': missingAnchors.isEmpty && unexpectedAnchors.isEmpty,
    };
  }
}