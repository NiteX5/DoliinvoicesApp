import 'models.dart';

/// Detecta si un documento OCR corresponde a una Factura, Boleta o es desconocido
/// usando scoring heurístico basado en palabras clave y características de layout.

class DocumentTypeDetector {
  // Palabras FUERTES que indican claramente BOLETA (peso 3)
  static const _strongBoletaKeywords = <String>[
    'boleta electrónica',
    'boleta de venta',
    'boleta afecta',
    'boleta exenta',
    'boleta no afecta',
    'dte tipo 39',
    'dte 39',
    'no válida como factura',
    'no es factura',
    'representación impresa de boleta',
    'código de verificación boleta',
  ];

  // Palabras FUERTES que indican claramente FACTURA (peso 3)
  static const _strongFacturaKeywords = <String>[
    'factura electrónica',
    'factura de venta',
    'factura afecta',
    'factura exenta',
    'factura de exportación',
    'factura de compra',
    'dte tipo 33',
    'dte 33',
    'razón social',
    'razón social cliente',
    'rut cliente',
    'dirección cliente',
    'giro cliente',
    'orden de compra',
    'oc n°',
    'orden compra',
    'centro de costo',
    'forma de pago',
    'condiciones de pago',
    'fecha vencimiento',
    'vendedor',
    'cajero',
    'sucursal',
    'bodega',
    'retención',
  ];

  // Palabras MEDIAS para BOLETA (peso 1)
  static const _mediumBoletaKeywords = <String>[
    'boleta',
    'total a pagar',
    'monto total',
    'valor total',
    'total boleta',
    'gracias por su compra',
    'gracias por preferirnos',
    'vuelva pronto',
    'conservar para garantía',
    'conservar para cambio',
    'papel térmico',
    'ancho 58mm',
    'ancho 80mm',
    'impreso por',
    'sistema de facturación',
  ];

  // Palabras MEDIAS para FACTURA (peso 1)
  static const _mediumFacturaKeywords = <String>[
    'factura',
    'neto',
    'neto afecto',
    'neto no afecto',
    'exento',
    'iva',
    'i.v.a.',
    'impuesto',
    'total exento',
    'total afecto',
    'total iva',
    'total neto',
    'subtotal',
    'descuento global',
    'descuento total',
    'flete',
    'otros impuestos',
    'código',
    'cod.',
    'descripción',
    'unidad',
    'unid.',
    'precio unitario',
    'p. unitario',
    'valor unitario',
    'desc.',
    'descuento',
    '% desc',
    'neto línea',
    'iva línea',
    'total línea',
    'glosa',
    'observaciones',
    'trackid',
    'código de verificación',
    'timbraje',
    'caf',
    'resolución exenta',
    'número de resolución',
    'fecha resolución',
  ];

  // Palabras que indican DESGLOSE DE IMPUESTOS (muy fuerte para factura)
  static const _taxBreakdownKeywords = <String>[
    'neto',
    'exento',
    'iva',
    'i.v.a.',
    'impuesto',
  ];

  /// Detecta el tipo de documento basándose en el texto OCR y dimensiones
  static DocumentType detect(OcrDocument doc) {
    final allText = doc.lines.map((l) => l.text.toLowerCase()).join(' ');

    int boletaScore = 0;
    int facturaScore = 0;

    // Palabras fuertes
    for (final kw in _strongBoletaKeywords) {
      if (allText.contains(kw)) boletaScore += 3;
    }
    for (final kw in _strongFacturaKeywords) {
      if (allText.contains(kw)) facturaScore += 3;
    }

    // Palabras medias
    for (final kw in _mediumBoletaKeywords) {
      if (allText.contains(kw)) boletaScore += 1;
    }
    for (final kw in _mediumFacturaKeywords) {
      if (allText.contains(kw)) facturaScore += 1;
    }

    // Heurística de layout: ancho de documento (coordenadas relativas)
    // Papel térmico ~58-80mm -> ancho pequeño en pixeles relativos
    // Factura carta/oficio -> ancho grande
    if (doc.width > 0 && doc.width < 400) {
      boletaScore += 2; // Probable papel térmico
    } else if (doc.width > 800) {
      facturaScore += 2; // Probable papel carta
    }

    // Heurística fuerte: ¿hay desglose neto/iva/total?
    if (_hasTaxBreakdown(allText)) {
      facturaScore += 3;
    }

    // Heurística: ¿hay columnas de tabla (código, cantidad, precio unitario, subtotal)?
    if (_hasTableStructure(doc)) {
      facturaScore += 2;
    }

    // Heurística: ¿solo aparece "Total" sin desglose?
    if (_onlyTotalNoBreakdown(allText)) {
      boletaScore += 2;
    }

    // Decisión con histéresis para evitar oscilaciones
    if (boletaScore > facturaScore + 1) return DocumentType.boleta;
    if (facturaScore > boletaScore + 1) return DocumentType.factura;
    return DocumentType.unknown;
  }

  /// Verifica si el texto contiene desglose de impuestos (neto, iva, exento)
  static bool _hasTaxBreakdown(String text) {
    int count = 0;
    for (final kw in _taxBreakdownKeywords) {
      if (text.contains(kw)) count++;
    }
    // Necesita al menos 2 de las 3 palabras clave principales
    return count >= 2;
  }

  /// Verifica si el documento tiene estructura de tabla (columnas alineadas)
  static bool _hasTableStructure(OcrDocument doc) {
    if (doc.lines.length < 3) return false;

    // Buscar líneas que contengan múltiples números alineados (columnas)
    int tableLikeLines = 0;
    for (final line in doc.lines) {
      final numbers = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?')
          .allMatches(line.text)
          .length;
      if (numbers >= 3) tableLikeLines++;
    }
    return tableLikeLines >= 2;
  }

  /// Verifica si solo aparece "Total" sin desglose de neto/IVA
  static bool _onlyTotalNoBreakdown(String text) {
    final hasTotal = text.contains('total');
    final hasBreakdown = _hasTaxBreakdown(text);
    return hasTotal && !hasBreakdown;
  }

  /// Retorna el score detallado para debugging
  static Map<String, dynamic> getDebugInfo(OcrDocument doc) {
    final allText = doc.lines.map((l) => l.text.toLowerCase()).join(' ');

    int boletaScore = 0;
    int facturaScore = 0;
    final matchedBoleta = <String>[];
    final matchedFactura = <String>[];

    for (final kw in _strongBoletaKeywords) {
      if (allText.contains(kw)) {
        boletaScore += 3;
        matchedBoleta.add('$kw (strong)');
      }
    }
    for (final kw in _strongFacturaKeywords) {
      if (allText.contains(kw)) {
        facturaScore += 3;
        matchedFactura.add('$kw (strong)');
      }
    }
    for (final kw in _mediumBoletaKeywords) {
      if (allText.contains(kw)) {
        boletaScore += 1;
        matchedBoleta.add('$kw (medium)');
      }
    }
    for (final kw in _mediumFacturaKeywords) {
      if (allText.contains(kw)) {
        facturaScore += 1;
        matchedFactura.add('$kw (medium)');
      }
    }

    if (doc.width > 0 && doc.width < 400) boletaScore += 2;
    if (doc.width > 800) facturaScore += 2;
    if (_hasTaxBreakdown(allText)) facturaScore += 3;
    if (_hasTableStructure(doc)) facturaScore += 2;
    if (_onlyTotalNoBreakdown(allText)) boletaScore += 2;

    return {
      'type': detect(doc).name,
      'boletaScore': boletaScore,
      'facturaScore': facturaScore,
      'width': doc.width,
      'matchedBoleta': matchedBoleta,
      'matchedFactura': matchedFactura,
      'hasTaxBreakdown': _hasTaxBreakdown(allText),
      'hasTableStructure': _hasTableStructure(doc),
      'onlyTotalNoBreakdown': _onlyTotalNoBreakdown(allText),
    };
  }
}