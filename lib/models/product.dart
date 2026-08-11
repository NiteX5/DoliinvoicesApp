/// Modelo de un producto o servicio de Dolibarr.
///
/// Se usa para el selector de productos al registrar líneas de factura
/// y para el autocompletado de productos escaneados por OCR/IA.
class Product {
  final int id;
  final String label;
  final String? ref;
  final String? code;
  final double? price;
  final double? tvaTx;
  final int type; // 0 = producto, 1 = servicio

  Product({
    required this.id,
    required this.label,
    this.ref,
    this.code,
    this.price,
    this.tvaTx,
    required this.type,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      label: json['label']?.toString() ?? '',
      ref: json['ref']?.toString(),
      code: json['code']?.toString(),
      price: double.tryParse(json['price']?.toString() ?? ''),
      tvaTx: double.tryParse(json['tva_tx']?.toString() ?? ''),
      type: int.tryParse(json['type']?.toString() ?? '0') ?? 0,
    );
  }
}
