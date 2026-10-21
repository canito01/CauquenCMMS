import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/asset_model.dart';
import '../models/checklist_item_model.dart';
import '../models/crew_model.dart';
import '../models/spare_part_model.dart';
import '../models/task_template_model.dart';
import '../models/user_model.dart';
import '../models/work_order_model.dart';
import '../models/workflow_stage_model.dart';

class CloudSyncBundle {
  final List<WorkOrderModel>? workOrders;
  final List<AssetModel>? assets;
  final List<SparePartModel>? spareParts;
  final List<TaskTemplateModel>? templates;
  final List<CrewModel>? crews;
  final List<UserModel>? users;

  const CloudSyncBundle({
    this.workOrders,
    this.assets,
    this.spareParts,
    this.templates,
    this.crews,
    this.users,
  });
}

class SupabaseSyncService {
  static const String _metaPrefix = '__CAUQUEN_META_V2__:';
  static const String _stepMetaPrefix = '__CAUQUEN_STEP_V2__:';

  static SupabaseClient? get client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Inicializa el cliente Supabase al arrancar la app si está configurado
  static Future<void> initializeIfConfigured() async {
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
      } catch (_) {}
    }
  }

  // Subir imagen binaria a Supabase Storage (Bucket 'evidences')
  static Future<String?> uploadEvidencePhoto({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      await supabase.storage.from('evidences').uploadBinary(
            cleanFileName,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = supabase.storage.from('evidences').getPublicUrl(cleanFileName);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  // Convierte una foto en Base64 a URL pública de Supabase Storage si aún no fue subida
  static Future<String> _ensurePhotoUploaded(
    String photoStr, {
    required String filePrefix,
    String contentType = 'image/jpeg',
  }) async {
    if (photoStr.isEmpty ||
        photoStr.startsWith('http://') ||
        photoStr.startsWith('https://')) {
      return photoStr;
    }
    try {
      final rawBase64 = photoStr.contains(',') ? photoStr.split(',')[1] : photoStr;
      final bytes = base64Decode(rawBase64);
      final ext = contentType.contains('png') ? 'png' : 'jpg';
      final fileName = '${filePrefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final uploadedUrl = await uploadEvidencePhoto(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      return uploadedUrl ?? photoStr;
    } catch (_) {
      return photoStr;
    }
  }

  // Registrar foto en la tabla 'evidence_photos'
  static Future<bool> recordEvidencePhoto({
    required String workOrderId,
    required String photoUrl,
    String? caption,
  }) async {
    final supabase = client;
    if (supabase == null) return false;

    try {
      final existing = await supabase
          .from('evidence_photos')
          .select('id')
          .eq('work_order_id', workOrderId)
          .eq('photo_url', photoUrl)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('evidence_photos').insert({
          'work_order_id': workOrderId,
          'photo_url': photoUrl,
          'caption': caption ?? 'Evidencia fotográfica de orden de trabajo',
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Eliminar orden de trabajo de la nube
  static Future<void> deleteWorkOrderFromCloud(String orderId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('checklist_items').delete().eq('work_order_id', orderId);
      await supabase.from('evidence_photos').delete().eq('work_order_id', orderId);
      await supabase.from('work_orders').delete().eq('id', orderId);
    } catch (_) {}
  }

  static Future<void> deleteAssetFromCloud(String assetId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('assets').delete().eq('id', assetId);
    } catch (_) {}
  }

  static Future<void> deleteSparePartFromCloud(String partId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('spare_parts').delete().eq('id', partId);
    } catch (_) {}
  }

  static Future<void> deleteTemplateFromCloud(String templateId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('task_templates').delete().eq('id', templateId);
    } catch (_) {}
  }

  static Future<void> deleteCrewFromCloud(String crewId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('crews').delete().eq('id', crewId);
    } catch (_) {}
  }

  static Future<void> deleteUserFromCloud(String userId) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      await supabase.from('plant_users').delete().eq('id', userId);
    } catch (_) {}
  }

  // Sincronizar órdenes de trabajo locales hacia PostgreSQL y fotos hacia Storage
  static Future<List<WorkOrderModel>?> syncWorkOrdersToCloud(
    List<WorkOrderModel> orders, {
    Set<String> deletedIds = const {},
  }) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final List<WorkOrderModel> updatedOrders = [];

      for (final order in orders) {
        if (deletedIds.contains(order.id)) continue;

        // 1. Upsert en tabla assets
        await supabase.from('assets').upsert({
          'id': order.asset.id,
          'code': order.asset.code,
          'name': order.asset.name,
          'location': order.asset.location,
          'criticality': order.asset.criticality,
          'status': order.asset.status,
          'last_maintenance': order.asset.lastMaintenance,
        });

        // 2. Procesar fotos de evidencia generales de la OT
        final List<String> updatedPhotoUrls = [];
        for (int i = 0; i < order.evidencePhotos.length; i++) {
          final uploaded = await _ensurePhotoUploaded(
            order.evidencePhotos[i],
            filePrefix: 'wo_${order.orderNumber}_ev_$i',
          );
          updatedPhotoUrls.add(uploaded);
          if (uploaded.startsWith('http')) {
            await recordEvidencePhoto(
              workOrderId: order.id,
              photoUrl: uploaded,
              caption: 'Evidencia general OT ${order.orderNumber}',
            );
          }
        }

        // 3. Procesar fotos de cada paso del checklist (1 foto, múltiples fotos, antes y después)
        final List<ChecklistItemModel> updatedChecklist = [];
        for (int sIdx = 0; sIdx < order.checklist.length; sIdx++) {
          final item = order.checklist[sIdx];

          // Subir lista de fotos del paso (allPhotos)
          final List<String> stepUploadedUrls = [];
          for (int pIdx = 0; pIdx < item.allPhotos.length; pIdx++) {
            final uploadedStepPhoto = await _ensurePhotoUploaded(
              item.allPhotos[pIdx],
              filePrefix: 'wo_${order.orderNumber}_stp_${sIdx}_$pIdx',
            );
            stepUploadedUrls.add(uploadedStepPhoto);
          }

          // Subir foto Antes y Después si existen
          String? uploadedBefore = item.photoBeforeUrl;
          if (uploadedBefore != null && uploadedBefore.isNotEmpty) {
            uploadedBefore = await _ensurePhotoUploaded(
              uploadedBefore,
              filePrefix: 'wo_${order.orderNumber}_stp_${sIdx}_before',
            );
          }

          String? uploadedAfter = item.photoAfterUrl;
          if (uploadedAfter != null && uploadedAfter.isNotEmpty) {
            uploadedAfter = await _ensurePhotoUploaded(
              uploadedAfter,
              filePrefix: 'wo_${order.orderNumber}_stp_${sIdx}_after',
            );
          }

          updatedChecklist.add(item.copyWith(
            photoUrl: stepUploadedUrls.isNotEmpty ? stepUploadedUrls.first : item.photoUrl,
            photoUrls: stepUploadedUrls,
            photoBeforeUrl: uploadedBefore,
            photoAfterUrl: uploadedAfter,
          ));
        }

        // 4. Procesar firma si es Base64
        String? finalSignature = order.supervisorSignature;
        if (finalSignature != null && finalSignature.startsWith('data:image')) {
          finalSignature = await _ensurePhotoUploaded(
            finalSignature,
            filePrefix: 'sig_${order.orderNumber}',
            contentType: 'image/png',
          );
        }

        // 5. Preparar metadatos enriquecidos compatibles con versión base o extendida de PostgreSQL
        final cleanProtocols = order.safetyProtocols
            .where((p) => !p.startsWith(_metaPrefix))
            .toList();
        final metaPayload = jsonEncode({
          'assignedCrew': order.assignedCrew,
          'stages': order.stages.map((s) => s.toMap()).toList(),
          'spareParts': order.spareParts.map((p) => p.toMap()).toList(),
          'evidencePhotos': updatedPhotoUrls,
        });
        final protocolsWithMeta = [...cleanProtocols, '$_metaPrefix$metaPayload'];

        // Intentar upsert con columnas nuevas; si la BD aún no corrió el ALTER TABLE, caer al esquema base
        try {
          await supabase.from('work_orders').upsert({
            'id': order.id,
            'order_number': order.orderNumber,
            'title': order.title,
            'description': order.description,
            'type': order.type.name,
            'priority': order.priority.name,
            'status': order.status.name,
            'asset_id': order.asset.id,
            'technician_name': order.technicianName,
            'technician_badge': order.technicianBadge,
            'assigned_crew': order.assignedCrew,
            'scheduled_date': order.scheduledDate.toIso8601String(),
            'started_at': order.startedAt?.toIso8601String(),
            'completed_at': order.completedAt?.toIso8601String(),
            'elapsed_minutes': order.elapsedMinutes,
            'pause_reason': order.pauseReason,
            'safety_protocols': protocolsWithMeta,
            'stages': order.stages.map((s) => s.toMap()).toList(),
            'spare_parts_json': order.spareParts.map((p) => p.toMap()).toList(),
            'evidence_photos_json': updatedPhotoUrls,
            'root_cause': order.rootCause,
            'technician_notes': order.technicianNotes,
            'supervisor_signature': finalSignature,
            'updated_at': order.updatedAt.toIso8601String(),
          });
        } catch (_) {
          await supabase.from('work_orders').upsert({
            'id': order.id,
            'order_number': order.orderNumber,
            'title': order.title,
            'description': order.description,
            'type': order.type.name,
            'priority': order.priority.name,
            'status': order.status.name,
            'asset_id': order.asset.id,
            'technician_name': order.technicianName,
            'technician_badge': order.technicianBadge,
            'scheduled_date': order.scheduledDate.toIso8601String(),
            'started_at': order.startedAt?.toIso8601String(),
            'completed_at': order.completedAt?.toIso8601String(),
            'elapsed_minutes': order.elapsedMinutes,
            'pause_reason': order.pauseReason,
            'safety_protocols': protocolsWithMeta,
            'root_cause': order.rootCause,
            'technician_notes': order.technicianNotes,
            'supervisor_signature': finalSignature,
            'updated_at': order.updatedAt.toIso8601String(),
          });
        }

        // 6. Sincronizar checklist_items de la OT en LOTE (1 sola consulta en vez de N consultas)
        try {
          final existingRows = await supabase
              .from('checklist_items')
              .select('id')
              .eq('work_order_id', order.id);
          final currentIds = updatedChecklist.map((e) => e.id).toSet();
          final toDeleteIds = <String>[];
          for (final row in (existingRows as List)) {
            final rowId = row['id'] as String?;
            if (rowId != null && !currentIds.contains(rowId)) {
              toDeleteIds.add(rowId);
            }
          }
          if (toDeleteIds.isNotEmpty) {
            await supabase.from('checklist_items').delete().inFilter('id', toDeleteIds);
          }
        } catch (_) {}

        if (updatedChecklist.isNotEmpty) {
          final nowIso = DateTime.now().toIso8601String();
          final fullBatch = updatedChecklist.map((item) {
            final stepMetaEncoded = '$_stepMetaPrefix${jsonEncode(item.toMap())}';
            return {
              'id': item.id,
              'work_order_id': order.id,
              'stage_id': item.stageId,
              'stage_name': item.stageName,
              'title': item.title,
              'description': item.description,
              'type': item.type.name,
              'is_completed': item.isCompleted,
              'is_required': item.isRequired,
              'numeric_value': item.numericValue,
              'unit': item.unit,
              'min_acceptable': item.minAcceptable,
              'max_acceptable': item.maxAcceptable,
              'photo_url': item.photoUrl,
              'photo_urls': item.photoUrls,
              'min_photos': item.minPhotos,
              'max_photos': item.maxPhotos,
              'photo_before_url': item.photoBeforeUrl,
              'photo_after_url': item.photoAfterUrl,
              'options': item.options,
              'selected_option': item.selectedOption,
              'selected_options': item.selectedOptions,
              'text_value': item.textValue,
              'notes': stepMetaEncoded,
              'updated_at': nowIso,
            };
          }).toList();

          try {
            await supabase.from('checklist_items').upsert(fullBatch);
          } catch (_) {
            final fallbackBatch = updatedChecklist.map((item) {
              final stepMetaEncoded = '$_stepMetaPrefix${jsonEncode(item.toMap())}';
              return {
                'id': item.id,
                'work_order_id': order.id,
                'title': item.title,
                'description': item.description,
                'type': item.type.name,
                'is_completed': item.isCompleted,
                'numeric_value': item.numericValue,
                'unit': item.unit,
                'min_acceptable': item.minAcceptable,
                'max_acceptable': item.maxAcceptable,
                'notes': stepMetaEncoded,
                'updated_at': nowIso,
              };
            }).toList();
            await supabase.from('checklist_items').upsert(fallbackBatch);
          }
        }

        updatedOrders.add(order.copyWith(
          checklist: updatedChecklist,
          evidencePhotos: updatedPhotoUrls,
          supervisorSignature: finalSignature,
          syncStatus: SyncStatus.synced,
        ));
      }
      return updatedOrders;
    } catch (_) {
      return null;
    }
  }

  // Descargar (PULL) todas las órdenes de trabajo desde Supabase PostgreSQL
  static Future<List<WorkOrderModel>?> fetchWorkOrdersFromCloud({
    required List<AssetModel> fallbackAssets,
  }) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final assetsRows = await supabase.from('assets').select();
      final Map<String, AssetModel> assetsById = {
        for (final a in fallbackAssets) a.id: a,
      };
      for (final row in (assetsRows as List)) {
        final m = row as Map<String, dynamic>;
        final asset = AssetModel(
          id: m['id'] as String,
          code: m['code'] as String? ?? 'EQ-000',
          name: m['name'] as String? ?? 'Equipo de Planta',
          location: m['location'] as String? ?? 'Planta General',
          criticality: m['criticality'] as String? ?? 'MEDIA',
          status: m['status'] as String? ?? 'OPERATIVO',
          lastMaintenance: m['last_maintenance'] as String? ?? '-',
        );
        assetsById[asset.id] = asset;
      }

      final woRows = await supabase
          .from('work_orders')
          .select()
          .order('updated_at', ascending: false);

      if ((woRows as List).isEmpty) return <WorkOrderModel>[];

      final checklistRows = await supabase.from('checklist_items').select();
      final photosRows = await supabase.from('evidence_photos').select();

      final Map<String, List<ChecklistItemModel>> checklistByOrder = {};
      for (final rawRow in (checklistRows as List)) {
        final r = rawRow as Map<String, dynamic>;
        final woId = r['work_order_id'] as String?;
        if (woId == null) continue;

        ChecklistItemModel? parsedItem;
        final notesStr = r['notes'] as String?;
        if (notesStr != null && notesStr.startsWith(_stepMetaPrefix)) {
          try {
            final jsonPart = notesStr.substring(_stepMetaPrefix.length);
            final decodedMap = jsonDecode(jsonPart) as Map<String, dynamic>;
            parsedItem = ChecklistItemModel.fromMap(decodedMap);
          } catch (_) {}
        }

        parsedItem ??= ChecklistItemModel(
          id: r['id'] as String,
          stageId: r['stage_id'] as String? ?? 'stg-1',
          stageName: r['stage_name'] as String? ?? 'Etapa 1: Procedimientos Iniciales',
          title: r['title'] as String? ?? 'Procedimiento técnico',
          description: r['description'] as String? ?? '',
          type: ChecklistItemType.values.firstWhere(
            (t) => t.name == (r['type'] as String? ?? 'booleanCheck'),
            orElse: () => ChecklistItemType.booleanCheck,
          ),
          isCompleted: r['is_completed'] as bool? ?? false,
          isRequired: r['is_required'] as bool? ?? true,
          numericValue: (r['numeric_value'] as num?)?.toDouble(),
          unit: r['unit'] as String?,
          minAcceptable: (r['min_acceptable'] as num?)?.toDouble(),
          maxAcceptable: (r['max_acceptable'] as num?)?.toDouble(),
          photoUrl: r['photo_url'] as String?,
          photoUrls: List<String>.from(r['photo_urls'] as List? ?? []),
          minPhotos: (r['min_photos'] as num?)?.toInt() ?? 1,
          maxPhotos: (r['max_photos'] as num?)?.toInt() ?? 5,
          photoBeforeUrl: r['photo_before_url'] as String?,
          photoAfterUrl: r['photo_after_url'] as String?,
          options: List<String>.from(r['options'] as List? ?? []),
          selectedOption: r['selected_option'] as String?,
          selectedOptions: List<String>.from(r['selected_options'] as List? ?? []),
          textValue: r['text_value'] as String?,
          notes: notesStr,
        );

        checklistByOrder.putIfAbsent(woId, () => []).add(parsedItem);
      }

      final Map<String, List<String>> photosByOrder = {};
      for (final rawPhoto in (photosRows as List)) {
        final p = rawPhoto as Map<String, dynamic>;
        final woId = p['work_order_id'] as String?;
        final url = p['photo_url'] as String?;
        if (woId != null && url != null && url.isNotEmpty) {
          final list = photosByOrder.putIfAbsent(woId, () => []);
          if (!list.contains(url)) list.add(url);
        }
      }

      final List<WorkOrderModel> result = [];
      for (final w in woRows) {
        final woId = w['id'] as String;
        final assetId = w['asset_id'] as String?;
        final asset = (assetId != null && assetsById.containsKey(assetId))
            ? assetsById[assetId]!
            : (fallbackAssets.isNotEmpty
                ? fallbackAssets.first
                : const AssetModel(
                    id: 'ast-default',
                    code: 'EQ-001',
                    name: 'Equipo de Planta',
                    location: 'Nave Principal',
                    criticality: 'MEDIA',
                    status: 'OPERATIVO',
                    lastMaintenance: '-',
                  ));

        final rawProtocols = List<String>.from(w['safety_protocols'] as List? ?? []);
        final List<String> cleanProtocols = [];
        String? assignedCrew = w['assigned_crew'] as String?;
        List<WorkflowStageModel> stages = [];
        List<SparePartModel> spareParts = [];
        List<String> evidencePhotos = List<String>.from(photosByOrder[woId] ?? []);

        if (w['stages'] is List && (w['stages'] as List).isNotEmpty) {
          stages = (w['stages'] as List)
              .map((s) => WorkflowStageModel.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList();
        }
        if (w['spare_parts_json'] is List && (w['spare_parts_json'] as List).isNotEmpty) {
          spareParts = (w['spare_parts_json'] as List)
              .map((p) => SparePartModel.fromMap(Map<String, dynamic>.from(p as Map)))
              .toList();
        }
        if (w['evidence_photos_json'] is List && (w['evidence_photos_json'] as List).isNotEmpty) {
          for (final ph in (w['evidence_photos_json'] as List)) {
            if (ph is String && !evidencePhotos.contains(ph)) {
              evidencePhotos.add(ph);
            }
          }
        }

        for (final p in rawProtocols) {
          if (p.startsWith(_metaPrefix)) {
            try {
              final metaJson = jsonDecode(p.substring(_metaPrefix.length)) as Map<String, dynamic>;
              assignedCrew ??= metaJson['assignedCrew'] as String?;
              if (stages.isEmpty && metaJson['stages'] is List) {
                stages = (metaJson['stages'] as List)
                    .map((s) => WorkflowStageModel.fromMap(Map<String, dynamic>.from(s as Map)))
                    .toList();
              }
              if (spareParts.isEmpty && metaJson['spareParts'] is List) {
                spareParts = (metaJson['spareParts'] as List)
                    .map((sp) => SparePartModel.fromMap(Map<String, dynamic>.from(sp as Map)))
                    .toList();
              }
              if (metaJson['evidencePhotos'] is List) {
                for (final ph in (metaJson['evidencePhotos'] as List)) {
                  if (ph is String && !evidencePhotos.contains(ph)) {
                    evidencePhotos.add(ph);
                  }
                }
              }
            } catch (_) {}
          } else {
            cleanProtocols.add(p);
          }
        }

        result.add(
          WorkOrderModel(
            id: woId,
            orderNumber: w['order_number'] as String? ?? 'OT-0000',
            title: w['title'] as String? ?? 'Orden de Trabajo',
            description: w['description'] as String? ?? '',
            type: WorkOrderType.values.firstWhere(
              (t) => t.name == (w['type'] as String? ?? 'correctivo'),
              orElse: () => WorkOrderType.correctivo,
            ),
            priority: WorkOrderPriority.values.firstWhere(
              (p) => p.name == (w['priority'] as String? ?? 'normal'),
              orElse: () => WorkOrderPriority.normal,
            ),
            status: WorkOrderStatus.values.firstWhere(
              (s) => s.name == (w['status'] as String? ?? 'pendiente'),
              orElse: () => WorkOrderStatus.pendiente,
            ),
            asset: asset,
            technicianName: w['technician_name'] as String? ?? 'Operario de Planta',
            technicianBadge: w['technician_badge'] as String? ?? 'TEC-0000',
            assignedCrew: assignedCrew,
            scheduledDate: DateTime.tryParse(w['scheduled_date'] as String? ?? '') ?? DateTime.now(),
            startedAt: w['started_at'] != null ? DateTime.tryParse(w['started_at'] as String) : null,
            completedAt: w['completed_at'] != null ? DateTime.tryParse(w['completed_at'] as String) : null,
            elapsedMinutes: (w['elapsed_minutes'] as num?)?.toInt() ?? 0,
            pauseReason: w['pause_reason'] as String?,
            safetyProtocols: cleanProtocols,
            stages: stages,
            checklist: checklistByOrder[woId] ?? [],
            spareParts: spareParts,
            rootCause: w['root_cause'] as String?,
            technicianNotes: w['technician_notes'] as String?,
            supervisorSignature: w['supervisor_signature'] as String?,
            evidencePhotos: evidencePhotos,
            syncStatus: SyncStatus.synced,
            updatedAt: DateTime.tryParse(w['updated_at'] as String? ?? '') ?? DateTime.now(),
          ),
        );
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  // Sincronizar Activos con Supabase
  static Future<void> syncAssetsToCloud(List<AssetModel> assets) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      for (final asset in assets) {
        await supabase.from('assets').upsert({
          'id': asset.id,
          'code': asset.code,
          'name': asset.name,
          'location': asset.location,
          'criticality': asset.criticality,
          'status': asset.status,
          'last_maintenance': asset.lastMaintenance,
        });
      }
    } catch (_) {}
  }

  static Future<List<AssetModel>?> fetchAssetsFromCloud() async {
    final supabase = client;
    if (supabase == null) return null;
    try {
      final rows = await supabase.from('assets').select();
      if ((rows as List).isEmpty) return null;
      return rows.map((m) {
        return AssetModel(
          id: m['id'] as String,
          code: m['code'] as String? ?? '',
          name: m['name'] as String? ?? '',
          location: m['location'] as String? ?? '',
          criticality: m['criticality'] as String? ?? 'MEDIA',
          status: m['status'] as String? ?? 'OPERATIVO',
          lastMaintenance: m['last_maintenance'] as String? ?? '-',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  // Sincronizar Repuestos con Supabase
  static Future<void> syncSparePartsToCloud(List<SparePartModel> parts) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      for (final part in parts) {
        await supabase.from('spare_parts').upsert({
          'id': part.id,
          'code': part.code,
          'description': part.description,
          'location_warehouse': part.locationWarehouse,
          'stock_available': part.stockAvailable,
          'unit': part.unit,
        });
      }
    } catch (_) {}
  }

  static Future<List<SparePartModel>?> fetchSparePartsFromCloud() async {
    final supabase = client;
    if (supabase == null) return null;
    try {
      final rows = await supabase.from('spare_parts').select();
      if ((rows as List).isEmpty) return null;
      return rows.map((m) {
        return SparePartModel(
          id: m['id'] as String,
          code: m['code'] as String? ?? '',
          description: m['description'] as String? ?? '',
          locationWarehouse: m['location_warehouse'] as String? ?? '',
          stockAvailable: (m['stock_available'] as num?)?.toInt() ?? 0,
          unit: m['unit'] as String? ?? 'un',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  // Sincronizar Plantillas / Protocolos Técnicos Maestros con Supabase
  static Future<void> syncTemplatesToCloud(List<TaskTemplateModel> templates) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      for (final tpl in templates) {
        await supabase.from('task_templates').upsert({
          'id': tpl.id,
          'name': tpl.name,
          'description': tpl.description,
          'type': tpl.type.name,
          'default_priority': tpl.defaultPriority.name,
          'estimated_minutes': tpl.estimatedMinutes,
          'stages': tpl.stages.map((s) => s.toMap()).toList(),
          'steps': tpl.steps.map((s) => s.toMap()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  static Future<List<TaskTemplateModel>?> fetchTemplatesFromCloud() async {
    final supabase = client;
    if (supabase == null) return null;
    try {
      final rows = await supabase.from('task_templates').select();
      if ((rows as List).isEmpty) return null;
      return rows.map((m) {
        return TaskTemplateModel.fromMap({
          'id': m['id'],
          'name': m['name'],
          'description': m['description'] ?? '',
          'type': m['type'] ?? 'preventivo',
          'defaultPriority': m['default_priority'] ?? 'normal',
          'estimatedMinutes': m['estimated_minutes'] ?? 45,
          'stages': m['stages'] ?? [],
          'steps': m['steps'] ?? [],
        });
      }).toList();
    } catch (_) {
      return null;
    }
  }

  // Sincronizar Cuadrillas con Supabase
  static Future<void> syncCrewsToCloud(List<CrewModel> crews) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      for (final crew in crews) {
        await supabase.from('crews').upsert({
          'id': crew.id,
          'name': crew.name,
          'shift': crew.shift,
          'specialty': crew.specialty,
          'leader_name': crew.leaderName,
          'leader_badge': crew.leaderBadge,
          'member_names': crew.memberNames,
          'notes': crew.notes,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  static Future<List<CrewModel>?> fetchCrewsFromCloud() async {
    final supabase = client;
    if (supabase == null) return null;
    try {
      final rows = await supabase.from('crews').select();
      if ((rows as List).isEmpty) return null;
      return rows.map((m) {
        return CrewModel(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          shift: m['shift'] as String? ?? 'Turno Mañana',
          specialty: m['specialty'] as String? ?? '',
          leaderName: m['leader_name'] as String? ?? '',
          leaderBadge: m['leader_badge'] as String? ?? '',
          memberNames: List<String>.from(m['member_names'] as List? ?? []),
          notes: m['notes'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  // Sincronizar Usuarios de Planta con Supabase
  static Future<void> syncUsersToCloud(List<UserModel> users) async {
    final supabase = client;
    if (supabase == null) return;
    try {
      for (final u in users) {
        await supabase.from('plant_users').upsert({
          'id': u.id,
          'email': u.email,
          'name': u.name,
          'badge': u.badge,
          'role': u.role.name,
          'shift': u.shift,
          'specialty': u.specialty,
          'phone': u.phone,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  static Future<List<UserModel>?> fetchUsersFromCloud() async {
    final supabase = client;
    if (supabase == null) return null;
    try {
      final rows = await supabase.from('plant_users').select();
      if ((rows as List).isEmpty) return null;
      return rows.map((m) {
        return UserModel.fromMap(m);
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
