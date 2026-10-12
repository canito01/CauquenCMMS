import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/asset_model.dart';
import '../../../core/models/checklist_item_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/mock_data_service.dart';

class AdminWorkOrdersScreen extends ConsumerStatefulWidget {
  const AdminWorkOrdersScreen({super.key});

  @override
  ConsumerState<AdminWorkOrdersScreen> createState() => _AdminWorkOrdersScreenState();
}

class _AdminWorkOrdersScreenState extends ConsumerState<AdminWorkOrdersScreen> {
  String _searchQuery = '';
  WorkOrderStatus? _statusFilter;
  WorkOrderPriority? _priorityFilter;

  void _showCreateOrderDialog(BuildContext context) {
    final assets = ref.read(assetsProvider);
    final plantUsers = MockDataService.getMockUsers();

    if (assets.isEmpty) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    AssetModel selectedAsset = assets.first;
    String selectedTechnician = plantUsers.first.name;
    String selectedBadge = plantUsers.first.badge;
    WorkOrderPriority selectedPriority = WorkOrderPriority.normal;
    WorkOrderType selectedType = WorkOrderType.correctivo;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Row(
                children: const [
                  Icon(Icons.add_task, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Despachar Nueva Orden de Trabajo', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título de la Tarea / Intervención',
                          hintText: 'Ej: Ajuste de rodamientos y prueba de vibración',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descripción técnica del trabajo',
                          hintText: 'Detalle el procedimiento requerido...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<AssetModel>(
                              initialValue: selectedAsset,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: const InputDecoration(labelText: 'Activo / Máquina'),
                              items: assets.map((a) {
                                return DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.code} - ${a.name}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedAsset = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedTechnician,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: const InputDecoration(labelText: 'Técnico Asignado'),
                              items: plantUsers.map((u) {
                                return DropdownMenuItem(
                                  value: u.name,
                                  child: Text('${u.name} (${u.badge})', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final u = plantUsers.firstWhere((usr) => usr.name == val);
                                  setDialogState(() {
                                    selectedTechnician = u.name;
                                    selectedBadge = u.badge;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<WorkOrderPriority>(
                              initialValue: selectedPriority,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: const InputDecoration(labelText: 'Nivel de Prioridad'),
                              items: WorkOrderPriority.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedPriority = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<WorkOrderType>(
                              initialValue: selectedType,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: const InputDecoration(labelText: 'Tipo de Mantenimiento'),
                              items: WorkOrderType.values.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;

                    final newOrderNumber = 'OT-2026-${(1000 + DateTime.now().millisecond).toString()}';
                    final newOrder = WorkOrderModel(
                      id: const Uuid().v4(),
                      orderNumber: newOrderNumber,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? 'Trabajo asignado por supervisión.' : descCtrl.text.trim(),
                      type: selectedType,
                      priority: selectedPriority,
                      status: WorkOrderStatus.pendiente,
                      asset: selectedAsset,
                      technicianName: selectedTechnician,
                      technicianBadge: selectedBadge,
                      scheduledDate: DateTime.now(),
                      checklist: [
                        ChecklistItemModel(
                          id: const Uuid().v4(),
                          title: 'Inspección visual previa y bloqueo LOTO',
                          type: ChecklistItemType.booleanCheck,
                          isCompleted: false,
                        ),
                        ChecklistItemModel(
                          id: const Uuid().v4(),
                          title: 'Verificación de torque y tolerancia mecánica',
                          type: ChecklistItemType.booleanCheck,
                          isCompleted: false,
                        ),
                      ],
                      updatedAt: DateTime.now(),
                    );

                    await ref.read(workOrdersProvider.notifier).createWorkOrder(newOrder);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('¡Orden de Trabajo $newOrderNumber despachada a $selectedTechnician!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Despachar a Cuadrilla'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOrderDetailModal(BuildContext context, WorkOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.orderNumber} • ${order.title}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Activo: ${order.asset.code} • ${order.asset.name} • ${order.asset.location}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        // Cuadrícula de Datos
                        Row(
                          children: [
                            _buildInfoChip('Técnico', '${order.technicianName} (${order.technicianBadge})'),
                            const SizedBox(width: 16),
                            _buildInfoChip('Tipo', order.type.name.toUpperCase()),
                            const SizedBox(width: 16),
                            _buildInfoChip('Prioridad', order.priority.name.toUpperCase()),
                            const SizedBox(width: 16),
                            _buildInfoChip('Estado', order.status.name.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Descripción del Requerimiento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(order.description, style: const TextStyle(fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 20),

                        // Planilla de verificación
                        const Text('Planilla de Tareas / Checklist:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        ...order.checklist.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: item.isCompleted ? AppColors.success : AppColors.textMuted,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 12))),
                                if (item.numericValue != null)
                                  Text(
                                    '${item.numericValue} ${item.unit ?? ""}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: item.isOutOfRange ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),

                        // Evidencias Fotográficas
                        const Text('Evidencias Fotográficas Registradas en Planta:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        if (order.evidencePhotos.isEmpty)
                          const Text('Sin fotos adjuntas.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                        else
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: order.evidencePhotos.length,
                              itemBuilder: (ctx, i) {
                                final photoUrl = order.evidencePhotos[i];
                                return Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: photoUrl.startsWith('http')
                                      ? Image.network(photoUrl, fit: BoxFit.cover)
                                      : const Center(child: Icon(Icons.image, color: AppColors.primary)),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Cierre y Diagnóstico si está finalizada
                        if (order.status == WorkOrderStatus.finalizada) ...[
                          const Text('Diagnóstico de Cierre & Causa Raíz:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(order.rootCause ?? 'No especificada', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                          const SizedBox(height: 8),
                          const Text('Observaciones Técnicas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(order.technicianNotes ?? 'Sin notas', style: const TextStyle(fontSize: 13, color: Colors.white)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workOrders = ref.watch(workOrdersProvider);

    // Filtrar órdenes
    final filtered = workOrders.where((order) {
      final matchesSearch = _searchQuery.isEmpty ||
          order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.technicianName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.asset.code.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == null || order.status == _statusFilter;
      final matchesPriority = _priorityFilter == null || order.priority == _priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Barra Superior: Título + Botón de Creación
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestión y Despacho de Órdenes de Trabajo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${filtered.length} órdenes encontradas en el sistema',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showCreateOrderDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NUEVA ORDEN DE TRABAJO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Barra de Búsqueda y Filtros
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar por OT, descripción, técnico o código de activo...',
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Estado: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    _buildFilterChip('Todos', null, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Pendiente', WorkOrderStatus.pendiente, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('En Proceso', WorkOrderStatus.enProceso, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Pausada', WorkOrderStatus.pausada, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Finalizada', WorkOrderStatus.finalizada, _statusFilter, (val) => setState(() => _statusFilter = val)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tabla de Órdenes de Trabajo
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
              columns: const [
                DataColumn(label: Text('Nº OT', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Título & Equipo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Prioridad', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Técnico Asignado', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Progreso', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Fotos', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((order) {
                final statusColor = order.status == WorkOrderStatus.finalizada
                    ? AppColors.success
                    : (order.status == WorkOrderStatus.enProceso ? AppColors.warning : AppColors.textSecondary);

                return DataRow(
                  cells: [
                    DataCell(Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(order.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${order.asset.code} • ${order.asset.name}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(Text(order.type.name.toUpperCase(), style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.priority == WorkOrderPriority.urgente
                              ? AppColors.danger.withValues(alpha: 0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.priority.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.priority == WorkOrderPriority.urgente ? AppColors.danger : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(order.technicianName, style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        '${order.completedTasksCount}/${order.totalTasksCount} (${(order.progressPercentage * 100).toInt()}%)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Icon(Icons.camera_alt, size: 14, color: order.evidencePhotos.isNotEmpty ? AppColors.warning : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('${order.evidencePhotos.length}', style: TextStyle(fontSize: 11, color: order.evidencePhotos.isNotEmpty ? AppColors.warning : AppColors.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          order.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                        tooltip: 'Ver Detalle y Evidencias',
                        onPressed: () => _showOrderDetailModal(context, order),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip<T>(String label, T value, T currentValue, ValueChanged<T> onSelected) {
    final isSelected = value == currentValue;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textSecondary)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        showCheckmark: false,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}
