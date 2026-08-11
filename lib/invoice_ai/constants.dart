
class InvoiceAiConstants {
  /// API Key de Gemini. Se obtiene desde variable de entorno (dart-define).
  /// Configurar: flutter run --dart-define=GEMINI_API_KEY=tu_key_aqui
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const Duration timeout = Duration(seconds: 25);
  static const num defaultIvaTx = 19;
}
