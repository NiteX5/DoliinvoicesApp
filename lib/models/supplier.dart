class Supplier {
  final int? id;
  final String name;
  final String? rut;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? country;
  final String? giro;
  final String? contactName;
  final int? status; // 0 = inactivo, 1 = activo (estado Dolibarr)

  Supplier({
    this.id,
    required this.name,
    this.rut,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.country,
    this.giro,
    this.contactName,
    this.status,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: _asInt(json['id']),
      name: _asString(json['name'] ?? json['label']) ?? '',
      rut: _asString(json['idprof1'] ?? json['vat_number']),
      email: _asString(json['email']),
      phone: _asString(json['phone']),
      address: _asString(json['address']),
      city: _asString(json['town']),
      country: _asString(json['country_code']),
      giro: _asString(json['giro']),
      contactName: _asString(json['contact_name']),
      status: _asInt(json['status']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Supplier && other.id == id && id != null;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (rut != null) 'idprof1': rut,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'town': city,
      if (country != null) 'country_code': country,
      if (giro != null) 'giro': giro,
      if (contactName != null) 'contact_name': contactName,
      'type': 1, // 1 = proveedor
    };
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

  Supplier copyWith({
    int? id,
    String? name,
    String? rut,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    String? giro,
    String? contactName,
    int? status,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      rut: rut ?? this.rut,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      giro: giro ?? this.giro,
      contactName: contactName ?? this.contactName,
      status: status ?? this.status,
    );
  }
}
