import 'package:markdown/markdown.dart';

/// Domain object that validates markdown structure consistency between input and output
/// Focuses on high-level structural elements only (headers, lists, blockquotes, code blocks)
class MarkdownStructureValidator {
  /// High-level structural elements we care about
  static const _structuralElements = {
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',  // Headers
    'ul', 'ol', 'li',                      // Lists
    'blockquote',                          // Blockquotes
    'pre', 'code',                         // Code blocks
    'hr',                                  // Horizontal rules
    'table', 'thead', 'tbody', 'tr'       // Tables (structure only)
  };

  /// Extracts only high-level structural elements from markdown content
  static List<String> extractStructure(String markdown) {
    final document = Document();
    final nodes = document.parseLines(markdown.split('\n'));
    
    final structure = <String>[];
    
    for (final node in nodes) {
      if (node is Element) {
        _collectStructuralElements(node, structure);
      }
    }
    
    return structure;
  }
  
  static void _collectStructuralElements(Element element, List<String> structure) {
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
      final listItems = element.children?.whereType<Element>()
          .where((e) => e.tag == 'li').length ?? 0;
      buffer.write('($listItems)');
    }
    
    // For headers, preserve the level
    if (element.tag.startsWith('h') && element.tag.length == 2) {
      // Header level is already in the tag (h1, h2, etc.)
    }
    
    // For tables, include basic structure info
    if (element.tag == 'table') {
      final rows = element.children?.whereType<Element>()
          .where((e) => e.tag == 'tr' || 
                       (e.children?.any((child) => child is Element && child.tag == 'tr') ?? false))
          .length ?? 0;
      if (rows > 0) buffer.write('($rows)');
    }
    
    return buffer.toString();
  }
  
  /// Validates that the markdown structure is preserved
  static bool validateStructureConsistency(String original, String translated) {
    final originalStructure = extractStructure(original);
    final translatedStructure = extractStructure(translated);
    
    return _compareStructures(originalStructure, translatedStructure);
  }
  
  static bool _compareStructures(List<String> original, List<String> translated) {
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