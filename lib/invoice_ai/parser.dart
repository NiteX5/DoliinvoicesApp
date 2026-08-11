import 'models.dart';
import 'amount_utils.dart';
import 'date_utils.dart';

class InvoiceParser {
  static InvoiceResult parse(Map<String, dynamic> json) {
    final headerJson = json['header'] as Map<String, dynamic>?;
    final itemsJson = (json['items'] ?? json['productos']) as List<dynamic>?;

    return InvoiceResult(
      header: _parseHeader(headerJson),
      items: itemsJson != null
          ? itemsJson
              .map((item) => _parseItem(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  static InvoiceHeader _parseHeader(Map<String, dynamic>? json) {
    if (json == null) {
      return InvoiceHeader();
    }
    return InvoiceHeader(
      tipoDocumento: _asString(json['tipoDocumento']),
      numeroDocumento: _asString(json['numeroDocumento']),
      fecha: DateUtils.normalize(_asString(json['fecha'])),
      fechaVencimiento:
          DateUtils.normalize(_asString(json['fechaVencimiento'])),
      proveedor: _asString(json['proveedor']),
      rut: _asString(json['rut']),
      giro: _asString(json['giro']),
      direccion: _asString(json['direccion']),
      ciudad: _asString(json['ciudad']),
      moneda: _asString(json['moneda']),
      neto: _asDouble(json['neto']),
      exento: _asDouble(json['exento']),
      iva: _asDouble(json['iva']),
      otrosImpuestos: _asDouble(json['otrosImpuestos']),
      total: _asDouble(json['total']),
    );
  }

  static InvoiceItem _parseItem(Map<String, dynamic> json) {
    return InvoiceItem(
      tipoLinea: _asString(json['tipoLinea']),
      codigo: _asString(json['codigo']),
      descripcion: _asString(json['descripcion']),
      cantidad: _asDouble(json['cantidad']),
      unidad: _asString(json['unidad']),
      precioUnitario: _asDouble(json['precioUnitario']),
      descuento: _asDouble(json['descuento']),
      subtotal: _asDouble(json['subtotal']),
      iva: _asDouble(json['iva']),
      tasaIva: _asDouble(json['tasaIva']),
      totalLinea: _asDouble(json['totalLinea']),
      priceIncludesVat: json['priceIncludesVat'] as bool?,
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return AmountUtils.normalize(value.toString());
  }
}
