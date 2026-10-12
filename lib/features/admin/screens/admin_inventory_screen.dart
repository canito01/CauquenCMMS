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
    final codeCtrl = TextEditingController(text: partToEdit?.code ?? '');
    final descCtrl = TextEditingController(text: partToEdit?.description ?? '');
    final locCtrl = TextEditingController(text: partToEdit?.locationWarehouse ?? '');
    final stockCtrl = TextEditingController(text: partToEdit != null ? partToEdit.stockAvailable.toString() : '10');
    String unit = partToEdit?.unit ?? 'un';

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
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Código de Parte / SKU', hintText: 'Ej: VAL-NEU-52'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Descripción del Insumo / Pieza', hintText: 'Ej: Válvula biestable 5/2 pilotada'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locCtrl,
                        decoration: const InputDecoration(labelText: 'Ubicación en Almacén Central', hintText: 'Ej: Estante B-02 / Gaveta 4'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!isEditing) ...[
                            Expanded(
                              child: TextField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Stock Inicial Disponible'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                              items: ['un', 'lts', 'kg', 'mts', 'jgo'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) => setDialogState(() => unit = val ?? 'un'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (codeCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;

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
                          content: Text(isEditing ? 'Repuesto ${newPart.code} actualizado' : 'Repuesto ${newPart.code} incorporado'),
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
    if (parts.isEmpty) return;

    SparePartModel selectedPart = preselectedPart ?? parts.first;
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
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Repuesto
                      DropdownButtonFormField<SparePartModel>(
                        initialValue: selectedPart,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: const InputDecoration(labelText: 'Repuesto / Pieza'),
                        items: parts.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.code} - ${p.description} (Stock: ${p.stockAvailable} ${p.unit})',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedPart = val);
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
                              '${selectedPart.stockAvailable} ${selectedPart.unit}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: isAddition ? 'Cantidad a Ingresar (+)' : 'Cantidad a Retirar (-)',
                                prefixIcon: Icon(isAddition ? Icons.add : Icons.remove, color: deltaColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
                            child: Text(selectedPart.unit, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Motivo del Movimiento',
                          hintText: 'Ej: Recepción proveedor, merma, rotura, etc.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: deltaColor),
                  onPressed: () async {
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    if (qty <= 0) return;

                    if (!isAddition && qty > selectedPart.stockAvailable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: No se pueden retirar $qty ${selectedPart.unit}. Stock disponible: ${selectedPart.stockAvailable}'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    final delta = isAddition ? qty : -qty;
                    await ref.read(inventoryProvider.notifier).adjustStock(
                          partId: selectedPart.id,
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
                                ? '¡Ingresaron +$qty ${selectedPart.unit} al stock de ${selectedPart.code}!'
                                : '¡Se retiraron -$qty ${selectedPart.unit} del stock de ${selectedPart.code}!',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gestión de Inventario & Repuestos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('${spareParts.length} artículos en catálogo • $lowStockCount con alerta de stock crítico', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showStockAdjustmentDialog(isAddition: true),
                        icon: const Icon(Icons.add_circle, size: 16),
                        label: const Text('INGRESO DE STOCK (+)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showStockAdjustmentDialog(isAddition: false),
                        icon: const Icon(Icons.remove_circle, size: 16),
                        label: const Text('SALIDA MANUAL (-)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
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
