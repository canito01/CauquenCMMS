import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../common/connectivity_badge.dart';
import '../../work_orders/widgets/report_breakdown_sheet.dart';
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
    final canAccessAdmin = currentUser?.role == UserRole.supervisor || currentUser?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🦅 Cauquén CMMS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${currentUser?.name ?? "Operario de Planta"} • ${currentUser?.badge ?? "TEC-0000"}',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (canAccessAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: OutlinedButton.icon(
                onPressed: () => context.go('/admin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.dashboard_customize_outlined, size: 14, color: Colors.white),
                label: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Sincronizar órdenes y plantillas con la central',
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
            onPressed: () async {
              final ok = await ref.read(syncQueueProvider.notifier).syncAllBidirectional();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '✓ Órdenes y plantillas sincronizadas con la central.'
                          : 'Modo Offline activo. Trabajando con datos locales.',
                    ),
                    backgroundColor: ok ? AppColors.success : AppColors.warning,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (isOnline) {
            await ref.read(syncQueueProvider.notifier).syncAllBidirectional();
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            // Alerta de sincronización offline/online (100% ancho)
            if (syncQueue.isNotEmpty) ...[
              Container(
                width: double.infinity,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$totalOrders OTs activas',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CUADRÍCULA DE 2 COLUMNAS CON BOTONES TÁCTILES GRANDES (OCUPA 100% DEL ANCHO)
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
                const SizedBox(width: 10),
                // 2. EN PROCESO
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
            const SizedBox(height: 10),
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
                const SizedBox(width: 10),
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
            const SizedBox(height: 10),
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
                const SizedBox(width: 10),
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
            const SizedBox(height: 14),

            // Botón Rápido para que el Operario Reporte una Avería o Solicitud en Planta (Estilo MaintainX)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => ReportBreakdownSheet.show(context),
                icon: const Icon(Icons.add_alert_rounded, size: 20),
                label: const Text(
                  '+ REPORTAR AVERÍA O SOLICITUD EN PLANTA',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Tarea Activa en Turno (Acción Rápida 100% Ancho)
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
                width: double.infinity,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activeOrder.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                          ),
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
                              fontWeight: FontWeight.w800,
                              color: activeOrder.status == WorkOrderStatus.enProceso
                                  ? AppColors.warning
                                  : AppColors.paused,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      activeOrder.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.precision_manufacturing_outlined, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${activeOrder.asset.code} • ${activeOrder.asset.name} (${activeOrder.asset.location})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Barra de progreso MaintainX a ancho completo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Avance del Protocolo (${activeOrder.resolvedStages.length} etapas)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${activeOrder.completedTasksCount}/${activeOrder.totalTasksCount} pasos (${(activeOrder.progressPercentage * 100).toInt()}%)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: activeOrder.progressPercentage,
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    if (activeOrder.pauseReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Motivo de pausa: ${activeOrder.pauseReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.paused, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
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
                              : 'REANUDAR TAREA EN PLANTA',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
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
                  child: const Text('VER TODAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            ...workOrders.take(4).map((order) {
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
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 118),
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
              const SizedBox(height: 10),
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
