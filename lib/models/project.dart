class Project {
  final int? id;
  final String ref;
  final String title;
  final String? description;
  final String? dateStart;
  final String? dateEnd;
  final int? status;
  final int? fkSoc;
  final String? thirdPartyName;

  Project({
    this.id,
    required this.ref,
    required this.title,
    this.description,
    this.dateStart,
    this.dateEnd,
    this.status,
    this.fkSoc,
    this.thirdPartyName,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: _asInt(json['id']),
      ref: _asString(json['ref']) ?? '',
      title: _asString(json['title'] ?? json['label']) ?? '',
      description: _asString(json['description']),
      dateStart: _asString(json['date_start']),
      dateEnd: _asString(json['date_end']),
      status: _asInt(json['status']),
      fkSoc: _asInt(json['fk_soc']),
      thirdPartyName: _asString(json['thirdparty_name'] ?? json['client_name']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id && id != null;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ref': ref,
      'title': title,
      if (description != null) 'description': description,
      if (dateStart != null) 'date_start': dateStart,
      if (dateEnd != null) 'date_end': dateEnd,
      if (status != null) 'status': status,
      if (fkSoc != null) 'fk_soc': fkSoc,
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

  Project copyWith({
    int? id,
    String? ref,
    String? title,
    String? description,
    String? dateStart,
    String? dateEnd,
    int? status,
    int? fkSoc,
    String? thirdPartyName,
  }) {
    return Project(
      id: id ?? this.id,
      ref: ref ?? this.ref,
      title: title ?? this.title,
      description: description ?? this.description,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      status: status ?? this.status,
      fkSoc: fkSoc ?? this.fkSoc,
      thirdPartyName: thirdPartyName ?? this.thirdPartyName,
    );
  }
}
