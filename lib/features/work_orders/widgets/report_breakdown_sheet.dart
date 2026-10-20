import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/asset_model.dart';
import '../../../core/models/checklist_item_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/models/workflow_stage_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/supabase_sync_service.dart';

class ReportBreakdownSheet extends ConsumerStatefulWidget {
  const ReportBreakdownSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ReportBreakdownSheet(),
    );
  }

  @override
  ConsumerState<ReportBreakdownSheet> createState() => _ReportBreakdownSheetState();
}

class _ReportBreakdownSheetState extends ConsumerState<ReportBreakdownSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedAssetId;
  WorkOrderPriority _priority = WorkOrderPriority.urgente;
  bool _startImmediately = false;
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;
  final List<String> _capturedPhotos = [];

  final List<String> _quickFailures = const [
    'Fuga de aceite / fluido',
    'Vibración o ruido anormal',
    'Sobretemperatura en equipo',
    'Falla eléctrica / Térmica caída',
    'Luminaria o fotocélula dañada',
    'Parada imprevista de línea',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await file.readAsBytes();
      final isOnline = ref.read(isOnlineStateProvider);

      String? uploadedUrl;
      if (isOnline && SupabaseConfig.isConfigured) {
        final fileName = 'breakdown_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedUrl = await SupabaseSyncService.uploadEvidencePhoto(
          bytes: bytes,
          fileName: fileName,
        );
      }

      final photoData = uploadedUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (mounted) {
        setState(() {
          _capturedPhotos.add(photoData);
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo adjuntar la foto: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final assets = ref.read(assetsProvider);
    if (assets.isEmpty) return;

    final selectedAsset = assets.firstWhere(
      (a) => a.id == _selectedAssetId,
      orElse: () => assets.first,
    );

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(authProvider).user;
    final techName = currentUser?.name ?? 'Operario de Planta';
    final techBadge = currentUser?.badge ?? 'TEC-4482';
    final now = DateTime.now();
    final orderNum = 'OT-${now.year}-${(1000 + now.millisecondsSinceEpoch % 8999)}';
    final orderId = 'wo-${const Uuid().v4().substring(0, 8)}';

    final isBreakdown = _priority == WorkOrderPriority.urgente || _priority == WorkOrderPriority.alta;

    // Etapas estándar de atención de avería en planta (estilo MaintainX)
    const stages = [
      WorkflowStageModel(
        id: 'stg-corr-1',
        name: 'Etapa 1: Seguridad & Diagnóstico en Planta',
        description: 'Consignación del equipo y evaluación de causa raíz',
        order: 1,
      ),
      WorkflowStageModel(
        id: 'stg-corr-2',
        name: 'Etapa 2: Intervención Correctiva & Pruebas',
        description: 'Reparación, registro fotográfico antes/después y puesta en marcha',
        order: 2,
      ),
    ];

    final checklist = [
      const ChecklistItemModel(
        id: 'corr-s1',
        stageId: 'stg-corr-1',
        stageName: 'Etapa 1: Seguridad & Diagnóstico en Planta',
        title: 'Consignación de seguridad (LOTO) y delimitación del área',
        description: 'Verificar corte de energía y ausencia de presión residual antes de intervenir.',
        type: ChecklistItemType.booleanCheck,
        isRequired: true,
      ),
      ChecklistItemModel(
        id: 'corr-s2',
        stageId: 'stg-corr-2',
        stageName: 'Etapa 2: Intervención Correctiva & Pruebas',
        title: 'Registro fotográfico ANTES y DESPUÉS de la reparación',
        description: 'Documentar el componente averiado y la condición final reparada.',
        type: ChecklistItemType.photoBeforeAfter,
        photoBeforeUrl: _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null,
        isRequired: true,
      ),
      const ChecklistItemModel(
        id: 'corr-s3',
        stageId: 'stg-corr-2',
        stageName: 'Etapa 2: Intervención Correctiva & Pruebas',
        title: 'Prueba funcional de puesta en marcha sin anomalías',
        description: 'Comprobar operación estable sin fugas, ruidos ni vibraciones anormales.',
        type: ChecklistItemType.booleanCheck,
        isRequired: true,
      ),
    ];

    final newOrder = WorkOrderModel(
      id: orderId,
      orderNumber: orderNum,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : 'Reporte generado en planta por $techName ($techBadge).',
      type: isBreakdown ? WorkOrderType.correctivo : WorkOrderType.rutina,
      priority: _priority,
      status: _startImmediately ? WorkOrderStatus.enProceso : WorkOrderStatus.pendiente,
      asset: selectedAsset,
      technicianName: techName,
      technicianBadge: techBadge,
      scheduledDate: now,
      startedAt: _startImmediately ? now : null,
      safetyProtocols: const [
        'Bloqueo de energía LOTO obligatorio antes de intervenir',
        'Uso de EPP completo (Guantes de seguridad y protección ocular)',
      ],
      stages: stages,
      checklist: checklist,
      evidencePhotos: _capturedPhotos,
      syncStatus: ref.read(isOnlineStateProvider) ? SyncStatus.synced : SyncStatus.pendingSync,
      updatedAt: now,
    );

    await ref.read(workOrdersProvider.notifier).createWorkOrder(newOrder);

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _startImmediately
              ? '✓ Avería $orderNum creada e iniciada. Sincronizada con supervisión.'
              : '✓ Solicitud / Avería $orderNum enviada y sincronizada con la central.',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    if (_startImmediately) {
      context.push('/execution/$orderId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);
    if (_selectedAssetId == null && assets.isNotEmpty) {
      _selectedAssetId = assets.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle superior
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reportar Avería o Solicitud en Planta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Se notificará al panel de administración y quedará registrada la OT',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 1. Selector de Equipo / Máquina
              const Text(
                '1. EQUIPO O SECTOR AFECTADO *',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedAssetId,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined, size: 20, color: AppColors.primary),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: assets.map((AssetModel asset) {
                  return DropdownMenuItem<String>(
                    value: asset.id,
                    child: Text(
                      '${asset.code} • ${asset.name} (${asset.location})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedAssetId = val),
              ),
              const SizedBox(height: 16),

              // 2. Nivel de Urgencia
              const Text(
                '2. NIVEL DE URGENCIA / IMPACTO EN PLANTA *',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPriorityOption(
                      label: 'URGENTE',
                      sub: 'Equipo Parado',
                      priority: WorkOrderPriority.urgente,
                      color: AppColors.danger,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPriorityOption(
                      label: 'ALTA',
                      sub: 'Falla Activa',
                      priority: WorkOrderPriority.alta,
                      color: AppColors.warning,
                      icon: Icons.priority_high_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPriorityOption(
                      label: 'NORMAL',
                      sub: 'Solicitud',
                      priority: WorkOrderPriority.normal,
                      color: AppColors.primary,
                      icon: Icons.build_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Falla detectada (Chips rápidos + campo)
              const Text(
                '3. ¿QUÉ FALLA O ANOMALÍA DETECTASTE? *',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickFailures.map((q) {
                  final selected = _titleCtrl.text == q;
                  return ActionChip(
                    label: Text(
                      q,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: selected ? AppColors.primary : AppColors.surfaceSecondary,
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _titleCtrl.text = q;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: Pérdida de aceite en sello mecánico de bomba...',
                  prefixIcon: Icon(Icons.edit_note, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Indicá brevemente la falla detectada' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Detalle u observación adicional (Opcional)',
                  hintText: 'Ej: Se observa goteo continuo al encender la línea 2...',
                ),
              ),
              const SizedBox(height: 16),

              // 4. Evidencia Fotográfica en el acto
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '4. EVIDENCIA FOTOGRÁFICA DE LA FALLA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                  Text(
                    '${_capturedPhotos.length} adjunta(s)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingPhoto ? null : () => _takePhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('TOMAR FOTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingPhoto ? null : () => _takePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('GALERÍA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUploadingPhoto)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(color: AppColors.primary),
                ),
              if (_capturedPhotos.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedPhotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final p = _capturedPhotos[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.startsWith('http')
                                ? Image.network(p, width: 76, height: 76, fit: BoxFit.cover)
                                : Image.memory(
                                    base64Decode(p.contains(',') ? p.split(',')[1] : p),
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setState(() => _capturedPhotos.removeAt(idx)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 5. Opción de iniciar intervención inmediatamente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Auto-asignarme e iniciar reparación ahora',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Si está desactivado, quedará como Solicitud Pendiente en la bandeja general.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: _startImmediately,
                  onChanged: (v) => setState(() => _startImmediately = v),
                ),
              ),
              const SizedBox(height: 18),

              // Botón de Envío
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: Icon(_startImmediately ? Icons.play_arrow_rounded : Icons.send_rounded, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'REGISTRANDO EN PLANTA...'
                        : (_startImmediately
                            ? 'CREAR E INICIAR INTERVENCIÓN AHORA'
                            : 'ENVIAR REPORTE DE AVERÍA / SOLICITUD'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _priority == WorkOrderPriority.urgente ? AppColors.danger : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityOption({
    required String label,
    required String sub,
    required WorkOrderPriority priority,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _priority == priority;
    return InkWell(
      onTap: () => setState(() => _priority = priority),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

