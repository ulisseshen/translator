import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:translator/markdown_spliter.dart';

void main() {
  group('MarkdownSplitter - 20KB Chunk Size Limit', () {
    test('should not exceed 20KB limit when splitting release-notes-2.8.0.md', () async {
      // Setup: Read the large test file
      const filePath = 'test/links/inputs/release-notes-2.8.0.md';
      final file = File(filePath);
      
      expect(file.existsSync(), isTrue, reason: 'Test file should exist');
      
      final content = await file.readAsString();
      final splitter = MarkdownSplitter(maxBytes: 20480); // 20KB default
      
      // Act: Split the content
      final chunks = splitter.splitMarkdown(content);
      
      // Assert: No chunk should exceed 20KB
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        expect(chunk.utf8ByteSize, lessThanOrEqualTo(20480),
            reason: 'Chunk $i should not exceed 20KB limit (actual: ${chunk.utf8ByteSize} bytes)');
      }
      
      // Verify content integrity
      final recombined = splitter.getEnterily(chunks);
      expect(recombined, equals(content), 
          reason: 'Recombined content should match original');
      
      // Log statistics for verification
      print('File size: ${utf8.encode(content).length} bytes (${(utf8.encode(content).length / 1024).toStringAsFixed(2)} KB)');
      print('Number of chunks: ${chunks.length}');
      print('Chunk sizes (bytes): ${chunks.map((c) => c.utf8ByteSize).join(', ')}');
      print('Largest chunk: ${chunks.map((c) => c.utf8ByteSize).reduce((a, b) => a > b ? a : b)} bytes');
    });

    test('should handle custom chunk size limits correctly', () async {
      const filePath = 'test/links/inputs/release-notes-2.8.0.md';
      final file = File(filePath);
      final content = await file.readAsString();
      
      // Test with smaller 10KB limit
      final splitter10KB = MarkdownSplitter(maxBytes: 10240);
      final chunks10KB = splitter10KB.splitMarkdown(content);
      
      for (int i = 0; i < chunks10KB.length; i++) {
        final chunk = chunks10KB[i];
        expect(chunk.utf8ByteSize, lessThanOrEqualTo(10240),
            reason: 'Chunk $i should not exceed 10KB limit (actual: ${chunk.utf8ByteSize} bytes)\ninto file ${file.path}');
      }
      
      // Test with larger 50KB limit
      final splitter50KB = MarkdownSplitter(maxBytes: 51200);
      final chunks50KB = splitter50KB.splitMarkdown(content);
      
      for (int i = 0; i < chunks50KB.length; i++) {
        final chunk = chunks50KB[i];
        expect(chunk.utf8ByteSize, lessThanOrEqualTo(51200),
            reason: 'Chunk $i should not exceed 50KB limit (actual: ${chunk.utf8ByteSize} bytes)');
      }
      
      // Smaller limit should create more chunks
      expect(chunks10KB.length, greaterThan(chunks50KB.length),
          reason: 'Smaller chunk limit should result in more chunks');
    });

    test('should properly calculate UTF-8 byte sizes vs code unit sizes', () async {
      const filePath = 'test/links/inputs/release-notes-2.8.0.md';
      final file = File(filePath);
      final content = await file.readAsString();
      final splitter = MarkdownSplitter(maxBytes: 20480);
      
      final chunks = splitter.splitMarkdown(content);
      
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        
        // Verify UTF-8 byte size calculation is accurate
        final actualUtf8Bytes = utf8.encode(chunk.content).length;
        expect(chunk.utf8ByteSize, equals(actualUtf8Bytes),
            reason: 'Chunk $i UTF-8 byte size should be accurately calculated');
        
        // Verify code units calculation is accurate
        final actualCodeUnits = chunk.content.codeUnits.length;
        expect(chunk.codeUnitsSize, equals(actualCodeUnits),
            reason: 'Chunk $i code units size should be accurately calculated');
        
        // UTF-8 bytes should be >= code units for content with multi-byte chars
        expect(chunk.utf8ByteSize, greaterThanOrEqualTo(chunk.codeUnitsSize),
            reason: 'UTF-8 byte size should be >= code units size');
      }
    });
  });
}