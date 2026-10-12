import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/spare_part_model.dart';
import '../../../core/services/app_providers.dart';

class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  ConsumerState<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  String _searchQuery = '';
  bool _onlyLowStock = false;

  void _showAddPartDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    String unit = 'un';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: const [
              Icon(Icons.inventory_2, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Dar de Alta Repuesto en Almacén', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
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
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock Inicial Disponible'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        dropdownColor: AppColors.surfaceElevated,
                        decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                        items: ['un', 'lts', 'kg', 'mts'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (val) => unit = val ?? 'un',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;

                final qty = int.tryParse(stockCtrl.text.trim()) ?? 0;
                final newPart = SparePartModel(
                  id: const Uuid().v4(),
                  code: codeCtrl.text.trim().toUpperCase(),
                  description: descCtrl.text.trim(),
                  locationWarehouse: locCtrl.text.trim().isEmpty ? 'Almacén Central' : locCtrl.text.trim(),
                  stockAvailable: qty,
                  consumedQuantity: 0,
                  unit: unit,
                );

                await ref.read(inventoryProvider.notifier).addOrUpdatePart(newPart);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Repuesto ${newPart.code} incorporado al inventario'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Guardar en Inventario'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);

    final filtered = inventory.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.locationWarehouse.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesLowStock = !_onlyLowStock || p.isLowStock;
      return matchesQuery && matchesLowStock;
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
                const Text('Almacén Central de Repuestos e Insumos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${filtered.length} ítems registrados en catálogo de mantenimiento', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddPartDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NUEVO REPUESTO'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Barra de búsqueda y filtro de stock crítico
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Buscar por código, descripción o estantería...', prefixIcon: Icon(Icons.search, color: AppColors.primary), isDense: true),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Solo Stock Crítico (< 3 un)', style: TextStyle(fontSize: 11)),
                selected: _onlyLowStock,
                selectedColor: AppColors.danger.withValues(alpha: 0.3),
                checkmarkColor: AppColors.danger,
                onSelected: (val) => setState(() => _onlyLowStock = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tabla de Inventario
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
              columns: const [
                DataColumn(label: Text('Código / SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Descripción del Insumo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Ubicación en Almacén', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Stock Actual', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Consumido en Planta', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Estado de Reposición', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((part) {
                return DataRow(
                  cells: [
                    DataCell(Text(part.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    DataCell(Text(part.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(part.locationWarehouse, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    DataCell(
                      Text(
                        '${part.stockAvailable} ${part.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: part.isLowStock ? AppColors.danger : Colors.white,
                        ),
                      ),
                    ),
                    DataCell(Text('${part.consumedQuantity} ${part.unit}', style: const TextStyle(color: AppColors.textMuted))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: part.isLowStock ? AppColors.danger.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          part.isLowStock ? 'REPOSICIÓN URGENTE' : 'STOCK ÓPTIMO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: part.isLowStock ? AppColors.danger : AppColors.success,
                          ),
                        ),
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
}
