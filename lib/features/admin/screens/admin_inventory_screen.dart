import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/spare_part_model.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/services/app_providers.dart';

class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  ConsumerState<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _onlyLowStock = false;

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

  // --- Modal para Registrar o Modificar Repuesto ---
  void _showPartDialog({SparePartModel? partToEdit}) {
    final isEditing = partToEdit != null;
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: partToEdit?.code ?? '');
    final descCtrl = TextEditingController(text: partToEdit?.description ?? '');
    final locCtrl = TextEditingController(text: partToEdit?.locationWarehouse ?? '');
    final stockCtrl = TextEditingController(text: partToEdit != null ? partToEdit.stockAvailable.toString() : '10');
    
    final standardUnits = ['un', 'lts', 'l', 'kg', 'g', 'mts', 'm', 'jgo', 'par', 'caja'];
    final unitOptions = {...standardUnits, if (partToEdit != null) partToEdit.unit}.toList();
    String unit = (partToEdit != null && unitOptions.contains(partToEdit.unit)) ? partToEdit.unit : 'un';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.inventory_2, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(isEditing ? 'Modificar Repuesto' : 'Dar de Alta Nuevo Repuesto'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeCtrl,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Código de Parte / SKU *',
                                  hintText: 'Ej: VAL-NEU-52',
                                  prefixIcon: Icon(Icons.qr_code, size: 20),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'El código SKU es obligatorio';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (!isEditing) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                                tooltip: 'Generar código SKU automático',
                                onPressed: () {
                                  final genCode = 'REP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                                  setDialogState(() => codeCtrl.text = genCode);
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descripción del Insumo / Pieza *',
                            hintText: 'Ej: Válvula biestable 5/2 pilotada',
                            prefixIcon: Icon(Icons.description_outlined, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'La descripción es obligatoria';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación en Almacén Central',
                            hintText: 'Ej: Estante B-02 / Gaveta 4',
                            prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isEditing) ...[
                              Expanded(
                                child: TextFormField(
                                  controller: stockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock Inicial Disponible *',
                                    prefixIcon: Icon(Icons.tag, size: 20),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Ingrese cantidad';
                                    }
                                    final numVal = int.tryParse(val.trim());
                                    if (numVal == null || numVal < 0) {
                                      return 'Número entero ≥ 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: unit,
                                dropdownColor: AppColors.surfaceElevated,
                                decoration: const InputDecoration(
                                  labelText: 'Unidad de Medida',
                                  prefixIcon: Icon(Icons.straighten, size: 20),
                                ),
                                items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (val) => setDialogState(() => unit = val ?? 'un'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final qty = isEditing ? partToEdit.stockAvailable : (int.tryParse(stockCtrl.text.trim()) ?? 0);
                    final newPart = SparePartModel(
                      id: isEditing ? partToEdit.id : const Uuid().v4(),
                      code: codeCtrl.text.trim().toUpperCase(),
                      description: descCtrl.text.trim(),
                      locationWarehouse: locCtrl.text.trim().isEmpty ? 'Almacén Central' : locCtrl.text.trim(),
                      stockAvailable: qty,
                      consumedQuantity: isEditing ? partToEdit.consumedQuantity : 0,
                      unit: unit,
                    );

                    await ref.read(inventoryProvider.notifier).addOrUpdatePart(newPart);

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? 'Repuesto ${newPart.code} actualizado' : 'Repuesto ${newPart.code} incorporado al inventario'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Guardar en Inventario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Modal para Entrada o Salida Manual de Stock ---
  void _showStockAdjustmentDialog({SparePartModel? preselectedPart, required bool isAddition}) {
    final parts = ref.read(inventoryProvider);
    if (parts.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Catálogo de Repuestos Vacío'),
          content: const Text('No hay ningún repuesto en inventario actualmente. Por favor, crea un nuevo repuesto con el botón "NUEVO REPUESTO" antes de registrar entradas o salidas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String selectedPartId = preselectedPart?.id ?? parts.first.id;
    if (!parts.any((p) => p.id == selectedPartId)) {
      selectedPartId = parts.first.id;
    }

    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController(
      text: isAddition ? 'Recepción de remito / Compra a proveedor' : 'Retiro para mantenimiento preventivo',
    );
    final user = ref.read(authProvider).user;
    final performedBy = user?.name ?? 'Supervisor de Planta';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final deltaColor = isAddition ? AppColors.success : AppColors.danger;
            final currentPart = parts.firstWhere((p) => p.id == selectedPartId, orElse: () => parts.first);

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isAddition ? Icons.add_circle : Icons.remove_circle, color: deltaColor),
                  const SizedBox(width: 10),
                  Text(isAddition ? 'Ingreso / Entrada Manual de Stock' : 'Retiro / Salida Manual de Stock'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selector de Repuesto por ID
                        DropdownButtonFormField<String>(
                          initialValue: selectedPartId,
                          dropdownColor: AppColors.surfaceElevated,
                          decoration: const InputDecoration(labelText: 'Repuesto / Insumo *'),
                          items: parts.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                '${p.code} - ${p.description} (Stock: ${p.stockAvailable} ${p.unit})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedPartId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // Indicador de Stock Actual
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Stock Actual en Almacén:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(
                                '${currentPart.stockAvailable} ${currentPart.unit}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isAddition ? 'Cantidad a Ingresar (+) *' : 'Cantidad a Retirar (-) *',
                                  prefixIcon: Icon(isAddition ? Icons.add : Icons.remove, color: deltaColor),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Ingrese cantidad';
                                  }
                                  final q = int.tryParse(val.trim());
                                  if (q == null || q <= 0) {
                                    return 'Debe ser mayor a 0';
                                  }
                                  if (!isAddition && q > currentPart.stockAvailable) {
                                    return 'Stock insuficiente (disp: ${currentPart.stockAvailable})';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 52,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                              child: Text(currentPart.unit, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: reasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Motivo / Justificación del Movimiento',
                            hintText: 'Ej: Recepción proveedor, merma, rotura, etc.',
                            prefixIcon: Icon(Icons.notes, size: 20),
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
                  style: ElevatedButton.styleFrom(backgroundColor: deltaColor),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

                    final delta = isAddition ? qty : -qty;
                    await ref.read(inventoryProvider.notifier).adjustStock(
                          partId: currentPart.id,
                          delta: delta,
                          reason: reasonCtrl.text.trim().isEmpty ? (isAddition ? 'Ingreso manual' : 'Salida manual') : reasonCtrl.text.trim(),
                          performedBy: performedBy,
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAddition
                                ? '¡Ingresaron +$qty ${currentPart.unit} al stock de ${currentPart.code}!'
                                : '¡Se retiraron -$qty ${currentPart.unit} del stock de ${currentPart.code}!',
                          ),
                          backgroundColor: deltaColor,
                        ),
                      );
                    }
                  },
                  child: Text(isAddition ? 'Confirmar Ingreso (+)' : 'Confirmar Retiro (-)'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirmación de Eliminar Repuesto ---
  void _confirmDeletePart(SparePartModel part) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar Repuesto de Almacén'),
        content: Text('¿Está seguro de que desea eliminar el repuesto ${part.code} (${part.description})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              await ref.read(inventoryProvider.notifier).deletePart(part.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Repuesto ${part.code} eliminado del catálogo'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Eliminar Insumo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spareParts = ref.watch(inventoryProvider);
    final stockMovements = ref.watch(stockMovementsProvider);

    final filteredParts = spareParts.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.locationWarehouse.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesLow = !_onlyLowStock || p.isLowStock;
      return matchesQuery && matchesLow;
    }).toList();

    final lowStockCount = spareParts.where((p) => p.isLowStock).length;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      children: [
        // Cabecera superior con botones de acción rápida
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Text('Gestión de Inventario & Repuestos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('${spareParts.length} artículos en catálogo • $lowStockCount con alerta de stock crítico', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showStockAdjustmentDialog(isAddition: true),
                        icon: const Icon(Icons.add_circle, size: 16),
                        label: const Text('INGRESO DE STOCK (+)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showStockAdjustmentDialog(isAddition: false),
                        icon: const Icon(Icons.remove_circle, size: 16),
                        label: const Text('SALIDA MANUAL (-)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showPartDialog(),
                        icon: const Icon(Icons.inventory_2, size: 16),
                        label: const Text('NUEVO REPUESTO'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(icon: const Icon(Icons.inventory_2), text: 'Catálogo de Repuestos (${filteredParts.length})'),
                  Tab(icon: const Icon(Icons.history), text: 'Movimientos & Trazabilidad (${stockMovements.length})'),
                ],
              ),
            ],
          ),
        ),

        // Filtros y Búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por código SKU, descripción o ubicación en almacén...',
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              FilterChip(
                selected: _onlyLowStock,
                label: Text('Solo Stock Crítico ($lowStockCount)'),
                labelStyle: TextStyle(color: _onlyLowStock ? Colors.white : AppColors.danger, fontWeight: FontWeight.bold),
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.danger,
                checkmarkColor: Colors.white,
                onSelected: (val) => setState(() => _onlyLowStock = val),
              ),
            ],
          ),
        ),

        // Contenido de las pestañas
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- PESTAÑA 1: Catálogo de Repuestos ---
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
                        columns: const [
                          DataColumn(label: Text('Código SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Descripción de la Pieza', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Ubicación Almacén', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Stock Disponible', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Consumo Acumulado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Estado Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Ajuste Rápido', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredParts.map((part) {
                          return DataRow(
                            cells: [
                              DataCell(Text(part.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                              DataCell(Text(part.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(part.locationWarehouse, style: const TextStyle(color: AppColors.textSecondary))),
                              DataCell(Text('${part.stockAvailable} ${part.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              DataCell(Text('${part.consumedQuantity} ${part.unit}', style: const TextStyle(color: AppColors.textMuted))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (part.isLowStock ? AppColors.danger : AppColors.success).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    part.isLowStock ? 'CRÍTICO / BAJO' : 'ABASTECIDO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: part.isLowStock ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                ),
                              ),
                              // Botones rápidos de ajuste (+ / -)
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 20),
                                      tooltip: 'Sumar Stock (+)',
                                      onPressed: () => _showStockAdjustmentDialog(preselectedPart: part, isAddition: true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                                      tooltip: 'Restar Stock (-)',
                                      onPressed: () => _showStockAdjustmentDialog(preselectedPart: part, isAddition: false),
                                    ),
                                  ],
                                ),
                              ),
                              // Acciones de editar y eliminar
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                      tooltip: 'Modificar Repuesto',
                                      onPressed: () => _showPartDialog(partToEdit: part),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                      tooltip: 'Eliminar Insumo',
                                      onPressed: () => _confirmDeletePart(part),
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
              ),

              // --- PESTAÑA 2: Movimientos & Trazabilidad ---
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (stockMovements.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.history_outlined, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text('No hay movimientos manuales registrados aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text('Cada vez que agregues o descuentes stock, quedará registrado aquí con fecha, motivo y responsable.', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
                          columns: const [
                            DataColumn(label: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tipo Movimiento', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Código Repuesto', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Stock Anterior ➔ Nuevo', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Responsable', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: stockMovements.map((mov) {
                            final isEntrada = mov.type == StockMovementType.entrada;
                            final movColor = isEntrada ? AppColors.success : AppColors.danger;

                            return DataRow(
                              cells: [
                                DataCell(Text(dateFormat.format(mov.timestamp), style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: movColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isEntrada ? 'ENTRADA (+)' : 'SALIDA (-)',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: movColor),
                                    ),
                                  ),
                                ),
                                DataCell(Text(mov.partCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                DataCell(Text(mov.partDescription, style: const TextStyle(fontSize: 12))),
                                DataCell(Text('${isEntrada ? "+" : "-"}${mov.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: movColor))),
                                DataCell(Text('${mov.previousStock} ➔ ${mov.newStock}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(Text(mov.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                                DataCell(Text(mov.performedBy, style: const TextStyle(fontSize: 12))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
