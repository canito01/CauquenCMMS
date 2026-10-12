import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/checklist_item_model.dart';
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

    final isUrgent = order.priority == WorkOrderPriority.urgente;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: Text(
            order.orderNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Descargar Informe PDF Oficial',
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text('Generando informe para ${order.orderNumber}...'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  final filename = await PdfReportService.downloadOrPrintReport(order);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Archivo "$filename" descargado con éxito.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: ConnectivityBadge(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: AppColors.surface,
              child: TabBar(
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Tareas'),
                  Tab(text: 'Repuestos'),
                  Tab(text: 'Comentarios'),
                ],
              ),
            ),
          ),
        ),
        // TEMPORIZADOR DE LABOR (WORK TIMER) FIJO EN LA PARTE INFERIOR
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Temporizador de labor destacado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              order.status == WorkOrderStatus.enProceso ? Icons.timer : Icons.timer_outlined,
                              size: 18,
                              color: order.status == WorkOrderStatus.enProceso ? AppColors.warning : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Temporizador de Labor:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Text(
                          _formatLaborTime(order),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: order.status == WorkOrderStatus.enProceso ? AppColors.warning : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(context, ref, order),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Pestaña 1: Info (Equipo, protocolos de seguridad, detalles generales)
            _buildInfoTab(order, isUrgent),

            // Pestaña 2: Tareas (Protocolos y pasos técnicos de checklist)
            _buildTasksTab(order),

            // Pestaña 3: Repuestos (Insumos asignados y almacén)
            _buildPartsTab(order),

            // Pestaña 4: Comentarios (Notas técnicas, causa raíz, histórico)
            _buildCommentsTab(order),
          ],
        ),
      ),
    );
  }

  // --- Pestaña 1: Info ---
  Widget _buildInfoTab(WorkOrderModel order, bool isUrgent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado con estado y criticidad
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isUrgent ? AppColors.dangerContainer : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isUrgent ? AppColors.danger.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                order.type.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusBgColor(order.status),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.status.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getStatusTextColor(order.status),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Título y descripción
        Text(
          order.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          order.description,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Ficha del Activo / Equipo Asignado
        _buildSectionHeader('EQUIPO / ACTIVO ASIGNADO'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildDataRow(label: 'Código y Nombre:', value: '${order.asset.code} - ${order.asset.name}'),
              const Divider(height: 16),
              _buildDataRow(label: 'Ubicación Planta:', value: order.asset.location),
              const Divider(height: 16),
              _buildDataRow(
                label: 'Criticidad:',
                value: order.asset.criticality,
                valueColor: order.asset.criticality == 'ALTA' ? AppColors.danger : AppColors.primary,
              ),
              const Divider(height: 16),
              _buildDataRow(label: 'Último Mantenimiento:', value: order.asset.lastMaintenance),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Protocolo de Seguridad y EPP Obligatorio
        if (order.safetyProtocols.isNotEmpty) ...[
          _buildSectionHeader('SEGURIDAD & EPP OBLIGATORIO'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.safetyProtocols.map((protocol) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          protocol,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Asignación de Personal
        _buildSectionHeader('PERSONAL ASIGNADO'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildDataRow(label: 'Técnico Responsable:', value: '${order.technicianName} (${order.technicianBadge})'),
              if (order.assignedCrew != null) ...[
                const Divider(height: 16),
                _buildDataRow(label: 'Cuadrilla de Planta:', value: order.assignedCrew!),
              ],
              const Divider(height: 16),
              _buildDataRow(
                label: 'Prioridad:',
                value: order.priority.name.toUpperCase(),
                valueColor: isUrgent ? AppColors.danger : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Pestaña 2: Tareas (Checklist) ---
  Widget _buildTasksTab(WorkOrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROCEDIMIENTOS Y PASOS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${order.completedTasksCount} / ${order.totalTasksCount} completados',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (order.checklist.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No hay pasos configurados en esta orden.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          ...order.checklist.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;

            String subtitle = 'Inspección Sí/No';
            if (item.type == ChecklistItemType.numericMeasurement) {
              subtitle = 'Medición (${item.minAcceptable ?? 0} a ${item.maxAcceptable ?? 0} ${item.unit ?? ""})';
            } else if (item.type == ChecklistItemType.photoRequired) {
              subtitle = 'Evidencia fotográfica obligatoria';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.isCompleted ? AppColors.successContainer.withValues(alpha: 0.5) : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.isCompleted ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: item.isCompleted ? AppColors.success : AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      item.isCompleted ? Icons.check : Icons.circle,
                      size: item.isCompleted ? 14 : 8,
                      color: item.isCompleted ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$idx. ${item.title}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.isCompleted ? AppColors.textPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- Pestaña 3: Repuestos ---
  Widget _buildPartsTab(WorkOrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'REPUESTOS E INSUMOS ASIGNADOS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (order.spareParts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No se asignaron repuestos para esta orden.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          ...order.spareParts.map((part) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${part.code} - ${part.description}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text('Almacén: ${part.locationWarehouse}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${part.consumedQuantity} ${part.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- Pestaña 4: Comentarios & Cierre ---
  Widget _buildCommentsTab(WorkOrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'OBSERVACIONES & REGISTRO TÉCNICO',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Observaciones Técnicas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                order.technicianNotes ?? 'Sin observaciones técnicas cargadas.',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              if (order.rootCause != null) ...[
                const Divider(height: 20),
                const Text('Causa Raíz / Diagnóstico:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  order.rootCause!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
              if (order.pauseReason != null) ...[
                const Divider(height: 20),
                const Text('Motivo de Pausa:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.paused)),
                const SizedBox(height: 4),
                Text(
                  order.pauseReason!,
                  style: const TextStyle(fontSize: 13, color: AppColors.paused, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
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

  String _formatLaborTime(WorkOrderModel order) {
    final mins = order.elapsedMinutes;
    if (mins <= 0) {
      return order.status == WorkOrderStatus.pendiente ? '00:00 (Sin iniciar)' : '0 min';
    }
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) {
      return '${h}h ${m}min acumulados';
    }
    return '$m min acumulados';
  }

  Color _getStatusBgColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.pendiente:
        return AppColors.surfaceElevated;
      case WorkOrderStatus.enProceso:
        return AppColors.warningContainer;
      case WorkOrderStatus.pausada:
        return AppColors.pausedContainer;
      case WorkOrderStatus.finalizada:
        return AppColors.successContainer;
    }
  }

  Color _getStatusTextColor(WorkOrderStatus status) {
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
        icon: const Icon(Icons.play_arrow, size: 20),
        label: const Text('INICIAR ORDEN DE TRABAJO'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (order.status == WorkOrderStatus.enProceso) {
      return ElevatedButton.icon(
        onPressed: () {
          context.push('/execution/${order.id}');
        },
        icon: const Icon(Icons.build_outlined, size: 20),
        label: const Text('CONTINUAR EJECUCIÓN (TIMER ACTIVO)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        icon: const Icon(Icons.replay, size: 20),
        label: const Text('REANUDAR TAREA'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.paused,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () {
          context.push('/execution/${order.id}');
        },
        icon: const Icon(Icons.assignment_turned_in, size: 18),
        label: const Text('VER INFORME Y FIRMA DE CIERRE'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
