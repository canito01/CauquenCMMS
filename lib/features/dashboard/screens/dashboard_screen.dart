import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../common/connectivity_badge.dart';
import '../../work_orders/widgets/work_order_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workOrders = ref.watch(workOrdersProvider);
    final syncQueue = ref.watch(syncQueueProvider);
    final isOnline = ref.watch(isOnlineStateProvider);

    final totalOrders = workOrders.length;
    final inProgressOrders = workOrders.where((o) => o.status == WorkOrderStatus.enProceso).toList();
    final pendingOrders = workOrders.where((o) => o.status == WorkOrderStatus.pendiente).length;
    final pausedOrders = workOrders.where((o) => o.status == WorkOrderStatus.pausada).toList();
    final completedOrders = workOrders.where((o) => o.status == WorkOrderStatus.finalizada).length;

    // Buscar si hay una OT actualmente en proceso o pausada para acción rápida
    final activeOrder = inProgressOrders.isNotEmpty
        ? inProgressOrders.first
        : (pausedOrders.isNotEmpty ? pausedOrders.first : null);

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🦅 Cauquén CMMS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${currentUser?.name ?? "Operario de Planta"} • ${currentUser?.badge ?? "TEC-0000"}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (currentUser?.role == UserRole.supervisor || currentUser?.role == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
              tooltip: 'Portal Administrativo Web',
              onPressed: () => context.go('/admin'),
            ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (isOnline) {
            await ref.read(syncQueueProvider.notifier).processSyncQueue();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Alerta de sincronización si hay elementos pendientes en cola
            if (syncQueue.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOnline ? AppColors.primary : AppColors.warning,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.sync : Icons.cloud_off,
                      color: isOnline ? AppColors.primary : AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline
                                ? 'Sincronización lista (${syncQueue.length} cambios)'
                                : 'Modo Offline: ${syncQueue.length} eventos en espera',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            isOnline
                                ? 'Pulsa para enviar las evidencias y firmas al servidor.'
                                : 'Los cambios se guardan localmente y se enviarán al volver la red.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isOnline)
                      TextButton(
                        onPressed: () {
                          ref.read(syncQueueProvider.notifier).processSyncQueue();
                        },
                        child: const Text('ENVIAR'),
                      ),
                  ],
                ),
              ),
            ],

            // KPIs Grid
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'EN PROCESO',
                    value: inProgressOrders.length.toString(),
                    color: AppColors.warning,
                    icon: Icons.timelapse,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'PENDIENTES',
                    value: pendingOrders.toString(),
                    color: AppColors.textSecondary,
                    icon: Icons.pending_actions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'FINALIZADAS',
                    value: completedOrders.toString(),
                    color: AppColors.success,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'TOTAL ASIGNADAS',
                    value: totalOrders.toString(),
                    color: AppColors.primary,
                    icon: Icons.assignment_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tarjeta de Retomar OT Activa (Requerimiento clave del PDF)
            if (activeOrder != null) ...[
              const Text(
                'TAREA ACTIVA EN TURNO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeOrder.status == WorkOrderStatus.enProceso
                        ? AppColors.warning
                        : AppColors.paused,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeOrder.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: activeOrder.status == WorkOrderStatus.enProceso
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.paused.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activeOrder.status == WorkOrderStatus.enProceso ? 'EN CURSO' : 'PAUSADA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: activeOrder.status == WorkOrderStatus.enProceso
                                  ? AppColors.warning
                                  : AppColors.paused,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeOrder.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Activo: ${activeOrder.asset.code} • ${activeOrder.asset.location}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (activeOrder.pauseReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo de pausa: ${activeOrder.pauseReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.paused, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/execution/${activeOrder.id}');
                      },
                      icon: Icon(
                        activeOrder.status == WorkOrderStatus.enProceso ? Icons.play_arrow : Icons.replay,
                      ),
                      label: Text(
                        activeOrder.status == WorkOrderStatus.enProceso
                            ? 'CONTINUAR (${activeOrder.completedTasksCount}/${activeOrder.totalTasksCount})'
                            : 'REANUDAR TAREA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeOrder.status == WorkOrderStatus.enProceso
                            ? AppColors.warning
                            : AppColors.paused,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Lista de OTs del Día
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ÓRDENES DE TRABAJO RECIENTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.go('/orders');
                  },
                  child: const Text('VER TODAS'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...workOrders.take(3).map((order) {
              return WorkOrderCard(
                order: order,
                onTap: () {
                  context.push('/order/${order.id}');
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

