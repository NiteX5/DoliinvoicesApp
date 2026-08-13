import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gestiona la API Key de Gemini en el almacenamiento cifrado del dispositivo.
class GeminiSettingsService {
  static const String _apiKeyStorageKey = 'gemini_api_key';

  final FlutterSecureStorage _secureStorage;
  String? _apiKey;

  GeminiSettingsService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String? get apiKey => _apiKey;

  Future<void> load() async {
    _apiKey = await _secureStorage.read(key: _apiKeyStorageKey);
  }

  Future<void> setApiKey(String apiKey) async {
    final normalizedApiKey = apiKey.trim();
    _apiKey = normalizedApiKey.isEmpty ? null : normalizedApiKey;

    if (_apiKey == null) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
      return;
    }

    await _secureStorage.write(key: _apiKeyStorageKey, value: _apiKey);
  }
}
