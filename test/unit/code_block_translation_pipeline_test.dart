import 'package:test/test.dart';
import '../../lib/code_block_translation_pipeline.dart';

void main() {
  group('CodeBlockTranslationPipeline', () {
    late CodeBlockTranslationPipeline pipeline;

    setUp(() {
      pipeline = CodeBlockTranslationPipeline();
    });

    group('Basic Translation', () {
      test('should translate simple content without code blocks', () async {
        const originalContent = '''
# Simple Document

This is a simple document without any code blocks.

## Section 1

Some content here.

## Section 2

More content here.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            return content
                .replaceAll('Simple Document', 'Documento Simples')
                .replaceAll('This is a simple document', 'Este é um documento simples')
                .replaceAll('without any code blocks', 'sem blocos de código')
                .replaceAll('Section 1', 'Seção 1')
                .replaceAll('Some content here', 'Algum conteúdo aqui')
                .replaceAll('Section 2', 'Seção 2')
                .replaceAll('More content here', 'Mais conteúdo aqui');
          },
        );

        expect(result.translatedContent, contains('Documento Simples'));
        expect(result.translatedContent, contains('Este é um documento simples'));
        expect(result.translatedContent, contains('sem blocos de código'));
        expect(result.translatedContent, contains('Seção 1'));
        expect(result.translatedContent, contains('Algum conteúdo aqui'));
        expect(result.extractedCodeBlocks, isEmpty);
        expect(result.stats.totalCodeBlocksExtracted, equals(0));
      });

      test('should preserve fenced code blocks during translation', () async {
        const originalContent = '''
# Code Example

Here's how to use the function:

```dart
void main() {
  print('Hello World');
}
```

That's the basic usage.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            return content
                .replaceAll('Code Example', 'Exemplo de Código')
                .replaceAll('Here\'s how to use the function:', 'Aqui está como usar a função:')
                .replaceAll('That\'s the basic usage.', 'Esse é o uso básico.');
          },
        );

        expect(result.stats.totalCodeBlocksExtracted, equals(1));
      });

      test('should ignore inline code blocks during translation', () async {
        const originalContent = '''
# API Usage

Use the `getData()` function to retrieve information.

Call `processData()` with the result.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            return content
                .replaceAll('API Usage', 'Uso da API')
                .replaceAll('Use the', 'Use a')
                .replaceAll('function to retrieve information', 'função para recuperar informações')
                .replaceAll('Call', 'Chame')
                .replaceAll('with the result', 'com o resultado');
          },
        );
        expect(result.stats.totalCodeBlocksExtracted, equals(0));
      });

      test('should handle mixed fenced and inline code blocks', () async {
        const originalContent = '''
# Mixed Code Example

First, call `init()`:

```dart
void init() {
  print('Initializing...');
}
```

Then use `start()` to begin.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            return content
                .replaceAll('Mixed Code Example', 'Exemplo de Código Misto')
                .replaceAll('First, call', 'Primeiro, chame')
                .replaceAll('Then use', 'Então use')
                .replaceAll('to begin', 'para começar');
          },
        );

        expect(result.translatedContent, contains('Exemplo de Código Misto'));
        expect(result.translatedContent, contains('Primeiro, chame `init()`:'));
        expect(result.translatedContent, contains('```dart'));
        expect(result.translatedContent, contains('void init() {'));
        expect(result.translatedContent, contains('Então use `start()` para começar'));
        expect(result.extractedCodeBlocks, hasLength(1));
      });
    });

    group('Chunking and Large Content', () {
      test('should handle content that requires chunking', () async {
        final largeContent = StringBuffer();
        largeContent.writeln('# Large Document');
        
        for (int i = 1; i <= 100; i++) {
          largeContent.writeln('## Section $i');
          largeContent.writeln('This is content for section $i with some text.');
          largeContent.writeln('');
        }

        final result = await pipeline.translateContent(
          originalContent: largeContent.toString(),
          maxBytes: 1000, // Force chunking
          translator: (content) async {
            return content
                .replaceAll('Large Document', 'Documento Grande')
                .replaceAll('Section', 'Seção')
                .replaceAll('This is content for section', 'Este é o conteúdo da seção')
                .replaceAll('with some text', 'com algum texto');
          },
        );

        expect(result.translatedContent, contains('Documento Grande'));
        expect(result.translatedContent, contains('Seção 1'));
        expect(result.translatedContent, contains('Seção 100'));
        expect(result.translatedContent, contains('Este é o conteúdo da seção'));
        expect(result.processedChunks.length, greaterThan(1));
        expect(result.stats.totalChunks, greaterThan(1));
      });
    });

    group('Parallel Translation', () {
      test('should translate content in parallel', () async {
        const originalContent = '''
# Parallel Test

## Section A
Content A that needs translation.

## Section B  
Content B that needs translation.

## Section C
Content C that needs translation.
''';

        int translationCallCount = 0;
        final result = await pipeline.translateContentParallel(
          originalContent: originalContent,
          maxBytes: 100, // Force multiple chunks
          maxConcurrency: 2,
          translator: (content) async {
            translationCallCount++;
            // Simulate some processing time
            await Future.delayed(Duration(milliseconds: 10));
            
            return content
                .replaceAll('Parallel Test', 'Teste Paralelo')
                .replaceAll('Section A', 'Seção A')
                .replaceAll('Section B', 'Seção B')
                .replaceAll('Section C', 'Seção C')
                .replaceAll('Content A that needs translation', 'Conteúdo A que precisa de tradução')
                .replaceAll('Content B that needs translation', 'Conteúdo B que precisa de tradução')
                .replaceAll('Content C that needs translation', 'Conteúdo C que precisa de tradução');
          },
        );

        expect(result.translatedContent, contains('Teste Paralelo'));
        expect(result.translatedContent, contains('Seção A'));
        expect(result.translatedContent, contains('Seção B'));
        expect(result.translatedContent, contains('Seção C'));
        expect(result.translatedContent, contains('Conteúdo A que precisa'));
        expect(translationCallCount, greaterThan(1)); // Should have been chunked
      });

      test('should handle translation errors gracefully in parallel mode', () async {
        const originalContent = '''
# Error Test

## Good Section
This content translates fine.

## Bad Section
This content will cause an error.

## Another Good Section
This content also translates fine.
''';

        final result = await pipeline.translateContentParallel(
          originalContent: originalContent,
          maxBytes: 100, // Force chunking
          translator: (content) async {
            if (content.contains('will cause an error')) {
              throw Exception('Translation failed');
            }
            
            return content
                .replaceAll('Error Test', 'Teste de Erro')
                .replaceAll('Good Section', 'Seção Boa')
                .replaceAll('This content translates fine', 'Este conteúdo traduz bem')
                .replaceAll('Another Good Section', 'Outra Seção Boa')
                .replaceAll('Another', 'Outra') // Add this for partial matches
                .replaceAll('This content also translates fine', 'Este conteúdo também traduz bem');
          },
        );

        expect(result.translatedContent, contains('Teste de Erro'));
        expect(result.translatedContent, contains('Seção Boa'));
        expect(result.translatedContent, contains('Este conteúdo traduz bem'));
        expect(result.translatedContent, contains('Outra Seção Boa'));
        // Error chunk should remain untranslated
        expect(result.translatedContent, contains('This content will cause an error'));
      });

      test('should report progress during parallel translation', () async {
        const originalContent = '''
# Progress Test

## Section 1
Content 1

## Section 2  
Content 2

## Section 3
Content 3
''';

        final progressUpdates = <String>[];
        
        final result = await pipeline.translateContentParallel(
          originalContent: originalContent,
          maxBytes: 50, // Force multiple chunks
          translator: (content) async {
            await Future.delayed(Duration(milliseconds: 10));
            return content.replaceAll('Content', 'Conteúdo');
          },
          progressCallback: (completed, total) {
            progressUpdates.add('$completed/$total');
          },
        );

        expect(result.translatedContent, contains('Conteúdo 1'));
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last, endsWith('/${result.processedChunks.length}'));
      });
    });

    group('Statistics and Validation', () {
      test('should provide comprehensive statistics', () async {
        const originalContent = '''
# Statistics Test

Use `function()` here:

```dart
void function() {
  print('test');
}
```

And `another()` there.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async => content.replaceAll('Statistics Test', 'Teste de Estatísticas'),
        );

        final stats = result.stats;
        
        expect(stats.originalContentBytes, isA<int>());
        expect(stats.totalCodeBlocksExtracted, equals(1));
        expect(stats.totalChunks, isA<int>());
        expect(stats.processingTimeMs, isA<int>());
        expect(stats.processingTimeSeconds, isA<int>());
        expect(stats.bytesPerSecond, isA<double>());
        expect(stats.codeBlocksRestored, equals(1));
        expect(stats.restorationSuccess, isTrue);
      });

      test('should validate pipeline configuration', () {
        
        final componentInfo = pipeline.getComponentInfo();
        expect(componentInfo['extractor'], isNotNull);
        expect(componentInfo['splitter'], isNotNull);
        expect(componentInfo['restorer'], isNotNull);
      });

      test('should detect restoration failures in statistics', () async {
        const originalContent = '''
# Test Document

Here is some `inline code` example.

```dart
void function() {
  print('test');
}
```

More text with `another()` call.
''';

        // Mock a translator that removes anchors, simulating a translation that loses them
        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            // Remove all anchors, simulating a translation that loses them
            return content
                .replaceAll(RegExp(r'__CODE_BLOCK_ANCHOR_\d+__'), 'MISSING_CODE')
                .replaceAll('Test Document', 'Documento de Teste');
          },
        );

        // The final content should still contain the missing anchor patterns
        // because restoration can't happen without proper anchors
        expect(result.translatedContent, contains('MISSING_CODE'));
        expect(result.stats.restorationSuccess, isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty content', () async {
        const originalContent = '';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async => content,
        );

        expect(result.translatedContent, equals(''));
        expect(result.extractedCodeBlocks, isEmpty);
        expect(result.processedChunks, isEmpty);
        expect(result.stats.totalCodeBlocksExtracted, equals(0));
      });

      test('should handle content with only whitespace', () async {
        const originalContent = '   \n\n\t  ';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async => content,
        );

        expect(result.translatedContent, equals(originalContent));
        expect(result.extractedCodeBlocks, isEmpty);
        expect(result.processedChunks, hasLength(1));
      });

      test('should handle content with only code blocks', () async {
        const originalContent = '''
```dart
void main() {
  print('Hello');
}
```

```python
print("World")
```
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async => content, // No actual translation needed
        );

        expect(result.translatedContent, contains('void main()'));
        expect(result.translatedContent, contains('print("World")'));
        expect(result.extractedCodeBlocks, hasLength(2));
      });

      test('should handle malformed code blocks gracefully', () async {
        const originalContent = '''
# Malformed Test

```dart
// Missing closing fence
void incomplete() {

More text here.
''';

        final result = await pipeline.translateContent(
          originalContent: originalContent,
          translator: (content) async {
            return content.replaceAll('Malformed Test', 'Teste Malformado');
          },
        );

        expect(result.translatedContent, contains('Teste Malformado'));
        expect(result.translatedContent, isNotNull);
        // Should not crash, even with malformed input
      });
    });

    group('Performance', () {
      test('should handle large documents efficiently', () async {
        final largeContent = StringBuffer();
        largeContent.writeln('# Performance Test');
        
        // Create a document with 500 sections
        for (int i = 1; i <= 500; i++) {
          largeContent.writeln('## Section $i');
          largeContent.writeln('Content for section $i with `code$i` example.');
          if (i % 10 == 0) {
            largeContent.writeln('```dart');
            largeContent.writeln('void section$i() {');
            largeContent.writeln('  print("Section $i");');
            largeContent.writeln('}');
            largeContent.writeln('```');
          }
          largeContent.writeln('');
        }

        final stopwatch = Stopwatch()..start();
        
        final result = await pipeline.translateContentParallel(
          originalContent: largeContent.toString(),
          maxConcurrency: 5,
          translator: (content) async {
            // Simulate translation work
            await Future.delayed(Duration(milliseconds: 1));
            return content.replaceAll('Performance Test', 'Teste de Performance');
          },
        );
        
        stopwatch.stop();

        expect(result.translatedContent, contains('Teste de Performance'));
        expect(result.extractedCodeBlocks.length, equals(50)); 
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
        expect(result.stats.processingTimeMs, isA<int>());
      });
    });
  });
}