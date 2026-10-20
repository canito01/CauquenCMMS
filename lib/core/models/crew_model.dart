class CrewModel {
  final String id;
  final String name; // ej: Cuadrilla Alfa - Mecánica
  final String shift; // ej: Turno Mañana (06:00 - 14:00)
  final String specialty; // ej: Mantenimiento Mecánico y Neumático
  final String leaderName; // ej: Carlos Méndez
  final String leaderBadge; // ej: SUP-1020
  final List<String> memberNames; // Nombres de los integrantes
  final String notes;

  const CrewModel({
    required this.id,
    required this.name,
    required this.shift,
    required this.specialty,
    required this.leaderName,
    required this.leaderBadge,
    required this.memberNames,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shift': shift,
      'specialty': specialty,
      'leaderName': leaderName,
      'leaderBadge': leaderBadge,
      'memberNames': memberNames,
      'notes': notes,
    };
  }

  factory CrewModel.fromMap(Map<String, dynamic> map) {
    return CrewModel(
      id: map['id'] as String,
      name: map['name'] as String,
      shift: map['shift'] as String? ?? 'Turno Mañana',
      specialty: map['specialty'] as String? ?? 'Mantenimiento General',
      leaderName: map['leaderName'] as String? ?? 'Sin asignar',
      leaderBadge: map['leaderBadge'] as String? ?? 'SUP-0000',
      memberNames: List<String>.from(map['memberNames'] as List? ?? []),
      notes: map['notes'] as String? ?? '',
    );
  }

  CrewModel copyWith({
    String? id,
    String? name,
    String? shift,
    String? specialty,
    String? leaderName,
    String? leaderBadge,
    List<String>? memberNames,
    String? notes,
  }) {
    return CrewModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shift: shift ?? this.shift,
      specialty: specialty ?? this.specialty,
      leaderName: leaderName ?? this.leaderName,
      leaderBadge: leaderBadge ?? this.leaderBadge,
      memberNames: memberNames ?? this.memberNames,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrewModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

