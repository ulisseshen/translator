/// Validates that reference-style markdown links remain functional after translation
/// Inspired by Flutter's link reference checker implementation
class MarkdownLinkValidator {
  /// Pattern to match reference-style links: [text][ref]
  static final _referenceLinkPattern = RegExp(r'\[([^\[\]]+)\]\[([^\[\]]*)\]');
  
  /// Pattern to match link definitions: [ref]: url
  static final _linkDefinitionPattern = RegExp(r'^\s*\[([^\]]+)\]:\s*(.+)$', multiLine: true);
  
  
  /// Pattern to match HTML comments
  static final _htmlCommentPattern = RegExp(r'<!--.*?-->', dotAll: true);
  
  /// Pattern to match Jekyll/Liquid comment blocks
  static final _jekyllCommentPattern = RegExp(r'\{%\s*comment\s*%\}.*?\{%\s*endcomment\s*-?%\}', dotAll: true);
  
  /// Pattern to match HTML pre/code blocks
  static final _preCodeBlockPattern = RegExp(r'<pre.*?</pre>', dotAll: true);
  
  /// Pattern to match PR titles in paragraphs (from Flutter release notes)
  /// Example: <p><a href="https://github.com/flutter/engine/pull/27070">27070</a> [web][felt] Fix stdout inheritance...</p>
  static final _pullRequestTitlePattern = RegExp(
    r'<p><a href="https://github.com/.*?/pull/\d+">\d+</a>.*?</p>',
    dotAll: true,
  );
  
  /// Pattern to match PR titles in list items (from Flutter release notes)  
  /// Example: <li>[docs][FWW] DropdownButton... by @user in https://github.com/flutter/flutter/pull/100316</li>
  static final _pullRequestTitleInListItemPattern = RegExp(
    r'<li>(?:(?!<li>).)*?in\s+(?:<a[^>]*?href="https://github\.com/[^/]+/[^/]+/pull/\d+">[\d]+</a>|https://github\.com/[^/]+/[^/]+/pull/\d+)(?:(?!<li>).)*?</li>',
    dotAll: true,
  );
  
  /// Pattern to match highlight blocks
  /// Example: [[highlight]]flutter[[/highlight]]
  static final _highlightBlockPattern = RegExp(r'\[\[highlight\]\].*?\[\[/highlight\]\]', dotAll: true);
  
  /// Pattern to find invalid reference links - matches the original Flutter implementation
  /// Finds [text][ref] patterns that should be rendered as <a> tags but aren't
  static final _invalidLinkReferencePattern = RegExp(r'\[[^\[\]]+]\[[^\[\]]*]');

  /// Validates that all reference-style links have matching definitions
  static bool validateReferenceLinks(String original, String translated) {
    final result = validateReferenceLinksDetailed(original, translated);
    return result.isValid;
  }
  
  /// Find invalid reference links in content - following original Flutter implementation
  /// This method closely mirrors the original `_findInContent` function
  /// Returns only reference patterns that should have definitions but don't
  static List<String> findInvalidReferences(String content) {
    // Extract all reference link information
    final info = _extractReferenceLinkInfo(content);
    final invalidReferences = <String>[];
    
    String cleaned = content;
    
    // Apply all exclusions first (matches original _allReplacements)
    cleaned = cleaned.replaceAll(_htmlCommentPattern, '');
    cleaned = cleaned.replaceAll(_jekyllCommentPattern, '');
    cleaned = cleaned.replaceAll(_preCodeBlockPattern, '');
    cleaned = cleaned.replaceAll(_pullRequestTitlePattern, '');
    cleaned = cleaned.replaceAll(_pullRequestTitleInListItemPattern, '');
    cleaned = cleaned.replaceAll(_highlightBlockPattern, '');
    
    // Remove fenced code blocks (``` ... ```)
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
    
    // Remove indented code blocks (4 spaces or a tab at line start)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^( {4,}|\t).*(\n|\r|$)', multiLine: true),
      (match) => '',
    );
    
    // Remove inline code spans (`...`)
    cleaned = cleaned.replaceAll(RegExp(r'`[^`]*?`'), '');
    
    // Find all reference-style links
    final allReferences = _invalidLinkReferencePattern.allMatches(cleaned);
    
    // Check each reference to see if it has a definition
    for (final match in allReferences) {
      final fullMatch = match[0];
      if (fullMatch != null) {
        // Extract the reference key from [text][ref] pattern
        final refMatch = _referenceLinkPattern.firstMatch(fullMatch);
        if (refMatch != null) {
          final reference = (refMatch.group(2) ?? '').toLowerCase().trim()
              .replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
          final actualRef = reference.isEmpty 
              ? refMatch.group(1)!.toLowerCase().trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ')
              : reference;
          
          // Only report as invalid if this reference has an actual definition available
          // This prevents false positives for patterns like [Text Scaling][Material] 
          // which are labels, not reference links
          if (!info.definitions.containsKey(actualRef) && info.definitions.isNotEmpty) {
            // Check if there are any definitions that could match this pattern
            // Only report as broken if there's evidence this should be a reference link
            final hasRelatedDefinitions = info.definitions.keys.any((key) => 
              key.contains(actualRef.split(' ').first) || actualRef.contains(key.split(' ').first));
            
            if (hasRelatedDefinitions) {
              invalidReferences.add(fullMatch);
            }
          }
        }
      }
    }
    
    return invalidReferences;
  }
  
  /// Gets detailed validation results for debugging
  static ReferenceLinkValidationResult validateReferenceLinksDetailed(String original, String translated) {
    final originalInfo = _extractReferenceLinkInfo(original);
    final translatedInfo = _extractReferenceLinkInfo(translated);
    
    return _validateLinkConsistency(originalInfo, translatedInfo);
  }
  
  /// Extracts reference link information using robust regex patterns
  static ReferenceLinkInfo _extractReferenceLinkInfo(String markdown) {
    final references = <String>{};
    final definitions = <String, String>{};

    // Remove HTML comments and Jekyll comments
    String cleaned = markdown.replaceAll(_htmlCommentPattern, '');
    cleaned = cleaned.replaceAll(_jekyllCommentPattern, '');

    // Remove fenced code blocks (``` ... ```)
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');

    // Remove indented code blocks (4 spaces or a tab at line start)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^( {4,}|\t).*(\n|\r|$)', multiLine: true),
      (match) => '',
    );

    // Remove inline code spans (`...`)
    cleaned = cleaned.replaceAll(RegExp(r'`[^`]*?`'), '');

    // First, find all link definitions: [ref]: url (from cleaned content)
    final definitionMatches = _linkDefinitionPattern.allMatches(cleaned);
    for (final match in definitionMatches) {
      final reference = match.group(1)!.toLowerCase().trim();
      final url = match.group(2)!.trim();
      if (url.isNotEmpty) {
        definitions[reference] = url;
      }
    }

    // Only extract reference links that have corresponding definitions
    // This prevents false positives for patterns like [Text Scaling][Material] which are labels
    final referenceMatches = _referenceLinkPattern.allMatches(cleaned);
    for (final match in referenceMatches) {
      final reference = (match.group(2) ?? '').toLowerCase().trim()
          .replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
      final actualRef = reference.isEmpty 
          ? match.group(1)!.toLowerCase().trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ')
          : reference;
      
      // Only include as a reference if there's a corresponding definition
      if (definitions.containsKey(actualRef)) {
        references.add(actualRef);
      }
    }

    return ReferenceLinkInfo(references, definitions);
  }
  
  
  /// Validates that reference links are consistent between original and translated
  /// Following the original Flutter implementation approach - focus on broken references
  static ReferenceLinkValidationResult _validateLinkConsistency(ReferenceLinkInfo original, ReferenceLinkInfo translated) {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Primary check: Find broken references (references without definitions) in translated content
    // BUT only report as issues if the reference existed in the original and had a definition
    // This prevents false positives for patterns that look like reference links but aren't
    final brokenReferences = <String>[];
    
    // Check references in translated content that don't have definitions
    for (final reference in translated.references) {
      if (!translated.definitions.containsKey(reference)) {
        // Only treat as broken if the original had this reference and it had a definition
        if (original.references.contains(reference) && original.definitions.containsKey(reference)) {
          brokenReferences.add(reference);
        }
      }
    }
    
    // Also check for original references that were lost during translation 
    // (they had definitions in original but don't appear in translated at all)
    for (final originalRef in original.references) {
      if (original.definitions.containsKey(originalRef) && 
          !translated.references.contains(originalRef) && 
          !translated.definitions.containsKey(originalRef)) {
        brokenReferences.add(originalRef);
      }
    }
    
    if (brokenReferences.isNotEmpty) {
      issues.add('Broken references (no definition found): ${brokenReferences.join(', ')}');
    }
    
    // Secondary check: Detect potential translation issues
    final originalReferences = original.references;
    final translatedReferences = translated.references;
    
    if (originalReferences.isNotEmpty && translatedReferences.isEmpty) {
      warnings.add('All reference links were lost in translation');
    } else if (originalReferences.length != translatedReferences.length) {
      warnings.add('Reference count changed: ${originalReferences.length} -> ${translatedReferences.length}');
    }
    
    // Optional check: Find unused definitions (might indicate over-translation)
    final usedReferences = translated.references;
    final definedReferences = translated.definitions.keys.toSet();
    final unusedDefinitions = definedReferences.difference(usedReferences);
    
    if (unusedDefinitions.isNotEmpty) {
      warnings.add('Unused link definitions: ${unusedDefinitions.join(', ')}');
    }
    
    // Note: We don't check for missing URLs like the previous implementation
    // because the original Flutter checker only looks for broken references
    // The URL consistency is less important than functional reference links
    
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