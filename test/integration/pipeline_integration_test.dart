import 'package:test/test.dart';
import 'package:translator/code_block_translation_pipeline.dart';

void main() {
  group('Pipeline Integration Tests', () {
    

    test('should demonstrate adapter components without external dependencies', () async {
      // Test that the adapter can be created and provides valid component info
      // This test doesn't use the actual translator to avoid dependencies
      
      final pipeline = CodeBlockTranslationPipeline();
      
      final componentInfo = pipeline.getComponentInfo();
      expect(componentInfo['extractor'], isNotNull);
      expect(componentInfo['splitter'], isNotNull);
      expect(componentInfo['restorer'], isNotNull);
      
      print('\n=== Pipeline Components ===');
      print('Extractor: ${componentInfo['extractor']}');
      print('Splitter: ${componentInfo['splitter']}');
      print('Restorer: ${componentInfo['restorer']}');
    });

    test('should handle parallel processing with error recovery', () async {
      final pipeline = CodeBlockTranslationPipeline();

      const content = '''
# Error Test

## Good Section
This section translates fine.

## Problem Section  
This will cause an error during translation.

## Another Good Section
This section also translates fine.
''';

      int translationAttempts = 0;
      final result = await pipeline.translateContentParallel(
        originalContent: content,
        maxConcurrency: 2,
        maxBytes: 100, // Force chunking
        translator: (chunkContent) async {
          translationAttempts++;
          
          // Simulate error for specific content
          if (chunkContent.contains('This will cause an error')) {
            throw Exception('Mock translation error');
          }
          
          return chunkContent
              .replaceAll('Error Test', 'Teste de Erro')
              .replaceAll('Good Section', 'Seção Boa')
              .replaceAll('Another Good Section', 'Outra Seção Boa')
              .replaceAll('Another', 'Outra') // Handle partial matches
              .replaceAll('This section translates fine', 'Esta seção traduz bem')
              .replaceAll('This section also translates fine', 'Esta seção também traduz bem');
        },
      );

      // Should have attempted translation multiple times (for multiple chunks)
      expect(translationAttempts, greaterThan(1));

      // Successful translations should work
      expect(result.translatedContent, contains('Teste de Erro'));
      expect(result.translatedContent, contains('Seção Boa'));
      expect(result.translatedContent, contains('Esta seção traduz bem'));
      expect(result.translatedContent, contains('Outra Seção Boa'));

      // Failed chunk should remain in original language
      expect(result.translatedContent, contains('This will cause an error'));

      // Pipeline should still report success overall
      expect(result.stats.restorationSuccess, isTrue);
    });
  });
}

// Mock translator removed since it doesn't match the actual interface
// The integration tests focus on the pipeline components instead