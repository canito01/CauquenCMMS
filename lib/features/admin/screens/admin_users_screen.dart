import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/mock_data_service.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final plantUsers = MockDataService.getMockUsers();

    final filtered = plantUsers.where((u) {
      return _searchQuery.isEmpty ||
          u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.badge.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.specialty.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cuadrillas y Personal Técnico de Planta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${filtered.length} operarios habilitados con credencial de acceso', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, legajo o especialidad técnica...',
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 20),

        // Tabla de Usuarios
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
              columns: const [
                DataColumn(label: Text('Legajo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Nombre y Apellido', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Rol de Planta', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Turno Operativo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Especialidad Técnica', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Contacto de Guardia', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((user) {
                final isSupervisor = user.role == UserRole.supervisor;

                return DataRow(
                  cells: [
                    DataCell(Text(user.badge, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isSupervisor ? AppColors.warning.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                            child: Icon(
                              isSupervisor ? Icons.verified_user : Icons.engineering,
                              size: 14,
                              color: isSupervisor ? AppColors.warning : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSupervisor ? AppColors.warning.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.roleDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSupervisor ? AppColors.warning : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(user.shift, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(user.specialty, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    DataCell(Text(user.phone ?? 'N/A', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

