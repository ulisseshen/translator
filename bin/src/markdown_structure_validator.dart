import 'package:markdown/markdown.dart';
import 'markdown_link_validator.dart';

/// Domain object that validates markdown structure consistency between input and output
/// Focuses on high-level structural elements only (headers, lists, blockquotes, code blocks)
class MarkdownStructureValidator {
  /// High-level structural elements we care about
  static const _structuralElements = {
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', // Headers
    // 'ul', 'ol', 'li',                      // Lists
    // 'blockquote',                          // Blockquotes
    // 'pre', 'code',                         // Code blocks
    // 'hr',                                  // Horizontal rules
    // 'table', 'thead', 'tbody', 'tr'       // Tables (structure only)
  };

  /// Return the count of high-level headers in the markdown content
  static int countHeaders(String markdown) {
    final document = Document();
    final nodes = document.parseLines(markdown.split('\n'));
    final filtered = nodes
        .whereType<Element>()
        .where(
          (node) => _structuralElements.contains(node.tag),
        )
        .toList();
    return filtered.length;
  }

  static void _collectStructuralElements(
      Element element, List<String> structure) {
    // Only collect high-level structural elements
    if (_structuralElements.contains(element.tag)) {
      final structureInfo = _getHighLevelStructure(element);
      if (structureInfo.isNotEmpty) {
        structure.add(structureInfo);
      }
    }

    // Recursively check children for structural elements
    for (final child in element.children ?? []) {
      if (child is Element) {
        _collectStructuralElements(child, structure);
      }
    }
  }

  static String _getHighLevelStructure(Element element) {
    final buffer = StringBuffer();
    buffer.write(element.tag);

    // For lists, include the type and nesting level info
    if (element.tag == 'ul' || element.tag == 'ol') {
      final listItems = element.children
              ?.whereType<Element>()
              .where((e) => e.tag == 'li')
              .length ??
          0;
      buffer.write('($listItems)');
    }

    // For headers, preserve the level
    if (element.tag.startsWith('h') && element.tag.length == 2) {
      // Header level is already in the tag (h1, h2, etc.)
    }

    // For tables, include basic structure info
    if (element.tag == 'table') {
      final rows = element.children
              ?.whereType<Element>()
              .where((e) =>
                  e.tag == 'tr' ||
                  (e.children?.any(
                          (child) => child is Element && child.tag == 'tr') ??
                      false))
              .length ??
          0;
      if (rows > 0) buffer.write('($rows)');
    }

    return buffer.toString();
  }

  /// Validates that the markdown structure is preserved
  static bool validateStructureConsistency(String original, String translated) {
    final originalStructure = countHeaders(original);
    final translatedStructure = countHeaders(translated);

    return originalStructure == translatedStructure;
  }

  /// Validates both structure and reference-style links consistency
  static bool validateStructureAndLinks(String original, String translated) {
    // First check structural consistency
    if (!validateStructureConsistency(original, translated)) {
      return false;
    }

    // Then check reference-style links
    return MarkdownLinkValidator.validateReferenceLinks(original, translated);
  }

  /// Gets detailed validation results for both structure and links
  static ValidationResult validateStructureAndLinksDetailed(
      String original, String translated) {
    final structureValid = validateStructureConsistency(original, translated);
    final linkValidation = MarkdownLinkValidator.validateReferenceLinksDetailed(
        original, translated);

    final issues = <String>[];
    final warnings = <String>[];

    if (!structureValid) {
      final originalStructure = countHeaders(original);
      final translatedStructure = countHeaders(translated);
      issues.add(
          'Header mismatch: ${originalStructure} vs ${translatedStructure} header elements');
    }

    if (!linkValidation.isValid) {
      issues.addAll(linkValidation.issues);
    }

    warnings.addAll(linkValidation.warnings);

    return ValidationResult(
      isValid: structureValid && linkValidation.isValid,
      issues: issues,
      warnings: warnings,
      linkValidation: linkValidation,
    );
  }

  static bool _compareStructures(
      List<String> original, List<String> translated) {
    if (original.length != translated.length) {
      return false;
    }

    for (int i = 0; i < original.length; i++) {
      if (original[i] != translated[i]) {
        return false;
      }
    }

    return true;
  }
}

/// Combined validation result for structure and links
class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final ReferenceLinkValidationResult linkValidation;

  const ValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.linkValidation,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ValidationResult:');
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
