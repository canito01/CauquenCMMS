import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../widgets/kpi_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workOrders = ref.watch(workOrdersProvider);
    final assets = ref.watch(assetsProvider);
    final inventory = ref.watch(inventoryProvider);

    final totalOrders = workOrders.length;
    final inProgressOrders = workOrders.where((o) => o.status == WorkOrderStatus.enProceso).length;
    final pausedOrders = workOrders.where((o) => o.status == WorkOrderStatus.pausada).length;
    final completedOrders = workOrders.where((o) => o.status == WorkOrderStatus.finalizada).length;
    final pendingOrders = workOrders.where((o) => o.status == WorkOrderStatus.pendiente).length;

    final urgentOrders = workOrders.where((o) => o.priority == WorkOrderPriority.urgente).length;
    final lowStockCount = inventory.where((p) => p.isLowStock).length;
    final criticalAssets = assets.where((a) => a.criticality == 'ALTA').length;

    // Calcular porcentaje de cumplimiento
    final complianceRate = totalOrders == 0 ? 100 : ((completedOrders / totalOrders) * 100).toInt();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Encabezado de Bienvenida
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Panel de Comando Industrial',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Monitoreo ejecutivo de órdenes, salud de activos y cuadrillas en tiempo real',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: const [
                  Icon(Icons.factory, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Planta Central • Turno Activo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Grid de KPIs Ejecutivos
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 950;
            final isMedium = constraints.maxWidth > 600;
            final crossAxisCount = isWide ? 4 : (isMedium ? 2 : 1);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 1.6 : 1.8,
              children: [
                KpiCard(
                  title: 'Órdenes Activas',
                  value: '${inProgressOrders + pausedOrders}',
                  subtitle: '$urgentOrders de prioridad urgente',
                  icon: Icons.precision_manufacturing,
                  color: AppColors.warning,
                  trend: '+2 hoy',
                  isTrendPositive: false,
                ),
                KpiCard(
                  title: 'Cumplimiento',
                  value: '$complianceRate%',
                  subtitle: '$completedOrders finalizadas de $totalOrders',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  trend: '+5.4%',
                  isTrendPositive: true,
                ),
                KpiCard(
                  title: 'MTTR Promedio',
                  value: '38 min',
                  subtitle: 'Tiempo medio de resolución en línea',
                  icon: Icons.timer_outlined,
                  color: AppColors.primary,
                  trend: '-12%',
                  isTrendPositive: true,
                ),
                KpiCard(
                  title: 'Alertas de Stock',
                  value: '$lowStockCount items',
                  subtitle: 'Repuestos bajo punto de pedido',
                  icon: Icons.inventory_2_outlined,
                  color: lowStockCount > 0 ? AppColors.danger : AppColors.success,
                  trend: lowStockCount > 0 ? 'Crítico' : 'Normal',
                  isTrendPositive: lowStockCount == 0,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Sección Central: Distribución de Tareas y Estado de Activos
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildOrdersStatusCard(workOrders, inProgressOrders, pausedOrders, completedOrders, pendingOrders)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildCriticalAssetsCard(assets, criticalAssets)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildOrdersStatusCard(workOrders, inProgressOrders, pausedOrders, completedOrders, pendingOrders),
                  const SizedBox(height: 20),
                  _buildCriticalAssetsCard(assets, criticalAssets),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 28),

        // Actividad Reciente de Técnicos en Planta
        _buildRecentActivitySection(workOrders),
      ],
    );
  }

  Widget _buildOrdersStatusCard(
    List<WorkOrderModel> workOrders,
    int inProgress,
    int paused,
    int completed,
    int pending,
  ) {
    final total = workOrders.isEmpty ? 1 : workOrders.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'DISTRIBUCIÓN OPERATIVA DE ÓRDENES (OT)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
              ),
              Icon(Icons.bar_chart, size: 18, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 20),

          // Barras de estado
          _buildStatusBar('En Proceso (Técnicos ejecutando en piso)', inProgress, total, AppColors.warning),
          const SizedBox(height: 14),
          _buildStatusBar('Pausadas (Espera de repuesto o turno)', paused, total, AppColors.paused),
          const SizedBox(height: 14),
          _buildStatusBar('Finalizadas y Firmadas', completed, total, AppColors.success),
          const SizedBox(height: 14),
          _buildStatusBar('Pendientes de Asignación', pending, total, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String label, int count, int total, Color color) {
    final pct = (count / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text('$count OT (${(pct * 100).toInt()}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.surfaceElevated,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildCriticalAssetsCard(List<dynamic> assets, int criticalCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MAQUINARIA CRÍTICA',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$criticalCount Alta Criticidad', style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...assets.take(4).map((asset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.settings, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asset.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${asset.code} • ${asset.location}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: asset.status == 'OPERATIVO'
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      asset.status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: asset.status == 'OPERATIVO' ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(List<WorkOrderModel> workOrders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'HISTORIAL RECIENTE DE AUDITORÍA Y EJECUCIÓN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
              ),
              Icon(Icons.history, size: 18, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          ...workOrders.take(5).map((order) {
            final hasPhotos = order.evidencePhotos.isNotEmpty;
            final isSigned = order.supervisorSignature != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: order.status == WorkOrderStatus.finalizada
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      order.status == WorkOrderStatus.finalizada ? Icons.verified : Icons.construction,
                      size: 16,
                      color: order.status == WorkOrderStatus.finalizada ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.orderNumber} • ${order.title}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Técnico: ${order.technicianName} (${order.technicianBadge}) • Activo: ${order.asset.code}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (hasPhotos)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.camera_alt, size: 10, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text('${order.evidencePhotos.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning)),
                            ],
                          ),
                        ),
                      if (isSigned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Firmado', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

