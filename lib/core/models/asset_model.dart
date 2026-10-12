class AssetModel {
  final String id;
  final String code; // ej: BOM-002, EXT-014
  final String name;
  final String location; // Planta / Línea / Sector
  final String criticality; // ALTA, MEDIA, BAJA
  final String status; // OPERATIVO, EN_FALLA, EN_MANTENIMIENTO
  final String lastMaintenance;

  const AssetModel({
    required this.id,
    required this.code,
    required this.name,
    required this.location,
    required this.criticality,
    required this.status,
    required this.lastMaintenance,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'location': location,
      'criticality': criticality,
      'status': status,
      'lastMaintenance': lastMaintenance,
    };
  }

  factory AssetModel.fromMap(Map<String, dynamic> map) {
    return AssetModel(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      location: map['location'] as String,
      criticality: map['criticality'] as String,
      status: map['status'] as String,
      lastMaintenance: map['lastMaintenance'] as String? ?? 'N/A',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

