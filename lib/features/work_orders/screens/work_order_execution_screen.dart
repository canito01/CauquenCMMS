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

          // Sección de Checklists y Mediciones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'PLANILLA DE VERIFICACIÓN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${order.completedTasksCount} / ${order.totalTasksCount}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...order.checklist.map((item) {
            return _buildChecklistCard(item, order, isReadOnly);
          }),

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
            const SizedBox(height: 20),

            // Botón de Finalización
            ElevatedButton.icon(
              onPressed: () => _handleCompleteOrder(context, order),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('FINALIZAR Y BLOQUEAR ORDEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
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

  Widget _buildChecklistCard(ChecklistItemModel item, WorkOrderModel order, bool isReadOnly) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.type == ChecklistItemType.booleanCheck) ...[
                  Checkbox(
                    value: item.isCompleted,
                    onChanged: isReadOnly
                        ? null
                        : (_) {
                            ref
                                .read(workOrdersProvider.notifier)
                                .toggleChecklistItem(order.id, item.id);
                          },
                    activeColor: AppColors.success,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Icon(
                      item.isCompleted ? Icons.check_circle : Icons.speed,
                      color: item.isCompleted
                          ? (item.isOutOfRange ? AppColors.danger : AppColors.success)
                          : AppColors.warning,
                      size: 22,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: item.isCompleted && item.type == ChecklistItemType.booleanCheck
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Si es medición numérica
            if (item.type == ChecklistItemType.numericMeasurement) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 8),
                    if (!isReadOnly)
                      ElevatedButton(
                        onPressed: () => _showMeasurementDialog(context, order.id, item),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(75, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(item.numericValue == null ? 'Medir' : 'Modificar', style: const TextStyle(fontSize: 11)),
                      ),
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
