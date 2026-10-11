import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/work_order_model.dart';

class WorkOrderCard extends StatelessWidget {
  final WorkOrderModel order;
  final VoidCallback onTap;

  const WorkOrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  Color _getPriorityColor(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.urgente:
        return AppColors.danger;
      case WorkOrderPriority.alta:
        return AppColors.warning;
      case WorkOrderPriority.normal:
        return AppColors.primary;
      case WorkOrderPriority.baja:
        return AppColors.textMuted;
    }
  }

  Color _getStatusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.pendiente:
        return AppColors.textSecondary;
      case WorkOrderStatus.enProceso:
        return AppColors.warning;
      case WorkOrderStatus.pausada:
        return AppColors.paused;
      case WorkOrderStatus.finalizada:
        return AppColors.success;
    }
  }

  String _getStatusText(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.pendiente:
        return 'PENDIENTE';
      case WorkOrderStatus.enProceso:
        return 'EN PROCESO';
      case WorkOrderStatus.pausada:
        return 'PAUSADA';
      case WorkOrderStatus.finalizada:
        return 'FINALIZADA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(order.priority);
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: OT Number + Prioridad + Estado Sync
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: priorityColor, width: 0.8),
                        ),
                        child: Text(
                          order.priority.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: priorityColor,
                          ),
                        ),
                      ),
                      if (order.evidencePhotos.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt, size: 11, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text(
                                '${order.evidencePhotos.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (order.syncStatus == SyncStatus.pendingSync) ...[
                        const Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.warning),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Título
              Text(
                order.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Información de Activo y Ubicación
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.asset.code} - ${order.asset.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.asset.location,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Barra de progreso de checklist
              if (order.totalTasksCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tareas: ${order.completedTasksCount}/${order.totalTasksCount}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${(order.progressPercentage * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: order.progressPercentage,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    order.status == WorkOrderStatus.finalizada ? AppColors.success : AppColors.primary,
                  ),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

