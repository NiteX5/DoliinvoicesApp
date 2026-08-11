import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String _apiKeyKey = 'doli_api_key';
  static const String _isAuthenticatedKey = 'is_authenticated';
  // NOTA: No hay defaultApiKey hardcodeado por seguridad.
  // El usuario debe ingresar su API Key de Dolibarr en la pantalla de login.

  String? _apiKey;
  bool _isAuthenticated = false;

  String? get apiKey => _apiKey;
  bool get isAuthenticated => _isAuthenticated;

  AuthService() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey);
    _isAuthenticated = prefs.getBool(_isAuthenticatedKey) ?? false;
    notifyListeners();
  }

  Future<bool> login(String apiKey) async {
    // Validación básica del API key
    if (apiKey.isEmpty || apiKey.length < 20) {
      return false;
    }

    _apiKey = apiKey;
    _isAuthenticated = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
    await prefs.setBool(_isAuthenticatedKey, true);
    
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _apiKey = null;
    _isAuthenticated = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_isAuthenticatedKey);
    
    notifyListeners();
  }
}
