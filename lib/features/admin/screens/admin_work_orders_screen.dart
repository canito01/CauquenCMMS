import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/checklist_item_model.dart';
import '../../../core/models/task_template_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/pdf_report_service.dart';

class AdminWorkOrdersScreen extends ConsumerStatefulWidget {
  const AdminWorkOrdersScreen({super.key});

  @override
  ConsumerState<AdminWorkOrdersScreen> createState() => _AdminWorkOrdersScreenState();
}

class _AdminWorkOrdersScreenState extends ConsumerState<AdminWorkOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _protocolSearchQuery = '';
  WorkOrderStatus? _statusFilter;
  WorkOrderPriority? _priorityFilter;
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  // --- Modal para Crear o Modificar Protocolo Técnico Maestro ---
  void _showProtocolDialog(BuildContext context, {TaskTemplateModel? templateToEdit}) {
    final isEditing = templateToEdit != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: templateToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: templateToEdit?.description ?? '');
    final timeCtrl = TextEditingController(text: (templateToEdit?.estimatedMinutes ?? 45).toString());
    WorkOrderType selectedType = templateToEdit?.type ?? WorkOrderType.preventivo;
    WorkOrderPriority selectedPriority = templateToEdit?.defaultPriority ?? WorkOrderPriority.normal;

    List<ChecklistItemModel> steps = List<ChecklistItemModel>.from(
      templateToEdit?.steps ?? [
        const ChecklistItemModel(
          id: 'step-init-1',
          title: 'Bloqueo y consignación de fuentes de energía (LOTO)',
          type: ChecklistItemType.booleanCheck,
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
                  Icon(isEditing ? Icons.edit : Icons.assignment_turned_in, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Modificar Protocolo Técnico' : 'Crear Nuevo Protocolo Técnico Maestro'),
                ],
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Protocolo Técnico *',
                            hintText: 'Ej: Protocolo de Calibración de Celdas de Carga',
                            prefixIcon: Icon(Icons.rule, size: 20),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción / Alcance del Protocolo',
                            hintText: 'Objetivo y normas aplicables al procedimiento...',
                            prefixIcon: Icon(Icons.description_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<WorkOrderType>(
                                initialValue: selectedType,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(labelText: 'Tipo de Mantenimiento'),
                                items: WorkOrderType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => selectedType = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<WorkOrderPriority>(
                                initialValue: selectedPriority,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(labelText: 'Prioridad Sugerida'),
                                items: WorkOrderPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => selectedPriority = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: timeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Tiempo Estimado (min)', prefixIcon: Icon(Icons.timer_outlined, size: 20)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Pasos Técnicos del Protocolo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PASOS TÉCNICOS DEL PROTOCOLO (${steps.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final newStep = await _showAddStepDialog(context);
                                if (newStep != null) {
                                  setDialogState(() => steps.add(newStep));
                                }
                              },
                              icon: const Icon(Icons.add_circle, size: 16),
                              label: const Text('AGREGAR PASO AL PROTOCOLO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: steps.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: Text('No hay pasos cargados en este protocolo. Presione "AGREGAR PASO AL PROTOCOLO".', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                                )
                              : Column(
                                  children: steps.asMap().entries.map((entry) {
                                    final idx = entry.key + 1;
                                    final step = entry.value;

                                    String stepTypeLabel = 'Inspección Sí/No';
                                    if (step.type == ChecklistItemType.numericMeasurement) {
                                      stepTypeLabel = 'Medición (${step.minAcceptable ?? 0} a ${step.maxAcceptable ?? 0} ${step.unit ?? ""})';
                                    } else if (step.type == ChecklistItemType.photoRequired) {
                                      stepTypeLabel = 'Evidencia fotográfica obligatoria';
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
                                                Text(stepTypeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                                                  steps[entry.key] = edited;
                                                });
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                            tooltip: 'Eliminar este paso',
                                            onPressed: () {
                                              setDialogState(() => steps.removeAt(entry.key));
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
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (steps.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debe agregar al menos un paso técnico al protocolo'), backgroundColor: AppColors.warning),
                      );
                      return;
                    }

                    final newTemplate = TaskTemplateModel(
                      id: isEditing ? templateToEdit.id : const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? 'Procedimiento técnico estandarizado de planta' : descCtrl.text.trim(),
                      type: selectedType,
                      defaultPriority: selectedPriority,
                      estimatedMinutes: int.tryParse(timeCtrl.text.trim()) ?? 45,
                      steps: steps,
                    );

                    ref.read(taskTemplatesProvider.notifier).addOrUpdateTemplate(newTemplate);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Protocolo "${newTemplate.name}" actualizado' : 'Nuevo protocolo "${newTemplate.name}" creado con éxito'), backgroundColor: AppColors.success),
                    );
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Crear Protocolo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Modal para Despachar o Modificar Orden de Trabajo ---
  void _showCreateOrderDialog(BuildContext context, {WorkOrderModel? orderToEdit, TaskTemplateModel? initialTemplate}) {
    final isEditing = orderToEdit != null;
    final formKey = GlobalKey<FormState>();
    final rawAssets = ref.read(assetsProvider);
    final assets = rawAssets.isNotEmpty ? rawAssets : MockDataService.getAssets();
    final rawUsers = ref.read(usersProvider);
    final plantUsers = rawUsers.isNotEmpty ? rawUsers : MockDataService.getMockUsers();
    final plantCrews = ref.read(crewsProvider);
    final templates = ref.read(taskTemplatesProvider);

    final titleCtrl = TextEditingController(text: orderToEdit?.title ?? (initialTemplate?.name ?? ''));
    final descCtrl = TextEditingController(text: orderToEdit?.description ?? (initialTemplate?.description ?? ''));

    String selectedAssetId = (orderToEdit != null && assets.any((a) => a.id == orderToEdit.asset.id))
        ? orderToEdit.asset.id
        : assets.first.id;

    bool assignToCrew = orderToEdit?.assignedCrew != null && plantCrews.isNotEmpty;
    String? selectedCrewName = (orderToEdit?.assignedCrew != null && plantCrews.any((c) => c.name == orderToEdit!.assignedCrew))
        ? orderToEdit!.assignedCrew
        : (plantCrews.isNotEmpty ? plantCrews.first.name : null);

    final defaultUser = (orderToEdit != null && plantUsers.any((u) => u.name == orderToEdit.technicianName))
        ? plantUsers.firstWhere((u) => u.name == orderToEdit.technicianName)
        : plantUsers.first;

    String selectedTechnician = defaultUser.name;
    String selectedBadge = defaultUser.badge;

    WorkOrderPriority selectedPriority = orderToEdit?.priority ?? (initialTemplate?.defaultPriority ?? WorkOrderPriority.normal);
    WorkOrderType selectedType = orderToEdit?.type ?? (initialTemplate?.type ?? WorkOrderType.correctivo);

    List<ChecklistItemModel> customSteps = List<ChecklistItemModel>.from(
      orderToEdit?.checklist ?? (initialTemplate?.steps ?? [
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
      ]),
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
                  child: Form(
                    key: formKey,
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
                                    Text('Cargar Protocolo desde Plantilla Predefinida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
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

                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Título de la Tarea / Intervención *',
                            hintText: 'Ej: Ajuste de rodamientos y prueba de vibración',
                            prefixIcon: Icon(Icons.assignment, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'El título de la orden es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción técnica del trabajo',
                            hintText: 'Detalle el procedimiento requerido...',
                            prefixIcon: Icon(Icons.description_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Activo / Máquina
                        DropdownButtonFormField<String>(
                          initialValue: selectedAssetId,
                          dropdownColor: AppColors.surfaceElevated,
                          decoration: const InputDecoration(
                            labelText: 'Activo / Máquina de Planta *',
                            prefixIcon: Icon(Icons.precision_manufacturing, size: 20),
                          ),
                          items: assets.map((a) {
                            return DropdownMenuItem<String>(
                              value: a.id,
                              child: Text('${a.code} - ${a.name} (${a.criticality})', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedAssetId = val);
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
                                  initialValue: (selectedCrewName != null && plantCrews.any((c) => c.name == selectedCrewName)) ? selectedCrewName : plantCrews.first.name,
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
                                  initialValue: plantUsers.any((u) => u.name == selectedTechnician) ? selectedTechnician : plantUsers.first.name,
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Configura los pasos del protocolo para el operario (inspección Sí/No, medición con tolerancias o fotos requeridas).',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PASOS TÉCNICOS DEL PROTOCOLO (${customSteps.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.primary)),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final newStep = await _showAddStepDialog(context);
                                if (newStep != null) {
                                  setDialogState(() => customSteps.add(newStep));
                                }
                              },
                              icon: const Icon(Icons.add_circle, size: 16),
                              label: const Text('AGREGAR PASO AL PROTOCOLO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final selectedAsset = assets.firstWhere((a) => a.id == selectedAssetId, orElse: () => assets.first);
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

  // --- MaintainX Slide-Over / Split-View Lateral Detail Panel ---
  Widget _buildLateralDetailPanel(WorkOrderModel order, BuildContext context) {
    final statusColor = order.status == WorkOrderStatus.finalizada
        ? AppColors.success
        : (order.status == WorkOrderStatus.enProceso
            ? AppColors.warning
            : (order.status == WorkOrderStatus.pausada ? AppColors.paused : AppColors.textSecondary));
    final statusBg = order.status == WorkOrderStatus.finalizada
        ? AppColors.successContainer
        : (order.status == WorkOrderStatus.enProceso
            ? AppColors.warningContainer
            : (order.status == WorkOrderStatus.pausada ? AppColors.pausedContainer : AppColors.surfaceElevated));

    final isUrgent = order.priority == WorkOrderPriority.urgente;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del Panel Lateral
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            order.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.dangerContainer,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 12, color: AppColors.danger),
                                SizedBox(width: 4),
                                Text(
                                  'PARADA / CRÍTICA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      hoverColor: AppColors.surfaceSecondary,
                      splashRadius: 18,
                      tooltip: 'Cerrar panel lateral',
                      onPressed: () => setState(() => _selectedOrderId = null),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.asset.code} • ${order.asset.name} (${order.asset.location})',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Botones de Acción Rápidos
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleDownloadPdf(context, order),
                        icon: const Icon(Icons.picture_as_pdf, size: 15),
                        label: const Text('Descargar Informe PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showCreateOrderDialog(context, orderToEdit: order),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.textPrimary),
                      label: const Text('Editar', style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'Eliminar orden',
                      onPressed: () => _confirmDeleteOrder(order),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cuerpo con Scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Resumen 2x2
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSideMetaItem(
                              'TÉCNICO ASIGNADO',
                              order.technicianName,
                              subtitle: order.technicianBadge,
                              icon: Icons.person_outline,
                            ),
                          ),
                          Container(width: 1, height: 36, color: AppColors.border),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSideMetaItem(
                              'CUADRILLA',
                              order.assignedCrew ?? 'Asignación Individual',
                              icon: Icons.group_outlined,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1, color: AppColors.border),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSideMetaItem(
                              'TIPO DE ORDEN',
                              order.type.name.toUpperCase(),
                              icon: Icons.category_outlined,
                            ),
                          ),
                          Container(width: 1, height: 36, color: AppColors.border),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSideMetaItem(
                              'PRIORIDAD',
                              order.priority.name.toUpperCase(),
                              icon: Icons.flag_outlined,
                              textColor: isUrgent ? AppColors.danger : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Pasos y Checklist del Protocolo Técnico
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protocolo Técnico (${order.checklist.length} pasos)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.completedTasksCount}/${order.totalTasksCount} completados (${(order.progressPercentage * 100).toInt()}%)',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final newStep = await _showAddStepDialog(context);
                        if (newStep != null) {
                          final updatedSteps = List<ChecklistItemModel>.from(order.checklist)..add(newStep);
                          final updatedOrder = order.copyWith(
                            checklist: updatedSteps,
                            updatedAt: DateTime.now(),
                          );
                          await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Paso "${newStep.title}" agregado al protocolo'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                      label: const Text('Agregar Paso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: order.totalTasksCount == 0 ? 0 : order.completedTasksCount / order.totalTasksCount,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      order.status == WorkOrderStatus.finalizada ? AppColors.success : AppColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),

                const SizedBox(height: 12),

                if (order.checklist.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text('No hay pasos configurados para este protocolo.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  )
                else
                  ...order.checklist.asMap().entries.map((entry) {
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
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: item.isCompleted ? AppColors.successContainer : AppColors.primaryContainer,
                            child: item.isCompleted
                                ? const Icon(Icons.check, size: 14, color: AppColors.success)
                                : Text('$idx', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text(stepTypeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (item.numericValue != null)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '${item.numericValue} ${item.unit ?? ""}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
                            splashRadius: 16,
                            tooltip: 'Modificar paso',
                            onPressed: () async {
                              final edited = await _showAddStepDialog(context, initialStep: item);
                              if (edited != null) {
                                final updatedSteps = List<ChecklistItemModel>.from(order.checklist);
                                final sIdx = updatedSteps.indexWhere((s) => s.id == item.id);
                                if (sIdx >= 0) {
                                  updatedSteps[sIdx] = edited;
                                  final updatedOrder = order.copyWith(
                                    checklist: updatedSteps,
                                    updatedAt: DateTime.now(),
                                  );
                                  await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                            splashRadius: 16,
                            tooltip: 'Eliminar paso',
                            onPressed: () async {
                              final updatedSteps = order.checklist.where((s) => s.id != item.id).toList();
                              final updatedOrder = order.copyWith(
                                checklist: updatedSteps,
                                updatedAt: DateTime.now(),
                              );
                              await ref.read(workOrdersProvider.notifier).updateWorkOrder(updatedOrder);
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                if (order.spareParts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Repuestos Utilizados:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: order.spareParts.map((p) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.build_circle_outlined, size: 18, color: AppColors.primary),
                          title: Text('${p.code} - ${p.description}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          trailing: Text('${p.consumedQuantity} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                if (order.status == WorkOrderStatus.finalizada) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle, size: 16, color: AppColors.success),
                            SizedBox(width: 6),
                            Text('Cierre de Orden & Causa Raíz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.rootCause ?? 'Desgaste operativo normal por horas de servicio.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        if (order.technicianNotes != null && order.technicianNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Observaciones: ${order.technicianNotes}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideMetaItem(String label, String value, {String? subtitle, required IconData icon, Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor ?? AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workOrders = ref.watch(workOrdersProvider);
    final templates = ref.watch(taskTemplatesProvider);

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

    return Column(
      children: [
        // Selector de Pestañas Principal (MaintainX Clean TabBar)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelColor: AppColors.textSecondary,
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(
                icon: const Icon(Icons.assignment_outlined, size: 18),
                text: 'Órdenes de Trabajo Despachadas (${filtered.length})',
              ),
              Tab(
                icon: const Icon(Icons.rule, size: 18),
                text: 'Protocolos Técnicos & Plantillas Maestras (${templates.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWorkOrdersTab(filtered, context),
              _buildProtocolsTab(templates, context),
            ],
          ),
        ),
      ],
    );
  }

  // --- Pestaña 1: Órdenes de Trabajo Despachadas (MaintainX Split-View) ---
  Widget _buildWorkOrdersTab(List<WorkOrderModel> filtered, BuildContext context) {
    final allOrders = ref.watch(workOrdersProvider);
    WorkOrderModel? selectedOrder;
    if (_selectedOrderId != null) {
      for (final o in allOrders) {
        if (o.id == _selectedOrderId) {
          selectedOrder = o;
          break;
        }
      }
    }

    final listViewContent = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Encabezado y Acción Principal
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestión y Despacho de Órdenes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${filtered.length} órdenes encontradas • Haz clic en una fila para desplegar el panel de inspección',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showCreateOrderDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('NUEVA ORDEN DE TRABAJO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Barra de Búsqueda y Filtros Rápidos
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por OT, equipo, técnico, cuadrilla o descripción...',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppColors.primary),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Estado: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    _buildFilterChip('Todos', null, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Pendiente', WorkOrderStatus.pendiente, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('En Proceso', WorkOrderStatus.enProceso, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Pausada', WorkOrderStatus.pausada, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    _buildFilterChip('Finalizada', WorkOrderStatus.finalizada, _statusFilter, (val) => setState(() => _statusFilter = val)),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 20, color: AppColors.border),
                    const SizedBox(width: 16),
                    const Text('Prioridad: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    _buildFilterChip('Todas', null, _priorityFilter, (val) => setState(() => _priorityFilter = val)),
                    _buildFilterChip('Urgente', WorkOrderPriority.urgente, _priorityFilter, (val) => setState(() => _priorityFilter = val)),
                    _buildFilterChip('Normal', WorkOrderPriority.normal, _priorityFilter, (val) => setState(() => _priorityFilter = val)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabla de Órdenes de Trabajo (MaintainX Clean Minimalist SaaS Table)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.3),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Nº OT')),
                DataColumn(label: Text('TÍTULO & EQUIPO')),
                DataColumn(label: Text('TIPO')),
                DataColumn(label: Text('PRIORIDAD')),
                DataColumn(label: Text('DESTINATARIO')),
                DataColumn(label: Text('PROGRESO')),
                DataColumn(label: Text('ESTADO')),
                DataColumn(label: Text('ACCIONES')),
              ],
              rows: filtered.map((order) {
                final isSelectedRow = order.id == _selectedOrderId;
                final isUrgent = order.priority == WorkOrderPriority.urgente;

                final statusColor = order.status == WorkOrderStatus.finalizada
                    ? AppColors.success
                    : (order.status == WorkOrderStatus.enProceso
                        ? AppColors.warning
                        : (order.status == WorkOrderStatus.pausada ? AppColors.paused : AppColors.textSecondary));
                final statusBg = order.status == WorkOrderStatus.finalizada
                    ? AppColors.successContainer
                    : (order.status == WorkOrderStatus.enProceso
                        ? AppColors.warningContainer
                        : (order.status == WorkOrderStatus.pausada ? AppColors.pausedContainer : AppColors.surfaceElevated));

                return DataRow(
                  selected: isSelectedRow,
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (isSelectedRow) return AppColors.primaryContainer.withValues(alpha: 0.7);
                    if (states.contains(WidgetState.hovered)) return AppColors.surfaceLight;
                    return null;
                  }),
                  onSelectChanged: (_) {
                    setState(() {
                      if (_selectedOrderId == order.id) {
                        _selectedOrderId = null;
                      } else {
                        _selectedOrderId = order.id;
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isSelectedRow ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${order.asset.code} • ${order.asset.name}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(order.type.name.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUrgent ? AppColors.dangerContainer : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isUrgent ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
                        ),
                        child: Text(
                          order.priority.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isUrgent ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(order.technicianName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (order.assignedCrew != null)
                            Text(order.assignedCrew!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${order.completedTasksCount}/${order.totalTasksCount} (${(order.progressPercentage * 100).toInt()}%)',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          order.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isSelectedRow ? Icons.visibility : Icons.visibility_outlined,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Inspeccionar en panel lateral',
                            onPressed: () {
                              setState(() {
                                _selectedOrderId = isSelectedRow ? null : order.id;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, size: 17, color: AppColors.primary),
                            tooltip: 'Descargar Informe PDF Oficial',
                            onPressed: () => _handleDownloadPdf(context, order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                            tooltip: 'Modificar orden',
                            onPressed: () => _showCreateOrderDialog(context, orderToEdit: order),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.danger),
                            tooltip: 'Eliminar orden',
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

    if (selectedOrder != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: listViewContent),
          SizedBox(
            width: 490,
            child: _buildLateralDetailPanel(selectedOrder, context),
          ),
        ],
      );
    }

    return listViewContent;
  }

  // --- Pestaña 2: Protocolos Técnicos & Plantillas Maestras ---
  Widget _buildProtocolsTab(List<TaskTemplateModel> templates, BuildContext context) {
    final filteredTemplates = templates.where((t) {
      if (_protocolSearchQuery.isEmpty) return true;
      final q = _protocolSearchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.steps.any((s) => s.title.toLowerCase().contains(q));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catálogo de Protocolos Técnicos Maestros',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${templates.length} protocolos estandarizados con procedimientos paso a paso y tolerancias',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showProtocolDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('NUEVO PROTOCOLO TÉCNICO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Barra de Búsqueda de Protocolos
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar protocolo por nombre, máquina o procedimiento...',
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.primary),
              isDense: true,
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: (val) => setState(() => _protocolSearchQuery = val),
          ),
        ),
        const SizedBox(height: 16),

        if (filteredTemplates.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No se encontraron protocolos técnicos.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          )
        else
          ...filteredTemplates.map((template) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.rule, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      template.name,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      template.type.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text('${template.estimatedMinutes} min', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(template.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Pasos técnicos del protocolo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PASOS TÉCNICOS DEL PROTOCOLO (${template.steps.length}):',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.primary),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final newStep = await _showAddStepDialog(context);
                            if (newStep != null) {
                              final updated = template.copyWith(
                                steps: List<ChecklistItemModel>.from(template.steps)..add(newStep),
                              );
                              ref.read(taskTemplatesProvider.notifier).addOrUpdateTemplate(updated);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Paso "${newStep.title}" agregado al protocolo ${template.name}'), backgroundColor: AppColors.success),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.add_circle, size: 14, color: AppColors.primary),
                          label: const Text('AGREGAR PASO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...template.steps.asMap().entries.map((stepEntry) {
                      final sIdx = stepEntry.key + 1;
                      final step = stepEntry.value;

                      String badgeText = 'Inspección Sí/No';
                      Color badgeColor = AppColors.primary;
                      if (step.type == ChecklistItemType.numericMeasurement) {
                        badgeText = 'Medición: ${step.minAcceptable ?? 0} a ${step.maxAcceptable ?? 0} ${step.unit ?? ""}';
                        badgeColor = AppColors.warning;
                      } else if (step.type == ChecklistItemType.photoRequired) {
                        badgeText = 'Foto Obligatoria';
                        badgeColor = AppColors.paused;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text('$sIdx', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(step.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                              tooltip: 'Modificar este paso',
                              onPressed: () async {
                                final edited = await _showAddStepDialog(context, initialStep: step);
                                if (edited != null) {
                                  final newSteps = List<ChecklistItemModel>.from(template.steps);
                                  newSteps[stepEntry.key] = edited;
                                  ref.read(taskTemplatesProvider.notifier).addOrUpdateTemplate(template.copyWith(steps: newSteps));
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                              tooltip: 'Eliminar este paso',
                              onPressed: () {
                                final newSteps = List<ChecklistItemModel>.from(template.steps)..removeAt(stepEntry.key);
                                ref.read(taskTemplatesProvider.notifier).addOrUpdateTemplate(template.copyWith(steps: newSteps));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Barra de Acciones del Protocolo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showProtocolDialog(context, templateToEdit: template),
                          icon: const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
                          label: const Text('Editar Protocolo', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            ref.read(taskTemplatesProvider.notifier).deleteTemplate(template.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Protocolo ${template.name} eliminado'), backgroundColor: AppColors.danger),
                            );
                          },
                          icon: const Icon(Icons.delete, size: 14),
                          label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _showCreateOrderDialog(context, initialTemplate: template);
                          },
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('Despachar OT con este Protocolo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFilterChip<T>(String label, T value, T currentValue, ValueChanged<T> onSelected) {
    final isSelected = value == currentValue;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        showCheckmark: false,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}
