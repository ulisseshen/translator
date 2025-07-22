import 'package:test/test.dart';
import '../bin/src/markdown_link_validator.dart';

void main() {
  group('Line Break Reference Tests', () {
    test('should handle line breaks in reference links', () {
      const content = '''
The [Material library][Material library] implements widgets that follow [Material
Design][Material
Design] principles.

[Material library]: {{api}}/material/material-library.html
[Material Design]: {{site.material}}/styles
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed('', content);
      
      expect(result.isValid, isTrue, reason: 'Should be valid despite line breaks');
      expect(result.issues, isEmpty, reason: 'Should have no broken reference issues');
      expect(result.translatedInfo.references, contains('material library'));
      expect(result.translatedInfo.references, contains('material design'));
      expect(result.translatedInfo.definitions.keys, contains('material library'));
      expect(result.translatedInfo.definitions.keys, contains('material design'));
    });

    test('should normalize multiple spaces in references', () {
      const content = '''
The [Flutter   
  Widget][Flutter   
  Widget] documentation.

[Flutter Widget]: /widgets
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed('', content);
      
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.translatedInfo.references, contains('flutter widget'));
      expect(result.translatedInfo.definitions.keys, contains('flutter widget'));
    });

    test('should handle mixed line breaks and spaces', () {
      const content = '''
See [Apple's Human
Interface    Guidelines
for iOS][Apple's Human
Interface    Guidelines
for iOS] for details.

[Apple's Human Interface Guidelines for iOS]: https://example.com
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed('', content);
      
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.translatedInfo.references, contains('apple\'s human interface guidelines for ios'));
      expect(result.translatedInfo.definitions.keys, contains('apple\'s human interface guidelines for ios'));
    });

    test('should still detect truly broken references', () {
      const content = '''
The [Material
Design][Material
Design] and [Broken Link][broken link] references.

[Material Design]: {{site.material}}/styles
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed('', content);
      
      expect(result.isValid, isFalse);
      expect(result.issues, isNotEmpty);
      expect(result.issues.first, contains('broken link'));
      expect(result.translatedInfo.references, contains('material design'));
      expect(result.translatedInfo.references, contains('broken link'));
      expect(result.translatedInfo.definitions.keys, contains('material design'));
      expect(result.translatedInfo.definitions.keys, isNot(contains('broken link')));
    });

    test('should handle shortcut reference links with line breaks', () {
      const content = '''
The [Material
Design][] specification.

[Material Design]: {{site.material}}/styles
''';

      final result = MarkdownLinkValidator.validateReferenceLinksDetailed('', content);
      
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.translatedInfo.references, contains('material design'));
      expect(result.translatedInfo.definitions.keys, contains('material design'));
    });
  });
}