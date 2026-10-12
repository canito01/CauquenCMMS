import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
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
    final pendingOrders = workOrders.where((o) => o.status == WorkOrderStatus.pendiente).toList();
    final pausedOrders = workOrders.where((o) => o.status == WorkOrderStatus.pausada).toList();
    final completedOrders = workOrders.where((o) => o.status == WorkOrderStatus.finalizada).toList();
    final preventiveOrders = workOrders.where((o) => o.type == WorkOrderType.preventivo).toList();
    
    // Averías críticas / Breakdowns (Correctivas o de Prioridad Urgente)
    final breakdownOrders = workOrders.where(
      (o) => o.priority == WorkOrderPriority.urgente || o.type == WorkOrderType.correctivo,
    ).toList();

    // Tarea activa en turno para acción rápida
    final activeOrder = inProgressOrders.isNotEmpty
        ? inProgressOrders.first
        : (pausedOrders.isNotEmpty ? pausedOrders.first : null);

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🦅 Cauquén CMMS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${currentUser?.name ?? "Operario de Planta"} • ${currentUser?.badge ?? "TEC-0000"}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/admin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.computer, size: 15, color: Colors.white),
              label: const Text('WEB ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (isOnline) {
            await ref.read(syncQueueProvider.notifier).processSyncQueue();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Alerta de sincronización offline/online
            if (syncQueue.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.primaryContainer : AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOnline ? AppColors.primary.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.sync : Icons.cloud_off_outlined,
                      color: isOnline ? AppColors.primary : AppColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline
                                ? 'Sincronización lista (${syncQueue.length} cambios pendientes)'
                                : 'Modo Offline: ${syncQueue.length} registros en cola local',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOnline
                                ? 'Toca "ENVIAR" para transferir evidencias al servidor.'
                                : 'Tus firmas y datos están seguros localmente en tu equipo.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isOnline)
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        onPressed: () {
                          ref.read(syncQueueProvider.notifier).processSyncQueue();
                        },
                        child: const Text('ENVIAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ],

            // Encabezado del Dashboard Operativo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PANEL DE CONTROL DE TURNO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$totalOrders OTs activas',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CUADRÍCULA DE 2 COLUMNAS CON BOTONES TÁCTILES GRANDES (DISEÑO INDUSTRIAL CAUQUÉN)
            Row(
              children: [
                // 1. AVERÍAS / BREAKDOWNS (Rojo bermellón #D32F2F crítico)
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'BREAKDOWNS',
                    subtitle: 'Averías Críticas',
                    value: breakdownOrders.length.toString(),
                    icon: Icons.warning_amber_rounded,
                    isCritical: true,
                    accentColor: AppColors.danger,
                    bgColor: AppColors.dangerContainer,
                    borderColor: AppColors.danger.withValues(alpha: 0.4),
                    onTap: () => context.go('/orders'),
                  ),
                ),
                const SizedBox(width: 12),
                // 2. EN PROCESO (Marrón tierra Cauquén #5C4033)
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'EN PROCESO',
                    subtitle: 'Ejecución en Planta',
                    value: inProgressOrders.length.toString(),
                    icon: Icons.timelapse_outlined,
                    accentColor: AppColors.warning,
                    bgColor: AppColors.surfaceSecondary,
                    borderColor: AppColors.border,
                    onTap: () => context.go('/orders'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 3. PREVENTIVO
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'PREVENTIVO',
                    subtitle: 'Planes Programados',
                    value: preventiveOrders.length.toString(),
                    icon: Icons.calendar_month_outlined,
                    accentColor: AppColors.primary,
                    bgColor: AppColors.surfaceSecondary,
                    borderColor: AppColors.border,
                    onTap: () => context.go('/orders'),
                  ),
                ),
                const SizedBox(width: 12),
                // 4. SOLICITUDES / PENDIENTES
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'SOLICITUDES',
                    subtitle: 'Nuevas Asignaciones',
                    value: pendingOrders.length.toString(),
                    icon: Icons.inbox_outlined,
                    accentColor: AppColors.primaryDark,
                    bgColor: AppColors.surfaceSecondary,
                    borderColor: AppColors.border,
                    onTap: () => context.go('/orders'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 5. FINALIZADAS
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'FINALIZADAS',
                    subtitle: 'Cierres de Turno',
                    value: completedOrders.length.toString(),
                    icon: Icons.task_alt_outlined,
                    accentColor: AppColors.success,
                    bgColor: AppColors.surfaceSecondary,
                    borderColor: AppColors.border,
                    onTap: () => context.go('/orders'),
                  ),
                ),
                const SizedBox(width: 12),
                // 6. TOTAL ASIGNADAS
                Expanded(
                  child: _buildTactileMetricButton(
                    context: context,
                    title: 'TOTAL GENERAL',
                    subtitle: 'Carga de Trabajo',
                    value: totalOrders.toString(),
                    icon: Icons.assignment_outlined,
                    accentColor: AppColors.primary,
                    bgColor: AppColors.surfaceSecondary,
                    borderColor: AppColors.border,
                    onTap: () => context.go('/orders'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tarea Activa en Turno (Acción Rápida)
            if (activeOrder != null) ...[
              const Text(
                'TAREA ACTIVA EN EJECUCIÓN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: activeOrder.status == WorkOrderStatus.enProceso
                        ? AppColors.primary
                        : AppColors.paused,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeOrder.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeOrder.status == WorkOrderStatus.enProceso
                                ? AppColors.warningContainer
                                : AppColors.pausedContainer,
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
                    const SizedBox(height: 8),
                    Text(
                      activeOrder.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Activo: ${activeOrder.asset.code} • ${activeOrder.asset.name} (${activeOrder.asset.location})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (activeOrder.pauseReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo de pausa: ${activeOrder.pauseReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.paused, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/execution/${activeOrder.id}');
                      },
                      icon: Icon(
                        activeOrder.status == WorkOrderStatus.enProceso ? Icons.play_arrow : Icons.replay,
                        size: 20,
                      ),
                      label: Text(
                        activeOrder.status == WorkOrderStatus.enProceso
                            ? 'CONTINUAR LABOR (${activeOrder.completedTasksCount}/${activeOrder.totalTasksCount} PASOS)'
                            : 'REANUDAR TAREA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Lista de Órdenes Recientes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ÓRDENES DE TRABAJO RECIENTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.go('/orders');
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('VER TODAS', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- Widget de Tarjeta Táctil Grande en Cuadrícula de 2 Columnas ---
  Widget _buildTactileMetricButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool isCritical = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 125),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isCritical ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  if (isCritical)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CRÍTICO',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isCritical ? AppColors.danger : AppColors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isCritical ? AppColors.danger : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
