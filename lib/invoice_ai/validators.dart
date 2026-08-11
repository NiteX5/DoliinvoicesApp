import 'models.dart';

class InvoiceValidators {
  static InvoiceResult validateAndFix(InvoiceResult result, DocumentType documentType) {
    final isBoleta = documentType == DocumentType.boleta;
    final validatedItems =
        result.items.where((item) => _isProduct(item, isBoleta)).map((item) => _validateItem(item, isBoleta)).toList();
    final validatedHeader = _validateHeader(result.header, validatedItems, isBoleta);

    // Validación cruzada encabezado ↔ ítems (solo informa, no modifica).
    _crossValidateHeaderItems(validatedHeader, validatedItems, isBoleta);

    // Detección de ítems duplicados (solo informa).
    _detectDuplicateItems(validatedItems);

    return InvoiceResult(
      header: validatedHeader,
      items: validatedItems,
    );
  }

  static InvoiceHeader _validateHeader(
      InvoiceHeader header, List<InvoiceItem> items, bool isBoleta) {
    double? neto = header.neto;
    double? iva = header.iva;
    double? total = header.total;
    double? exento = header.exento;
    double? otrosImpuestos = header.otrosImpuestos;

    // Para BOLETAS: no forzar desglose neto/iva si no existe
    // Las boletas suelen tener SOLO total. No inventar neto/iva.
    if (!isBoleta) {
      // Preservar totales impresos: las líneas pueden estar incompletas o puede haber
      // un descuento global, flete o redondeo fuera de la tabla de items.
      if (iva == null && total != null && neto != null) {
        final calculatedIva =
            total - neto - (exento ?? 0) - (otrosImpuestos ?? 0);
        if (calculatedIva >= 0) iva = calculatedIva;
      }

      if (neto == null && total != null && iva != null) {
        final calculatedNeto =
            total - iva - (exento ?? 0) - (otrosImpuestos ?? 0);
        if (calculatedNeto >= 0) neto = calculatedNeto;
      }

      if (total == null && neto != null && iva != null) {
        total = neto + iva + (exento ?? 0) + (otrosImpuestos ?? 0);
      }
    } else {
      // BOLETA: si solo hay total, respetar solo el total
      // No calcular neto/iva si no vienen en el documento
      if (total == null && neto != null && iva != null) {
        total = neto + iva + (exento ?? 0) + (otrosImpuestos ?? 0);
      }
    }

    return InvoiceHeader(
      tipoDocumento: header.tipoDocumento ?? (isBoleta ? 'boleta' : 'factura'),
      numeroDocumento: header.numeroDocumento,
      fecha: header.fecha,
      fechaVencimiento: header.fechaVencimiento,
      proveedor: header.proveedor,
      rut: header.rut,
      giro: header.giro,
      direccion: header.direccion,
      ciudad: header.ciudad,
      moneda: header.moneda,
      neto: neto,
      exento: exento,
      iva: iva,
      otrosImpuestos: otrosImpuestos,
      total: total,
    );
  }

  static InvoiceItem _validateItem(InvoiceItem item, bool isBoleta) {
    double? cantidad = item.cantidad;
    double? precioUnitario = item.precioUnitario;
    double? subtotal = item.subtotal;
    double? totalLinea = item.totalLinea;

    // Para BOLETAS: no forzar cantidad=1 ni calcular precio unitario si no hay datos
    // Las boletas a menudo solo tienen descripcion + total linea
    if (!isBoleta) {
      // Si OCR/Gemini no detectó la cantidad pero identificó ambas columnas monetarias,
      // recuperarla antes de usar 1 unidad por defecto.
      if ((cantidad == null || !cantidad.isFinite || cantidad <= 0) &&
          precioUnitario != null &&
          precioUnitario > 0 &&
          totalLinea != null) {
        final inferred = totalLinea / precioUnitario;
        if (inferred >= 1 && (inferred - inferred.round()).abs() < 0.001) {
          cantidad = inferred;
        }
      }
      cantidad ??= 1;

      if (precioUnitario == null && totalLinea != null) {
        precioUnitario = totalLinea / cantidad;
      }
      if (totalLinea == null && precioUnitario != null) {
        totalLinea = precioUnitario * cantidad;
      }

      if (subtotal == null && precioUnitario != null) {
        subtotal = precioUnitario * cantidad;
      }
    } else {
      // BOLETA: solo validar lo que ya viene, no inventar
      // cantidad, precioUnitario, subtotal pueden ser null
      if (totalLinea == null && precioUnitario != null && cantidad != null) {
        totalLinea = precioUnitario * cantidad;
      }
      if (subtotal == null && precioUnitario != null && cantidad != null) {
        subtotal = precioUnitario * cantidad;
      }
    }

    return InvoiceItem(
      tipoLinea: item.tipoLinea,
      codigo: item.codigo,
      descripcion: item.descripcion,
      cantidad: cantidad,
      unidad: item.unidad,
      precioUnitario: precioUnitario,
      descuento: item.descuento,
      subtotal: subtotal,
      iva: item.iva,
      tasaIva: item.tasaIva,
      totalLinea: totalLinea,
      priceIncludesVat: item.priceIncludesVat ?? isBoleta, // Boletas suelen ser precio con IVA
    );
  }

  /// Validación cruzada entre totales del encabezado y totales de ítems.
  /// Solo registra advertencias en consola, no modifica datos.
  static void _crossValidateHeaderItems(
      InvoiceHeader header, List<InvoiceItem> items, bool isBoleta) {
    if (items.isEmpty) return;
    if (header.total == null) return;

    final itemsSum = items.fold<double>(0, (sum, item) => sum + (item.totalLinea ?? 0));
    final headerTotal = header.total!;

    final diff = (headerTotal - itemsSum).abs();
    final tolerance = headerTotal * 0.05; // 5% tolerancia

    if (diff > tolerance) {
      print('⚠️ VALIDACIÓN CRUZADA: Header total ($headerTotal) ≠ Suma items ($itemsSum), diff=$diff (>5% tol=$tolerance)');
      print('   → Posibles causas: descuento global, flete, redondeo, items incompletos, o header incluye IVA y items son netos');
    } else {
      print('✅ Validación cruzada OK: Header total=$headerTotal ≈ Suma items=$itemsSum (diff=$diff)');
    }

    // Validar neto vs suma subtotales (solo facturas)
    if (!isBoleta && header.neto != null) {
      final subtotalsSum = items.fold<double>(0, (sum, item) => sum + (item.subtotal ?? 0));
      final netoDiff = (header.neto! - subtotalsSum).abs();
      final netoTolerance = header.neto! * 0.05;
      if (netoDiff > netoTolerance) {
        print('⚠️ VALIDACIÓN NETO: Header neto (${header.neto}) ≠ Suma subtotales ($subtotalsSum), diff=$netoDiff');
      }
    }
  }

  /// Detección de items duplicados: misma descripción + total similar (±5%)
  /// Solo registra advertencias en consola, no modifica datos.
  static void _detectDuplicateItems(List<InvoiceItem> items) {
    if (items.length < 2) return;

    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        final item1 = items[i];
        final item2 = items[j];

        if (item1.descripcion == null || item2.descripcion == null) continue;
        if (item1.totalLinea == null || item2.totalLinea == null) continue;

        final desc1 = item1.descripcion!.trim().toLowerCase();
        final desc2 = item2.descripcion!.trim().toLowerCase();

        // Descripción idéntica o muy similar
        if (desc1 == desc2 || _similarity(desc1, desc2) > 0.85) {
          final total1 = item1.totalLinea!;
          final total2 = item2.totalLinea!;
          final avgTotal = (total1 + total2) / 2;
          final diff = (total1 - total2).abs();
          final pctDiff = avgTotal > 0 ? diff / avgTotal : 0;

          if (pctDiff <= 0.05) { // ±5% en total
            print('⚠️ DUPLICADO DETECTADO: "${item1.descripcion}" x2 (totales: $total1 vs $total2, diff=${(pctDiff * 100).toStringAsFixed(1)}%)');
            print('   → Posible doble escaneo o línea repetida en documento');
          }
        }
      }
    }
  }

  /// Similitud simple de cadenas (Jaccard sobre palabras)
  static double _similarity(String a, String b) {
    final wordsA = a.split(RegExp(r'\s+')).toSet();
    final wordsB = b.split(RegExp(r'\s+')).toSet();
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return union > 0 ? intersection / union : 0.0;
  }

  static bool _isProduct(InvoiceItem item, bool isBoleta) {
    if (item.tipoLinea != null && item.tipoLinea!.toLowerCase() != 'producto') {
      return false;
    }
    final description = item.descripcion?.trim();
    if (description == null || description.length < 2) return false;
    final normalized =
        description.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const documentLabels = [
      'nota de venta',
      'nota venta',
      'subtotal',
      'total',
      'iva',
      'impuesto',
      'neto',
      'descuento global',
      'descuento total',
      'direccion',
      'dirección',
      'rut',
      'fecha',
      'folio',
      'forma de pago',
      'vendedor',
      'cliente',
      'proveedor',
      // Etiquetas específicas de boleta pie
      'gracias por su compra',
      'gracias por preferirnos',
      'vuelva pronto',
      'conservar para garant',
      'no valida como factura',
      'no es factura',
      'representacion impresa',
      'codigo de verificacion',
      'timbraje',
      'caf',
      'resolucion exenta',
      'numero de resolucion',
      'fecha resolucion',
    ];
    return !documentLabels.any((label) => normalized.contains(label));
  }
}