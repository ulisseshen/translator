import 'package:test/test.dart';
import '../bin/src/markdown_structure_validator.dart';

void main() {
  group('MarkdownStructureValidator High-Level Structure Tests', () {
    test('extracts high-level structural elements only', () {
      const markdown = '''
# Main Title
This is a paragraph with **bold text** and *italic text*.

## Section Header
Another paragraph with different content.

### Subsection
- First item
- Second item with [link](https://example.com)
- Third item

#### Code Section
```dart
void main() {
  print('Hello, world!');
}
```

> This is a blockquote with various content.
> It can span multiple lines.

| Column 1 | Column 2 |
|----------|----------|
| Data 1   | Data 2   |
| Data 3   | Data 4   |

---
''';

      final structure = MarkdownStructureValidator.extractStructure(markdown);
      
      // Should only contain high-level structural elements
      expect(structure, contains('h1'));
      expect(structure, contains('h2'));
      expect(structure, contains('h3'));
      expect(structure, contains('h4'));
      expect(structure, contains('ul(3)')); // List with 3 items
      expect(structure, contains('pre'));
      expect(structure, contains('blockquote'));
      expect(structure, contains('hr'));
      
      // Should NOT contain paragraph content or inline formatting
      expect(structure, isNot(contains('p')));
      expect(structure, isNot(contains('strong')));
      expect(structure, isNot(contains('em')));
      expect(structure, isNot(contains('a')));
    });

    test('validates identical high-level structure passes', () {
      const originalMarkdown = '''
# Flutter Guide
## Getting Started
- Install Flutter
- Set up IDE

### First App
```dart
void main() => runApp(MyApp());
```

> Remember to test your code!
''';

      const translatedMarkdown = '''
# Guia do Flutter
## Começando
- Instale o Flutter
- Configure o IDE

### Primeiro App
```dart
void main() => runApp(MyApp());
```

> Lembre-se de testar seu código!
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        originalMarkdown,
        translatedMarkdown,
      );

      expect(isValid, isTrue);
    });

    test('detects missing headers', () {
      const original = '''
# Main Title
## Subtitle
### Subsubtitle
Content here
''';

      const broken = '''
Main Title
Subtitle
Subsubtitle
Content here
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse);
    });

    test('detects missing list structure', () {
      const original = '''
# Instructions
- Step 1
- Step 2
  - Nested item
- Step 3
''';

      const broken = '''
# Instructions
Step 1
Step 2
Nested item
Step 3
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse);
    });

    test('detects missing code blocks', () {
      const original = '''
# Code Example
```dart
void main() {
  print('Hello');
}
```
''';

      const broken = '''
# Code Example
void main() {
  print('Hello');
}
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse);
    });

    test('detects missing blockquotes', () {
      const original = '''
# Important Note
> This is a critical warning
> Please pay attention
''';

      const broken = '''
# Important Note
This is a critical warning
Please pay attention
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse);
    });

    test('ignores paragraph content changes', () {
      const originalMarkdown = '''
# Flutter Widgets
This is a detailed explanation about Flutter widgets and how they work.
The paragraph contains technical terms and specific examples.

## State Management
Another paragraph with completely different content about state management.
''';

      const translatedMarkdown = '''
# Widgets do Flutter
Esta é uma explicação detalhada sobre widgets do Flutter e como funcionam.
O parágrafo contém termos técnicos e exemplos específicos.

## Gerenciamento de Estado
Outro parágrafo com conteúdo completamente diferente sobre gerenciamento de estado.
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        originalMarkdown,
        translatedMarkdown,
      );

      expect(isValid, isTrue, reason: 'Paragraph content changes should be ignored');
    });

    test('handles complex nested structures correctly', () {
      const markdown = '''
# Main Document
## Section 1
### Subsection A
- Item 1
- Item 2
  - Nested item 1
  - Nested item 2

### Subsection B
1. Ordered item 1
2. Ordered item 2

## Section 2
```python
def hello():
    print("Hello World")
```

> Important note about the code above

### Tables
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |

---

#### Final Section
Another paragraph here.
''';

      final structure = MarkdownStructureValidator.extractStructure(markdown);
      
      // Verify we capture nested structures appropriately
      expect(structure, contains('h1'));
      expect(structure, contains('h2'));
      expect(structure, contains('h3'));
      expect(structure, contains('h4'));
      expect(structure, contains('ul(2)')); // Main list with 2 items
      expect(structure, contains('ol(2)')); // Ordered list with 2 items
      expect(structure, contains('pre'));
      expect(structure, contains('blockquote'));
      expect(structure, contains('hr'));
    });

    test('handles empty and minimal markdown', () {
      const emptyMarkdown = '';
      final emptyStructure = MarkdownStructureValidator.extractStructure(emptyMarkdown);
      expect(emptyStructure, isEmpty);

      const minimalMarkdown = 'Just a paragraph with no structure.';
      final minimalStructure = MarkdownStructureValidator.extractStructure(minimalMarkdown);
      expect(minimalStructure, isEmpty);

      // Both should validate as consistent (both have no structure)
      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        emptyMarkdown,
        minimalMarkdown,
      );
      expect(isValid, isTrue);
    });

    test('detects incorrect list item counts', () {
      const original = '''
# Shopping List
- Apples
- Bananas
- Oranges
- Grapes
''';

      const broken = '''
# Shopping List
- Apples
- Bananas
- Oranges
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse, reason: 'Different number of list items should be detected');
    });

    test('handles mixed list types correctly', () {
      const markdown = '''
# Mixed Lists
## Unordered
- First item
- Second item

## Ordered  
1. First step
2. Second step
3. Third step

## Nested
- Main item 1
  1. Sub-item 1
  2. Sub-item 2
- Main item 2
''';

      final structure = MarkdownStructureValidator.extractStructure(markdown);
      
      expect(structure, contains('ul(2)')); // First unordered list
      expect(structure, contains('ol(3)')); // Ordered list with 3 items
      // Note: Nested structures might be captured differently depending on markdown parser
    });
  });
}