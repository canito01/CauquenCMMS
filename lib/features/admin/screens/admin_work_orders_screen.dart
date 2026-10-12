import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/asset_model.dart';
import '../../../core/models/checklist_item_model.dart';
import '../../../core/models/task_template_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/pdf_report_service.dart';

class AdminWorkOrdersScreen extends ConsumerStatefulWidget {
  const AdminWorkOrdersScreen({super.key});

  @override
  ConsumerState<AdminWorkOrdersScreen> createState() => _AdminWorkOrdersScreenState();
}

class _AdminWorkOrdersScreenState extends ConsumerState<AdminWorkOrdersScreen> {
  String _searchQuery = '';
  WorkOrderStatus? _statusFilter;
  WorkOrderPriority? _priorityFilter;

  // --- Descarga y Manejo de Informe PDF con Feedback ---
  Future<void> _handleDownloadPdf(BuildContext context, WorkOrderModel order) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 10),
              Text('Generando y descargando informe oficial para ${order.orderNumber}...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      final filename = await PdfReportService.downloadOrPrintReport(order);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Archivo "$filename" descargado con éxito en tu equipo.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // --- Sub-diálogo para Agregar o Editar Paso al Checklist ---
  Future<ChecklistItemModel?> _showAddStepDialog(BuildContext context, {ChecklistItemModel? initialStep}) async {
    final titleCtrl = TextEditingController(text: initialStep?.title ?? '');
    ChecklistItemType stepType = initialStep?.type ?? ChecklistItemType.booleanCheck;
    final unitCtrl = TextEditingController(text: initialStep?.unit ?? 'bar');
    final minCtrl = TextEditingController(text: initialStep?.minAcceptable != null ? initialStep!.minAcceptable.toString() : '1.0');
    final maxCtrl = TextEditingController(text: initialStep?.maxAcceptable != null ? initialStep!.maxAcceptable.toString() : '5.0');

    return showDialog<ChecklistItemModel>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStepState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(initialStep != null ? Icons.edit : Icons.add_circle_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(initialStep != null ? 'Modificar Paso del Protocolo' : 'Agregar Paso al Protocolo Técnico', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Descripción del Procedimiento / Tarea', hintText: 'Ej: Medición de temperatura en rodamientos'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ChecklistItemType>(
                      initialValue: stepType,
                      dropdownColor: AppColors.surfaceElevated,
                      decoration: const InputDecoration(labelText: 'Tipo de Validación'),
                      items: const [
                        DropdownMenuItem(value: ChecklistItemType.booleanCheck, child: Text('Inspección Sí/No (Checklist Booleano)')),
                        DropdownMenuItem(value: ChecklistItemType.numericMeasurement, child: Text('Medición Numérica (con Tolerancia Min/Max)')),
                        DropdownMenuItem(value: ChecklistItemType.photoRequired, child: Text('Evidencia Fotográfica Obligatoria')),
                      ],
                      onChanged: (val) {
                        if (val != null) setStepState(() => stepType = val);
                      },
                    ),
                    if (stepType == ChecklistItemType.numericMeasurement) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: unitCtrl,
                              decoration: const InputDecoration(labelText: 'Unidad de Medida', hintText: 'bar, °C, mm, V, rpm'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Mínimo Aceptable'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Máximo Aceptable'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final item = ChecklistItemModel(
                      id: initialStep?.id ?? const Uuid().v4(),
                      title: titleCtrl.text.trim(),
                      type: stepType,
                      unit: stepType == ChecklistItemType.numericMeasurement ? unitCtrl.text.trim() : null,
                      minAcceptable: stepType == ChecklistItemType.numericMeasurement ? double.tryParse(minCtrl.text.trim()) : null,
                      maxAcceptable: stepType == ChecklistItemType.numericMeasurement ? double.tryParse(maxCtrl.text.trim()) : null,
                      isCompleted: initialStep?.isCompleted ?? false,
                      numericValue: initialStep?.numericValue,
                    );
                    Navigator.pop(ctx, item);
                  },
                  child: Text(initialStep != null ? 'Guardar Paso' : 'Añadir Paso'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Modal para Despachar o Modificar Orden de Trabajo ---
  void _showCreateOrderDialog(BuildContext context, {WorkOrderModel? orderToEdit}) {
    final isEditing = orderToEdit != null;
    final assets = ref.read(assetsProvider);
    final plantUsers = ref.read(usersProvider);
    final plantCrews = ref.read(crewsProvider);
    final templates = TaskTemplateModel.getDefaultTemplates();

    if (assets.isEmpty) return;

    final titleCtrl = TextEditingController(text: orderToEdit?.title ?? '');
    final descCtrl = TextEditingController(text: orderToEdit?.description ?? '');

    AssetModel selectedAsset = orderToEdit != null
        ? assets.firstWhere((a) => a.id == orderToEdit.asset.id, orElse: () => assets.first)
        : assets.first;

    bool assignToCrew = orderToEdit?.assignedCrew != null && plantCrews.isNotEmpty;
    String? selectedCrewName = orderToEdit?.assignedCrew ?? (plantCrews.isNotEmpty ? plantCrews.first.name : null);

    String selectedTechnician = orderToEdit?.technicianName ?? (plantUsers.isNotEmpty ? plantUsers.first.name : 'Maximiliano Rossi');
    String selectedBadge = orderToEdit?.technicianBadge ?? (plantUsers.isNotEmpty ? plantUsers.first.badge : 'TEC-4482');

    WorkOrderPriority selectedPriority = orderToEdit?.priority ?? WorkOrderPriority.normal;
    WorkOrderType selectedType = orderToEdit?.type ?? WorkOrderType.correctivo;

    List<ChecklistItemModel> customSteps = List<ChecklistItemModel>.from(
      orderToEdit?.checklist ?? [
        const ChecklistItemModel(
          id: 'step-1',
          title: 'Bloqueo y consignación de energía eléctrica y neumática (LOTO)',
          type: ChecklistItemType.booleanCheck,
          isCompleted: false,
        ),
        const ChecklistItemModel(
          id: 'step-2',
          title: 'Inspección de desgaste y holguras mecánicas',
          type: ChecklistItemType.booleanCheck,
          isCompleted: false,
        ),
        const ChecklistItemModel(
          id: 'step-3',
          title: 'Medición de presión de trabajo en régimen',
          type: ChecklistItemType.numericMeasurement,
          unit: 'bar',
          minAcceptable: 3.5,
          maxAcceptable: 6.0,
          isCompleted: false,
        ),
        const ChecklistItemModel(
          id: 'step-4',
          title: 'Registro fotográfico del estado final y puesta en marcha',
          type: ChecklistItemType.photoRequired,
          isCompleted: false,
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit_note : Icons.add_task, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Modificar Orden de Trabajo (${orderToEdit.orderNumber})' : 'Despachar Nueva Orden de Trabajo'),
                ],
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Carga desde Plantilla
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 22),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cargar Protocolo desde Plantilla Predefinida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                  Text('Autocompleta título, prioridad y todos los pasos técnicos', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            DropdownButton<TaskTemplateModel>(
                              hint: const Text('Elegir Plantilla', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                              underline: const SizedBox(),
                              dropdownColor: AppColors.surfaceElevated,
                              items: templates.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t.name, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (tpl) {
                                if (tpl != null) {
                                  setDialogState(() {
                                    titleCtrl.text = tpl.name;
                                    descCtrl.text = tpl.description;
                                    selectedType = tpl.type;
                                    selectedPriority = tpl.defaultPriority;
                                    customSteps = List<ChecklistItemModel>.from(tpl.steps);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

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

                      // Activo / Máquina
                      DropdownButtonFormField<AssetModel>(
                        initialValue: selectedAsset,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: const InputDecoration(labelText: 'Activo / Máquina de Planta'),
                        items: assets.map((a) {
                          return DropdownMenuItem(
                            value: a,
                            child: Text('${a.code} - ${a.name} (${a.criticality})', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedAsset = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector: Asignar a Técnico Individual o a Cuadrilla
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DESTINATARIO DE LA ORDEN:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => assignToCrew = false),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !assignToCrew ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: !assignToCrew ? AppColors.primary : AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, size: 16, color: !assignToCrew ? AppColors.primary : AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Text('Técnico Individual', style: TextStyle(fontSize: 12, fontWeight: !assignToCrew ? FontWeight.bold : FontWeight.normal, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => assignToCrew = true),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: assignToCrew ? AppColors.warning.withValues(alpha: 0.2) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: assignToCrew ? AppColors.warning : AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.groups, size: 16, color: assignToCrew ? AppColors.warning : AppColors.textMuted),
                                          const SizedBox(width: 6),
                                          Text('Cuadrilla Completa', style: TextStyle(fontSize: 12, fontWeight: assignToCrew ? FontWeight.bold : FontWeight.normal, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (assignToCrew && plantCrews.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                initialValue: selectedCrewName ?? plantCrews.first.name,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(labelText: 'Seleccionar Cuadrilla de Mantenimiento'),
                                items: plantCrews.map((c) {
                                  return DropdownMenuItem(
                                    value: c.name,
                                    child: Text('${c.name} (${c.shift} • Líder: ${c.leaderName})', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final crew = plantCrews.firstWhere((c) => c.name == val);
                                    setDialogState(() {
                                      selectedCrewName = crew.name;
                                      selectedTechnician = crew.leaderName;
                                      selectedBadge = crew.leaderBadge;
                                    });
                                  }
                                },
                              ),
                            ] else ...[
                              DropdownButtonFormField<String>(
                                initialValue: selectedTechnician,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(labelText: 'Seleccionar Técnico Asignado'),
                                items: plantUsers.map((u) {
                                  return DropdownMenuItem(
                                    value: u.name,
                                    child: Text('${u.name} (${u.badge} • ${u.specialty})', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final u = plantUsers.firstWhere((usr) => usr.name == val, orElse: () => plantUsers.first);
                                    setDialogState(() {
                                      selectedTechnician = u.name;
                                      selectedBadge = u.badge;
                                      selectedCrewName = null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
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
                                return DropdownMenuItem(value: p, child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 12)));
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
                                return DropdownMenuItem(value: t, child: Text(t.name.toUpperCase(), style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Diseñador Visual Paso a Paso de Tareas (Step-by-step Builder)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('PASOS TÉCNICOS DEL PROTOCOLO (${customSteps.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.primary)),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final newStep = await _showAddStepDialog(context);
                              if (newStep != null) {
                                setDialogState(() => customSteps.add(newStep));
                              }
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Agregar Paso'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: customSteps.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: Text('No hay pasos agregados. Presiona "Agregar Paso" o carga una plantilla.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                              )
                            : Column(
                                children: customSteps.asMap().entries.map((entry) {
                                  final idx = entry.key + 1;
                                  final step = entry.value;

                                  String subtitle = 'Inspección Sí/No';
                                  if (step.type == ChecklistItemType.numericMeasurement) {
                                    subtitle = 'Medición (${step.minAcceptable ?? 0} a ${step.maxAcceptable ?? 0} ${step.unit ?? ""})';
                                  } else if (step.type == ChecklistItemType.photoRequired) {
                                    subtitle = 'Foto obligatoria requerida';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                          child: Text('$idx', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(step.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                          tooltip: 'Modificar este paso',
                                          onPressed: () async {
                                            final edited = await _showAddStepDialog(context, initialStep: step);
                                            if (edited != null) {
                                              setDialogState(() {
                                                customSteps[entry.key] = edited;
                                              });
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                          tooltip: 'Eliminar este paso',
                                          onPressed: () {
                                            setDialogState(() => customSteps.removeAt(entry.key));
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;

                    final String orderNum = isEditing ? orderToEdit.orderNumber : 'OT-2026-${(1000 + ref.read(workOrdersProvider).length + 1)}';

                    final newOrder = WorkOrderModel(
                      id: isEditing ? orderToEdit.id : const Uuid().v4(),
                      orderNumber: orderNum,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? 'Procedimiento programado según catálogo' : descCtrl.text.trim(),
                      type: selectedType,
                      priority: selectedPriority,
                      status: isEditing ? orderToEdit.status : WorkOrderStatus.pendiente,
                      asset: selectedAsset,
                      technicianName: selectedTechnician,
                      technicianBadge: selectedBadge,
                      assignedCrew: assignToCrew ? selectedCrewName : null,
                      scheduledDate: isEditing ? orderToEdit.scheduledDate : DateTime.now(),
                      safetyProtocols: isEditing ? orderToEdit.safetyProtocols : const ['EPP Completo', 'Bloqueo LOTO', 'Permiso de Trabajo'],
                      checklist: customSteps,
                      updatedAt: DateTime.now(),
                    );

                    if (isEditing) {
                      await ref.read(workOrdersProvider.notifier).updateWorkOrder(newOrder);
                    } else {
                      await ref.read(workOrdersProvider.notifier).createWorkOrder(newOrder);
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? '¡Orden de Trabajo $orderNum actualizada con éxito!' : '¡Orden de Trabajo $orderNum despachada a $selectedTechnician!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  icon: Icon(isEditing ? Icons.save : Icons.send, size: 16),
                  label: Text(isEditing ? 'Guardar Cambios en OT' : 'Despachar Orden de Trabajo'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirmación de Eliminar Orden ---
  void _confirmDeleteOrder(WorkOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar Orden de Trabajo'),
        content: Text('¿Está seguro de que desea eliminar la orden ${order.orderNumber} ("${order.title}")?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await ref.read(workOrdersProvider.notifier).deleteWorkOrder(order.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Orden ${order.orderNumber} eliminada'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Eliminar OT'),
          ),
        ],
      ),
    );
  }

  // --- Modal de Detalle e Inspección con botón de PDF y Gestión de Pasos ---
  void _showOrderDetailModal(BuildContext context, WorkOrderModel initialOrder) {
    WorkOrderModel currentOrder = initialOrder;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820, maxHeight: 880),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        currentOrder.orderNumber,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        currentOrder.title,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Activo: ${currentOrder.asset.code} • ${currentOrder.asset.name} • ${currentOrder.asset.location}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCreateOrderDialog(context, orderToEdit: currentOrder);
                                },
                                icon: const Icon(Icons.edit, size: 15, color: Colors.white),
                                label: const Text('MODIFICAR TAREA', style: TextStyle(color: Colors.white, fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _handleDownloadPdf(context, currentOrder),
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('DESCARGAR PDF OFICIAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            Row(
                              children: [
                                _buildInfoChip('Responsable', '${currentOrder.technicianName} (${currentOrder.technicianBadge})'),
                                const SizedBox(width: 12),
                                _buildInfoChip('Cuadrilla', currentOrder.assignedCrew ?? 'Asignación Individual'),
                                const SizedBox(width: 12),
                                _buildInfoChip('Prioridad', currentOrder.priority.name.toUpperCase()),
                                const SizedBox(width: 12),
                                _buildInfoChip('Estado', currentOrder.status.name.toUpperCase()),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Protocolo y Pasos Técnicos con Botón Agregar Paso
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Protocolo y Pasos Técnicos (${currentOrder.checklist.length}):',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final newStep = await _showAddStepDialog(context);
                                    if (newStep != null) {
                                      final updatedSteps = List<ChecklistItemModel>.from(currentOrder.checklist)..add(newStep);
                                      final updatedOrder = currentOrder.copyWith(
                                        checklist: updatedSteps,
                                        updatedAt: DateTime.now(),
                                      );
                                      await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                                      setModalState(() {
                                        currentOrder = updatedOrder;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Paso "${newStep.title}" agregado a la orden.'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Agregar Paso'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (currentOrder.checklist.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text('No hay pasos configurados. Usa "Agregar Paso" para incluir procedimientos.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ),
                              )
                            else
                              ...currentOrder.checklist.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final item = entry.value;

                                String stepTypeLabel = 'Inspección Sí/No';
                                if (item.type == ChecklistItemType.numericMeasurement) {
                                  stepTypeLabel = 'Medición (${item.minAcceptable ?? 0} a ${item.maxAcceptable ?? 0} ${item.unit ?? ""})';
                                } else if (item.type == ChecklistItemType.photoRequired) {
                                  stepTypeLabel = 'Evidencia fotográfica obligatoria';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: item.isCompleted ? AppColors.success.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                                        child: item.isCompleted
                                            ? const Icon(Icons.check, size: 14, color: AppColors.success)
                                            : Text('$idx', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                            Text(stepTypeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      if (item.numericValue != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${item.numericValue} ${item.unit ?? ""}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                        tooltip: 'Modificar este paso',
                                        onPressed: () async {
                                          final edited = await _showAddStepDialog(context, initialStep: item);
                                          if (edited != null) {
                                            final updatedSteps = List<ChecklistItemModel>.from(currentOrder.checklist);
                                            final stepIdx = updatedSteps.indexWhere((s) => s.id == item.id);
                                            if (stepIdx >= 0) {
                                              updatedSteps[stepIdx] = edited;
                                              final updatedOrder = currentOrder.copyWith(
                                                checklist: updatedSteps,
                                                updatedAt: DateTime.now(),
                                              );
                                              await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                                              setModalState(() {
                                                currentOrder = updatedOrder;
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Paso "${edited.title}" actualizado con éxito.'), backgroundColor: AppColors.success),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                        tooltip: 'Eliminar este paso de la tarea',
                                        onPressed: () async {
                                          final updatedSteps = currentOrder.checklist.where((s) => s.id != item.id).toList();
                                          final updatedOrder = currentOrder.copyWith(
                                            checklist: updatedSteps,
                                            updatedAt: DateTime.now(),
                                          );
                                          await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                                          setModalState(() {
                                            currentOrder = updatedOrder;
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Paso "${item.title}" eliminado de la orden.'), backgroundColor: AppColors.danger),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),

                        const SizedBox(height: 16),
                        if (currentOrder.spareParts.isNotEmpty) ...[
                          const Text('Repuestos Utilizados:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          ...currentOrder.spareParts.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.build, size: 18, color: AppColors.primary),
                                title: Text('${p.code} - ${p.description}', style: const TextStyle(fontSize: 12)),
                                trailing: Text('${p.consumedQuantity} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              )),
                          const SizedBox(height: 16),
                        ],

                        if (currentOrder.status == WorkOrderStatus.finalizada) ...[
                          const Text('Diagnóstico de Cierre & Causa Raíz:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(currentOrder.rootCause ?? 'Desgaste mecánico operativo normal por horas de funcionamiento.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                          const SizedBox(height: 8),
                          const Text('Observaciones Técnicas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(currentOrder.technicianNotes ?? 'Trabajo ejecutado según especificaciones de ingeniería. Equipo entregado 100% operativo.', style: const TextStyle(fontSize: 13, color: Colors.white)),
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
  },
);
}

  Widget _buildInfoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
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

    final filtered = workOrders.where((order) {
      final matchesSearch = _searchQuery.isEmpty ||
          order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.technicianName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (order.assignedCrew ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.asset.code.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == null || order.status == _statusFilter;
      final matchesPriority = _priorityFilter == null || order.priority == _priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gestión y Despacho de Órdenes de Trabajo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${filtered.length} órdenes encontradas en el sistema', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por OT, descripción, técnico, cuadrilla o código de activo...',
                  prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
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
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
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
                DataColumn(label: Text('Destinatario (Técnico / Cuadrilla)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Progreso', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Acciones & Informe', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((order) {
                final statusColor = order.status == WorkOrderStatus.finalizada
                    ? AppColors.success
                    : (order.status == WorkOrderStatus.enProceso ? AppColors.warning : AppColors.textSecondary);

                return DataRow(
                  onSelectChanged: (_) => _showOrderDetailModal(context, order),
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
                          color: order.priority == WorkOrderPriority.urgente ? AppColors.danger.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.priority.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: order.priority == WorkOrderPriority.urgente ? AppColors.danger : Colors.white),
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(order.technicianName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          if (order.assignedCrew != null)
                            Text(order.assignedCrew!, style: const TextStyle(fontSize: 10, color: AppColors.warning)),
                        ],
                      ),
                    ),
                    DataCell(Text('${order.completedTasksCount}/${order.totalTasksCount} (${(order.progressPercentage * 100).toInt()}%)', style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor.withValues(alpha: 0.5))),
                        child: Text(order.status.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ),
                    // Acciones: Ver detalle, Descargar PDF, Modificar, Eliminar
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Ver Detalle y Gestionar Pasos',
                            onPressed: () => _showOrderDetailModal(context, order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.warning),
                            tooltip: 'Descargar Informe PDF Oficial (Entrega a Empresa)',
                            onPressed: () => _handleDownloadPdf(context, order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                            tooltip: 'Modificar Orden de Trabajo y Pasos',
                            onPressed: () => _showCreateOrderDialog(context, orderToEdit: order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            tooltip: 'Eliminar Orden',
                            onPressed: () => _confirmDeleteOrder(order),
                          ),
                        ],
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
