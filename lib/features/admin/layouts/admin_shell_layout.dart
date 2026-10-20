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
  bool _isSyncingCloud = false;

  Future<void> _handleCloudSync() async {
    if (_isSyncingCloud) return;
    setState(() => _isSyncingCloud = true);
    final ok = await ref.read(syncQueueProvider.notifier).syncAllBidirectional();
    if (mounted) {
      setState(() => _isSyncingCloud = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✓ Sincronización bidireccional con Supabase completada.'
                : 'No se pudo conectar con la nube. Operando con datos locales.',
          ),
          backgroundColor: ok ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  final List<String> _tabTitles = [
    'Panel General & Reportes',
    'Órdenes de Trabajo',
    'Parque de Activos',
    'Almacén de Repuestos & Stock',
    'Personal & Cuadrillas',
  ];

  Widget _buildSidebarContent(UserModel? user, {bool isDrawer = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Marca
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('🦅', style: TextStyle(fontSize: 18)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Portal Administrativo',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),

        // Menú de Navegación
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text(
            'GESTIÓN & OPERACIONES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        _buildNavItem(0, Icons.insert_chart_outlined, Icons.insert_chart, 'Panel & Reportes', isDrawer: isDrawer),
        _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Órdenes de Trabajo', isDrawer: isDrawer),
        _buildNavItem(2, Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Activos', isDrawer: isDrawer),
        _buildNavItem(3, Icons.inventory_2_outlined, Icons.inventory_2, 'Repuestos & Stock', isDrawer: isDrawer),
        _buildNavItem(4, Icons.people_outline, Icons.people, 'Personal & Cuadrillas', isDrawer: isDrawer),

        const Spacer(),
        const Divider(height: 1, thickness: 1, color: AppColors.border),

        // Switch a Modo Operario Móvil
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.phone_android, size: 15, color: AppColors.primary),
            label: const Text(
              'Modo Operario Móvil',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Perfil del Administrador Logueado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : 'A').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Administrador',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.roleDisplayName ?? 'Supervisión',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar Sesión',
                icon: const Icon(Icons.logout, size: 16, color: AppColors.textSecondary),
                hoverColor: AppColors.dangerContainer,
                splashRadius: 18,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isSupervisor = user?.role == UserRole.supervisor;
    final isAdmin = user?.role == UserRole.admin;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (!isSupervisor && !isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: Center(
          child: Container(
            width: 440,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.dangerContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 40, color: AppColors.danger),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Acceso Restringido',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Solo usuarios con perfil de Supervisión o Administración pueden acceder al portal de gestión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.phone_android, size: 16),
                    label: const Text('Ir a la App Móvil de Operario'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screensStack = IndexedStack(
      index: _selectedIndex,
      children: const [
        AdminDashboardScreen(),
        AdminWorkOrdersScreen(),
        AdminAssetsScreen(),
        AdminInventoryScreen(),
        AdminUsersScreen(),
      ],
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _tabTitles[_selectedIndex],
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          actions: [
            IconButton(
              tooltip: 'Sincronizar datos con celulares de planta (Supabase)',
              icon: _isSyncingCloud
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_sync_outlined, color: Colors.white),
              onPressed: _handleCloudSync,
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: ConnectivityBadge(),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surfaceLight,
          child: SafeArea(
            child: _buildSidebarContent(user, isDrawer: true),
          ),
        ),
        body: screensStack,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Row(
        children: [
          // Sidebar de Navegación Lateral (MaintainX SaaS Minimalista)
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(right: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: _buildSidebarContent(user, isDrawer: false),
          ),

          // Área de Contenido Principal
          Expanded(
            child: Column(
              children: [
                // Topbar Superior Minimalista
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _tabTitles[_selectedIndex],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.business, size: 12, color: AppColors.textMuted),
                                SizedBox(width: 5),
                                Text(
                                  'Planta Central • Nave Industrial A & B',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isSyncingCloud ? null : _handleCloudSync,
                            icon: _isSyncingCloud
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.cloud_sync_outlined, size: 16, color: AppColors.primary),
                            label: Text(
                              _isSyncingCloud ? 'Sincronizando...' : 'Sincronizar Nube',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const ConnectivityBadge(),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pantalla Activa
                Expanded(child: screensStack),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String title, {bool isDrawer = false}) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (isDrawer && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
