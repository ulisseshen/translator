import 'package:markdown/markdown.dart';

/// Domain object that validates markdown structure consistency between input and output
class MarkdownStructureValidator {
  /// Extracts the structural elements from markdown content
  static List<String> extractStructure(String markdown) {
    final document = Document();
    final nodes = document.parseLines(markdown.split('\n'));
    
    final structure = <String>[];
    
    for (final node in nodes) {
      if (node is Element) {
        structure.add(_getElementStructure(node));
      }
    }
    
    return structure;
  }
  
  static String _getElementStructure(Element element) {
    final buffer = StringBuffer();
    buffer.write(element.tag);
    
    // Add attributes if they exist
    if (element.attributes.isNotEmpty) {
      final attrs = element.attributes.entries
          .map((e) => '${e.key}="${e.value}"')
          .join(' ');
      buffer.write('[$attrs]');
    }
    
    // Recursively add child elements
    for (final child in element.children ?? []) {
      if (child is Element) {
        buffer.write('>${_getElementStructure(child)}');
      }
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