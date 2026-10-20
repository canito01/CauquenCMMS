import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/checklist_item_model.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../common/connectivity_badge.dart';

class WorkOrderExecutionScreen extends ConsumerStatefulWidget {
  final String orderId;

  const WorkOrderExecutionScreen({super.key, required this.orderId});

  @override
  ConsumerState<WorkOrderExecutionScreen> createState() => _WorkOrderExecutionScreenState();
}

class _WorkOrderExecutionScreenState extends ConsumerState<WorkOrderExecutionScreen> {
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;
  String _selectedRootCause = 'Desgaste habitual de componentes';

  int _selectedStageIndex = 0;
  bool _viewAllStages = false;

  final List<String> _rootCauses = [
    'Desgaste habitual de componentes',
    'Lubricación insuficiente o degradada',
    'Falla eléctrica / Desbalance de fases',
    'Sobrecarga mecánica / Atasco',
    'Fatiga de material / Desalineación',
    'Mantenimiento preventivo rutinario',
  ];

  @override
  void dispose() {
    _sigController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStepPhoto(ImageSource source, String orderId, String stepId) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await photo.readAsBytes();
      final isOnline = ref.read(isOnlineStateProvider);

      String? uploadedUrl;
      if (isOnline && SupabaseConfig.isConfigured) {
        final fileName = 'step_${orderId}_${stepId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedUrl = await SupabaseSyncService.uploadEvidencePhoto(
          bytes: bytes,
          fileName: fileName,
        );
      }
      final photoData = uploadedUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await ref.read(workOrdersProvider.notifier).recordStepPhoto(orderId, stepId, photoData);
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Evidencia fotográfica del paso registrada con éxito.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _pickStepBeforeAfterPhoto(ImageSource source, String orderId, String stepId, bool isBefore) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await photo.readAsBytes();
      final isOnline = ref.read(isOnlineStateProvider);

      String? uploadedUrl;
      if (isOnline && SupabaseConfig.isConfigured) {
        final prefix = isBefore ? 'before' : 'after';
        final fileName = '${prefix}_${orderId}_${stepId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedUrl = await SupabaseSyncService.uploadEvidencePhoto(
          bytes: bytes,
          fileName: fileName,
        );
      }
      final photoData = uploadedUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await ref.read(workOrdersProvider.notifier).recordStepBeforeAfterPhoto(
        orderId: orderId,
        stepId: stepId,
        photoUrl: photoData,
        isBefore: isBefore,
      );

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBefore ? '✓ Foto "ANTES" registrada exitosamente' : '✓ Foto "DESPUÉS" registrada exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showTextObservationDialog(BuildContext context, WorkOrderModel order, ChecklistItemModel item) {
    final textCtrl = TextEditingController(text: item.textValue ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(item.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Observación del Técnico *',
                  hintText: 'Detalle el estado, anomalías o verificación realizada...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                ref.read(workOrdersProvider.notifier).recordStepText(order.id, item.id, textCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Guardar Observación'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, WorkOrderModel order) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await photo.readAsBytes();
      final isOnline = ref.read(isOnlineStateProvider);

      String? uploadedUrl;

      // Si tenemos conexión y Supabase está activo, subir directamente al bucket 'evidences'
      if (isOnline && SupabaseConfig.isConfigured) {
        final fileName = 'wo_${order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedUrl = await SupabaseSyncService.uploadEvidencePhoto(
          bytes: bytes,
          fileName: fileName,
        );

        if (uploadedUrl != null) {
          await SupabaseSyncService.recordEvidencePhoto(
            workOrderId: order.id,
            photoUrl: uploadedUrl,
            caption: 'Foto de evidencia (${order.orderNumber})',
          );
        }
      }

      // Si subió a Supabase usamos la URL pública; si estamos offline o falló la red, guardamos Base64 local
      final photoData = uploadedUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await ref.read(workOrdersProvider.notifier).attachEvidencePhoto(
            order.id,
            photoData,
          );

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  uploadedUrl != null ? Icons.cloud_done : Icons.save,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uploadedUrl != null
                        ? '¡Foto subida a Supabase Storage (evidences)!'
                        : 'Foto guardada localmente (se subirá a la nube al sincronizar).',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al acceder a la cámara o galería: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _viewPhotoFullscreen(String photoData, int index) {
    Widget imageWidget;
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      imageWidget = Image.network(
        photoData,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (ctx, err, stack) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 48),
        ),
      );
    } else {
      try {
        final rawBase64 = photoData.contains(',') ? photoData.split(',')[1] : photoData;
        final bytes = base64Decode(rawBase64);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 48),
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text('Evidencia #${index + 1}', style: const TextStyle(fontSize: 16)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoThumbnail(String photoData, int index, bool isReadOnly, WorkOrderModel order) {
    Widget imageWidget;
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      imageWidget = Image.network(
        photoData,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (ctx, err, stack) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.danger),
        ),
      );
    } else {
      try {
        final rawBase64 = photoData.contains(',') ? photoData.split(',')[1] : photoData;
        final bytes = base64Decode(rawBase64);
        imageWidget = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        imageWidget = const Center(
          child: Icon(Icons.broken_image, color: AppColors.danger),
        );
      }
    }

    return Container(
      width: 90,
      height: 90,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: () => _viewPhotoFullscreen(photoData, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
            ),
          ),
          if (!isReadOnly)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () {
                  ref.read(workOrdersProvider.notifier).removeEvidencePhoto(order.id, index);
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workOrders = ref.watch(workOrdersProvider);
    final order = workOrders.firstWhere(
      (o) => o.id == widget.orderId,
      orElse: () => throw Exception('OT no encontrada'),
    );

    final isReadOnly = order.status == WorkOrderStatus.finalizada;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ejecución • ${order.orderNumber}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Capturar Foto Evidencia',
            icon: const Icon(Icons.camera_alt, color: AppColors.warning),
            onPressed: isReadOnly ? null : () => _pickImage(ImageSource.camera, order),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Barra de Estado y Control de Cronómetro
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.warning, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TIEMPO ACUMULADO',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${order.elapsedMinutes} min',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isReadOnly)
                  if (order.status == WorkOrderStatus.enProceso)
                    OutlinedButton.icon(
                      onPressed: () => _showPauseDialog(context, order),
                      icon: const Icon(Icons.pause, size: 16, color: AppColors.paused),
                      label: const Text('PAUSAR', style: TextStyle(color: AppColors.paused, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.paused),
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    )
                  else if (order.status == WorkOrderStatus.pausada)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(workOrdersProvider.notifier).resumeWorkOrder(order.id);
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('REANUDAR', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(85, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Título y Activo
          Text(
            order.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Activo: ${order.asset.code} • ${order.asset.name}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Navegación Multi-Etapa de Protocolo (MaintainX Free Navigation)
          Builder(
            builder: (context) {
              final stages = order.resolvedStages;
              if (_selectedStageIndex >= stages.length) {
                _selectedStageIndex = 0;
              }
              final currentStage = stages.isNotEmpty ? stages[_selectedStageIndex] : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado de Progreso y Modo de Visualización
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ETAPAS DEL PROTOCOLO (${stages.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.completedRequiredStepsCount}/${order.totalRequiredStepsCount} obligatorios listos (${order.completedTasksCount}/${order.totalTasksCount} totales)',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _viewAllStages = !_viewAllStages),
                        icon: Icon(_viewAllStages ? Icons.view_carousel : Icons.view_agenda_outlined, size: 16),
                        label: Text(_viewAllStages ? 'Ver por Etapa' : 'Ver Todo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Carrusel / Chips de Navegación Libre entre Etapas
                  if (stages.length > 1) ...[
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: stages.length,
                        itemBuilder: (ctx, idx) {
                          final stg = stages[idx];
                          final isSelected = !_viewAllStages && _selectedStageIndex == idx;
                          final stgSteps = order.checklist.where((s) => s.stageId == stg.id || (s.stageId.isEmpty && idx == 0)).toList();
                          final missingReq = stgSteps.where((s) => s.isRequired && !s.isStepSatisfied).length;
                          final isStageDone = stgSteps.isNotEmpty && missingReq == 0;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isStageDone ? Icons.check_circle : (missingReq > 0 ? Icons.error_outline : Icons.task_alt),
                                    size: 14,
                                    color: isSelected ? Colors.white : (isStageDone ? AppColors.success : (missingReq > 0 ? AppColors.danger : AppColors.primary)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    stg.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceElevated,
                              side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                              showCheckmark: false,
                              onSelected: (_) {
                                setState(() {
                                  _selectedStageIndex = idx;
                                  _viewAllStages = false;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Vista por Etapa Activa o Vista Combinada
                  if (!_viewAllStages && currentStage != null) ...[
                    // Banner de la etapa en curso
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text('${_selectedStageIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentStage.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                if (currentStage.description.isNotEmpty)
                                  Text(currentStage.description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Builder(
                      builder: (ctx) {
                        final activeSteps = order.checklist.where((s) => s.stageId == currentStage.id || (s.stageId.isEmpty && _selectedStageIndex == 0)).toList();
                        if (activeSteps.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('No hay pasos configurados en esta etapa.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                          );
                        }
                        return Column(
                          children: activeSteps.map((item) => _buildChecklistCard(item, order, isReadOnly)).toList(),
                        );
                      },
                    ),

                    // Botones de Navegación Rápida entre Etapas (100% Ancho Táctil)
                    if (stages.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_selectedStageIndex > 0)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _selectedStageIndex--),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: const Text('Etapa Anterior', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 46),
                                  side: const BorderSide(color: AppColors.primary),
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          if (_selectedStageIndex > 0 && _selectedStageIndex < stages.length - 1)
                            const SizedBox(width: 10),
                          if (_selectedStageIndex < stages.length - 1)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _selectedStageIndex++),
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: const Text('Siguiente Etapa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ] else ...[
                    // Vista Desplegada Completa
                    ...stages.map((stg) {
                      final stgSteps = order.checklist.where((s) => s.stageId == stg.id || (s.stageId.isEmpty && stg == stages.first)).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.layers_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(stg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                ),
                              ],
                            ),
                          ),
                          ...stgSteps.map((item) => _buildChecklistCard(item, order, isReadOnly)),
                        ],
                      );
                    }),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // SECCIÓN DE EVIDENCIAS FOTOGRÁFICAS (CÁMARA / GALERÍA)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EVIDENCIAS FOTOGRÁFICAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${order.evidencePhotos.length} fotos',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!isReadOnly) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _pickImage(ImageSource.camera, order),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('USAR CÁMARA', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _pickImage(ImageSource.gallery, order),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('GALERÍA', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          if (order.evidencePhotos.isEmpty && !_isUploadingPhoto)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isReadOnly
                          ? 'No se adjuntaron fotos de evidencia a esta orden.'
                          : 'Toca "USAR CÁMARA" para fotografiar la máquina, componentes o roturas.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: order.evidencePhotos.length + (_isUploadingPhoto ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < order.evidencePhotos.length) {
                    final photoData = order.evidencePhotos[index];
                    return _buildPhotoThumbnail(photoData, index, isReadOnly, order);
                  } else {
                    return Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          SizedBox(height: 6),
                          Text('Subiendo...', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

          const SizedBox(height: 24),

          // Repuestos Consumidos
          const Text(
            'REPUESTOS E INSUMOS CONSUMIDOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (order.spareParts.isEmpty)
            const Text('Sin repuestos cargados.', style: TextStyle(color: AppColors.textMuted))
          else
            ...order.spareParts.map((part) {
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(part.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(part.description),
                  trailing: Text(
                    '${part.consumedQuantity} ${part.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // Cierre y Finalización
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'CIERRE Y FIRMA DE CONFORMIDAD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (isReadOnly) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Causa Raíz Diagnosticada:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(order.rootCause ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    const Text('Observaciones del Técnico:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(order.technicianNotes ?? 'Sin observaciones adicionales.', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.verified, color: AppColors.success, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OT Finalizada y Validada Digitalmente',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Selector de Causa Raíz
            const Text('Diagnóstico / Causa Raíz:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRootCause,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  items: _rootCauses.map((cause) {
                    return DropdownMenuItem(
                      value: cause,
                      child: Text(cause, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRootCause = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Observaciones
            const Text('Observaciones Técnicas:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Detalle trabajos realizados, ajustes de tolerancia y anomalías...',
              ),
            ),
            const SizedBox(height: 16),

            // Firma Digital
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Firma Digital en Pantalla:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => _sigController.clear(),
                  child: const Text('Limpiar Firma', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _sigController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Banner informativo de pasos obligatorios pendientes
            Builder(
              builder: (context) {
                final unsatisfied = order.getUnsatisfiedRequiredSteps();
                if (unsatisfied.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: AppColors.danger, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${unsatisfied.length} paso(s) obligatorio(s) pendiente(s)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                            ),
                            const Text(
                              'Debe completar todas las mediciones, fotos y verificaciones obligatorias antes de enviar el mantenimiento.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Botón de Finalización
            ElevatedButton.icon(
              onPressed: () => _handleCompleteOrder(context, order),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('FINALIZAR Y BLOQUEAR ORDEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: order.canBeCompleted ? AppColors.success : AppColors.primary.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStepPhotoWidget(String photoData, {double width = 80, double height = 80}) {
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      return Image.network(
        photoData,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: AppColors.danger),
      );
    } else {
      try {
        final rawBase64 = photoData.contains(',') ? photoData.split(',')[1] : photoData;
        final bytes = base64Decode(rawBase64);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: AppColors.danger),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, color: AppColors.danger);
      }
    }
  }

  void _viewSinglePhotoFullscreen(String photoData, String title) {
    Widget imageWidget;
    if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      imageWidget = Image.network(
        photoData,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
      );
    } else {
      try {
        final rawBase64 = photoData.contains(',') ? photoData.split(',')[1] : photoData;
        final bytes = base64Decode(rawBase64);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(title, style: const TextStyle(fontSize: 15)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChecklistCard(ChecklistItemModel item, WorkOrderModel order, bool isReadOnly) {
    final isDone = item.isStepSatisfied;

    String stepTypeTitle = 'Inspección Sí/No';
    Color stepTypeColor = AppColors.primary;
    if (item.type == ChecklistItemType.numericMeasurement) {
      stepTypeTitle = 'Medición (${item.minAcceptable ?? 0} a ${item.maxAcceptable ?? 0} ${item.unit ?? ""})';
      stepTypeColor = AppColors.warning;
    } else if (item.type == ChecklistItemType.photoRequired) {
      stepTypeTitle = item.minPhotos > 1
          ? 'Fotos Requeridas (${item.allPhotos.length}/${item.minPhotos} mín)'
          : 'Foto Requerida (${item.allPhotos.length}/${item.maxPhotos} máx)';
      stepTypeColor = AppColors.paused;
    } else if (item.type == ChecklistItemType.photoBeforeAfter) {
      stepTypeTitle = 'Fotos Antes y Después';
      stepTypeColor = Colors.purple;
    } else if (item.type == ChecklistItemType.textObservation) {
      stepTypeTitle = 'Observación / Nota Técnica';
      stepTypeColor = Colors.teal;
    } else if (item.type == ChecklistItemType.singleChoice) {
      stepTypeTitle = 'Selección Única';
      stepTypeColor = Colors.indigo;
    } else if (item.type == ChecklistItemType.multipleChoice) {
      stepTypeTitle = 'Selección Múltiple (${item.selectedOptions.length}/${item.options.length})';
      stepTypeColor = Colors.deepOrange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDone ? AppColors.success.withValues(alpha: 0.4) : (item.isRequired ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
          width: isDone ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del paso: Badges de Tipo y Obligatoriedad (Sin overflow en móviles estrechos)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stepTypeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: stepTypeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    stepTypeTitle,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stepTypeColor),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isRequired ? AppColors.danger.withValues(alpha: 0.1) : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: item.isRequired ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
                      ),
                      child: Text(
                        item.isRequired ? '* OBLIGATORIO' : 'OPCIONAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: item.isRequired ? AppColors.danger : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.success.withValues(alpha: 0.12) : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDone ? AppColors.success.withValues(alpha: 0.4) : AppColors.border),
                      ),
                      child: Text(
                        isDone ? '✓ LISTO' : (item.isRequired ? '⚠️ PENDIENTE' : 'PENDIENTE'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDone ? AppColors.success : (item.isRequired ? AppColors.danger : AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Título e Indicador Principal
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.type == ChecklistItemType.booleanCheck) ...[
                  Checkbox(
                    value: item.isCompleted,
                    onChanged: isReadOnly
                        ? null
                        : (_) {
                            ref.read(workOrdersProvider.notifier).toggleChecklistItem(order.id, item.id);
                          },
                    activeColor: AppColors.success,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      isDone ? Icons.check_circle : (item.isRequired ? Icons.error_outline : Icons.radio_button_unchecked),
                      color: isDone ? AppColors.success : (item.isRequired ? AppColors.danger : AppColors.textMuted),
                      size: 20,
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          decoration: item.isCompleted && item.type == ChecklistItemType.booleanCheck ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 1. Tipo: Medición Numérica
            if (item.type == ChecklistItemType.numericMeasurement) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rango nominal: [${item.minAcceptable ?? "-"} a ${item.maxAcceptable ?? "-"}] ${item.unit ?? ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          if (item.numericValue != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Valor registrado: ${item.numericValue} ${item.unit ?? ""}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: item.isOutOfRange ? AppColors.danger : AppColors.success,
                              ),
                            ),
                            if (item.isOutOfRange)
                              const Text(
                                '⚠️ ¡FUERA DE TOLERANCIA!',
                                style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (!isReadOnly)
                      ElevatedButton(
                        onPressed: () => _showMeasurementDialog(context, order.id, item),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(75, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(item.numericValue == null ? 'Medir' : 'Modificar', style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],

            // 2. Tipo: Foto Requerida (Soporta 1 o Múltiples Fotos estilo MaintainX)
            if (item.type == ChecklistItemType.photoRequired) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.allPhotos.length >= item.minPhotos ? Icons.check_circle : Icons.camera_alt_outlined,
                              size: 16,
                              color: item.allPhotos.length >= item.minPhotos ? AppColors.success : AppColors.paused,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.minPhotos > 1
                                  ? 'Evidencia Multi-Foto (${item.minPhotos} mín)'
                                  : 'Evidencia Fotográfica',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.allPhotos.length >= item.minPhotos
                                ? AppColors.successContainer
                                : AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.allPhotos.length} / ${item.minPhotos} obligatorias (máx ${item.maxPhotos})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: item.allPhotos.length >= item.minPhotos ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (item.allPhotos.isNotEmpty) ...[
                      SizedBox(
                        height: 96,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.allPhotos.length,
                          itemBuilder: (ctx, pIdx) {
                            final photoUrl = item.allPhotos[pIdx];
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: () => _viewSinglePhotoFullscreen(photoUrl, '${item.title} - Foto #${pIdx + 1}'),
                                      child: _buildStepPhotoWidget(photoUrl, width: 92, height: 92),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#${pIdx + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  if (!isReadOnly)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () {
                                          ref.read(workOrdersProvider.notifier).removeStepPhoto(order.id, item.id, pIdx);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: AppColors.danger,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 13, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          item.minPhotos > 1
                              ? 'Este paso requiere capturar al menos ${item.minPhotos} fotografías para quedar validado.'
                              : 'Capturá una foto en planta para validar este paso.',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],

                    if (!isReadOnly && item.allPhotos.length < item.maxPhotos)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _pickStepPhoto(ImageSource.camera, order.id, item.id),
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: Text(
                                item.allPhotos.isEmpty
                                    ? 'TOMAR FOTO (1/${item.minPhotos})'
                                    : 'AGREGAR FOTO (${item.allPhotos.length + 1}/${item.maxPhotos})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              onPressed: () => _pickStepPhoto(ImageSource.gallery, order.id, item.id),
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: const Text('Galería', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            // 3. Tipo: Fotos Antes y Después
            if (item.type == ChecklistItemType.photoBeforeAfter) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registro Comparativo ANTES / DESPUÉS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Slot ANTES
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: item.photoBeforeUrl != null ? AppColors.success : AppColors.border),
                            ),
                            child: Column(
                              children: [
                                const Text('FOTO ANTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                if (item.photoBeforeUrl != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: InkWell(
                                      onTap: () => _viewSinglePhotoFullscreen(item.photoBeforeUrl!, '${item.title} (ANTES)'),
                                      child: _buildStepPhotoWidget(item.photoBeforeUrl!, width: double.infinity, height: 70),
                                    ),
                                  ),
                                  if (!isReadOnly)
                                    TextButton(
                                      onPressed: () => _pickStepBeforeAfterPhoto(ImageSource.camera, order.id, item.id, true),
                                      child: const Text('Cambiar', style: TextStyle(fontSize: 10)),
                                    ),
                                ] else ...[
                                  const Icon(Icons.camera_alt_outlined, size: 24, color: AppColors.textMuted),
                                  const SizedBox(height: 4),
                                  if (!isReadOnly)
                                    ElevatedButton(
                                      onPressed: () => _pickStepBeforeAfterPhoto(ImageSource.camera, order.id, item.id, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                      ),
                                      child: const Text('Tomar Antes', style: TextStyle(fontSize: 10)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Slot DESPUÉS
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: item.photoAfterUrl != null ? AppColors.success : AppColors.border),
                            ),
                            child: Column(
                              children: [
                                const Text('FOTO DESPUÉS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                if (item.photoAfterUrl != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: InkWell(
                                      onTap: () => _viewSinglePhotoFullscreen(item.photoAfterUrl!, '${item.title} (DESPUÉS)'),
                                      child: _buildStepPhotoWidget(item.photoAfterUrl!, width: double.infinity, height: 70),
                                    ),
                                  ),
                                  if (!isReadOnly)
                                    TextButton(
                                      onPressed: () => _pickStepBeforeAfterPhoto(ImageSource.camera, order.id, item.id, false),
                                      child: const Text('Cambiar', style: TextStyle(fontSize: 10)),
                                    ),
                                ] else ...[
                                  const Icon(Icons.camera_alt_outlined, size: 24, color: AppColors.textMuted),
                                  const SizedBox(height: 4),
                                  if (!isReadOnly)
                                    ElevatedButton(
                                      onPressed: () => _pickStepBeforeAfterPhoto(ImageSource.camera, order.id, item.id, false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                      ),
                                      child: const Text('Tomar Después', style: TextStyle(fontSize: 10)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // 4. Tipo: Observación de Texto
            if (item.type == ChecklistItemType.textObservation) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: item.textValue != null && item.textValue!.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.notes, size: 14, color: Colors.teal),
                                  SizedBox(width: 4),
                                  Text('Observación registrada:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                              if (!isReadOnly)
                                TextButton(
                                  onPressed: () => _showTextObservationDialog(context, order, item),
                                  child: const Text('Modificar', style: TextStyle(fontSize: 10)),
                                ),
                            ],
                          ),
                          Text(item.textValue!, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sin observación registrada.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          if (!isReadOnly)
                            ElevatedButton.icon(
                              onPressed: () => _showTextObservationDialog(context, order, item),
                              icon: const Icon(Icons.edit_note, size: 14),
                              label: const Text('Escribir Nota', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            ),
                        ],
                      ),
              ),
            ],

            // 5. Tipo: Selección de Opción Única
            if (item.type == ChecklistItemType.singleChoice) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Seleccione el estado verificado:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: item.options.map((option) {
                        final isSelected = item.selectedOption == option;
                        return ChoiceChip(
                          label: Text(option, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: Colors.indigo,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                          onSelected: isReadOnly
                              ? null
                              : (_) {
                                  ref.read(workOrdersProvider.notifier).recordStepChoice(order.id, item.id, option);
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // 6. Tipo: Selección Múltiple / Sub-ítems Verificables (MaintainX Checkboxes)
            if (item.type == ChecklistItemType.multipleChoice) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Marque todos los ítems verificados:',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item.selectedOptions.length}/${item.options.length} marcados',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...item.options.map((option) {
                      final isChecked = item.selectedOptions.contains(option);
                      return InkWell(
                        onTap: isReadOnly
                            ? null
                            : () {
                                ref.read(workOrdersProvider.notifier).toggleStepMultiOption(order.id, item.id, option);
                              },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isChecked ? AppColors.successContainer.withValues(alpha: 0.6) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isChecked ? AppColors.success : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 18,
                                color: isChecked ? AppColors.success : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMeasurementDialog(BuildContext context, String orderId, ChecklistItemModel item) {
    final textCtrl = TextEditingController(text: item.numericValue?.toString() ?? '');
    final notesCtrl = TextEditingController(text: item.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Registrar ${item.unit ?? "Medición"}', style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Valor medido (${item.unit ?? ""})',
                  hintText: 'Ej: 65.5',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observación (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(textCtrl.text.trim());
                if (val != null) {
                  ref.read(workOrdersProvider.notifier).recordMeasurement(
                        orderId,
                        item.id,
                        val,
                        notesCtrl.text.trim(),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showPauseDialog(BuildContext context, WorkOrderModel order) {
    final pauseCtrl = TextEditingController(text: 'En espera de repuesto especial');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Pausar Orden de Trabajo', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indique el motivo de la detención temporal de la tarea:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pauseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de pausa',
                  hintText: 'Ej: Cambio de turno, repuesto no disponible...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(workOrdersProvider.notifier)
                    .pauseWorkOrder(order.id, pauseCtrl.text.trim());
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.paused),
              child: const Text('Confirmar Pausa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCompleteOrder(BuildContext context, WorkOrderModel order) async {
    // Validación estricta: Bloquear envío si existen pasos obligatorios sin completar
    final unsatisfied = order.getUnsatisfiedRequiredSteps();
    if (unsatisfied.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pasos Obligatorios Pendientes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No se puede finalizar la orden. Faltan ${unsatisfied.length} paso(s) marcados como obligatorios por el administrador:',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: unsatisfied.length,
                      separatorBuilder: (_, _) => const Divider(height: 8),
                      itemBuilder: (ctx, i) {
                        final item = unsatisfied[i];
                        IconData iconData = Icons.radio_button_unchecked;
                        String typeDesc = 'Verificación requerida';
                        if (item.type == ChecklistItemType.numericMeasurement) {
                          iconData = Icons.straighten;
                          typeDesc = 'Medición (${item.unit ?? "valor"}) pendiente';
                        } else if (item.type == ChecklistItemType.photoRequired) {
                          iconData = Icons.photo_camera;
                          typeDesc = 'Foto obligatoria pendiente';
                        } else if (item.type == ChecklistItemType.photoBeforeAfter) {
                          iconData = Icons.compare;
                          typeDesc = 'Fotos Antes y/o Después pendientes';
                        } else if (item.type == ChecklistItemType.textObservation) {
                          iconData = Icons.edit_note;
                          typeDesc = 'Observación técnica requerida';
                        } else if (item.type == ChecklistItemType.singleChoice) {
                          iconData = Icons.tune;
                          typeDesc = 'Selección de opción requerida';
                        }

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                            child: Icon(iconData, size: 16, color: AppColors.danger),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            '${item.stageName.isNotEmpty ? "${item.stageName} • " : ""}$typeDesc',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Revisar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final first = unsatisfied.first;
                  final stageIdx = order.resolvedStages.indexWhere((s) => s.id == first.stageId);
                  setState(() {
                    if (stageIdx != -1) {
                      _selectedStageIndex = stageIdx;
                      _viewAllStages = false;
                    } else {
                      _viewAllStages = true;
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Ir al Paso Pendiente'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe firmar en pantalla para validar el cierre de la orden de trabajo.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final isOnline = ref.read(isOnlineStateProvider);
    final sigBytes = await _sigController.toPngBytes();

    String signatureStr = 'SIG_VERIFIED_${DateTime.now().millisecondsSinceEpoch}';

    if (sigBytes != null) {
      if (isOnline && SupabaseConfig.isConfigured) {
        final sigFileName = 'sig_${order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}.png';
        final uploadedSigUrl = await SupabaseSyncService.uploadEvidencePhoto(
          bytes: sigBytes,
          fileName: sigFileName,
          contentType: 'image/png',
        );
        signatureStr = uploadedSigUrl ?? 'data:image/png;base64,${base64Encode(sigBytes)}';
      } else {
        signatureStr = 'data:image/png;base64,${base64Encode(sigBytes)}';
      }
    }

    await ref.read(workOrdersProvider.notifier).completeWorkOrder(
          orderId: order.id,
          rootCause: _selectedRootCause,
          notes: _notesController.text.trim(),
          signatureBase64: signatureStr,
          evidencePhotos: order.evidencePhotos,
        );

    // Si estamos online y Supabase configurado, procesar la cola de sincronización inmediatamente
    if (isOnline && SupabaseConfig.isConfigured) {
      await ref.read(syncQueueProvider.notifier).processSyncQueue();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline && SupabaseConfig.isConfigured
                ? '¡OT finalizada! Firmas y fotos sincronizadas con la nube (Supabase).'
                : '¡Orden de Trabajo finalizada y guardada localmente!',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }
}
