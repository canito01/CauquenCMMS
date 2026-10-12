enum StockMovementType {
  entrada,
  salida,
  ajuste,
}

class StockMovementModel {
  final String id;
  final String partId;
  final String partCode;
  final String partDescription;
  final StockMovementType type;
  final int quantity; // positivo
  final int previousStock;
  final int newStock;
  final String reason;
  final String performedBy;
  final DateTime timestamp;

  const StockMovementModel({
    required this.id,
    required this.partId,
    required this.partCode,
    required this.partDescription,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    required this.reason,
    required this.performedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'partId': partId,
      'partCode': partCode,
      'partDescription': partDescription,
      'type': type.name,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'reason': reason,
      'performedBy': performedBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as String,
      partId: map['partId'] as String,
      partCode: map['partCode'] as String,
      partDescription: map['partDescription'] as String,
      type: StockMovementType.values.byName(map['type'] as String? ?? 'ajuste'),
      quantity: (map['quantity'] as num).toInt(),
      previousStock: (map['previousStock'] as num).toInt(),
      newStock: (map['newStock'] as num).toInt(),
      reason: map['reason'] as String? ?? 'Ajuste manual',
      performedBy: map['performedBy'] as String? ?? 'Supervisor',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp'] as String) : DateTime.now(),
    );
  }
}

