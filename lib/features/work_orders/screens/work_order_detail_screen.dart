import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../common/connectivity_badge.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const WorkOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workOrders = ref.watch(workOrdersProvider);
    final order = workOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw Exception('OT no encontrada'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
            tooltip: 'Descargar Informe PDF Oficial',
            onPressed: () => PdfReportService.downloadOrPrintReport(order),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildActionButton(context, ref, order),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado con estado y tipo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.type.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título y descripción
          Text(
            order.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            order.description,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Ficha del Activo / Equipo
          _buildSectionHeader('EQUIPO / ACTIVO ASIGNADO'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildDataRow(
                    label: 'Código y Nombre:',
                    value: '${order.asset.code} - ${order.asset.name}',
                  ),
                  const Divider(),
                  _buildDataRow(
                    label: 'Ubicación Planta:',
                    value: order.asset.location,
                  ),
                  const Divider(),
                  _buildDataRow(
                    label: 'Criticidad:',
                    value: order.asset.criticality,
                    valueColor: order.asset.criticality == 'ALTA' ? AppColors.danger : null,
                  ),
                  const Divider(),
                  _buildDataRow(
                    label: 'Último Mantenimiento:',
                    value: order.asset.lastMaintenance,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Protocolo de Seguridad y EPP (Requerimiento de planta)
          if (order.safetyProtocols.isNotEmpty) ...[
            _buildSectionHeader('PROTOCOLO DE SEGURIDAD Y EPP OBLIGATORIO'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.safetyProtocols.map((protocol) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            protocol,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Repuestos e Insumos vinculados
          _buildSectionHeader('REPUESTOS E INSUMOS ASIGNADOS'),
          if (order.spareParts.isEmpty)
            const Text('No se asignaron repuestos para esta orden.', style: TextStyle(color: AppColors.textMuted))
          else
            ...order.spareParts.map((part) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.build_circle_outlined, color: AppColors.primary),
                  title: Text('${part.code} • ${part.description}'),
                  subtitle: Text('Almacén: ${part.locationWarehouse}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${part.consumedQuantity} ${part.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),

          // Tareas de Checklist
          _buildSectionHeader('RESUMEN DE CHECKLIST (${order.completedTasksCount}/${order.totalTasksCount})'),
          ...order.checklist.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.isCompleted ? AppColors.success : AppColors.textMuted,
                ),
                title: Text(item.title, style: const TextStyle(fontSize: 13)),
                subtitle: item.numericValue != null
                    ? Text('Medición: ${item.numericValue} ${item.unit ?? ""}')
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDataRow({required String label, required String value, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
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

  Widget _buildActionButton(BuildContext context, WidgetRef ref, WorkOrderModel order) {
    if (order.status == WorkOrderStatus.pendiente) {
      return ElevatedButton.icon(
        onPressed: () async {
          await ref.read(workOrdersProvider.notifier).startWorkOrder(order.id);
          if (context.mounted) {
            context.push('/execution/${order.id}');
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('INICIAR ORDEN DE TRABAJO'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (order.status == WorkOrderStatus.enProceso) {
      return ElevatedButton.icon(
        onPressed: () {
          context.push('/execution/${order.id}');
        },
        icon: const Icon(Icons.build),
        label: const Text('CONTINUAR EJECUCIÓN'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.black,
        ),
      );
    } else if (order.status == WorkOrderStatus.pausada) {
      return ElevatedButton.icon(
        onPressed: () async {
          await ref.read(workOrdersProvider.notifier).resumeWorkOrder(order.id);
          if (context.mounted) {
            context.push('/execution/${order.id}');
          }
        },
        icon: const Icon(Icons.replay),
        label: const Text('REANUDAR TAREA'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.paused,
          foregroundColor: Colors.white,
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () {
          context.push('/execution/${order.id}');
        },
        icon: const Icon(Icons.assignment_turned_in),
        label: const Text('VER INFORME Y FIRMA DE CIERRE'),
      );
    }
  }
}

