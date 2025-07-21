/// Utility class for validating markdown files before translation
class MarkdownValidator {
  /// Validation result containing status and details
  /// Focuses only on links and headers as requested
  static MarkdownValidationResult validateMarkdown(String content, String filePath) {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Check for basic markdown structure (empty files, etc.)
    _validateBasicStructure(content, issues, warnings);
    
    // Check for malformed links (both inline and reference-style)
    _validateLinks(content, issues, warnings);
    
    // Check for malformed headers
    _validateHeaders(content, issues, warnings);
    
    return MarkdownValidationResult(
      isValid: issues.isEmpty,
      filePath: filePath,
      issues: issues,
      warnings: warnings,
      contentLength: content.length,
    );
  }
  
  static void _validateBasicStructure(String content, List<String> issues, List<String> warnings) {
    if (content.trim().isEmpty) {
      issues.add('File is empty or contains only whitespace');
      return;
    }
    
    // Check for extremely long lines that might cause issues
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].length > 5000) {
        warnings.add('Line ${i + 1} is extremely long (${lines[i].length} chars) - might cause processing issues');
      }
    }
  }
  
  static void _validateLinks(String content, List<String> issues, List<String> warnings) {
    // Check for malformed inline links: [text](url)
    final inlineLinkPattern = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
    final inlineMatches = inlineLinkPattern.allMatches(content);
    
    for (final match in inlineMatches) {
      final linkText = match.group(1) ?? '';
      final linkUrl = match.group(2) ?? '';
      
      if (linkText.isEmpty) {
        warnings.add('Empty link text found: ${match.group(0)}');
      }
      
      if (linkUrl.isEmpty) {
        warnings.add('Empty link URL found: ${match.group(0)}');
      }
    }
    
    // Check for reference-style links and their definitions
    final referenceLinkPattern = RegExp(r'\[([^\]]+)\]\[([^\]]*)\]');
    final referenceMatches = referenceLinkPattern.allMatches(content);
    
    // Collect all reference definitions
    final referenceDefPattern = RegExp(r'^\s*\[([^\]]+)\]:\s*(.+)', multiLine: true);
    final referenceDefs = referenceDefPattern.allMatches(content);
    final definedRefs = <String>{};
    
    for (final def in referenceDefs) {
      final refId = def.group(1)?.trim().toLowerCase() ?? '';
      if (refId.isNotEmpty) {
        definedRefs.add(refId);
      }
    }
    
    // Check if all reference links have definitions
    for (final match in referenceMatches) {
      final linkText = match.group(1) ?? '';
      var refId = match.group(2)?.trim().toLowerCase() ?? '';
      
      // If reference ID is empty, use the link text as reference ID
      if (refId.isEmpty) {
        refId = linkText.toLowerCase();
      }
      
      if (!definedRefs.contains(refId)) {
        issues.add('Undefined reference link: [${match.group(1)}][${match.group(2)}] - missing definition for "$refId"');
      }
    }
    
    // Check for unclosed link brackets
    final openBrackets = RegExp(r'\[').allMatches(content).length;
    final closeBrackets = RegExp(r'\]').allMatches(content).length;
    final openParens = RegExp(r'\]\(').allMatches(content).length;
    final closeParens = RegExp(r'\]\([^)]*\)').allMatches(content).length;
    
    if (openBrackets != closeBrackets) {
      issues.add('Mismatched link brackets: $openBrackets opening, $closeBrackets closing');
    }
    
    if (openParens != closeParens) {
      issues.add('Mismatched link parentheses after brackets');
    }
  }
  
  static void _validateHeaders(String content, List<String> issues, List<String> warnings) {
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Check for headers with missing space after #
      if (RegExp(r'^#{1,6}[^#\s]').hasMatch(line)) {
        warnings.add('Line ${i + 1}: Header missing space after # symbols: "$line"');
      }
      
      // Check for headers with too many # symbols
      if (RegExp(r'^#{7,}').hasMatch(line)) {
        issues.add('Line ${i + 1}: Invalid header level (more than 6 #): "$line"');
      }
    }
  }
}

/// Result of markdown validation
class MarkdownValidationResult {
  final bool isValid;
  final String filePath;
  final List<String> issues;
  final List<String> warnings;
  final int contentLength;
  
  const MarkdownValidationResult({
    required this.isValid,
    required this.filePath,
    required this.issues,
    required this.warnings,
    required this.contentLength,
  });
  
  /// Check if file has any issues or warnings
  bool get hasProblems => issues.isNotEmpty || warnings.isNotEmpty;
  
  /// Get a summary of validation results
  String getSummary() {
    if (!hasProblems) {
      return '✅ Valid markdown file';
    }
    
    final parts = <String>[];
    if (issues.isNotEmpty) {
      parts.add('${issues.length} critical issue${issues.length > 1 ? 's' : ''}');
    }
    if (warnings.isNotEmpty) {
      parts.add('${warnings.length} warning${warnings.length > 1 ? 's' : ''}');
    }
    
    return '⚠️ ${parts.join(', ')}';
  }
  
  /// Print detailed validation results
  void printDetails() {
    print('📋 Markdown validation for: $filePath');
    print('   File size: ${(contentLength / 1024).toStringAsFixed(1)} KB');
    print('   Status: ${getSummary()}');
    
    if (issues.isNotEmpty) {
      print('   🚫 Critical Issues:');
      for (final issue in issues) {
        print('      • $issue');
      }
    }
    
    if (warnings.isNotEmpty) {
      print('   ⚠️ Warnings:');
      for (final warning in warnings) {
        print('      • $warning');
      }
    }
    
    if (!hasProblems) {
      print('   ✅ No issues found - file is ready for translation');
    }
  }
}