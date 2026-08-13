import 'dart:io';
import 'models.dart';
import 'ocr_service.dart';
import 'prompt_builder.dart';
import 'gemini_client.dart';
import 'parser.dart';
import 'validators.dart';
import 'mapper.dart';
import '../services/gemini_settings_service.dart';

class InvoiceAiService {
  final OcrService _ocrService = OcrService();
  late final GeminiClient _geminiClient;

  InvoiceAiService(GeminiSettingsService settingsService) {
    _geminiClient = GeminiClient(settingsService);
  }

  Future<DolibarrInvoiceResult> processImage(File imageFile) async {
    print('InvoiceAiService: processing image: ${imageFile.path}');
    final ocrResult = await _ocrService.processImage(imageFile);
    print('OcrDocument lines count: ${ocrResult.document.lines.length}');
    print('DocumentType: ${ocrResult.documentType.name}');
    for (var i = 0; i < ocrResult.document.lines.length; i++) {
      print('OcrDocument line $i: ${ocrResult.document.lines[i].text}');
    }

    final prompt =
        PromptBuilder.buildPrompt(ocrResult.document, ocrResult.documentType);
    final geminiResponse = await _geminiClient.extractData(prompt);
    try {
      final parsed = InvoiceParser.parse(geminiResponse);
      final invoiceResult =
          InvoiceValidators.validateAndFix(parsed, ocrResult.documentType);
      if (invoiceResult.items.isEmpty &&
          invoiceResult.header.numeroDocumento == null &&
          invoiceResult.header.fecha == null &&
          invoiceResult.header.total == null) {
        throw Exception(
            'Gemini no identifico datos utilizables del documento.');
      }

      final dolibarrResult = DolibarrMapper.toDolibarr(invoiceResult);
      print('InvoiceAiService: final dolibarr result: $dolibarrResult');
      return dolibarrResult;
    } catch (e, stackTrace) {
      print('InvoiceAiService: invalid Gemini extraction: $e\n$stackTrace');
      throw Exception('No se pudo completar automaticamente: $e');
    }
  }
}
