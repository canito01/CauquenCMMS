import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/work_order_model.dart';

class SupabaseSyncService {
  static SupabaseClient? get client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
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
      // Subir directamente al bucket 'evidences'
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

  // Registrar foto en la tabla 'evidence_photos'
  static Future<bool> recordEvidencePhoto({
    required String workOrderId,
    required String photoUrl,
    String? caption,
  }) async {
    final supabase = client;
    if (supabase == null) return false;

    try {
      // Verificar si ya existe el registro para evitar duplicados
      final existing = await supabase
          .from('evidence_photos')
          .select('id')
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

  // Sincronizar órdenes de trabajo locales hacia PostgreSQL y fotos hacia Storage
  static Future<List<WorkOrderModel>?> syncWorkOrdersToCloud(List<WorkOrderModel> orders) async {
    final supabase = client;
    if (supabase == null) return null;

    try {
      final List<WorkOrderModel> updatedOrders = [];

      for (final order in orders) {
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

        // 2. Procesar fotos de evidencia (subir Base64 a Supabase Storage si no son URLs)
        final List<String> updatedPhotoUrls = [];
        for (int i = 0; i < order.evidencePhotos.length; i++) {
          final photoStr = order.evidencePhotos[i];
          if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
            updatedPhotoUrls.add(photoStr);
            // Asegurar que esté registrado en la tabla
            await recordEvidencePhoto(
              workOrderId: order.id,
              photoUrl: photoStr,
              caption: 'Evidencia fotográfica OT ${order.orderNumber}',
            );
          } else {
            // Es Base64 local: decodificar y subir al bucket 'evidences'
            try {
              final rawBase64 = photoStr.contains(',') ? photoStr.split(',')[1] : photoStr;
              final bytes = base64Decode(rawBase64);
              final fileName = 'wo_${order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
              final uploadedUrl = await uploadEvidencePhoto(bytes: bytes, fileName: fileName);

              if (uploadedUrl != null) {
                updatedPhotoUrls.add(uploadedUrl);
                await recordEvidencePhoto(
                  workOrderId: order.id,
                  photoUrl: uploadedUrl,
                  caption: 'Evidencia fotográfica OT ${order.orderNumber}',
                );
              } else {
                updatedPhotoUrls.add(photoStr);
              }
            } catch (_) {
              updatedPhotoUrls.add(photoStr);
            }
          }
        }

        // 3. Procesar firma si es Base64
        String? finalSignature = order.supervisorSignature;
        if (finalSignature != null && finalSignature.startsWith('data:image')) {
          try {
            final rawSig = finalSignature.contains(',') ? finalSignature.split(',')[1] : finalSignature;
            final sigBytes = base64Decode(rawSig);
            final sigFileName = 'sig_${order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}.png';
            final uploadedSigUrl = await uploadEvidencePhoto(
              bytes: sigBytes,
              fileName: sigFileName,
              contentType: 'image/png',
            );
            if (uploadedSigUrl != null) {
              finalSignature = uploadedSigUrl;
            }
          } catch (_) {}
        }

        // 4. Upsert en tabla work_orders
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
          'safety_protocols': order.safetyProtocols,
          'root_cause': order.rootCause,
          'technician_notes': order.technicianNotes,
          'supervisor_signature': finalSignature,
          'updated_at': order.updatedAt.toIso8601String(),
        });

        // 5. Upsert en tabla checklist_items
        for (final item in order.checklist) {
          await supabase.from('checklist_items').upsert({
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
            'notes': item.notes,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        updatedOrders.add(order.copyWith(
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
}
