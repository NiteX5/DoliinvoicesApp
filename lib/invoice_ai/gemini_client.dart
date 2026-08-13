import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'constants.dart';
import '../services/gemini_settings_service.dart';

class GeminiClient {
  final GeminiSettingsService _settingsService;

  GeminiClient(this._settingsService);

  static const List<String> modelNames = [
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];

  // Esquema JSON para forzar estructura exacta de respuesta
  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'header': {
        'type': 'OBJECT',
        'properties': {
          'tipoDocumento': {'type': 'STRING', 'nullable': true},
          'numeroDocumento': {'type': 'STRING', 'nullable': true},
          'fecha': {'type': 'STRING', 'nullable': true},
          'fechaVencimiento': {'type': 'STRING', 'nullable': true},
          'proveedor': {'type': 'STRING', 'nullable': true},
          'rut': {'type': 'STRING', 'nullable': true},
          'giro': {'type': 'STRING', 'nullable': true},
          'direccion': {'type': 'STRING', 'nullable': true},
          'ciudad': {'type': 'STRING', 'nullable': true},
          'moneda': {'type': 'STRING', 'nullable': true},
          'neto': {'type': 'NUMBER', 'nullable': true},
          'exento': {'type': 'NUMBER', 'nullable': true},
          'iva': {'type': 'NUMBER', 'nullable': true},
          'otrosImpuestos': {'type': 'NUMBER', 'nullable': true},
          'total': {'type': 'NUMBER', 'nullable': true},
        },
        'required': [
          'tipoDocumento',
          'numeroDocumento',
          'fecha',
          'fechaVencimiento',
          'proveedor',
          'rut',
          'giro',
          'direccion',
          'ciudad',
          'moneda',
          'neto',
          'exento',
          'iva',
          'otrosImpuestos',
          'total',
        ],
      },
      'productos': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'tipoLinea': {'type': 'STRING', 'nullable': true},
            'codigo': {'type': 'STRING', 'nullable': true},
            'descripcion': {'type': 'STRING', 'nullable': true},
            'cantidad': {'type': 'NUMBER', 'nullable': true},
            'unidad': {'type': 'STRING', 'nullable': true},
            'precioUnitario': {'type': 'NUMBER', 'nullable': true},
            'descuento': {'type': 'NUMBER', 'nullable': true},
            'subtotal': {'type': 'NUMBER', 'nullable': true},
            'iva': {'type': 'NUMBER', 'nullable': true},
            'tasaIva': {'type': 'NUMBER', 'nullable': true},
            'totalLinea': {'type': 'NUMBER', 'nullable': true},
            'priceIncludesVat': {'type': 'BOOLEAN', 'nullable': true},
          },
          'required': [
            'tipoLinea',
            'codigo',
            'descripcion',
            'cantidad',
            'unidad',
            'precioUnitario',
            'descuento',
            'subtotal',
            'iva',
            'tasaIva',
            'totalLinea',
            'priceIncludesVat',
          ],
        },
      },
    },
    'required': ['header', 'productos'],
  };

  Future<Map<String, dynamic>> extractData(String prompt) async {
    final apiKey = _settingsService.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Configura la API Key de Gemini en Configuración antes de procesar facturas.',
      );
    }

    final failures = <String>[];

    for (final modelName in modelNames) {
      print('GeminiClient: Trying model: $modelName');
      try {
        // Reintentos con backoff exponencial (máx 3 intentos por modelo)
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final response = await http
                .post(
                  Uri.parse(
                    'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
                  ),
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'contents': [
                      {
                        'parts': [
                          {'text': prompt}
                        ]
                      }
                    ],
                    'generationConfig': {
                      'temperature': 0,
                      'topP': 0.1, // Determinístico: solo tokens más probables
                      'topK':
                          1, // Decodificación greedy (solo el token más probable)
                      'responseMimeType': 'application/json',
                      'responseSchema':
                          _responseSchema, // Forzar estructura exacta
                    },
                  }),
                )
                .timeout(InvoiceAiConstants.timeout);

            if (response.statusCode != 200) {
              final decoded = jsonDecode(utf8.decode(response.bodyBytes));
              final error =
                  decoded is Map<String, dynamic> ? decoded['error'] : null;
              final message =
                  error is Map ? error['message']?.toString() : null;
              failures.add(
                  '$modelName: ${message ?? 'HTTP ${response.statusCode}'}');
              // No reintentar en errores 4xx (salvo 429)
              if (response.statusCode >= 400 &&
                  response.statusCode < 500 &&
                  response.statusCode != 429) {
                break;
              }
              // Backoff antes de reintentar
              if (attempt < 3) await _backoff(attempt);
              continue;
            }

            final decoded = jsonDecode(utf8.decode(response.bodyBytes));
            final candidates = decoded['candidates'];
            if (candidates is List && candidates.isNotEmpty) {
              final content = candidates.first['content'];
              final parts =
                  content is Map<String, dynamic> ? content['parts'] : null;
              if (parts is List && parts.isNotEmpty) {
                final text = parts.first['text'];
                if (text is String && text.trim().isNotEmpty) {
                  final parsed = jsonDecode(text);
                  if (parsed is Map<String, dynamic>) {
                    print(
                        'GeminiClient: Success with $modelName on attempt $attempt');
                    return parsed;
                  }
                }
              }
            }
            failures.add('$modelName devolvió JSON vacío o inválido');
            if (attempt < 3) await _backoff(attempt);
          } catch (e, stackTrace) {
            print(
                'GeminiClient error for $modelName (attempt $attempt): $e\n$stackTrace');
            failures.add('$modelName (intento $attempt): $e');
            if (attempt < 3) await _backoff(attempt);
          }
        }
      } catch (e, stackTrace) {
        print('GeminiClient unexpected error for $modelName: $e\n$stackTrace');
        failures.add('$modelName: $e');
      }
    }
    throw Exception(
        'No se pudo extraer la factura con Gemini. ${failures.join(' | ')}');
  }

  /// Backoff exponencial con jitter: 1s, 2.5s, 5s (+/- 200ms)
  Future<void> _backoff(int attempt) async {
    final baseDelay = [1000, 2500, 5000][attempt - 1];
    final jitter = Random().nextInt(400) - 200; // +/- 200ms
    final delay = baseDelay + jitter;
    await Future.delayed(Duration(milliseconds: delay));
  }
}
