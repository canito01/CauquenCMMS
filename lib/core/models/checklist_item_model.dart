enum ChecklistItemType {
  booleanCheck,          // Inspección Conforme / Sí-No / Verificación
  numericMeasurement,    // Medición con unidad, rango minAcceptable y maxAcceptable
  photoRequired,         // Foto(s) obligatoria(s) (1 o múltiples fotos con cámara/galería)
  photoBeforeAfter,      // Foto Doble (Antes y Después de la tarea)
  textObservation,       // Entrada de texto / Notas obligatorias o libres
  singleChoice,          // Selección única entre opciones (ej: Conforme / Observado / No Aplica)
  multipleChoice,        // Selección múltiple / Sub-ítems verificables (MaintainX Checkboxes)
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

  // Propiedades para soporte multietapa y personalización MaintainX
  final String stageId;
  final String stageName;
  final bool isRequired;
  final String? photoUrl;
  final List<String> photoUrls;
  final int minPhotos; // Cantidad mínima de fotos requeridas en este paso (default 1)
  final int maxPhotos; // Cantidad máxima de fotos permitidas en este paso (default 5)
  final String? photoBeforeUrl;
  final String? photoAfterUrl;
  final List<String> options;
  final String? selectedOption;
  final List<String> selectedOptions;
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
    this.photoUrls = const [],
    this.minPhotos = 1,
    this.maxPhotos = 5,
    this.photoBeforeUrl,
    this.photoAfterUrl,
    this.options = const [],
    this.selectedOption,
    this.selectedOptions = const [],
    this.textValue,
  });

  /// Devuelve todas las fotos capturadas en este paso (compatible con `photoUrl` individual y `photoUrls` múltiple).
  List<String> get allPhotos {
    if (photoUrls.isNotEmpty) return photoUrls;
    if (photoUrl != null && photoUrl!.isNotEmpty) return [photoUrl!];
    return const [];
  }

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
        final requiredCount = minPhotos < 1 ? 1 : minPhotos;
        return allPhotos.length >= requiredCount || (isCompleted && allPhotos.isNotEmpty);
      case ChecklistItemType.photoBeforeAfter:
        return ((photoBeforeUrl != null &&
                photoBeforeUrl!.isNotEmpty &&
                photoAfterUrl != null &&
                photoAfterUrl!.isNotEmpty) ||
            isCompleted);
      case ChecklistItemType.textObservation:
        return (textValue != null && textValue!.trim().isNotEmpty) || isCompleted;
      case ChecklistItemType.singleChoice:
        return (selectedOption != null && selectedOption!.isNotEmpty) || isCompleted;
      case ChecklistItemType.multipleChoice:
        return selectedOptions.isNotEmpty || isCompleted;
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
    List<String>? photoUrls,
    int? minPhotos,
    int? maxPhotos,
    String? photoBeforeUrl,
    String? photoAfterUrl,
    List<String>? options,
    String? selectedOption,
    List<String>? selectedOptions,
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
      photoUrls: photoUrls ?? this.photoUrls,
      minPhotos: minPhotos ?? this.minPhotos,
      maxPhotos: maxPhotos ?? this.maxPhotos,
      photoBeforeUrl: photoBeforeUrl ?? this.photoBeforeUrl,
      photoAfterUrl: photoAfterUrl ?? this.photoAfterUrl,
      options: options ?? this.options,
      selectedOption: selectedOption ?? this.selectedOption,
      selectedOptions: selectedOptions ?? this.selectedOptions,
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
      'photoUrls': photoUrls,
      'minPhotos': minPhotos,
      'maxPhotos': maxPhotos,
      'photoBeforeUrl': photoBeforeUrl,
      'photoAfterUrl': photoAfterUrl,
      'options': options,
      'selectedOption': selectedOption,
      'selectedOptions': selectedOptions,
      'textValue': textValue,
    };
  }

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? 'booleanCheck';
    final parsedType = ChecklistItemType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ChecklistItemType.booleanCheck,
    );
    final rawPhotoUrls = List<String>.from(map['photoUrls'] as List? ?? []);
    final legacyPhotoUrl = map['photoUrl'] as String?;
    if (rawPhotoUrls.isEmpty && legacyPhotoUrl != null && legacyPhotoUrl.isNotEmpty) {
      rawPhotoUrls.add(legacyPhotoUrl);
    }

    return ChecklistItemModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      type: parsedType,
      isCompleted: map['isCompleted'] as bool? ?? false,
      numericValue: (map['numericValue'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      minAcceptable: (map['minAcceptable'] as num?)?.toDouble(),
      maxAcceptable: (map['maxAcceptable'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      stageId: map['stageId'] as String? ?? 'stg-1',
      stageName: map['stageName'] as String? ?? 'Etapa 1: Procedimientos Iniciales',
      isRequired: map['isRequired'] as bool? ?? true,
      photoUrl: legacyPhotoUrl ?? (rawPhotoUrls.isNotEmpty ? rawPhotoUrls.first : null),
      photoUrls: rawPhotoUrls,
      minPhotos: (map['minPhotos'] as num?)?.toInt() ?? 1,
      maxPhotos: (map['maxPhotos'] as num?)?.toInt() ?? 5,
      photoBeforeUrl: map['photoBeforeUrl'] as String?,
      photoAfterUrl: map['photoAfterUrl'] as String?,
      options: List<String>.from(map['options'] as List? ?? []),
      selectedOption: map['selectedOption'] as String?,
      selectedOptions: List<String>.from(map['selectedOptions'] as List? ?? []),
      textValue: map['textValue'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChecklistItemModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
