import 'package:test/test.dart';
import 'dart:io';
import '../../bin/src/markdown_link_validator.dart';

void main() {
  group('MarkdownLinkValidator comprehensive tests', () {
    late List<File> inputFiles;
    
    setUpAll(() async {
      // Load all markdown files from the inputs folder
      final inputsDir = Directory('/Users/ulisses.hen/projects/translator/test/links/inputs');
      inputFiles = inputsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .toList();
      
      print('Found ${inputFiles.length} markdown files to test:');
      for (final file in inputFiles) {
        print('  - ${file.path.split('/').last}');
      }
    });

    test('should validate all reference links in files inside input folder', () async {
      for (final file in inputFiles) {
        final fileName = file.path.split('/').last;
        final content = await file.readAsString();
        
        // Test that the content has valid reference links
        final result = MarkdownLinkValidator.validateReferenceLinksDetailed(content, content);
        
        expect(result.isValid, isTrue, 
          reason: 'File "$fileName" should have valid reference links structure. Issues: ${result.issues}');
        
        // Verify that reference links were found (if any exist)
        if (result.originalInfo.references.isNotEmpty) {
          expect(result.originalInfo.definitions.isNotEmpty, isTrue,
            reason: 'File "$fileName" should contain link definitions for its references');
        }
        
        print('✅ $fileName: ${result.originalInfo.references.length} reference links, ${result.originalInfo.definitions.length} definitions');
      }
    });

    test('should detect broken references when definitions are missing', () async {
      // Use the first input file for this test
      final content = await inputFiles.first.readAsString();
      final fileName = inputFiles.first.path.split('/').last;
      
      // Create content with a broken reference by removing all definitions
      String brokenContent = content.replaceAll(RegExp(r'^\s*\[([^\]]+)\]:\s*.+$', multiLine: true), '');
      
      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(content, brokenContent);
      
      expect(result.isValid, isFalse,
        reason: 'File "$fileName" content with missing definitions should be invalid');
      expect(result.issues.isNotEmpty, isTrue,
        reason: 'File "$fileName" should report broken references as issues');
    });

    test('should handle missing reference links gracefully', () async {
      // Use the first input file for this test
      final content = await inputFiles.first.readAsString();
      final fileName = inputFiles.first.path.split('/').last;
      
      // Create content with no reference links
      String noRefsContent = content.replaceAll(RegExp(r'\[([^\[\]]+)\]\[([^\[\]]*)\]'), r'\1');
      
      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(content, noRefsContent);
      
      // This should be valid (no broken references) but might have warnings
      expect(result.isValid, isTrue,
        reason: 'File "$fileName" content without reference links should be valid');
      expect(result.translatedInfo.references.isEmpty, isTrue,
        reason: 'File "$fileName" should have no references after removal');
    });

    test('should find invalid reference patterns using findInvalidReferences', () async {
      // Test the findInvalidReferences method on all input files
      for (final file in inputFiles) {
        final fileName = file.path.split('/').last;
        final content = await file.readAsString();
        final invalidRefs = MarkdownLinkValidator.findInvalidReferences(content);
        
        // The input should not have invalid references if it's well-formed
        expect(invalidRefs.isEmpty, isTrue,
          reason: 'File "$fileName" should not have invalid reference patterns. Found: $invalidRefs');
      }
    });

    test('should extract reference information correctly from input files', () async {
      // Test the internal extraction logic on all input files
      for (final file in inputFiles) {
        final fileName = file.path.split('/').last;
        final content = await file.readAsString();
        final info = MarkdownLinkValidator.validateReferenceLinksDetailed(content, content).originalInfo;
        
        // Print some examples for debugging
        print('$fileName - Sample references: ${info.references.take(5).toList()}');
        print('$fileName - Sample definitions: ${info.definitions.keys.take(5).toList()}');
        
        // If references exist, verify each has a corresponding definition
        for (final ref in info.references) {
          expect(info.definitions.containsKey(ref), isTrue,
            reason: 'File "$fileName" - Reference "$ref" should have a definition');
        }
      }
    });


  });
}