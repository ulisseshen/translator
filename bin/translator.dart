import 'src/dependency_injection.dart';
import 'src/translator_app.dart';

void main(List<String> arguments) async {
  // Setup dependency injection for production
  await setupProductionDependencies();
  
  // Get the configured application and run it
  final app = getIt<TranslatorApp>();
  await app.run(arguments);
}

