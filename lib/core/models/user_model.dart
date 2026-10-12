enum UserRole {
  technician,
  supervisor,
  admin,
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String badge;
  final UserRole role;
  final String shift;
  final String specialty;
  final String? phone;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.badge,
    required this.role,
    required this.shift,
    required this.specialty,
    this.phone,
    this.avatarUrl,
  });

  String get roleDisplayName {
    switch (role) {
      case UserRole.technician:
        return 'Técnico de Campo';
      case UserRole.supervisor:
        return 'Supervisor de Planta';
      case UserRole.admin:
        return 'Administrador GMAO';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'badge': badge,
      'role': role.name,
      'shift': shift,
      'specialty': specialty,
      'phone': phone,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      badge: map['badge'] as String,
      role: UserRole.values.byName(map['role'] as String? ?? 'technician'),
      shift: map['shift'] as String? ?? 'Turno Mañana',
      specialty: map['specialty'] as String? ?? 'Mantenimiento General',
      phone: map['phone'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? badge,
    UserRole? role,
    String? shift,
    String? specialty,
    String? phone,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      badge: badge ?? this.badge,
      role: role ?? this.role,
      shift: shift ?? this.shift,
      specialty: specialty ?? this.specialty,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

