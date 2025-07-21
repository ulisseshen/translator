/// Validates that reference-style markdown links remain functional after translation
/// Inspired by Flutter's link reference checker implementation
class MarkdownLinkValidator {
  /// Pattern to match reference-style links: [text][ref]
  static final _referenceLinkPattern = RegExp(r'\[([^\[\]]+)\]\[([^\[\]]*)\]');
  
  /// Pattern to match link definitions: [ref]: url
  static final _linkDefinitionPattern = RegExp(r'^\s*\[([^\]]+)\]:\s*(.+)$', multiLine: true);
  
  /// Pattern to match code blocks (fenced with ```)
  static final _fencedCodeBlockPattern = RegExp(r'```[\s\S]*?```', multiLine: true);
  
  /// Pattern to match inline code spans
  static final _inlineCodePattern = RegExp(r'`[^`]+`');
  
  /// Pattern to match HTML comments
  static final _htmlCommentPattern = RegExp(r'<!--.*?-->', dotAll: true);

  /// Validates that all reference-style links have matching definitions
  static bool validateReferenceLinks(String original, String translated) {
    final result = validateReferenceLinksDetailed(original, translated);
    return result.isValid;
  }
  
  /// Gets detailed validation results for debugging
  static ReferenceLinkValidationResult validateReferenceLinksDetailed(String original, String translated) {
    final originalInfo = _extractReferenceLinkInfo(original);
    final translatedInfo = _extractReferenceLinkInfo(translated);
    
    return _validateLinkConsistency(originalInfo, translatedInfo);
  }
  
  /// Extracts reference link information using robust regex patterns
  static ReferenceLinkInfo _extractReferenceLinkInfo(String markdown) {
    // Clean content by removing code blocks and comments first
    String cleanContent = _removeCodeBlocksAndComments(markdown);
    
    final references = <String>{};
    final definitions = <String, String>{};
    
    // Find all reference-style links: [text][ref]
    final referenceMatches = _referenceLinkPattern.allMatches(cleanContent);
    for (final match in referenceMatches) {
      final reference = (match.group(2) ?? '').toLowerCase().trim();
      if (reference.isNotEmpty) {
        references.add(reference);
      } else {
        // Handle shortcut reference links [text][] - use text as reference
        final text = match.group(1)!.toLowerCase().trim();
        references.add(text);
      }
    }
    
    // Find link definitions: [ref]: url
    final definitionMatches = _linkDefinitionPattern.allMatches(markdown);
    for (final match in definitionMatches) {
      final reference = match.group(1)!.toLowerCase().trim();
      final url = match.group(2)!.trim();
      if (url.isNotEmpty) {
        definitions[reference] = url;
      }
    }
    
    return ReferenceLinkInfo(references, definitions);
  }
  
  /// Remove code blocks and comments to avoid false positives
  static String _removeCodeBlocksAndComments(String content) {
    String cleaned = content;
    
    // Remove HTML comments
    cleaned = cleaned.replaceAll(_htmlCommentPattern, '');
    
    // Remove fenced code blocks
    cleaned = cleaned.replaceAll(_fencedCodeBlockPattern, '');
    
    // Remove inline code spans
    cleaned = cleaned.replaceAll(_inlineCodePattern, '');
    
    return cleaned;
  }
  
  /// Validates that reference links are consistent between original and translated
  /// Returns detailed validation result with issues and warnings
  static ReferenceLinkValidationResult _validateLinkConsistency(ReferenceLinkInfo original, ReferenceLinkInfo translated) {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Check 1: All original URLs should still be present
    final originalUrls = Set<String>.from(original.definitions.values);
    final translatedUrls = Set<String>.from(translated.definitions.values);
    final missingUrls = originalUrls.difference(translatedUrls);
    
    if (missingUrls.isNotEmpty) {
      issues.add('Missing URLs in translation: ${missingUrls.join(', ')}');
    }
    
    // Check 2: Find broken references (references without definitions) in translated
    final brokenReferences = <String>[];
    for (final reference in translated.references) {
      if (!translated.definitions.containsKey(reference)) {
        brokenReferences.add(reference);
      }
    }
    
    if (brokenReferences.isNotEmpty) {
      issues.add('Broken references (no definition found): ${brokenReferences.join(', ')}');
    }
    
    // Check 3: Find unused definitions (possible over-translation)
    final usedReferences = translated.references;
    final definedReferences = translated.definitions.keys.toSet();
    final unusedDefinitions = definedReferences.difference(usedReferences);
    
    if (unusedDefinitions.isNotEmpty) {
      warnings.add('Unused link definitions: ${unusedDefinitions.join(', ')}');
    }
    
    // Check 4: Detect potential translation issues
    // If we have references in original but not in translated, AI might have over-translated
    final originalReferences = original.references;
    final translatedReferences = translated.references;
    
    if (originalReferences.isNotEmpty && translatedReferences.isEmpty) {
      issues.add('All reference links were lost in translation');
    } else if (originalReferences.length != translatedReferences.length) {
      warnings.add('Reference count changed: ${originalReferences.length} -> ${translatedReferences.length}');
    }
    
    final isValid = issues.isEmpty;
    
    return ReferenceLinkValidationResult(
      isValid: isValid,
      issues: issues,
      warnings: warnings,
      originalInfo: original,
      translatedInfo: translated,
    );
  }
}

/// Information about reference-style links in markdown
class ReferenceLinkInfo {
  final Set<String> references;  // References used in [text][ref] format
  final Map<String, String> definitions;  // Definitions [ref]: url
  
  const ReferenceLinkInfo(this.references, this.definitions);
  
  @override
  String toString() {
    return 'ReferenceLinkInfo(references: $references, definitions: $definitions)';
  }
}

/// Detailed validation result for reference-style links
class ReferenceLinkValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final ReferenceLinkInfo originalInfo;
  final ReferenceLinkInfo translatedInfo;
  
  const ReferenceLinkValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.originalInfo,
    required this.translatedInfo,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ReferenceLinkValidationResult:');
    buffer.writeln('  Valid: $isValid');
    if (issues.isNotEmpty) {
      buffer.writeln('  Issues: ${issues.join(', ')}');
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('  Warnings: ${warnings.join(', ')}');
    }
    return buffer.toString();
  }
}