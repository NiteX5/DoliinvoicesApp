import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'models.dart';
import 'document_type_detector.dart';

class OcrService {
  Future<OcrResult> processImage(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await recognizer.processImage(inputImage);

      print('ML Kit recognized text: ${recognizedText.text}');

      final words = <OcrWord>[];
      double? minX, minY, maxX, maxY;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final text = element.text.trim();
            if (text.isEmpty) continue;

            final box = element.boundingBox;
            final word = OcrWord(
              text: text,
              left: box.left.toDouble(),
              top: box.top.toDouble(),
              right: box.right.toDouble(),
              bottom: box.bottom.toDouble(),
            );

            words.add(word);

            minX = (minX == null) ? word.left : (word.left < minX ? word.left : minX);
            minY = (minY == null) ? word.top : (word.top < minY ? word.top : minY);
            maxX = (maxX == null) ? word.right : (word.right > maxX ? word.right : maxX);
            maxY = (maxY == null) ? word.bottom : (word.bottom > maxY ? word.bottom : maxY);
          }
        }
      }

      if (words.isEmpty) {
        return OcrResult(
          document: OcrDocument(
            width: 0,
            height: 0,
            lines: [],
            words: [],
          ),
          documentType: DocumentType.unknown,
        );
      }

      // Clustering 1D robusto en eje Y (reemplaza threshold fijo)
      final lines = _groupWordsIntoLinesClustering(words);

      final document = OcrDocument(
        width: maxX! - minX!,
        height: maxY! - minY!,
        lines: lines,
        words: words, // Conservar todas las palabras con coordenadas
      );

      final documentType = DocumentTypeDetector.detect(document);
      print('DocumentTypeDetector: detected ${documentType.name} (width: ${document.width.toStringAsFixed(0)})');

      return OcrResult(
        document: document,
        documentType: documentType,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Agrupa palabras en líneas usando clustering 1D (DBSCAN simplificado) en eje Y.
  /// Más robusto que threshold fijo porque se adapta a la distribución real de alturas.
  List<OcrLine> _groupWordsIntoLinesClustering(List<OcrWord> words) {
    if (words.isEmpty) return [];

    // Ordenar por centerY
    final sortedWords = [...words]..sort((a, b) => a.centerY.compareTo(b.centerY));

    // Calcular distancias entre palabras consecutivas en Y
    final gaps = <double>[];
    for (int i = 1; i < sortedWords.length; i++) {
      gaps.add(sortedWords[i].centerY - sortedWords[i - 1].centerY);
    }

    // Estimar eps (radio de vecindad) como percentil 75 de gaps pequeños
    // Filtrar gaps > altura_promedio * 2 (saltos grandes entre líneas)
    final avgHeight = words.map((w) => w.height).reduce((a, b) => a + b) / words.length;
    final smallGaps = gaps.where((g) => g <= avgHeight * 2).toList()..sort();
    final eps = smallGaps.isNotEmpty
        ? smallGaps[(smallGaps.length * 0.75).floor()]
        : avgHeight * 0.6; // fallback al método anterior

    // DBSCAN 1D simplificado: agrupar palabras donde gap <= eps
    final rows = <List<OcrWord>>[];
    var currentRow = <OcrWord>[sortedWords.first];

    for (int i = 1; i < sortedWords.length; i++) {
      final gap = sortedWords[i].centerY - sortedWords[i - 1].centerY;
      if (gap <= eps) {
        currentRow.add(sortedWords[i]);
      } else {
        rows.add(currentRow);
        currentRow = [sortedWords[i]];
      }
    }
    rows.add(currentRow);

    // Construir líneas ordenando palabras por X dentro de cada fila
    final lines = <OcrLine>[];
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));

      double? lineLeft, lineTop, lineRight, lineBottom;
      for (final word in row) {
        lineLeft = (lineLeft == null) ? word.left : (word.left < lineLeft ? word.left : lineLeft);
        lineTop = (lineTop == null) ? word.top : (word.top < lineTop ? word.top : lineTop);
        lineRight = (lineRight == null) ? word.right : (word.right > lineRight ? word.right : lineRight);
        lineBottom = (lineBottom == null) ? word.bottom : (word.bottom > lineBottom ? word.bottom : lineBottom);
      }

      lines.add(OcrLine(
        words: row,
        left: lineLeft!,
        top: lineTop!,
        right: lineRight!,
        bottom: lineBottom!,
      ));
    }

    // Ordenar líneas por centerY
    lines.sort((a, b) => a.centerY.compareTo(b.centerY));
    return lines;
  }
}