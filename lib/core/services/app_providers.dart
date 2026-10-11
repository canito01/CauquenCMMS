import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/spare_part_model.dart';
import '../models/sync_item_model.dart';
import '../models/work_order_model.dart';
import '../config/supabase_config.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'supabase_sync_service.dart';

// Proveedor de Almacenamiento Local
final localStorageProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageProvider must be overridden in main()');
});

// Proveedor de Conectividad
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Estado de Conectividad Reactivo (Riverpod 3 Notifier)
class IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = ref.watch(connectivityServiceProvider);
    service.onConnectivityChanged.listen((online) {
      state = online;
    });
    return service.isOnline;
  }

  void updateStatus(bool val) {
    state = val;
  }
}

final isOnlineStateProvider =
    NotifierProvider<IsOnlineNotifier, bool>(IsOnlineNotifier.new);

// Proveedor de Repuestos / Inventario (Riverpod 3 Notifier)
class InventoryNotifier extends Notifier<List<SparePartModel>> {
  @override
  List<SparePartModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getSpareParts();
  }

  Future<void> consumePart(String partId, int quantity) async {
    final storage = ref.read(localStorageProvider);
    state = state.map((p) {
      if (p.id == partId) {
        final newStock = (p.stockAvailable - quantity).clamp(0, 9999);
        return p.copyWith(
          stockAvailable: newStock,
          consumedQuantity: p.consumedQuantity + quantity,
        );
      }
      return p;
    }).toList();
    await storage.saveSpareParts(state);
  }
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, List<SparePartModel>>(InventoryNotifier.new);

// Proveedor de Cola de Sincronización (Riverpod 3 Notifier)
class SyncQueueNotifier extends Notifier<List<SyncQueueItem>> {
  @override
  List<SyncQueueItem> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getSyncQueue();
  }

  Future<void> enqueue({
    required String entityId,
    required SyncActionType actionType,
    required String description,
  }) async {
    final storage = ref.read(localStorageProvider);
    final item = SyncQueueItem(
      id: const Uuid().v4(),
      entityId: entityId,
      entityType: 'work_order',
      actionType: actionType,
      description: description,
      createdAt: DateTime.now(),
    );
    await storage.enqueueSyncItem(item);
    state = storage.getSyncQueue();
  }

  Future<void> processSyncQueue() async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);
    if (!isOnline || state.isEmpty) return;

    final orders = ref.read(workOrdersProvider);

    // Si Supabase está configurado con credenciales, sincronizamos con PostgreSQL y Storage real
    if (SupabaseConfig.isConfigured) {
      final updatedOrders = await SupabaseSyncService.syncWorkOrdersToCloud(orders);
      if (updatedOrders != null) {
        await storage.saveWorkOrders(updatedOrders);
        ref.read(workOrdersProvider.notifier).updateAllOrders(updatedOrders);
      }
    } else {
      // Si aún no se configuraron credenciales, simula guardado local
      await Future.delayed(const Duration(seconds: 1));
      final updatedOrders = orders.map((o) {
        if (o.syncStatus == SyncStatus.pendingSync) {
          return o.copyWith(syncStatus: SyncStatus.synced);
        }
        return o;
      }).toList();

      await storage.saveWorkOrders(updatedOrders);
      ref.read(workOrdersProvider.notifier).refreshFromStorage();
    }

    // Limpiamos la cola
    await storage.clearSyncQueue();
    state = [];
  }

  Future<void> clearSyncQueue() async {
    final storage = ref.read(localStorageProvider);
    await storage.clearSyncQueue();
    state = [];
  }
}

final syncQueueProvider =
    NotifierProvider<SyncQueueNotifier, List<SyncQueueItem>>(SyncQueueNotifier.new);

// Proveedor de Órdenes de Trabajo (Riverpod 3 Notifier)
class WorkOrdersNotifier extends Notifier<List<WorkOrderModel>> {
  @override
  List<WorkOrderModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getWorkOrders();
  }

  void refreshFromStorage() {
    final storage = ref.read(localStorageProvider);
    state = storage.getWorkOrders();
  }

  // Iniciar ejecución de OT
  Future<void> startWorkOrder(String orderId) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        return wo.copyWith(
          status: WorkOrderStatus.enProceso,
          startedAt: wo.startedAt ?? DateTime.now(),
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.statusChange,
          description: 'OT iniciada por el técnico',
        );
  }

  // Pausar ejecución de OT
  Future<void> pauseWorkOrder(String orderId, String reason) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        return wo.copyWith(
          status: WorkOrderStatus.pausada,
          pauseReason: reason,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.statusChange,
          description: 'OT pausada: $reason',
        );
  }

  // Reanudar OT pausada
  Future<void> resumeWorkOrder(String orderId) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        return wo.copyWith(
          status: WorkOrderStatus.enProceso,
          pauseReason: null,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.statusChange,
          description: 'OT reanudada',
        );
  }

  // Alternar tarea de checklist (booleana)
  Future<void> toggleChecklistItem(String orderId, String itemId) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            return item.copyWith(isCompleted: !item.isCompleted);
          }
          return item;
        }).toList();

        return wo.copyWith(
          checklist: updatedChecklist,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.checklistUpdate,
          description: 'Checklist actualizado en OT',
        );
  }

  // Registrar medición numérica en checklist
  Future<void> recordMeasurement(
    String orderId,
    String itemId,
    double value,
    String? notes,
  ) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            return item.copyWith(
              numericValue: value,
              isCompleted: true,
              notes: notes,
            );
          }
          return item;
        }).toList();

        return wo.copyWith(
          checklist: updatedChecklist,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.checklistUpdate,
          description: 'Medición registrada: $value en OT',
        );
  }

  // Adjuntar foto de evidencia (URL o Base64) a la orden
  Future<void> attachEvidencePhoto(String orderId, String photoData) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final photos = List<String>.from(wo.evidencePhotos)..add(photoData);
        return wo.copyWith(
          evidencePhotos: photos,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.checklistUpdate,
          description: 'Foto de evidencia adjuntada a OT',
        );
  }

  // Eliminar foto de evidencia de una orden
  Future<void> removeEvidencePhoto(String orderId, int index) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final photos = List<String>.from(wo.evidencePhotos);
        if (index >= 0 && index < photos.length) {
          photos.removeAt(index);
        }
        return wo.copyWith(
          evidencePhotos: photos,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);
  }

  // Actualizar lista en memoria y local storage (post-sincronización en la nube)
  Future<void> updateAllOrders(List<WorkOrderModel> orders) async {
    final storage = ref.read(localStorageProvider);
    state = orders;
    await storage.saveWorkOrders(orders);
  }

  // Finalizar OT con firma, observaciones y fotos de evidencia
  Future<void> completeWorkOrder({
    required String orderId,
    required String rootCause,
    required String notes,
    required String signatureBase64,
    List<String>? evidencePhotos,
  }) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        return wo.copyWith(
          status: WorkOrderStatus.finalizada,
          completedAt: DateTime.now(),
          rootCause: rootCause,
          technicianNotes: notes,
          supervisorSignature: signatureBase64,
          evidencePhotos: evidencePhotos ?? wo.evidencePhotos,
          syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pendingSync,
          updatedAt: DateTime.now(),
        );
      }
      return wo;
    }).toList();

    state = updatedList;
    await storage.saveWorkOrders(updatedList);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.completionSignature,
          description: 'OT finalizada y firmada',
        );
  }
}

final workOrdersProvider =
    NotifierProvider<WorkOrdersNotifier, List<WorkOrderModel>>(WorkOrdersNotifier.new);
