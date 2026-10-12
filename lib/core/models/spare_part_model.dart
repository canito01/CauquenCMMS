class SparePartModel {
  final String id;
  final String code; // ej: ROD-6204-2RS, COR-SPZ-1250
  final String description;
  final String locationWarehouse; // ej: Almacén Central - Estante B3
  final int stockAvailable;
  final String unit; // ej: un, m, l, kg
  final int consumedQuantity;

  const SparePartModel({
    required this.id,
    required this.code,
    required this.description,
    required this.locationWarehouse,
    required this.stockAvailable,
    required this.unit,
    this.consumedQuantity = 0,
  });

  bool get isLowStock => stockAvailable <= 5;

  SparePartModel copyWith({
    String? id,
    String? code,
    String? description,
    String? locationWarehouse,
    int? stockAvailable,
    String? unit,
    int? consumedQuantity,
  }) {
    return SparePartModel(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      locationWarehouse: locationWarehouse ?? this.locationWarehouse,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      unit: unit ?? this.unit,
      consumedQuantity: consumedQuantity ?? this.consumedQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'locationWarehouse': locationWarehouse,
      'stockAvailable': stockAvailable,
      'unit': unit,
      'consumedQuantity': consumedQuantity,
    };
  }

  factory SparePartModel.fromMap(Map<String, dynamic> map) {
    return SparePartModel(
      id: map['id'] as String,
      code: map['code'] as String,
      description: map['description'] as String,
      locationWarehouse: map['locationWarehouse'] as String,
      stockAvailable: (map['stockAvailable'] as num).toInt(),
      unit: map['unit'] as String? ?? 'un',
      consumedQuantity: (map['consumedQuantity'] as num?)?.toInt() ?? 0,
    );
  }
}

