enum ChecklistItemType {
  booleanCheck,          // Inspección Conforme / Sí-No / Verificación
  numericMeasurement,    // Medición con unidad, rango minAcceptable y maxAcceptable
  photoRequired,         // Foto obligatoria (cámara/galería con preview)
  photoBeforeAfter,      // Foto Doble (Antes y Después de la tarea)
  textObservation,       // Entrada de texto / Notas obligatorias o libres
  singleChoice,          // Selección única entre opciones (ej: Conforme / Observado / No Aplica)
}

class ChecklistItemModel {
  final String id;
  final String title;
  final String description;
  final ChecklistItemType type;
  final bool isCompleted;
  final double? numericValue;
  final String? unit; // ej: bar, °C, A, V, mm, psi
  final double? minAcceptable;
  final double? maxAcceptable;
  final String? notes;

  // Nuevas propiedades para soporte multietapa y MaintainX
  final String stageId;
  final String stageName;
  final bool isRequired;
  final String? photoUrl;
  final String? photoBeforeUrl;
  final String? photoAfterUrl;
  final List<String> options;
  final String? selectedOption;
  final String? textValue;

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
    this.stageId = 'stg-1',
    this.stageName = 'Etapa 1: Procedimientos Iniciales',
    this.isRequired = true,
    this.photoUrl,
    this.photoBeforeUrl,
    this.photoAfterUrl,
    this.options = const [],
    this.selectedOption,
    this.textValue,
  });

  bool get isOutOfRange {
    if (type != ChecklistItemType.numericMeasurement || numericValue == null) {
      return false;
    }
    if (minAcceptable != null && numericValue! < minAcceptable!) return true;
    if (maxAcceptable != null && numericValue! > maxAcceptable!) return true;
    return false;
  }

  /// Comprueba si este paso cumple con los requisitos para considerarse completo y permitir el cierre.
  bool get isStepSatisfied {
    if (!isRequired) return true; // Si es opcional, no bloquea el avance
    switch (type) {
      case ChecklistItemType.booleanCheck:
        return isCompleted;
      case ChecklistItemType.numericMeasurement:
        return numericValue != null && isCompleted;
      case ChecklistItemType.photoRequired:
        return (photoUrl != null && photoUrl!.isNotEmpty) || isCompleted;
      case ChecklistItemType.photoBeforeAfter:
        return ((photoBeforeUrl != null && photoBeforeUrl!.isNotEmpty && photoAfterUrl != null && photoAfterUrl!.isNotEmpty) || isCompleted);
      case ChecklistItemType.textObservation:
        return (textValue != null && textValue!.trim().isNotEmpty) || isCompleted;
      case ChecklistItemType.singleChoice:
        return (selectedOption != null && selectedOption!.isNotEmpty) || isCompleted;
    }
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
    String? stageId,
    String? stageName,
    bool? isRequired,
    String? photoUrl,
    String? photoBeforeUrl,
    String? photoAfterUrl,
    List<String>? options,
    String? selectedOption,
    String? textValue,
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
      stageId: stageId ?? this.stageId,
      stageName: stageName ?? this.stageName,
      isRequired: isRequired ?? this.isRequired,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBeforeUrl: photoBeforeUrl ?? this.photoBeforeUrl,
      photoAfterUrl: photoAfterUrl ?? this.photoAfterUrl,
      options: options ?? this.options,
      selectedOption: selectedOption ?? this.selectedOption,
      textValue: textValue ?? this.textValue,
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
      'stageId': stageId,
      'stageName': stageName,
      'isRequired': isRequired,
      'photoUrl': photoUrl,
      'photoBeforeUrl': photoBeforeUrl,
      'photoAfterUrl': photoAfterUrl,
      'options': options,
      'selectedOption': selectedOption,
      'textValue': textValue,
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
      stageId: map['stageId'] as String? ?? 'stg-1',
      stageName: map['stageName'] as String? ?? 'Etapa 1: Procedimientos Iniciales',
      isRequired: map['isRequired'] as bool? ?? true,
      photoUrl: map['photoUrl'] as String?,
      photoBeforeUrl: map['photoBeforeUrl'] as String?,
      photoAfterUrl: map['photoAfterUrl'] as String?,
      options: List<String>.from(map['options'] as List? ?? []),
      selectedOption: map['selectedOption'] as String?,
      textValue: map['textValue'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChecklistItemModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
