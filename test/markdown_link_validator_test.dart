import 'package:test/test.dart';
import '../bin/src/markdown_link_validator.dart';
import '../bin/src/markdown_structure_validator.dart';

void main() {
  group('MarkdownLinkValidator Reference-Style Links', () {
    test('validates correct reference-style links', () {
      const original = '''
# Documentation
Here is [a link][link1] and [another link][link2].

[link1]: https://example.com
[link2]: https://flutter.dev
''';

      const translated = '''
# Documentação
Aqui está [um link][link1] e [outro link][link2].

[link1]: https://example.com
[link2]: https://flutter.dev
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue);
    });

    test('detects broken reference when label is translated but definition is not updated', () {
      const original = '''
# Guide
Check out [this tutorial][tutorial].

[tutorial]: https://example.com/tutorial
''';

      // AI translated the reference label but not the definition
      const brokenTranslation = '''
# Guia
Confira [este tutorial][este tutorial].

[tutorial]: https://example.com/tutorial
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, brokenTranslation);
      expect(isValid, isFalse, reason: 'Should detect broken reference when label is translated');
      
      // Test detailed validation
      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, brokenTranslation);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(contains('Broken references')));
      expect(result.issues, contains(contains('este tutorial')));
    });

    test('detects missing URL when definition is lost', () {
      const original = '''
# Resources
Visit [the docs][docs] for more info.

[docs]: https://flutter.dev/docs
''';

      // Definition URL was lost in translation
      const brokenTranslation = '''
# Recursos
Visite [a documentação][docs] para mais informações.

[docs]: 
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, brokenTranslation);
      expect(isValid, isFalse, reason: 'Should detect when URL definition is lost');
    });

    test('handles multiple reference-style links correctly', () {
      const original = '''
# Multiple Links
See [Flutter][flutter], [Dart][dart], and [Firebase][firebase].

[flutter]: https://flutter.dev
[dart]: https://dart.dev
[firebase]: https://firebase.google.com
''';

      const translated = '''
# Múltiplos Links
Veja [Flutter][flutter], [Dart][dart], e [Firebase][firebase].

[flutter]: https://flutter.dev
[dart]: https://dart.dev
[firebase]: https://firebase.google.com
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue);
    });

    test('detects when some reference definitions are missing', () {
      const original = '''
# Links
Go to [site A][a] and [site B][b].

[a]: https://example-a.com
[b]: https://example-b.com
''';

      // One definition is missing
      const brokenTranslation = '''
# Links
Vá para [site A][a] e [site B][b].

[a]: https://example-a.com
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, brokenTranslation);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(contains('Missing URLs')));
      expect(result.issues, contains(contains('https://example-b.com')));
    });

    test('handles case insensitive reference matching', () {
      const original = '''
# Case Test
Link to [GitHub][GITHUB].

[github]: https://github.com
''';

      const translated = '''
# Teste de Caso
Link para [GitHub][GITHUB].

[github]: https://github.com
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue, reason: 'Should handle case insensitive reference matching');
    });

    test('detects unused definitions as warnings', () {
      const original = '''
# Simple
Just [one link][link1].

[link1]: https://example.com
''';

      // Extra unused definition in translation
      const translated = '''
# Simples
Apenas [um link][link1].

[link1]: https://example.com
[unused]: https://unused.com
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, translated);
      expect(result.isValid, isTrue, reason: 'Unused definitions should not make validation fail');
      expect(result.warnings, contains(contains('Unused link definitions')));
      expect(result.warnings, contains(contains('unused')));
    });

    test('handles empty content correctly', () {
      const empty1 = '';
      const empty2 = 'Just text, no links.';
      
      final isValid = MarkdownLinkValidator.validateReferenceLinks(empty1, empty2);
      expect(isValid, isTrue, reason: 'Empty content should validate successfully');
    });

    test('handles complex markdown with mixed link types', () {
      const original = '''
# Mixed Links
Here's an [inline link](https://inline.com) and a [reference link][ref1].

Also check <https://autolink.com> and [another ref][ref2].

[ref1]: https://reference1.com
[ref2]: https://reference2.com
''';

      const translated = '''
# Links Mistos
Aqui está um [link inline](https://inline.com) e um [link de referência][ref1].

Também confira <https://autolink.com> e [outra ref][ref2].

[ref1]: https://reference1.com
[ref2]: https://reference2.com
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue, reason: 'Should only validate reference-style links, ignore others');
    });

    test('detects the exact problem from user example', () {
      const original = '''
Check [this link][this is a link].

[this is a link]: https://somelink.com
''';

      // Exactly the problem described by the user
      const brokenTranslation = '''
Confira [esse é um link][this is a link].

[esse é um link]: https://somelink.com
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, brokenTranslation);
      expect(result.isValid, isFalse, reason: 'Should detect the exact user problem');
      expect(result.issues, contains(contains('Broken references')));
      expect(result.issues, contains(contains('this is a link')));
    });

    test('handles shortcut reference links [text][]', () {
      const original = '''
See [Flutter][] for more info.

[flutter]: https://flutter.dev
''';

      const translated = '''
Veja [Flutter][] para mais informações.

[flutter]: https://flutter.dev
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue, reason: 'Should handle shortcut reference links');
    });

    test('ignores links inside code blocks', () {
      const original = '''
# Documentation
Here's a [real link][docs].

```markdown
This [fake link][fake] should be ignored.
```

And another `[inline fake][fake2]` in code.

[docs]: https://flutter.dev
''';

      const translated = '''
# Documentação
Aqui está um [link real][docs].

```markdown
Este [link falso][fake] deve ser ignorado.
```

E outro `[falso inline][fake2]` no código.

[docs]: https://flutter.dev
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue, reason: 'Should ignore links inside code blocks');
    });

    test('ignores links inside HTML comments', () {
      const original = '''
# Guide
Check [this link][docs].

<!-- TODO: Add [another link][todo] -->

[docs]: https://flutter.dev
''';

      const translated = '''
# Guia
Confira [este link][docs].

<!-- TODO: Adicione [outro link][todo] -->

[docs]: https://flutter.dev
''';

      final isValid = MarkdownLinkValidator.validateReferenceLinks(original, translated);
      expect(isValid, isTrue, reason: 'Should ignore links inside HTML comments');
    });

    test('detects when all reference links are lost', () {
      const original = '''
Visit [Flutter][flutter] and [Dart][dart].

[flutter]: https://flutter.dev
[dart]: https://dart.dev
''';

      // AI converted to inline links, losing reference style
      const translated = '''
Visite [Flutter](https://flutter.dev) e [Dart](https://dart.dev).

[flutter]: https://flutter.dev
[dart]: https://dart.dev
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, translated);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(contains('All reference links were lost')));
    });

    test('provides warnings for reference count changes', () {
      const original = '''
See [link1][ref1] and [link2][ref2].

[ref1]: https://example1.com
[ref2]: https://example2.com
''';

      // One reference was converted to inline
      const translated = '''
Veja [link1](https://example1.com) e [link2][ref2].

[ref1]: https://example1.com
[ref2]: https://example2.com
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed(original, translated);
      expect(result.warnings, contains(contains('Reference count changed: 2 -> 1')));
    });
  });

  group('MarkdownStructureValidator with Link Validation', () {
    test('validates both structure and links together', () {
      const original = '''
# Documentation
## Getting Started
- Step 1: Read [the docs][docs]
- Step 2: Try [examples][examples]

[docs]: https://flutter.dev/docs
[examples]: https://flutter.dev/samples
''';

      const translated = '''
# Documentação
## Começando
- Passo 1: Leia [a documentação][docs]
- Passo 2: Tente [exemplos][examples]

[docs]: https://flutter.dev/docs
[examples]: https://flutter.dev/samples
''';

      final isValid = MarkdownStructureValidator.validateStructureAndLinks(original, translated);
      expect(isValid, isTrue);
    });

    test('detects both structure and link issues', () {
      const original = '''
# Main Title
## Section
- Item with [link][ref]

[ref]: https://example.com
''';

      // Missing structure AND broken link
      const brokenTranslation = '''
Main Title
Section
Item with [link][translated-ref]

[ref]: https://example.com
''';

      final result = MarkdownStructureValidator.validateStructureAndLinksDetailed(original, brokenTranslation);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(contains('Structure mismatch')));
      expect(result.issues, contains(contains('Broken references')));
    });

    test('provides detailed validation results', () {
      const original = '''
# Guide
Check [this][link1] and [that][link2].

[link1]: https://example1.com
[link2]: https://example2.com
''';

      const problematic = '''
# Guide
Check [this][translated-link1] and [that][link2].

[link1]: https://example1.com
[link2]: https://example2.com
[unused]: https://unused.com
''';

      final result = MarkdownStructureValidator.validateStructureAndLinksDetailed(original, problematic);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(contains('Broken references')));
      expect(result.warnings, contains(contains('Unused link definitions')));
      expect(result.linkValidation, isNotNull);
    });
  });
}