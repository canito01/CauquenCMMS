import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/app_providers.dart';
import '../../common/connectivity_badge.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cerrar Sesión de Operador'),
        content: const Text(
          '¿Desea cerrar la sesión actual de la cuadrilla? Deberá ingresar legajo y contraseña nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncQueue = ref.watch(syncQueueProvider);
    final isOnline = ref.watch(isOnlineStateProvider);
    final connectivityService = ref.read(connectivityServiceProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isSupervisor = user?.role == UserRole.supervisor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil y Sincronización'),
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: () => _showLogoutDialog(context),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Perfil del Técnico de Planta
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isSupervisor
                        ? AppColors.warning.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.2),
                    child: Icon(
                      isSupervisor ? Icons.verified_user : Icons.engineering,
                      size: 34,
                      color: isSupervisor ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Operario de Planta',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Legajo: ${user?.badge ?? "TEC-0000"} • ${user?.shift ?? "Turno General"}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.roleDisplayName ?? "Técnico"} • ${user?.specialty ?? "Mantenimiento"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar Sesión',
                    icon: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                    onPressed: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Acceso al Portal Administrativo Web
          Card(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primary),
            ),
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 30),
              title: const Text('Portal Administrativo Web', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Gestione órdenes, inventarios, KPIs y catálogo de activos'),
              trailing: const Icon(Icons.arrow_forward, color: AppColors.primary),
              onTap: () => context.go('/admin'),
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta de Estado de Base de Datos Cloud (Supabase)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SupabaseConfig.isConfigured
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SupabaseConfig.isConfigured ? AppColors.success : AppColors.primary,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  SupabaseConfig.isConfigured ? Icons.cloud_done : Icons.cloud_queue,
                  color: SupabaseConfig.isConfigured ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SupabaseConfig.isConfigured
                            ? 'Base de Datos Cloud: Conectada (Supabase)'
                            : 'Base de Datos Cloud: Supabase Listo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        SupabaseConfig.isConfigured
                            ? 'Sincronizando directamente con PostgreSQL y Storage.'
                            : 'Script SQL generado en supabase_schema.sql. Pega tus claves en supabase_config.dart para activar el enlace.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Control de Motor Offline-First
          const Text(
            'MOTOR OFFLINE-FIRST Y COBERTURA DE PLANTA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: isOnline ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Conectado a Red de Planta' : 'Modo Sin Cobertura (Offline)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              isOnline
                                  ? 'Sincronización en tiempo real habilitada'
                                  : 'Operando localmente en SQLite/Caché',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: !connectivityService.isSimulatedOffline,
                      activeThumbColor: AppColors.success,
                      inactiveTrackColor: AppColors.warning.withValues(alpha: 0.3),
                      inactiveThumbColor: AppColors.warning,
                      onChanged: (_) {
                        connectivityService.toggleSimulateOffline();
                        ref.read(isOnlineStateProvider.notifier).updateStatus(connectivityService.isOnline);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eventos pendientes en cola local:',
                            style: TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${syncQueue.length} mutaciones en espera',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: syncQueue.isEmpty ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: (!isOnline || syncQueue.isEmpty || _isSyncing)
                          ? null
                          : () async {
                              setState(() => _isSyncing = true);
                              await ref.read(syncQueueProvider.notifier).processSyncQueue();
                              setState(() => _isSyncing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('¡Datos y firmas sincronizados con éxito con el servidor!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync, size: 16),
                      label: Text(_isSyncing ? 'Enviando...' : 'Sincronizar Ya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(130, 38),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Historial de la Cola de Sincronización
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COLA DE CAMBIOS LOCALES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              if (syncQueue.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(syncQueueProvider.notifier).clearSyncQueue();
                  },
                  child: const Text('Limpiar Cola', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (syncQueue.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: const [
                  Icon(Icons.cloud_done_outlined, size: 40, color: AppColors.success),
                  SizedBox(height: 8),
                  Text(
                    'Todos los datos están sincronizados',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No hay órdenes ni firmas pendientes de envío.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...syncQueue.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.pending_actions, color: AppColors.warning),
                  title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    DateFormat('dd/MM HH:mm:ss').format(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.actionType.name.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

