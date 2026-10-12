import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/crew_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/app_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Modal para Agregar o Modificar Personal ---
  void _showUserDialog({UserModel? userToEdit}) {
    final isEditing = userToEdit != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: userToEdit?.name ?? '');
    final badgeCtrl = TextEditingController(
      text: userToEdit?.badge ?? 'TEC-${(1000 + ref.read(usersProvider).length + 1)}',
    );
    final emailCtrl = TextEditingController(text: userToEdit?.email ?? '');
    final phoneCtrl = TextEditingController(text: userToEdit?.phone ?? '');
    final specialtyCtrl = TextEditingController(text: userToEdit?.specialty ?? 'Mecánica Industrial');

    UserRole selectedRole = userToEdit?.role ?? UserRole.technician;

    const validShifts = [
      'Turno Mañana (06:00 - 14:00)',
      'Turno Tarde (14:00 - 22:00)',
      'Turno Noche (22:00 - 06:00)',
      'Turno Rotativo',
    ];
    String selectedShift = userToEdit?.shift ?? validShifts.first;
    if (!validShifts.contains(selectedShift)) {
      selectedShift = validShifts.first;
    }

    final crews = ref.read(crewsProvider);
    final validCrewNames = crews.map((c) => c.name).toList();
    String? selectedCrew = userToEdit?.crewName;
    if (selectedCrew != null && !validCrewNames.contains(selectedCrew)) {
      selectedCrew = null;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.person_add, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Modificar Empleado / Operario' : 'Dar de Alta Nuevo Operario / Empleado'),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: nameCtrl,
                                autofocus: !isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre y Apellido *',
                                  hintText: 'Ej: Juan Pérez',
                                  prefixIcon: Icon(Icons.person_outline, size: 18),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'El nombre es obligatorio';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: badgeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Legajo / Código *',
                                  hintText: 'Ej: TEC-1045',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'El legajo es obligatorio';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Correo Electrónico',
                                  hintText: 'usuario@planta.com',
                                  prefixIcon: Icon(Icons.email_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono de Contacto',
                                  hintText: '+54 9 11 ...',
                                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<UserRole>(
                                initialValue: selectedRole,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(
                                  labelText: 'Rol en Sistema *',
                                  prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: UserRole.technician,
                                    child: Text('Técnico / Operario de Campo', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.supervisor,
                                    child: Text('Supervisor de Mantenimiento', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.admin,
                                    child: Text('Administrador de Planta', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedRole = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedShift,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(
                                  labelText: 'Turno Operativo *',
                                  prefixIcon: Icon(Icons.access_time, size: 18),
                                ),
                                items: validShifts.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedShift = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: specialtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especialidad Técnica',
                            hintText: 'Ej: Mecánica Industrial, Hidráulica, Neumática, PLC',
                            prefixIcon: Icon(Icons.handyman_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          initialValue: selectedCrew,
                          dropdownColor: AppColors.surfaceElevated,
                          decoration: const InputDecoration(
                            labelText: 'Asignar a Cuadrilla (Opcional)',
                            prefixIcon: Icon(Icons.groups_outlined, size: 18),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Sin cuadrilla fija (Técnico Independiente)', style: TextStyle(fontSize: 12)),
                            ),
                            ...crews.map((c) => DropdownMenuItem(
                                  value: c.name,
                                  child: Text('${c.name} (${c.shift})', style: const TextStyle(fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedCrew = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final user = UserModel(
                      id: isEditing ? userToEdit.id : const Uuid().v4(),
                      email: emailCtrl.text.trim().isEmpty ? '${badgeCtrl.text.trim().toLowerCase()}@planta.com' : emailCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      badge: badgeCtrl.text.trim().toUpperCase(),
                      role: selectedRole,
                      shift: selectedShift,
                      specialty: specialtyCtrl.text.trim().isEmpty ? 'Mantenimiento General' : specialtyCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      crewName: selectedCrew,
                    );

                    if (isEditing) {
                      await ref.read(usersProvider.notifier).updateUser(user);
                    } else {
                      await ref.read(usersProvider.notifier).addUser(user);
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? '✓ Operario ${user.name} actualizado' : '✓ Operario ${user.name} registrado con éxito'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Registrar Operario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirmación de Eliminar Personal ---
  void _confirmDeleteUser(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirmar Baja de Personal'),
        content: Text('¿Está seguro de que desea eliminar a ${user.name} (${user.badge}) de la nómina de planta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await ref.read(usersProvider.notifier).deleteUser(user.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Empleado ${user.name} eliminado de la nómina'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Dar de Baja'),
          ),
        ],
      ),
    );
  }

  // --- Modal para Armar o Modificar Cuadrilla ---
  void _showCrewDialog({CrewModel? crewToEdit}) {
    final isEditing = crewToEdit != null;
    final crewFormKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: crewToEdit?.name ?? '');
    final specialtyCtrl = TextEditingController(text: crewToEdit?.specialty ?? 'Mantenimiento General');
    final notesCtrl = TextEditingController(text: crewToEdit?.notes ?? '');

    const validShifts = [
      'Turno Mañana (06:00 - 14:00)',
      'Turno Tarde (14:00 - 22:00)',
      'Turno Noche (22:00 - 06:00)',
      'Turno Rotativo',
    ];
    String selectedShift = crewToEdit?.shift ?? validShifts.first;
    if (!validShifts.contains(selectedShift)) {
      selectedShift = validShifts.first;
    }

    final users = ref.read(usersProvider);
    final supervisors = users.where((u) => u.role == UserRole.supervisor || u.role == UserRole.admin).toList();
    final potentialLeaders = supervisors.isNotEmpty ? supervisors : users;

    String selectedLeader = crewToEdit?.leaderName ?? (potentialLeaders.isNotEmpty ? potentialLeaders.first.name : 'Carlos Méndez');
    String selectedLeaderBadge = crewToEdit?.leaderBadge ?? (potentialLeaders.isNotEmpty ? potentialLeaders.first.badge : 'SUP-1020');

    if (!potentialLeaders.any((u) => u.name == selectedLeader) && potentialLeaders.isNotEmpty) {
      selectedLeader = potentialLeaders.first.name;
      selectedLeaderBadge = potentialLeaders.first.badge;
    }

    final technicians = users.where((u) => u.role == UserRole.technician).toList();
    final selectableUsers = technicians.isNotEmpty ? technicians : users;
    List<String> selectedMembers = List<String>.from(crewToEdit?.memberNames ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.group_add, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Modificar Cuadrilla de Trabajo' : 'Armar Nueva Cuadrilla de Trabajo'),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: Form(
                  key: crewFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          autofocus: !isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la Cuadrilla *',
                            hintText: 'Ej: Cuadrilla Alfa - Mecánica & Neumática',
                            prefixIcon: Icon(Icons.groups, size: 18),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'El nombre de la cuadrilla es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedShift,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(
                                  labelText: 'Turno Asignado *',
                                  prefixIcon: Icon(Icons.access_time, size: 18),
                                ),
                                items: validShifts.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedShift = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedLeader,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(
                                  labelText: 'Líder / Supervisor a Cargo *',
                                  prefixIcon: Icon(Icons.verified_user_outlined, size: 18),
                                ),
                                items: potentialLeaders.map((u) {
                                  return DropdownMenuItem(value: u.name, child: Text('${u.name} (${u.badge})', style: const TextStyle(fontSize: 12)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final u = potentialLeaders.firstWhere((x) => x.name == val, orElse: () => potentialLeaders.first);
                                    setDialogState(() {
                                      selectedLeader = u.name;
                                      selectedLeaderBadge = u.badge;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: specialtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especialidad / Alcance',
                            hintText: 'Ej: Bombas, Válvulas, Circuitos Hidráulicos',
                            prefixIcon: Icon(Icons.handyman_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Sectores / Naves Asignadas',
                            hintText: 'Ej: Nave A Extrusión, Sala de Calderas',
                            prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Selección de Operarios Integrantes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SELECCIONAR OPERARIOS INTEGRANTES:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
                            ),
                            Text(
                              '${selectedMembers.length} seleccionados',
                              style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: selectableUsers.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: Text('No hay operarios registrados aún.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                                )
                              : Column(
                                  children: selectableUsers.map((tech) {
                                    final isSelected = selectedMembers.contains(tech.name);
                                    return CheckboxListTile(
                                      dense: true,
                                      title: Text(tech.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text('${tech.badge} • ${tech.specialty}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      value: isSelected,
                                      activeColor: AppColors.primary,
                                      onChanged: (bool? checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            selectedMembers.add(tech.name);
                                          } else {
                                            selectedMembers.remove(tech.name);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!crewFormKey.currentState!.validate()) return;

                    final crew = CrewModel(
                      id: isEditing ? crewToEdit.id : const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      shift: selectedShift,
                      specialty: specialtyCtrl.text.trim().isEmpty ? 'Mantenimiento General' : specialtyCtrl.text.trim(),
                      leaderName: selectedLeader,
                      leaderBadge: selectedLeaderBadge,
                      memberNames: selectedMembers,
                      notes: notesCtrl.text.trim(),
                    );

                    if (isEditing) {
                      await ref.read(crewsProvider.notifier).updateCrew(crew);
                    } else {
                      await ref.read(crewsProvider.notifier).addCrew(crew);
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? '✓ Cuadrilla ${crew.name} actualizada' : '✓ Cuadrilla ${crew.name} armada con éxito'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Confirmar y Crear Cuadrilla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirmación de Eliminar Cuadrilla ---
  void _confirmDeleteCrew(CrewModel crew) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Desarmar Cuadrilla'),
        content: Text('¿Está seguro de que desea desarmar la cuadrilla "${crew.name}"? Los operarios quedarán como independientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await ref.read(crewsProvider.notifier).deleteCrew(crew.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cuadrilla ${crew.name} desarmada'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Desarmar Cuadrilla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantUsers = ref.watch(usersProvider);
    final plantCrews = ref.watch(crewsProvider);

    final filteredUsers = plantUsers.where((u) {
      return _searchQuery.isEmpty ||
          u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.badge.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.specialty.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u.crewName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredCrews = plantCrews.where((c) {
      return _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.specialty.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.leaderName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Cabecera superior con tabs
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Administración de Personal & Cuadrillas',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Alta, baja, edición de nómina de operarios y conformación de equipos de trabajo',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showUserDialog(),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('AGREGAR OPERARIO / PERSONAL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCrewDialog(),
                        icon: const Icon(Icons.group_add, size: 16),
                        label: const Text('ARMAR NUEVA CUADRILLA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(icon: const Icon(Icons.people), text: 'Nómina de Personal (${filteredUsers.length})'),
                  Tab(icon: const Icon(Icons.groups), text: 'Cuadrillas & Equipos (${filteredCrews.length})'),
                ],
              ),
            ],
          ),
        ),

        // Barra de búsqueda rápida
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar persona por nombre, legajo, cuadrilla o especialidad...',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),

        // Contenido de las Pestañas
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- PESTAÑA 1: Nómina de Personal ---
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
                        columns: const [
                          DataColumn(label: Text('Legajo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Nombre y Apellido', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Rol de Planta', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Cuadrilla Asignada', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Turno Operativo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Especialidad', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredUsers.map((user) {
                          final isSupervisor = user.role == UserRole.supervisor;
                          final isAdmin = user.role == UserRole.admin;

                          return DataRow(
                            cells: [
                              DataCell(Text(user.badge, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSupervisor || isAdmin
                                          ? AppColors.warning.withValues(alpha: 0.2)
                                          : AppColors.primary.withValues(alpha: 0.2),
                                      child: Icon(
                                        isSupervisor || isAdmin ? Icons.verified_user : Icons.engineering,
                                        size: 14,
                                        color: isSupervisor || isAdmin ? AppColors.warning : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isSupervisor || isAdmin ? AppColors.warning : AppColors.primary).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    user.roleDisplayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSupervisor || isAdmin ? AppColors.warning : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  user.crewName ?? 'Sin cuadrilla',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: user.crewName != null ? Colors.white : AppColors.textMuted,
                                    fontWeight: user.crewName != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(Text(user.shift, style: const TextStyle(fontSize: 12))),
                              DataCell(Text(user.specialty, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                              DataCell(Text(user.phone ?? user.email, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                      tooltip: 'Modificar Empleado',
                                      onPressed: () => _showUserDialog(userToEdit: user),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                      tooltip: 'Dar de Baja',
                                      onPressed: () => _confirmDeleteUser(user),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              // --- PESTAÑA 2: Cuadrillas & Equipos ---
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (filteredCrews.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.groups_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No hay cuadrillas creadas aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Presiona el botón "ARMAR CUADRILLA" para agrupar operarios por turno y especialidad.', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showCrewDialog(),
                              icon: const Icon(Icons.group_add),
                              label: const Text('Crear Primera Cuadrilla'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520,
                        mainAxisExtent: 260,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredCrews.length,
                      itemBuilder: (context, index) {
                        final crew = filteredCrews[index];

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      crew.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                        tooltip: 'Editar Cuadrilla',
                                        onPressed: () => _showCrewDialog(crewToEdit: crew),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        tooltip: 'Desarmar Cuadrilla',
                                        onPressed: () => _confirmDeleteCrew(crew),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      crew.shift,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      crew.specialty,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Líder: ${crew.leaderName} (${crew.leaderBadge})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Integrantes de la cuadrilla:',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: crew.memberNames.isEmpty
                                        ? [
                                            const Text('Sin operarios asignados aún', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                          ]
                                        : crew.memberNames.map((name) {
                                            return Chip(
                                              backgroundColor: AppColors.surfaceElevated,
                                              side: const BorderSide(color: AppColors.border),
                                              avatar: const Icon(Icons.person, size: 14, color: AppColors.primary),
                                              label: Text(name, style: const TextStyle(fontSize: 11)),
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                            );
                                          }).toList(),
                                  ),
                                ),
                              ),
                              if (crew.notes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Sectores: ${crew.notes}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
