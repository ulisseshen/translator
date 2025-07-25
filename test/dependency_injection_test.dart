import 'package:test/test.dart';
import 'package:translator/translator.dart';
import '../bin/src/dependency_injection.dart';
import '../bin/src/header_tools_service.dart';
import '../bin/src/translator_app.dart';

/// Example of how easy it is to test with DI
void main() {
  group('DI Configuration Tests', () {
    tearDown(() async {
      // Clean up after each test
      await getIt.reset();
    });

    test('should easily setup test dependencies with mocks', () async {
      // Mock translator that adds a prefix to show it's working
      final mockTranslator = TestTranslator();
      
      // Setup DI with our mock
      await setupTestDependencies(mockTranslator: mockTranslator);
      
      // Get the configured app
      final app = getIt<TranslatorApp>();
      
      // Verify we can get dependencies without calling getIt everywhere
      expect(app, isNotNull);
      
      // Test that our mock is being used
      final translator = getIt<Translator>();
      final result = await translator.translate('test', onFirstModelError: () {});
      expect(result, equals('TEST_MOCK: test'));
    });

    test('should configure different dependencies for different test scenarios', () async {
      // First scenario: fast mock translator
      await setupTestDependencies(
        mockTranslator: TestTranslator(prefix: 'FAST'),
      );
      
      var translator = getIt<Translator>();
      var result = await translator.translate('hello', onFirstModelError: () {});
      expect(result, equals('FAST_MOCK: hello'));
      
      // Reset and configure for second scenario
      await setupTestDependencies(
        mockTranslator: TestTranslator(prefix: 'SLOW'),
      );
      
      translator = getIt<Translator>();
      result = await translator.translate('world', onFirstModelError: () {});
      expect(result, equals('SLOW_MOCK: world'));
    });

    test('should allow testing with production-like configuration', () async {
      // Setup production dependencies (but we could override specific ones)
      await setupProductionDependencies();
      
      // We get actual production dependencies
      final app = getIt<TranslatorApp>();
      expect(app, isNotNull);
      
      // But we could still override specific dependencies for testing
      // This shows the power of the DI approach
      getIt.unregister<Translator>();
      getIt.registerSingleton<Translator>(TestTranslator(prefix: 'OVERRIDE'));
      
      final translator = getIt<Translator>();
      final result = await translator.translate('test', onFirstModelError: () {});
      expect(result, equals('OVERRIDE_MOCK: test'));
    });

    test('should easily mock HeaderToolsService for testing tools functionality', () async {
      // Mock header tools service
      final mockHeaderTools = TestHeaderToolsService();
      
      // Setup DI with our mock
      await setupTestDependencies(
        mockTranslator: TestTranslator(), 
        mockHeaderToolsService: mockHeaderTools,
      );
      
      // Test direct access to the mock service
      final headerToolsService = getIt<HeaderToolsService>();
      expect(headerToolsService, equals(mockHeaderTools));
      
      // Test mock behavior directly
      await headerToolsService.ensureHeaderLinking(['test_directory']);
      
      // Verify mock was called
      expect(mockHeaderTools.ensureHeaderLinkingCalled, isTrue);
      expect(mockHeaderTools.lastArguments, equals(['test_directory']));
    });
  });
}

/// Example test translator implementation
class TestTranslator implements Translator {
  final String prefix;
  
  TestTranslator({this.prefix = 'TEST'});

  @override
  Future<String> translate(String text, {required Function onFirstModelError, bool useSecond = false}) async {
    // Simulate some work
    await Future.delayed(Duration(milliseconds: 1));
    return '${prefix}_MOCK: $text';
  }
}

/// Example test header tools service implementation
class TestHeaderToolsService implements HeaderToolsService {
  bool ensureHeaderLinkingCalled = false;
  bool substituteCalled = false;
  List<String>? lastArguments;

  @override
  Future<void> ensureHeaderLinking(List<String> arguments) async {
    ensureHeaderLinkingCalled = true;
    lastArguments = arguments;
    // Mock behavior - just simulate the work
    await Future.delayed(Duration(milliseconds: 1));
    print('MOCK: ensureHeaderLinking called with: $arguments');
  }

  @override
  Future<void> substitute(List<String> arguments) async {
    substituteCalled = true;
    lastArguments = arguments;
    // Mock behavior - just simulate the work
    await Future.delayed(Duration(milliseconds: 1));
    print('MOCK: substitute called with: $arguments');
  }
}