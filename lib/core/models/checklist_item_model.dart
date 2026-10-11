enum ChecklistItemType {
  booleanCheck,
  numericMeasurement,
  textObservation,
}

class ChecklistItemModel {
  final String id;
  final String title;
  final String description;
  final ChecklistItemType type;
  final bool isCompleted;
  final double? numericValue;
  final String? unit; // ej: bar, °C, A, V, mm
  final double? minAcceptable;
  final double? maxAcceptable;
  final String? notes;

  const ChecklistItemModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.isCompleted = false,
    this.numericValue,
    this.unit,
    this.minAcceptable,
    this.maxAcceptable,
    this.notes,
  });

  bool get isOutOfRange {
    if (type != ChecklistItemType.numericMeasurement || numericValue == null) {
      return false;
    }
    if (minAcceptable != null && numericValue! < minAcceptable!) return true;
    if (maxAcceptable != null && numericValue! > maxAcceptable!) return true;
    return false;
  }

  ChecklistItemModel copyWith({
    String? id,
    String? title,
    String? description,
    ChecklistItemType? type,
    bool? isCompleted,
    double? numericValue,
    String? unit,
    double? minAcceptable,
    double? maxAcceptable,
    String? notes,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      numericValue: numericValue ?? this.numericValue,
      unit: unit ?? this.unit,
      minAcceptable: minAcceptable ?? this.minAcceptable,
      maxAcceptable: maxAcceptable ?? this.maxAcceptable,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'isCompleted': isCompleted,
      'numericValue': numericValue,
      'unit': unit,
      'minAcceptable': minAcceptable,
      'maxAcceptable': maxAcceptable,
      'notes': notes,
    };
  }

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
    return ChecklistItemModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      type: ChecklistItemType.values.byName(map['type'] as String? ?? 'booleanCheck'),
      isCompleted: map['isCompleted'] as bool? ?? false,
      numericValue: (map['numericValue'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      minAcceptable: (map['minAcceptable'] as num?)?.toDouble(),
      maxAcceptable: (map['maxAcceptable'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

