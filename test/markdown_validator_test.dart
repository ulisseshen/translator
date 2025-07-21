import 'package:test/test.dart';
import '../bin/src/markdown_validator.dart';

void main() {
  group('MarkdownValidator', () {
    group('Valid Markdown Tests', () {
      test('should pass validation for simple valid markdown', () {
        const validMarkdown = '''# Title

This is a paragraph with **bold** and *italic* text.

## Section

- List item 1
- List item 2

[Link text](https://example.com)

```dart
print('Hello World');
```
''';

        final result = MarkdownValidator.validateMarkdown(validMarkdown, 'test.md');
        
        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
        expect(result.hasProblems, isFalse);
        expect(result.getSummary(), contains('Valid markdown'));
      });

      test('should pass validation for complex valid markdown', () {
        const complexMarkdown = '''---
title: Complex Document
---

# Main Title

This document contains various markdown elements.

## Headers and Content

### Level 3 Header

#### Level 4 Header

##### Level 5 Header

###### Level 6 Header

## Links and References

Here's an [inline link](https://example.com) and another [link with title](https://example.com "Title").

Reference-style links work too: [Reference link][1].

[1]: https://example.com

## Code Examples

Inline `code` works fine.

```javascript
function hello() {
    console.log("Hello, world!");
}
```

## Lists

- Unordered list item
- Another item
  - Nested item
  - Another nested item

1. Ordered list
2. Second item
3. Third item

## Emphasis

*Italic text* and **bold text** and ***both***.

## Tables

| Column 1 | Column 2 |
|----------|----------|
| Cell 1   | Cell 2   |
''';

        final result = MarkdownValidator.validateMarkdown(complexMarkdown, 'complex.md');
        
        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });
    });

    group('Invalid Markdown Tests', () {
      test('should fail validation for empty content', () {
        const emptyMarkdown = '';
        
        final result = MarkdownValidator.validateMarkdown(emptyMarkdown, 'empty.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains('File is empty or contains only whitespace'));
      });

      // Code block validation removed - focusing only on links and headers

      test('should fail validation for mismatched link brackets', () {
        const invalidMarkdown = '''# Title

This has [mismatched brackets and [another one](http://example.com).

[Another unmatched bracket here.
''';
        
        final result = MarkdownValidator.validateMarkdown(invalidMarkdown, 'bad_links.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains(contains('Mismatched link brackets')));
      });

      test('should fail validation for invalid header levels', () {
        const invalidMarkdown = '''# Valid Header

####### Invalid Header (7 levels)

Normal content.
''';
        
        final result = MarkdownValidator.validateMarkdown(invalidMarkdown, 'bad_headers.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains(contains('Invalid header level')));
      });

      test('should fail validation for mismatched link parentheses', () {
        const invalidMarkdown = '''# Title

[Link with missing closing paren](http://example.com

[Another link](http://example.com)
''';
        
        final result = MarkdownValidator.validateMarkdown(invalidMarkdown, 'bad_parens.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains(contains('Mismatched link parentheses')));
      });

      test('should fail validation for undefined reference links', () {
        const invalidMarkdown = '''# Title

Here's a [valid inline link](http://example.com).

Here's a [broken reference link][missing-ref] with no definition.

Here's a [working reference link][1].

[1]: http://example.com

Here's [another broken][undefined] reference.
''';
        
        final result = MarkdownValidator.validateMarkdown(invalidMarkdown, 'bad_refs.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains(contains('Undefined reference link')));
        expect(result.issues, contains(contains('missing-ref')));
        expect(result.issues, contains(contains('undefined')));
      });
    });

    group('Warning Tests', () {
      test('should generate warnings for headers without space', () {
        const warningMarkdown = '''#Title Without Space

##Another Bad Header

### Good Header

Normal content.
''';
        
        final result = MarkdownValidator.validateMarkdown(warningMarkdown, 'header_warnings.md');
        
        expect(result.isValid, isTrue); // Warnings don't make it invalid
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((w) => w.contains('Header missing space')), isTrue);
        expect(result.hasProblems, isTrue); // Has warnings
      });

      test('should generate warnings for empty links', () {
        const warningMarkdown = '''# Title

[Empty link text]() and [](http://example.com) are both problematic.

[Good link](http://example.com) is fine.
''';
        
        final result = MarkdownValidator.validateMarkdown(warningMarkdown, 'empty_links.md');
        
        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((w) => w.contains('Empty link')), isTrue);
      });

      // List validation removed - focusing only on links and headers

      test('should generate warnings for extremely long lines', () {
        final longLine = 'a' * 6000;
        final warningMarkdown = '''# Title

Normal line.

$longLine

Another normal line.
''';
        
        final result = MarkdownValidator.validateMarkdown(warningMarkdown, 'long_lines.md');
        
        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((w) => w.contains('extremely long')), isTrue);
      });
    });

    group('MarkdownValidationResult Tests', () {
      test('should provide correct summary for valid file', () {
        final result = MarkdownValidationResult(
          isValid: true,
          filePath: 'test.md',
          issues: [],
          warnings: [],
          contentLength: 100,
        );
        
        expect(result.getSummary(), contains('Valid markdown'));
        expect(result.hasProblems, isFalse);
      });

      test('should provide correct summary for file with issues', () {
        final result = MarkdownValidationResult(
          isValid: false,
          filePath: 'test.md',
          issues: ['Issue 1', 'Issue 2'],
          warnings: ['Warning 1'],
          contentLength: 100,
        );
        
        expect(result.getSummary(), contains('2 critical issues'));
        expect(result.getSummary(), contains('1 warning'));
        expect(result.hasProblems, isTrue);
      });

      test('should provide correct summary for file with only warnings', () {
        final result = MarkdownValidationResult(
          isValid: true,
          filePath: 'test.md',
          issues: [],
          warnings: ['Warning 1', 'Warning 2', 'Warning 3'],
          contentLength: 100,
        );
        
        expect(result.getSummary(), contains('3 warnings'));
        expect(result.getSummary(), isNot(contains('critical issue')));
        expect(result.hasProblems, isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle markdown with only whitespace', () {
        const whitespaceMarkdown = '   \n\t  \n   ';
        
        final result = MarkdownValidator.validateMarkdown(whitespaceMarkdown, 'whitespace.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues, contains('File is empty or contains only whitespace'));
      });

      test('should handle valid markdown with links and headers', () {
        const validMarkdown = '''# Main Title

## Section Header

Here's an [inline link](https://example.com) and a [reference link][1].

### Subsection

Another [link with title](https://example.com "Title") works fine.

[1]: https://example.com
''';
        
        final result = MarkdownValidator.validateMarkdown(validMarkdown, 'valid_links_headers.md');
        
        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });

      test('should detect issues with both links and headers', () {
        const invalidMarkdown = '''####### Too many hash symbols

This has [broken link][missing-ref] and unclosed [bracket.

Normal content continues.
''';
        
        final result = MarkdownValidator.validateMarkdown(invalidMarkdown, 'mixed_issues.md');
        
        expect(result.isValid, isFalse);
        expect(result.issues.any((issue) => issue.contains('Invalid header level')), isTrue);
        expect(result.issues.any((issue) => issue.contains('Undefined reference link')), isTrue);
      });
    });
  });
}