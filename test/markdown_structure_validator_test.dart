import 'package:test/test.dart';
import '../bin/src/markdown_structure_validator.dart';

void main() {
  group('MarkdownStructureValidator Header Counting Tests', () {
    test('counts only headers in markdown', () {
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

      final headers = MarkdownStructureValidator.countHeaders(markdown);
      expect(headers, equals(4));
    });

    test('validates identical header structure passes', () {
      const originalMarkdown = '''
# Flutter Guide
## Getting Started
### First App
''';

      const translatedMarkdown = '''
# Guia do Flutter
## Começando
### Primeiro App
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

    test('detects missing header structure', () {
      const original = '''
# Instructions
## Final Steps
''';

      const broken = '''
# Instructions
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        original,
        broken,
      );

      expect(isValid, isFalse);
    });

    // Removed test for code blocks, as only headers are validated.

    // Removed test for blockquotes, as only headers are validated.

    test('ignores paragraph content changes', () {
      const originalMarkdown = '''
# Flutter Widgets
## State Management
''';

      const translatedMarkdown = '''
# Widgets do Flutter
## Gerenciamento de Estado
''';

      final isValid = MarkdownStructureValidator.validateStructureConsistency(
        originalMarkdown,
        translatedMarkdown,
      );

      expect(isValid, isTrue, reason: 'Paragraph content changes should be ignored');
    });

    test('counts all headers in complex markdown', () {
      const markdown = '''
# Main Document
## Section 1
### Subsection A
### Subsection B
## Section 2
### Tables
#### Final Section
''';

      final headers = MarkdownStructureValidator.countHeaders(markdown);
      expect(headers, equals(7), reason: 'Should count all headers correctly');
    });

    test('handles empty and minimal markdown', () {
      const emptyMarkdown = '';
      final emptyHeaders = MarkdownStructureValidator.countHeaders(emptyMarkdown);
      expect(emptyHeaders, isZero);

      const minimalMarkdown = 'Just a paragraph with no structure.';
      final minimalHeaders = MarkdownStructureValidator.countHeaders(minimalMarkdown);
      expect(minimalHeaders, isZero);
    });

    // Removed test for list item counts, as only headers are validated.

    // Removed test for mixed list types, as countHeaders now only counts headers.
  });
}