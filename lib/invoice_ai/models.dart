class OcrWord {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

class OcrLine {
  final List<OcrWord> words;
  final double left;
  final double top;
  final double right;
  final double bottom;

  OcrLine({
    required this.words,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  String get text => words.map((w) => w.text).join(' ');
  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

class OcrDocument {
  final double width;
  final double height;
  final List<OcrLine> lines;
  final List<OcrWord> words; // Todas las palabras con coordenadas para alineación de columnas

  OcrDocument({
    required this.width,
    required this.height,
    required this.lines,
    required this.words,
  });
}

enum DocumentType {
  unknown,
  factura,
  boleta,
}

class OcrResult {
  final OcrDocument document;
  final DocumentType documentType;

  OcrResult({
    required this.document,
    required this.documentType,
  });
}

class InvoiceHeader {
  final String? tipoDocumento;
  final String? numeroDocumento;
  final String? fecha;
  final String? fechaVencimiento;
  final String? proveedor;
  final String? rut;
  final String? giro;
  final String? direccion;
  final String? ciudad;
  final String? moneda;
  final double? neto;
  final double? exento;
  final double? iva;
  final double? otrosImpuestos;
  final double? total;

  InvoiceHeader({
    this.tipoDocumento,
    this.numeroDocumento,
    this.fecha,
    this.fechaVencimiento,
    this.proveedor,
    this.rut,
    this.giro,
    this.direccion,
    this.ciudad,
    this.moneda,
    this.neto,
    this.exento,
    this.iva,
    this.otrosImpuestos,
    this.total,
  });
}

class InvoiceItem {
  final String? tipoLinea;
  final String? codigo;
  final String? descripcion;
  final double? cantidad;
  final String? unidad;
  final double? precioUnitario;
  final double? descuento;
  final double? subtotal;
  final double? iva;
  final double? tasaIva;
  final double? totalLinea;
  final bool? priceIncludesVat;

  InvoiceItem({
    this.tipoLinea,
    this.codigo,
    this.descripcion,
    this.cantidad,
    this.unidad,
    this.precioUnitario,
    this.descuento,
    this.subtotal,
    this.iva,
    this.tasaIva,
    this.totalLinea,
    this.priceIncludesVat,
  });
}

class InvoiceResult {
  final InvoiceHeader header;
  final List<InvoiceItem> items;

  InvoiceResult({
    required this.header,
    required this.items,
  });
}

class DolibarrInvoiceItem {
  final String description;
  final num qty;
  final String subprice;
  final String totalHt;
  final num tvaTx;
  final num remisePercent;
  final bool priceIncludesVat;

  DolibarrInvoiceItem({
    required this.description,
    required this.qty,
    required this.subprice,
    required this.totalHt,
    required this.tvaTx,
    this.remisePercent = 0,
    this.priceIncludesVat = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'qty': qty,
      'subprice': subprice,
      'total_ht': totalHt,
      'tva_tx': tvaTx,
      'remise_percent': remisePercent,
      'price_includes_vat': priceIncludesVat,
    };
  }
}

class DolibarrInvoiceResult {
  final String? refSupplier;
  final String? date;
  final String? supplier;
  final String? supplierRut;
  final String? supplierGiro;
  final String? supplierDireccion;
  final String? supplierCiudad;
  final String? supplierEmail;
  final String? supplierPhone;
  final String? totalTtc;
  final String? totalHt;
  final String? totalTva;
  // Campos de condiciones de pago
  final int? condReglementId;
  final String? dateLimReglement;
  final int? modeReglementId;
  final List<DolibarrInvoiceItem> items;

  DolibarrInvoiceResult({
    this.refSupplier,
    this.date,
    this.supplier,
    this.supplierRut,
    this.supplierGiro,
    this.supplierDireccion,
    this.supplierCiudad,
    this.supplierEmail,
    this.supplierPhone,
    this.totalTtc,
    this.totalHt,
    this.totalTva,
    this.condReglementId,
    this.dateLimReglement,
    this.modeReglementId,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      if (refSupplier != null) 'numero_factura': refSupplier,
      if (date != null) 'fecha': date,
      if (supplier != null) 'proveedor': supplier,
      if (supplierRut != null) 'rut': supplierRut,
      if (supplierGiro != null) 'giro': supplierGiro,
      if (supplierDireccion != null) 'direccion': supplierDireccion,
      if (supplierCiudad != null) 'ciudad': supplierCiudad,
      if (supplierEmail != null) 'email': supplierEmail,
      if (supplierPhone != null) 'phone': supplierPhone,
      if (totalTtc != null) 'monto_total': totalTtc,
      if (totalHt != null) 'neto': totalHt,
      'iva': totalTva ?? '0.00',
      if (condReglementId != null) 'cond_reglement_id': condReglementId,
      if (dateLimReglement != null) 'date_lim_reglement': dateLimReglement,
      if (modeReglementId != null) 'mode_reglement_id': modeReglementId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
