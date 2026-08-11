import 'models.dart';
import 'date_utils.dart';
import 'amount_utils.dart';

class LocalFallback {
  static InvoiceResult extractSimple(OcrDocument document, DocumentType documentType) {
    print('LocalFallback: extractSimple called (type: ${documentType.name})');
    final allText = document.lines.map((l) => l.text).join('\n');
    final lineTexts = document.lines.map((l) => l.text).toList();

    final isBoleta = documentType == DocumentType.boleta;

    final numeroDocumento = _extractNumeroDocumento(lineTexts, isBoleta);
    final fecha = _extractFecha(lineTexts);
    final rut = _extractRut(allText);
    final proveedor = _extractProveedor(lineTexts, isBoleta);
    final neto = _extractNeto(lineTexts, isBoleta);
    final iva = _extractIva(lineTexts, isBoleta);
    final exento = _extractExento(lineTexts, isBoleta);
    final total = _extractTotal(lineTexts, isBoleta);
    final items = _extractItemsByColumns(document, isBoleta);

    print('LocalFallback found: '
        'numeroDocumento=$numeroDocumento, '
        'fecha=$fecha, '
        'rut=$rut, '
        'proveedor=$proveedor, '
        'neto=$neto, '
        'exento=$exento, '
        'iva=$iva, '
        'total=$total, '
        'itemsCount=${items.length}');

    return InvoiceResult(
      header: InvoiceHeader(
        tipoDocumento: isBoleta ? 'boleta' : 'factura',
        numeroDocumento: numeroDocumento,
        fecha: fecha,
        rut: rut,
        proveedor: proveedor,
        neto: neto,
        exento: exento,
        iva: iva,
        total: total,
      ),
      items: items,
    );
  }

  // ==================== EXTRACCIÓN DE ENCABEZADO (mejorado) ====================

  static String? _extractNumeroDocumento(List<String> lineTexts, bool isBoleta) {
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      final keywords = isBoleta
          ? ['boleta', 'n°', 'nro', 'folio']
          : ['factura', 'n°', 'nro', 'folio'];
      if (keywords.any((kw) => lineLower.contains(kw))) {
        final match = RegExp(r'[A-Z]?\d{6,}').firstMatch(line);
        if (match != null) {
          print('_extractNumeroDocumento found in: $line: ${match.group(0)}');
          return match.group(0);
        }
      }
    }

    for (final line in lineTexts) {
      final match = RegExp(r'[A-Z]?\d{6,}').firstMatch(line);
      if (match != null) {
        print('_extractNumeroDocumento fallback found in: $line: ${match.group(0)}');
        return match.group(0);
      }
    }
    return null;
  }

  static String? _extractFecha(List<String> lineTexts) {
    for (final line in lineTexts) {
      final normalized = DateUtils.normalize(line);
      if (normalized != null) {
        print('_extractFecha found in line: $line, $normalized');
        return normalized;
      }
    }
    return null;
  }

  static String? _extractRut(String allText) {
    final match = RegExp(r'\b\d{1,3}\.\d{3}\.\d{3}[- ]?[0-9kK]').firstMatch(allText);
    if (match != null) {
      print('_extractRut found: ${match.group(0)}');
    }
    return match?.group(0);
  }

  static String? _extractProveedor(List<String> lineTexts, bool isBoleta) {
    final keywords = isBoleta
        ? ['giro', 'razon social', 'razón social', 'comercio', 'empresa']
        : ['razon social', 'razón social', 'emisor', 'proveedor', 'empresa'];
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      if (keywords.any((kw) => lineLower.contains(kw))) {
        final parts = line.split(':');
        if (parts.length > 1 && parts[1].trim().length > 2) {
          return parts[1].trim();
        }
      }
    }
    return null;
  }

  static double? _extractNeto(List<String> lineTexts, bool isBoleta) {
    if (isBoleta) return null;
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('total afecto') ||
          lineLower.contains('valor mercader') ||
          lineLower.contains('neto afecto')) {
        final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
            .allMatches(line)
            .toList();
        if (matches.isNotEmpty) {
          final neto = AmountUtils.normalize(matches[0].group(0));
          print('_extractNeto found in line: $line: $neto');
          return neto;
        }
      }
    }

    for (final line in lineTexts) {
      final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
          .allMatches(line)
          .toList();
      if (matches.length == 3) {
        final neto = AmountUtils.normalize(matches[0].group(0));
        print('_extractNeto found in 3-number line: $line: $neto');
        return neto;
      }
    }
    return null;
  }

  static double? _extractExento(List<String> lineTexts, bool isBoleta) {
    if (isBoleta) return null;
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('exento')) {
        final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
            .allMatches(line)
            .toList();
        for (final m in matches) {
          final candidate = AmountUtils.normalize(m.group(0));
          if (candidate != null && candidate > 0) {
            print('_extractExento found in line: $line: $candidate');
            return candidate;
          }
        }
      }
    }
    return null;
  }

  static double? _extractIva(List<String> lineTexts, bool isBoleta) {
    if (isBoleta) return null;
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('iva')) {
        final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
            .allMatches(line)
            .toList();
        for (final m in matches) {
          final candidate = AmountUtils.normalize(m.group(0));
          if (candidate != null && candidate > 0) {
            print('_extractIva found in line: $line: $candidate');
            return candidate;
          }
        }
      }
    }

    for (final line in lineTexts) {
      final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
          .allMatches(line)
          .toList();
      if (matches.length == 3) {
        final iva = AmountUtils.normalize(matches[1].group(0));
        print('_extractIva found in 3-number line: $line: $iva');
        return iva;
      }
    }
    return null;
  }

  static double? _extractTotal(List<String> lineTexts, bool isBoleta) {
    final keywords = isBoleta
        ? ['total a pagar', 'monto total', 'valor total', 'total boleta', 'total:']
        : ['total a pagar', 'total', 'monto total', 'valor total'];
    for (final line in lineTexts) {
      final lineLower = line.toLowerCase();
      if (keywords.any((kw) => lineLower.contains(kw))) {
        final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
            .allMatches(line)
            .toList();
        if (matches.isNotEmpty) {
          final total = AmountUtils.normalize(matches.last.group(0));
          print('_extractTotal found in line: $line: $total');
          return total;
        }
      }
    }

    if (!isBoleta) {
      for (final line in lineTexts) {
        final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
            .allMatches(line)
            .toList();
        if (matches.length == 3) {
          final total = AmountUtils.normalize(matches[2].group(0));
          print('_extractTotal found in 3-number line: $line: $total');
          return total;
        }
      }
    }

    final amounts = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
        .allMatches(lineTexts.join('\n'))
        .map((m) => AmountUtils.normalize(m.group(0)))
        .where((a) => a != null && a > 0)
        .toList()
        .cast<double>();
    print('_extractTotal found amounts: $amounts');
    amounts.sort((a, b) => b.compareTo(a));
    if (amounts.isNotEmpty) {
      print('_extractTotal fallback: ${amounts.first}');
      return amounts.first;
    }
    return null;
  }

  // ==================== EXTRACCIÓN DE ÍTEMS: BUCKET POR CENTERX (NUEVO) ====================

  /// Extrae items agrupando palabras por columnas (buckets de centerX ~25px).
  /// Funciona para facturas (tabla) y boletas (línea simple).
  static List<InvoiceItem> _extractItemsByColumns(OcrDocument document, bool isBoleta) {
    final items = <InvoiceItem>[];
    bool inItems = false;

    final startKeywords = isBoleta
        ? ['detalle', 'producto', 'servicio', 'descripcion', 'descripción', 'cant']
        : ['descripcion', 'descripción', 'cant', 'cantidad', 'codigo', 'código'];

    final endKeywords = isBoleta
        ? ['total', 'iva', 'acuse', 'gracias', 'conservar', 'garantia', 'cambio', 'verificacion', 'caf', 'resolucion']
        : ['total', 'valor', 'iva', 'acuse', 'subtotal', 'descuento global', 'flete', 'neto'];

    for (final line in document.lines) {
      final lineLower = line.text.toLowerCase();

      if (!inItems && startKeywords.any((kw) => lineLower.contains(kw))) {
        inItems = true;
        continue;
      }

      if (inItems && endKeywords.any((kw) => lineLower.contains(kw))) {
        break;
      }

      if (inItems) {
        if (isBoleta) {
          _extractBoletaItem(line, items);
        } else {
          _extractFacturaItemByColumns(line, document.words, items);
        }
      }
    }
    print('_extractItemsByColumns found ${items.length} items (isBoleta=$isBoleta)');
    return items;
  }

  /// Boletas: línea simple "Descripción ... $X.XXX" o "2 x Descripción ... $X.XXX"
  static void _extractBoletaItem(OcrLine line, List<InvoiceItem> items) {
    final matches = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
        .allMatches(line.text)
        .toList();

    if (matches.isNotEmpty) {
      final totalLinea = AmountUtils.normalize(matches.last.group(0));

      // Cantidad al inicio: "2 x ", "2x ", "Cant 2", "2 und"
      double? cantidad;
      final qtyMatch = RegExp(r'^(\d+(?:[.,]\d+)?)\s*[xX]\s*').firstMatch(line.text);
      if (qtyMatch != null) {
        cantidad = AmountUtils.normalize(qtyMatch.group(1));
      } else {
        final qtyMatch2 = RegExp(r'(?:cant|quantity|qty)\.?\s*(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(line.text);
        if (qtyMatch2 != null) {
          cantidad = AmountUtils.normalize(qtyMatch2.group(1));
        }
      }

      // Descripción: todo antes del último número (el total)
      String description = line.text;
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        description = line.text.substring(0, lastMatch.start).trim();
      }
      // Limpiar "2 x ", "2x ", "Cant 2 " del inicio
      description = description.replaceFirst(RegExp(r'^\d+(?:[.,]\d+)?\s*[xX]\s*'), '').trim();
      description = description.replaceFirst(RegExp(r'(?:cant|quantity|qty)\.?\s*\d+(?:[.,]\d+)?\s*', caseSensitive: false), '').trim();
      description = description.replaceAll(RegExp(r'\s+'), ' ');

      if (description.isNotEmpty && totalLinea != null) {
        items.add(InvoiceItem(
          descripcion: description,
          cantidad: cantidad,
          precioUnitario: null,
          subtotal: null,
          totalLinea: totalLinea,
          tipoLinea: 'producto',
          priceIncludesVat: true,
        ));
        print('_extractBoletaItem added: $description, qty=$cantidad, total=$totalLinea');
      }
    }
  }

  /// Facturas: detectar columnas por buckets de centerX en TODAS las palabras del documento.
  static void _extractFacturaItemByColumns(OcrLine line, List<OcrWord> allWords, List<InvoiceItem> items) {
    // 1. Agrupar TODAS las palabras del documento por centerX (buckets ~25px)
    // Esto detecta columnas globales, no solo de esta línea
    final columnBuckets = <int, List<OcrWord>>{};
    const bucketSize = 25.0;

    for (final word in allWords) {
      final bucket = (word.centerX / bucketSize).round();
      columnBuckets.putIfAbsent(bucket, () => []).add(word);
    }

    // 2. Identificar buckets que son "columnas numéricas" (≥50% palabras son números)
    final numericBuckets = <int>[];
    columnBuckets.forEach((bucket, words) {
      final numericCount = words.where((w) => _looksLikeNumber(w.text)).length;
      if (words.length >= 2 && numericCount / words.length >= 0.5) {
        numericBuckets.add(bucket);
      }
    });
    numericBuckets.sort((a, b) => a.compareTo(b)); // izquierda a derecha

    // 3. Para esta línea, encontrar palabras en buckets numéricos
    final lineNumericWords = <OcrWord>[];
    for (final word in line.words) {
      final bucket = (word.centerX / bucketSize).round();
      if (numericBuckets.contains(bucket) && _looksLikeNumber(word.text)) {
        lineNumericWords.add(word);
      }
    }

    if (lineNumericWords.length < 2) return; // Necesitamos al menos 2 números (precio + total)

    // Ordenar por X (izquierda a derecha)
    lineNumericWords.sort((a, b) => a.centerX.compareTo(b.centerX));

    // Leer de derecha a izquierda: último = totalLinea, penúltimo = precioUnitario, antepenúltimo = cantidad
    final totalLinea = AmountUtils.normalize(lineNumericWords.last.text);
    double? precioUnitario = lineNumericWords.length >= 2
        ? AmountUtils.normalize(lineNumericWords[lineNumericWords.length - 2].text)
        : null;
    double cantidad = 1;

    if (lineNumericWords.length >= 3) {
      final candidateQty = AmountUtils.normalize(lineNumericWords[lineNumericWords.length - 3].text);
      if (candidateQty != null && candidateQty > 0 && candidateQty <= 100000) {
        cantidad = candidateQty;
      }
    } else if (precioUnitario != null &&
        totalLinea != null &&
        precioUnitario > 0 &&
        precioUnitario <= 1000 &&
        totalLinea >= precioUnitario * 2) {
      // Recibos compactos: solo cantidad y total
      cantidad = precioUnitario;
      precioUnitario = totalLinea / cantidad;
    }

    // Descripción: texto a la izquierda del primer número de la fila
    final firstNumericX = lineNumericWords.first.centerX;
    final descriptionWords = line.words.where((w) => w.centerX < firstNumericX - 10).toList();
    descriptionWords.sort((a, b) => a.left.compareTo(b.left));
    String description = descriptionWords.map((w) => w.text).join(' ').trim();
    description = description.replaceAll(RegExp(r'\s+'), ' ');

    // Limpiar códigos de producto al inicio (ej: "780123456 PAN BIMBO" -> "PAN BIMBO")
    description = description.replaceFirst(RegExp(r'^\d{6,}\s+'), '').trim();

    if (description.isNotEmpty && totalLinea != null && precioUnitario != null) {
      items.add(InvoiceItem(
        descripcion: description,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
        subtotal: precioUnitario * cantidad,
        totalLinea: totalLinea,
        tipoLinea: 'producto',
        priceIncludesVat: false,
      ));
      print('_extractFacturaItemByColumns added: $description, qty=$cantidad, unit=$precioUnitario, total=$totalLinea');
    }
  }

  static bool _looksLikeNumber(String text) {
    final cleaned = text.replaceAll(RegExp(r'[.,]'), '').replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d+$').hasMatch(cleaned) && cleaned.length <= 12;
  }
}