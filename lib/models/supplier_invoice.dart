class SupplierInvoice {
  final int? id;
  final String ref;
  final String? refSupplier;
  final String? date;
  final double? totalHt;
  final double? totalTtc;
  final double? totalVat;
  final int? fkSoc;
  final String? supplierName;
  final int? fkProject;
  final String? projectName;
  final int? status;
  final String? notePublic;
  final List<InvoiceLine>? lines;
  final String? clasificacion;
  // Campos de condiciones de pago
  final int? condReglementId;        // Condiciones de pago (FK a llx_c_cond_reglement)
  final String? dateLimReglement;    // Fecha límite de pago (YYYY-MM-DD)
  final int? modeReglementId;        // Forma de pago (FK a llx_c_paiement)

  SupplierInvoice({
    this.id,
    required this.ref,
    this.refSupplier,
    this.date,
    this.totalHt,
    this.totalTtc,
    this.totalVat,
    this.fkSoc,
    this.supplierName,
    this.fkProject,
    this.projectName,
    this.status,
    this.notePublic,
    this.lines,
    this.clasificacion,
    this.condReglementId,
    this.dateLimReglement,
    this.modeReglementId,
  });

  factory SupplierInvoice.fromJson(Map<String, dynamic> json) {
    List<InvoiceLine>? linesList;
    if (json['lines'] != null) {
      linesList = (json['lines'] as List)
          .map((line) => InvoiceLine.fromJson(line))
          .toList();
    }

    // Leer clasificación desde array_options (campo extra de Dolibarr).
    String? clasificacion = _asString(json['clasificacion']);
    if (clasificacion == null || clasificacion.isEmpty) {
      final arrayOptions = json['array_options'];
      if (arrayOptions is Map) {
        clasificacion = _asString(arrayOptions['options_clasificacion']);
      }
    }

    return SupplierInvoice(
      id: _asInt(json['id']),
      ref: _asString(json['ref']) ?? '',
      refSupplier: _asString(json['ref_supplier']),
      date: _parseDate(json['date']),
      totalHt: _asDouble(json['total_ht']),
      totalTtc: _asDouble(json['total_ttc']),
      totalVat: _asDouble(json['total_vat'] ?? json['total_tva']),
      fkSoc: _asInt(json['fk_soc'] ?? json['socid']),
      supplierName: _asString(json['supplier_name'] ?? json['thirdparty_name']),
      fkProject: _asInt(json['fk_project']),
      projectName: _asString(json['project_name'] ?? json['project_ref']),
      status: _asInt(json['status']),
      notePublic: _asString(json['note_public']),
      lines: linesList,
      clasificacion: clasificacion,
      condReglementId: _asInt(json['cond_reglement_id']),
      dateLimReglement: _parseDate(json['date_lim_reglement']),
      modeReglementId: _asInt(json['mode_reglement_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ref': ref,
      if (refSupplier != null) 'ref_supplier': refSupplier,
      if (date != null) 'date': date,
      if (totalHt != null) 'total_ht': totalHt,
      if (totalTtc != null) 'total_ttc': totalTtc,
      if (totalVat != null) 'total_tva': totalVat,
      if (fkSoc != null) 'socid': fkSoc,
      if (fkProject != null) 'fk_project': fkProject,
      if (status != null) 'status': status,
      if (notePublic != null) 'note_public': notePublic,
      if (lines != null) 'lines': lines!.map((line) => line.toJson()).toList(),
      // NO enviar 'clasificacion' como campo directo - Dolibarr lo ignora, solo usa array_options
      if (condReglementId != null) 'cond_reglement_id': condReglementId,
      if (dateLimReglement != null) 'date_lim_reglement': dateLimReglement,
      if (modeReglementId != null) 'mode_reglement_id': modeReglementId,
    };
  }

  SupplierInvoice copyWith({
    int? id,
    String? ref,
    String? refSupplier,
    String? date,
    double? totalHt,
    double? totalTtc,
    double? totalVat,
    int? fkSoc,
    String? supplierName,
    int? fkProject,
    String? projectName,
    int? status,
    String? notePublic,
    List<InvoiceLine>? lines,
    String? clasificacion,
    int? condReglementId,
    String? dateLimReglement,
    int? modeReglementId,
  }) {
    return SupplierInvoice(
      id: id ?? this.id,
      ref: ref ?? this.ref,
      refSupplier: refSupplier ?? this.refSupplier,
      date: date ?? this.date,
      totalHt: totalHt ?? this.totalHt,
      totalTtc: totalTtc ?? this.totalTtc,
      totalVat: totalVat ?? this.totalVat,
      fkSoc: fkSoc ?? this.fkSoc,
      supplierName: supplierName ?? this.supplierName,
      fkProject: fkProject ?? this.fkProject,
      projectName: projectName ?? this.projectName,
      status: status ?? this.status,
      notePublic: notePublic ?? this.notePublic,
      lines: lines ?? this.lines,
      clasificacion: clasificacion ?? this.clasificacion,
      condReglementId: condReglementId ?? this.condReglementId,
      dateLimReglement: dateLimReglement ?? this.dateLimReglement,
      modeReglementId: modeReglementId ?? this.modeReglementId,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  /// Normaliza fechas en varios formatos que puede devolver Dolibarr.
  static String? _parseDate(dynamic value) {
    if (value == null) return null;

    // Manejar valores numéricos directamente (timestamps Unix como int)
    if (value is int) {
      // Detectar timestamp Unix (10 dígitos en segundos, 13 en milisegundos).
      if (value >= 1000000000 && value <= 9999999999) {
        // 10 dígitos = segundos desde la época Unix
        final date = DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: false);
        return date.toIso8601String().split('T')[0];
      } else if (value >= 1000000000000 && value <= 9999999999999) {
        // 13 dígitos = milisegundos desde la época Unix
        final date = DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
        return date.toIso8601String().split('T')[0];
      }
      // Si es un entero pequeño, podría ser una fecha compacta como YYYYMMDD
      final str = value.toString();
      if (str.length == 8) {
        // Intentar formato YYYYMMDD
        final year = int.tryParse(str.substring(0, 4));
        final month = int.tryParse(str.substring(4, 6));
        final day = int.tryParse(str.substring(6, 8));
        if (year != null && month != null && day != null &&
            month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final date = DateTime(year, month, day);
          return date.toIso8601String().split('T')[0];
        }
      }
    }

    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Intentar formato ISO primero (YYYY-MM-DD o YYYY-MM-DDTHH:MM:SS)
    try {
      final date = DateTime.parse(str);
      return date.toIso8601String().split('T')[0];
    } catch (_) {}

    // Intentar timestamp Unix en segundos (10 dígitos)
    if (RegExp(r'^\d{10}$').hasMatch(str)) {
      final timestamp = int.parse(str);
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: false);
      return date.toIso8601String().split('T')[0];
    }

    // Intentar timestamp Unix en milisegundos (13 dígitos)
    if (RegExp(r'^\d{13}$').hasMatch(str)) {
      final timestamp = int.parse(str);
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: false);
      return date.toIso8601String().split('T')[0];
    }

    // Intentar formato europeo DD/MM/YYYY
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(str)) {
      final parts = str.split('/');
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final date = DateTime(year, month, day);
        return date.toIso8601String().split('T')[0];
      }
    }

    // Intentar formato europeo con hora DD/MM/YYYY HH:MM:SS
    if (RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}$').hasMatch(str)) {
      final parts = str.split(' ');
      final dateParts = parts[0].split('/');
      final day = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final year = int.tryParse(dateParts[2]);
      if (day != null && month != null && year != null) {
        final date = DateTime(year, month, day);
        return date.toIso8601String().split('T')[0];
      }
    }

    // Intentar formato YYYYMMDD (8 dígitos).
    if (RegExp(r'^\d{8}$').hasMatch(str)) {
      final year = int.tryParse(str.substring(0, 4));
      final month = int.tryParse(str.substring(4, 6));
      final day = int.tryParse(str.substring(6, 8));
      if (year != null && month != null && day != null &&
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        final date = DateTime(year, month, day);
        return date.toIso8601String().split('T')[0];
      }
    }

    // Devolver tal cual si no se puede parsear
    return str;
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}

class InvoiceLine {
  final int? id;
  final String? description;
  final double? qty;
  final double? subprice;
  final double? totalHt;
  final double? tvaTx;
  final double? remisePercent;
  final String? productRef;
  final bool? pricesIncludeVat;

  InvoiceLine({
    this.id,
    this.description,
    this.qty,
    this.subprice,
    this.totalHt,
    this.tvaTx,
    this.remisePercent,
    this.productRef,
    this.pricesIncludeVat,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      id: _asInt(json['id']),
      description: _asString(json['desc'] ?? json['description']),
      qty: _asDouble(json['qty']),
      subprice: _asDouble(json['subprice']),
      totalHt: _asDouble(json['total_ht']),
      tvaTx: _asDouble(json['tva_tx']),
      remisePercent: _asDouble(json['remise_percent']),
      productRef: _asString(json['product_ref']),
      pricesIncludeVat: json['prices_include_vat'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (description != null) 'desc': description,
      if (qty != null) 'qty': qty,
      if (subprice != null) 'subprice': subprice,
      if (totalHt != null) 'total_ht': totalHt,
      if (tvaTx != null) 'tva_tx': tvaTx,
      if (remisePercent != null) 'remise_percent': remisePercent,
      if (productRef != null) 'product_ref': productRef,
      if (pricesIncludeVat != null) 'prices_include_vat': pricesIncludeVat,
    };
  }

  InvoiceLine copyWith({
    int? id,
    String? description,
    double? qty,
    double? subprice,
    double? totalHt,
    double? tvaTx,
    double? remisePercent,
    String? productRef,
    bool? pricesIncludeVat,
  }) {
    return InvoiceLine(
      id: id ?? this.id,
      description: description ?? this.description,
      qty: qty ?? this.qty,
      subprice: subprice ?? this.subprice,
      totalHt: totalHt ?? this.totalHt,
      tvaTx: tvaTx ?? this.tvaTx,
      remisePercent: remisePercent ?? this.remisePercent,
      productRef: productRef ?? this.productRef,
      pricesIncludeVat: pricesIncludeVat ?? this.pricesIncludeVat,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
