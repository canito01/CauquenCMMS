class WorkflowStageModel {
  final String id;
  final String name; // ej: "Etapa 1: Chequeo de Motor y Presión"
  final String description; // ej: "Verificación de motor, fluidos, manómetros y tablero"
  final int order; // 1, 2, 3...

  const WorkflowStageModel({
    required this.id,
    required this.name,
    this.description = '',
    this.order = 1,
  });

  WorkflowStageModel copyWith({
    String? id,
    String? name,
    String? description,
    int? order,
  }) {
    return WorkflowStageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'order': order,
    };
  }

  factory WorkflowStageModel.fromMap(Map<String, dynamic> map) {
    return WorkflowStageModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is WorkflowStageModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

