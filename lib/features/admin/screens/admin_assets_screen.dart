import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/asset_model.dart';
import '../../../core/services/app_providers.dart';

class AdminAssetsScreen extends ConsumerStatefulWidget {
  const AdminAssetsScreen({super.key});

  @override
  ConsumerState<AdminAssetsScreen> createState() => _AdminAssetsScreenState();
}

class _AdminAssetsScreenState extends ConsumerState<AdminAssetsScreen> {
  String _searchQuery = '';
  String? _criticalityFilter;

  void _showAddAssetDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String criticality = 'ALTA';
    String status = 'OPERATIVO';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Row(
                children: const [
                  Icon(Icons.precision_manufacturing, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Registrar Nuevo Activo de Planta', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Código de Identificación', hintText: 'Ej: COM-008'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del Equipo', hintText: 'Ej: Compresor de Tornillo Atlas Copco'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Ubicación / Sector de Planta', hintText: 'Ej: Sala de Compresores / Nave A'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: criticality,
                            dropdownColor: AppColors.surfaceElevated,
                            decoration: const InputDecoration(labelText: 'Criticidad'),
                            items: ['ALTA', 'MEDIA', 'BAJA'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) => setDialogState(() => criticality = val ?? 'ALTA'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            dropdownColor: AppColors.surfaceElevated,
                            decoration: const InputDecoration(labelText: 'Estado Operativo'),
                            items: ['OPERATIVO', 'EN_MANTENIMIENTO', 'FUERA_DE_SERVICIO'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
                            onChanged: (val) => setDialogState(() => status = val ?? 'OPERATIVO'),
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
                    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;

                    final newAsset = AssetModel(
                      id: const Uuid().v4(),
                      code: codeCtrl.text.trim().toUpperCase(),
                      name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty ? 'Planta General' : locationCtrl.text.trim(),
                      criticality: criticality,
                      status: status,
                      lastMaintenance: 'Recién registrado',
                    );

                    await ref.read(assetsProvider.notifier).addOrUpdateAsset(newAsset);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Activo ${newAsset.code} registrado con éxito'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Guardar Activo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);

    final filtered = assets.where((a) {
      final matchesQuery = _searchQuery.isEmpty ||
          a.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.location.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCrit = _criticalityFilter == null || a.criticality == _criticalityFilter;
      return matchesQuery && matchesCrit;
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
                const Text(
                  'Parque de Maquinaria y Activos Industriales',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.2),
                ),
                const SizedBox(height: 4),
                Text('${filtered.length} equipos registrados en planta', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddAssetDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('NUEVO ACTIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar activo por código, nombre o ubicación...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.primary),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String?>(
                value: _criticalityFilter,
                dropdownColor: Colors.white,
                hint: const Text('Criticidad: Todas', style: TextStyle(fontSize: 12)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'ALTA', child: Text('ALTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger))),
                  const DropdownMenuItem(value: 'MEDIA', child: Text('MEDIA', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'BAJA', child: Text('BAJA', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) => setState(() => _criticalityFilter = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabla de Activos
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.3),
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 54,
                    columns: const [
                      DataColumn(label: Text('CÓDIGO')),
                      DataColumn(label: Text('MÁQUINA / EQUIPO')),
                      DataColumn(label: Text('UBICACIÓN EN PLANTA')),
                      DataColumn(label: Text('CRITICIDAD')),
                      DataColumn(label: Text('ESTADO')),
                      DataColumn(label: Text('ÚLTIMO MANT.')),
                    ],
                    rows: filtered.map((asset) {
                      final isOperative = asset.status == 'OPERATIVO';
                      final isHighCrit = asset.criticality == 'ALTA';

                      return DataRow(
                        cells: [
                          DataCell(Text(asset.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          DataCell(Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                          DataCell(Text(asset.location, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isHighCrit ? AppColors.dangerContainer : AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isHighCrit ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
                              ),
                              child: Text(
                                asset.criticality,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isHighCrit ? AppColors.danger : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOperative ? AppColors.successContainer : AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isOperative ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                asset.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOperative ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(asset.lastMaintenance, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
