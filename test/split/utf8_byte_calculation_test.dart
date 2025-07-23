import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:translator/markdown_spliter.dart';

void main() {
  group('MarkdownSplitter UTF-8 Byte Calculation Tests', () {
    test('should split test.md file with 20KB chunks using correct UTF-8 byte calculation', () async {
      // Load the actual test.md file
      final testFile = File('/Users/ulisses.hen/projects/translator/test/split/test.md');
      final content = await testFile.readAsString();
      
      // Test with 20KB limit
      const chunkSize = 20480; // 20KB
      final splitter = MarkdownSplitter(maxBytes: chunkSize);
      
      final chunks = splitter.splitMarkdown(content);
      
      final totalFileSize = utf8.encode(content).length;
      print('Total file size: $totalFileSize UTF-8 bytes');
      print('Chunk size limit: $chunkSize bytes (20KB)');
      print('Total chunks created: ${chunks.length}');
      print('Expected chunks (if perfectly split): ${(totalFileSize / chunkSize).ceil()}');
      print('');
      
      // Analyze each chunk - NO CHUNK should exceed 20KB unless it's a single oversized section
      bool foundProblematicChunk = false;
      
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        
        print('Chunk $i: ${chunk.utf8ByteSize} UTF-8 bytes (${chunk.type.name}, translatable: ${chunk.isTranslatable})');
        
        if (chunk.utf8ByteSize > chunkSize) {
          print('  ❌ EXCEEDS 20KB limit by ${chunk.utf8ByteSize - chunkSize} bytes!');
          
          // Check if this is a single section that's inherently oversized (acceptable)
          // or multiple sections incorrectly combined (not acceptable)
          final sectionHeaders = RegExp(r'^### ', multiLine: true).allMatches(chunk.content).length;
          final hasNonSectionContent = !chunk.content.trim().startsWith('###');
          
          if (hasNonSectionContent && sectionHeaders > 0) {
            // This chunk has both non-section content AND sections - this is the problem!
            print('  🚨 PROBLEM: Chunk contains non-section content + $sectionHeaders sections');
            print('  This means the algorithm combined pre-content with sections incorrectly');
            foundProblematicChunk = true;
          } else if (sectionHeaders == 1 && chunk.content.trim().startsWith('###')) {
            print('  ℹ️  Single oversized ### section (acceptable - cannot split within section)');
          } else if (sectionHeaders == 0 && hasNonSectionContent) {
            // Check if this contains a large code block or similar unsplittable content
            final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(chunk.content);
            int totalCodeSize = 0;
            for (final match in codeBlocks) {
              totalCodeSize += utf8.encode(match.group(0)!).length;
            }
            
            if (totalCodeSize > chunkSize * 0.8) { // If >80% is code
              print('  ℹ️  Large code block content (${totalCodeSize} bytes code) - cannot split code');
            } else {
              print('  ℹ️  Pre-section content only - could potentially be split further');
            }
          } else if (sectionHeaders > 1) {
            print('  🚨 PROBLEM: Multiple ### sections combined in oversized chunk ($sectionHeaders sections)');
            foundProblematicChunk = true;
          } else {
            print('  🚨 UNKNOWN: Unexpected chunk structure');
            foundProblematicChunk = true;
          }
        } else {
          print('  ✅ Within 20KB limit');
        }
        print('');
      }
      
      // With enhanced splitting algorithm, we should have much better chunk sizes
      // Only single inherently oversized sections should exceed the limit now
      expect(foundProblematicChunk, isFalse,
          reason: 'MarkdownSplitter should now split at both ### and ## headers to avoid oversized chunks. '
                 'Only individual oversized sections that cannot be split further should exceed the limit.');
      
      // Verify content integrity
      final recombined = chunks.map((c) => c.content).join('');
      expect(recombined.trim(), equals(content.trim()),
          reason: 'Content should be preserved after splitting');
    });
  });
}