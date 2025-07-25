// Legacy constants - these will be moved to configuration classes
const int kMaxKbSize = 28;
const String kSignatureTranslated = 'ia-translate: true';

/// Application constants that don't change
class AppConstants {
  static const String signatureTranslated = 'ia-translate: true';
  static const String defaultExtension = '.md';
  static const int defaultMaxKbSize = 28;
  
  // File processing constants
  static const String sentFilePrefix = '_sent';
  static const String receivedFilePrefix = '_received';
  static const String invalidStructurePrefix = '_structure_invalid';
  static const String invalidLinkPrefix = '_link_invalid';
}