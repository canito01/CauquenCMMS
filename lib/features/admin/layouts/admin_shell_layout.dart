import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/app_providers.dart';
import '../../common/connectivity_badge.dart';
import '../screens/admin_assets_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_inventory_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_work_orders_screen.dart';

class AdminShellLayout extends ConsumerStatefulWidget {
  const AdminShellLayout({super.key});

  @override
  ConsumerState<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends ConsumerState<AdminShellLayout> {
  int _selectedIndex = 0;

  final List<String> _tabTitles = [
    'Panel General & KPIs',
    'Órdenes de Trabajo',
    'Parque de Activos',
    'Almacén de Repuestos',
    'Cuadrillas de Planta',
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isSupervisor = user?.role == UserRole.supervisor;
    final isAdmin = user?.role == UserRole.admin;

    if (!isSupervisor && !isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.danger),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 60, color: AppColors.danger),
                const SizedBox(height: 16),
                const Text('ACCESO RESTRINGIDO A ADMINISTRACIÓN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Solo usuarios con perfil de Supervisor o Administrador pueden acceder a este portal.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Ir a la App Móvil de Operario'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar de Navegación Lateral (Diseño Desktop Industrial)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Marca
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Center(
                          child: Text('🦅', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Cauquén CMMS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Portal Administrativo',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Menú de Navegación
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: const Text(
                    'GESTIÓN & OPERACIONES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Panel General'),
                _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Órdenes de Trabajo'),
                _buildNavItem(2, Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Parque de Activos'),
                _buildNavItem(3, Icons.inventory_2_outlined, Icons.inventory_2, 'Inventario & Stock'),
                _buildNavItem(4, Icons.badge_outlined, Icons.badge, 'Cuadrillas de Planta'),

                const Spacer(),
                const Divider(height: 1),

                // Botón para Cambiar a Vista de Operario Móvil
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.phone_android, size: 16, color: AppColors.warning),
                    label: const Text(
                      'VER MODO OPERARIO MÓVIL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Perfil del Administrador Logueado
                Container(
                  padding: const EdgeInsets.all(14),
                  color: AppColors.surfaceElevated,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSupervisor ? AppColors.warning.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                        child: Icon(
                          isSupervisor ? Icons.verified_user : Icons.engineering,
                          size: 18,
                          color: isSupervisor ? AppColors.warning : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Administrador',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.roleDisplayName ?? 'Supervisión',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar Sesión',
                        icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Área de Contenido Principal
          Expanded(
            child: Column(
              children: [
                // Topbar Superior
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _tabTitles[_selectedIndex],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Nave Industrial A & B • Planta Central',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          ConnectivityBadge(),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pantalla Activa
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      AdminDashboardScreen(),
                      AdminWorkOrdersScreen(),
                      AdminAssetsScreen(),
                      AdminInventoryScreen(),
                      AdminUsersScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String title) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

