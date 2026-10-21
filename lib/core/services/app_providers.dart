import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/asset_model.dart';
import '../models/checklist_item_model.dart';
import '../models/crew_model.dart';
import '../models/spare_part_model.dart';
import '../models/stock_movement_model.dart';
import '../models/sync_item_model.dart';
import '../models/task_template_model.dart';
import '../models/user_model.dart';
import '../models/work_order_model.dart';
import '../models/workflow_stage_model.dart';
import '../config/supabase_config.dart';
import 'mock_data_service.dart';
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
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncSparePartsToCloud(state);
    }
  }

  Future<void> addOrUpdatePart(SparePartModel part) async {
    final storage = ref.read(localStorageProvider);
    final current = List<SparePartModel>.from(state);
    final idx = current.indexWhere((p) => p.id == part.id);
    if (idx >= 0) {
      current[idx] = part;
    } else {
      current.insert(0, part);
    }
    state = current;
    await storage.saveSpareParts(current);
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncSparePartsToCloud(current);
    }
  }

  Future<void> adjustStock({
    required String partId,
    required int delta,
    required String reason,
    required String performedBy,
  }) async {
    final storage = ref.read(localStorageProvider);
    SparePartModel? targetPart;
    int prevStock = 0;
    int nextStock = 0;

    final updated = state.map((p) {
      if (p.id == partId) {
        prevStock = p.stockAvailable;
        nextStock = (p.stockAvailable + delta).clamp(0, 999999);
        targetPart = p.copyWith(stockAvailable: nextStock);
        return targetPart!;
      }
      return p;
    }).toList();

    state = updated;
    await storage.saveSpareParts(updated);

    if (targetPart != null) {
      final movement = StockMovementModel(
        id: const Uuid().v4(),
        partId: targetPart!.id,
        partCode: targetPart!.code,
        partDescription: targetPart!.description,
        type: delta >= 0 ? StockMovementType.entrada : StockMovementType.salida,
        quantity: delta.abs(),
        previousStock: prevStock,
        newStock: nextStock,
        reason: reason,
        performedBy: performedBy,
        timestamp: DateTime.now(),
      );
      await ref.read(stockMovementsProvider.notifier).addMovement(movement);
    }
  }

  Future<void> deletePart(String partId) async {
    final storage = ref.read(localStorageProvider);
    await storage.addDeletedId(partId);
    final updated = state.where((p) => p.id != partId).toList();
    state = updated;
    await storage.saveSpareParts(updated);
    if (SupabaseConfig.isConfigured) {
      await SupabaseSyncService.deleteSparePartFromCloud(partId);
    }
  }

  Future<void> replaceAllParts(List<SparePartModel> parts) async {
    final storage = ref.read(localStorageProvider);
    state = parts;
    await storage.saveSpareParts(parts);
  }
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, List<SparePartModel>>(InventoryNotifier.new);

// Proveedor de Trazabilidad de Movimientos de Stock
class StockMovementsNotifier extends Notifier<List<StockMovementModel>> {
  @override
  List<StockMovementModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getStockMovements();
  }

  Future<void> addMovement(StockMovementModel movement) async {
    final storage = ref.read(localStorageProvider);
    final updated = List<StockMovementModel>.from(state)..insert(0, movement);
    state = updated;
    await storage.saveStockMovements(updated);
  }
}

final stockMovementsProvider =
    NotifierProvider<StockMovementsNotifier, List<StockMovementModel>>(StockMovementsNotifier.new);

// Proveedor de Activos / Equipos de Planta
class AssetsNotifier extends Notifier<List<AssetModel>> {
  @override
  List<AssetModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getAssets();
  }

  Future<void> addOrUpdateAsset(AssetModel asset) async {
    final storage = ref.read(localStorageProvider);
    final current = List<AssetModel>.from(state);
    final idx = current.indexWhere((a) => a.id == asset.id);
    if (idx >= 0) {
      current[idx] = asset;
    } else {
      current.insert(0, asset);
    }
    state = current;
    await storage.saveAssets(current);
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncAssetsToCloud(current);
    }
  }

  Future<void> replaceAllAssets(List<AssetModel> assets) async {
    final storage = ref.read(localStorageProvider);
    state = assets;
    await storage.saveAssets(assets);
  }
}

final assetsProvider =
    NotifierProvider<AssetsNotifier, List<AssetModel>>(AssetsNotifier.new);

// Proveedor de Cola de Sincronización (Riverpod 3 Notifier)
class SyncQueueNotifier extends Notifier<List<SyncQueueItem>> {
  bool _isSyncing = false;

  @override
  List<SyncQueueItem> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getSyncQueue();
  }

  void refreshQueue() {
    final storage = ref.read(localStorageProvider);
    state = storage.getSyncQueue();
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
    await syncAllBidirectional();
  }

  /// Sincronización Bidireccional Completa (Push + Pull) entre PC Admin y Dispositivos Móviles
  Future<bool> syncAllBidirectional() async {
    if (_isSyncing) return true;
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);
    if (!isOnline) return false;

    _isSyncing = true;
    try {
      final deletedIds = storage.getDeletedIds();
      final localOrders = ref.read(workOrdersProvider);
      final localAssets = ref.read(assetsProvider);
      final localParts = ref.read(inventoryProvider);
      final localTemplates = ref.read(taskTemplatesProvider);
      final localCrews = ref.read(crewsProvider);
      final localUsers = ref.read(usersProvider);

      if (SupabaseConfig.isConfigured) {
        try {
          // 0. Aplicar eliminaciones pendientes en la nube (Tombstones locales)
          for (final delId in deletedIds) {
            await SupabaseSyncService.deleteWorkOrderFromCloud(delId);
            await SupabaseSyncService.deleteTemplateFromCloud(delId);
            await SupabaseSyncService.deleteSparePartFromCloud(delId);
            await SupabaseSyncService.deleteCrewFromCloud(delId);
            await SupabaseSyncService.deleteUserFromCloud(delId);
          }

          // 1. Si hay cambios pendientes locales en la cola, empujar ÚNICAMENTE las órdenes modificadas (PUSH)
          final dirtyEntityIds = state.map((q) => q.entityId).toSet();
          if (dirtyEntityIds.isNotEmpty) {
            final dirtyOrders = localOrders
                .where((o) => dirtyEntityIds.contains(o.id) && !deletedIds.contains(o.id))
                .toList();
            if (dirtyOrders.isNotEmpty) {
              await SupabaseSyncService.syncWorkOrdersToCloud(
                dirtyOrders,
                deletedIds: deletedIds,
              );
            }
            await storage.clearSyncQueue();
            state = [];
          }

          // 2. Descargar datos actualizados desde Supabase (PULL)
          final cloudAssets = await SupabaseSyncService.fetchAssetsFromCloud();
          if (cloudAssets != null && cloudAssets.isNotEmpty) {
            final filteredAssets = cloudAssets.where((a) => !deletedIds.contains(a.id)).toList();
            await ref.read(assetsProvider.notifier).replaceAllAssets(filteredAssets);
          } else if (cloudAssets != null && cloudAssets.isEmpty) {
            await SupabaseSyncService.syncAssetsToCloud(localAssets);
          }

          final cloudParts = await SupabaseSyncService.fetchSparePartsFromCloud();
          if (cloudParts != null && cloudParts.isNotEmpty) {
            final filteredParts = cloudParts.where((p) => !deletedIds.contains(p.id)).toList();
            await ref.read(inventoryProvider.notifier).replaceAllParts(filteredParts);
          } else if (cloudParts != null && cloudParts.isEmpty) {
            await SupabaseSyncService.syncSparePartsToCloud(localParts);
          }

          final cloudTemplates = await SupabaseSyncService.fetchTemplatesFromCloud();
          if (cloudTemplates != null && cloudTemplates.isNotEmpty) {
            final filteredTemplates = cloudTemplates.where((t) => !deletedIds.contains(t.id)).toList();
            await ref.read(taskTemplatesProvider.notifier).replaceAllTemplates(filteredTemplates);
          } else if (cloudTemplates != null && cloudTemplates.isEmpty) {
            await SupabaseSyncService.syncTemplatesToCloud(localTemplates);
          }

          final cloudCrews = await SupabaseSyncService.fetchCrewsFromCloud();
          if (cloudCrews != null && cloudCrews.isNotEmpty) {
            final filteredCrews = cloudCrews.where((c) => !deletedIds.contains(c.id)).toList();
            await ref.read(crewsProvider.notifier).replaceAllCrews(filteredCrews);
          } else if (cloudCrews != null && cloudCrews.isEmpty) {
            await SupabaseSyncService.syncCrewsToCloud(localCrews);
          }

          final cloudUsers = await SupabaseSyncService.fetchUsersFromCloud();
          if (cloudUsers != null && cloudUsers.isNotEmpty) {
            final filteredUsers = cloudUsers.where((u) => !deletedIds.contains(u.id)).toList();
            await ref.read(usersProvider.notifier).replaceAllUsers(filteredUsers);
          } else if (cloudUsers != null && cloudUsers.isEmpty) {
            await SupabaseSyncService.syncUsersToCloud(localUsers);
          }

          final effectiveAssets = ref.read(assetsProvider);
          final cloudOrders = await SupabaseSyncService.fetchWorkOrdersFromCloud(
            fallbackAssets: effectiveAssets,
          );

          if (cloudOrders != null) {
            final latestDeleted = storage.getDeletedIds();
            final currentQueueIds = storage.getSyncQueue().map((q) => q.entityId).toSet();
            final currentLocal = ref.read(workOrdersProvider);
            final Map<String, WorkOrderModel> localMap = {
              for (final o in currentLocal) o.id: o,
            };

            final List<WorkOrderModel> merged = [];
            final Set<String> seenIds = {};

            for (final cloudOrder in cloudOrders) {
              if (latestDeleted.contains(cloudOrder.id)) continue;
              seenIds.add(cloudOrder.id);
              final localMatch = localMap[cloudOrder.id];
              if (localMatch != null &&
                  (localMatch.syncStatus == SyncStatus.pendingSync ||
                      currentQueueIds.contains(localMatch.id)) &&
                  localMatch.updatedAt.isAfter(cloudOrder.updatedAt)) {
                merged.add(localMatch);
              } else {
                merged.add(cloudOrder);
              }
            }

            // Solo conservar órdenes locales que aún están pendientes de subir (creadas offline)
            for (final localOrder in currentLocal) {
              if (!seenIds.contains(localOrder.id) &&
                  !latestDeleted.contains(localOrder.id) &&
                  (localOrder.syncStatus == SyncStatus.pendingSync ||
                      currentQueueIds.contains(localOrder.id))) {
                merged.add(localOrder);
              }
            }

            await ref.read(workOrdersProvider.notifier).updateAllOrders(merged);
          }
          return true;
        } catch (_) {
          return false;
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        final updatedOrders = localOrders.map((o) {
          if (o.syncStatus == SyncStatus.pendingSync) {
            return o.copyWith(syncStatus: SyncStatus.synced);
          }
          return o;
        }).toList();

        await storage.saveWorkOrders(updatedOrders);
        ref.read(workOrdersProvider.notifier).refreshFromStorage();
        await storage.clearSyncQueue();
        state = [];
        return true;
      }
    } finally {
      _isSyncing = false;
    }
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
    // Lanzar sincronización inicial con la nube en segundo plano al abrir la app
    Future.microtask(() async {
      if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
        await ref.read(syncQueueProvider.notifier).syncAllBidirectional();
      }
    });
    return storage.getWorkOrders();
  }

  void refreshFromStorage() {
    final storage = ref.read(localStorageProvider);
    state = storage.getWorkOrders();
  }

  /// Sube inmediatamente una única orden modificada/creada a Supabase sin re-subir el resto del listado
  Future<void> _pushSingleOrderByIdIfOnline(String orderId) async {
    if (!SupabaseConfig.isConfigured) return;
    final storage = ref.read(localStorageProvider);
    if (storage.getDeletedIds().contains(orderId)) return;

    final order = state.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final pushed = await SupabaseSyncService.syncWorkOrdersToCloud(
      [order],
      deletedIds: storage.getDeletedIds(),
    );
    if (pushed != null && pushed.isNotEmpty) {
      final syncedOrder = pushed.first;
      final latestDeleted = storage.getDeletedIds();
      if (latestDeleted.contains(orderId)) return;

      await storage.removeSyncItemsByEntityId(orderId);
      ref.read(syncQueueProvider.notifier).refreshQueue();

      final updatedList = state.map((o) => o.id == orderId ? syncedOrder : o).toList();
      state = updatedList;
      await storage.saveWorkOrders(updatedList);
    }
  }

  // Crear nueva orden de trabajo desde el panel de administración o desde reporte en planta
  Future<void> createWorkOrder(WorkOrderModel order) async {
    final storage = ref.read(localStorageProvider);
    await storage.removeDeletedId(order.id);

    final pendingOrder = order.copyWith(syncStatus: SyncStatus.pendingSync);
    final current = List<WorkOrderModel>.from(state)..insert(0, pendingOrder);
    state = current;
    await storage.saveWorkOrders(current);

    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: order.id,
          actionType: SyncActionType.statusChange,
          description: 'Nueva OT creada: ${order.orderNumber}',
        );

    await _pushSingleOrderByIdIfOnline(order.id);
  }

  // Modificar orden de trabajo existente
  Future<void> updateWorkOrder(WorkOrderModel order) async {
    final storage = ref.read(localStorageProvider);
    final current = List<WorkOrderModel>.from(state);
    final idx = current.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      current[idx] = order.copyWith(
        syncStatus: SyncStatus.pendingSync,
        updatedAt: DateTime.now(),
      );
      state = current;
      await storage.saveWorkOrders(current);
      await ref.read(syncQueueProvider.notifier).enqueue(
            entityId: order.id,
            actionType: SyncActionType.statusChange,
            description: 'OT actualizada: ${order.orderNumber}',
          );
      await _pushSingleOrderByIdIfOnline(order.id);
    }
  }

  // Eliminar orden de trabajo
  Future<void> deleteWorkOrder(String orderId) async {
    final storage = ref.read(localStorageProvider);
    await storage.addDeletedId(orderId);
    await storage.removeSyncItemsByEntityId(orderId);
    ref.read(syncQueueProvider.notifier).refreshQueue();

    final current = state.where((o) => o.id != orderId).toList();
    state = current;
    await storage.saveWorkOrders(current);
    if (SupabaseConfig.isConfigured) {
      await SupabaseSyncService.deleteWorkOrderFromCloud(orderId);
    }
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
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Registrar foto en paso de checklist específico (soporta 1 o múltiples fotos)
  Future<void> recordStepPhoto(String orderId, String itemId, String photoData) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            final currentPhotos = List<String>.from(item.allPhotos);
            if (currentPhotos.length < item.maxPhotos) {
              currentPhotos.add(photoData);
            } else if (currentPhotos.isNotEmpty) {
              currentPhotos[currentPhotos.length - 1] = photoData;
            }
            final requiredMin = item.minPhotos < 1 ? 1 : item.minPhotos;
            return item.copyWith(
              photoUrl: currentPhotos.isNotEmpty ? currentPhotos.first : photoData,
              photoUrls: currentPhotos,
              isCompleted: currentPhotos.length >= requiredMin,
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
          description: 'Foto registrada en paso de OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Eliminar una foto específica de un paso de checklist multi-foto
  Future<void> removeStepPhoto(String orderId, String itemId, int photoIndex) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            final currentPhotos = List<String>.from(item.allPhotos);
            if (photoIndex >= 0 && photoIndex < currentPhotos.length) {
              currentPhotos.removeAt(photoIndex);
            }
            final requiredMin = item.minPhotos < 1 ? 1 : item.minPhotos;
            return item.copyWith(
              photoUrl: currentPhotos.isNotEmpty ? currentPhotos.first : '',
              photoUrls: currentPhotos,
              isCompleted: currentPhotos.length >= requiredMin,
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
          description: 'Foto eliminada en paso de OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Alternar opción en paso de selección múltiple (MaintainX Multiple Choice)
  Future<void> toggleStepMultiOption(String orderId, String itemId, String option) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            final currentSelected = List<String>.from(item.selectedOptions);
            if (currentSelected.contains(option)) {
              currentSelected.remove(option);
            } else {
              currentSelected.add(option);
            }
            return item.copyWith(
              selectedOptions: currentSelected,
              isCompleted: currentSelected.isNotEmpty,
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
          description: 'Selección múltiple actualizada en OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Registrar foto antes/después en paso específico
  Future<void> recordStepBeforeAfterPhoto({
    required String orderId,
    required String stepId,
    required String photoUrl,
    required bool isBefore,
  }) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == stepId) {
            final newBefore = isBefore ? photoUrl : item.photoBeforeUrl;
            final newAfter = !isBefore ? photoUrl : item.photoAfterUrl;
            final completed = (newBefore != null && newBefore.isNotEmpty) &&
                (newAfter != null && newAfter.isNotEmpty);
            return item.copyWith(
              photoBeforeUrl: newBefore,
              photoAfterUrl: newAfter,
              isCompleted: completed,
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
          description: 'Foto Antes/Después actualizada en OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Registrar observación / texto en paso
  Future<void> recordStepText(String orderId, String itemId, String text) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            return item.copyWith(
              textValue: text,
              isCompleted: text.trim().isNotEmpty,
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
          description: 'Observación actualizada en OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
  }

  // Registrar selección única en paso
  Future<void> recordStepChoice(String orderId, String itemId, String option) async {
    final storage = ref.read(localStorageProvider);
    final isOnline = ref.read(isOnlineStateProvider);

    final updatedList = state.map((wo) {
      if (wo.id == orderId) {
        final updatedChecklist = wo.checklist.map((item) {
          if (item.id == itemId) {
            return item.copyWith(
              selectedOption: option,
              isCompleted: option.isNotEmpty,
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
          description: 'Selección actualizada en OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await ref.read(syncQueueProvider.notifier).enqueue(
          entityId: orderId,
          actionType: SyncActionType.checklistUpdate,
          description: 'Foto de evidencia eliminada de OT',
        );
    await _pushSingleOrderByIdIfOnline(orderId);
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
    await _pushSingleOrderByIdIfOnline(orderId);
  }
}

final workOrdersProvider =
    NotifierProvider<WorkOrdersNotifier, List<WorkOrderModel>>(WorkOrdersNotifier.new);

// ============================================================================
// Estado y Proveedor de Autenticación de Operadores (Offline-First)
// ============================================================================
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final storage = ref.watch(localStorageProvider);
    final cachedUser = storage.getCurrentUser();
    return AuthState(user: cachedUser);
  }

  // Inicio de sesión con credenciales (Legajo / Correo y Contraseña)
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final cleanId = identifier.trim().toLowerCase();
    final cleanPass = password.trim();

    if (cleanId.isEmpty || cleanPass.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Debe ingresar su legajo o correo y contraseña.',
      );
      return false;
    }

    if (cleanPass.length < 4) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'La contraseña debe tener al menos 4 caracteres.',
      );
      return false;
    }

    // Si Supabase está configurado y hay conexión, podemos intentar login cloud
    final isOnline = ref.read(isOnlineStateProvider);
    if (isOnline && SupabaseConfig.isConfigured && cleanId.contains('@')) {
      try {
        final res = await SupabaseSyncService.client?.auth.signInWithPassword(
          email: cleanId,
          password: cleanPass,
        );
        if (res?.user != null) {
          final plantUser = UserModel(
            id: res!.user!.id,
            email: res.user!.email ?? cleanId,
            name: res.user!.userMetadata?['name'] as String? ?? cleanId.split('@')[0].toUpperCase(),
            badge: res.user!.userMetadata?['badge'] as String? ?? 'TEC-CLOU',
            role: UserRole.technician,
            shift: 'Turno Mañana',
            specialty: 'Mantenimiento de Planta',
          );
          final storage = ref.read(localStorageProvider);
          await storage.saveCurrentUser(plantUser);
          state = AuthState(user: plantUser, isLoading: false);
          return true;
        }
      } catch (_) {
        // Si falla cloud (por ejemplo usuario offline o no registrado en auth), caemos en el padrón local
      }
    }

    // Padrón de técnicos y supervisores de planta
    final plantUsers = MockDataService.getMockUsers();
    final matchedUser = plantUsers.firstWhere(
      (u) =>
          u.email.toLowerCase() == cleanId ||
          u.badge.toLowerCase() == cleanId ||
          u.name.toLowerCase().contains(cleanId),
      orElse: () => UserModel(
        id: 'usr-custom-${DateTime.now().millisecondsSinceEpoch}',
        email: cleanId.contains('@') ? cleanId : '$cleanId@planta.com',
        name: cleanId.toUpperCase(),
        badge: cleanId.toUpperCase(),
        role: cleanId.contains('sup') ? UserRole.supervisor : UserRole.technician,
        shift: 'Turno General',
        specialty: 'Mantenimiento General',
      ),
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveCurrentUser(matchedUser);

    state = AuthState(user: matchedUser, isLoading: false);
    return true;
  }

  // Acceso rápido de desarrollo / pruebas para operarios
  Future<void> quickLoginAs(UserModel user) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveCurrentUser(user);
    state = AuthState(user: user, isLoading: false);
  }

  // Cierre de sesión seguro
  Future<void> logout() async {
    final storage = ref.read(localStorageProvider);
    await storage.clearCurrentUser();
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseSyncService.client?.auth.signOut();
      } catch (_) {}
    }
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// Proveedor de Gestión de Personal / Usuarios de Planta
class UsersNotifier extends Notifier<List<UserModel>> {
  @override
  List<UserModel> build() {
    final storage = ref.watch(localStorageProvider);
    final list = storage.getUsers();
    return list.isNotEmpty ? list : MockDataService.getMockUsers();
  }

  Future<void> replaceAllUsers(List<UserModel> users) async {
    final storage = ref.read(localStorageProvider);
    state = users;
    await storage.saveUsers(users);
  }

  Future<void> addUser(UserModel user) async {
    final storage = ref.read(localStorageProvider);
    final current = List<UserModel>.from(state)..add(user);
    state = current;
    await storage.saveUsers(current);
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncUsersToCloud(current);
    }
  }

  Future<void> updateUser(UserModel user) async {
    final storage = ref.read(localStorageProvider);
    final current = List<UserModel>.from(state);
    final idx = current.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      current[idx] = user;
      state = current;
      await storage.saveUsers(current);
      if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
        await SupabaseSyncService.syncUsersToCloud(current);
      }
    }
  }

  Future<void> deleteUser(String userId) async {
    final storage = ref.read(localStorageProvider);
    await storage.addDeletedId(userId);
    final current = state.where((u) => u.id != userId).toList();
    state = current;
    await storage.saveUsers(current);
    if (SupabaseConfig.isConfigured) {
      await SupabaseSyncService.deleteUserFromCloud(userId);
    }
  }
}

final usersProvider =
    NotifierProvider<UsersNotifier, List<UserModel>>(UsersNotifier.new);

// Proveedor de Cuadrillas de Mantenimiento
class CrewsNotifier extends Notifier<List<CrewModel>> {
  @override
  List<CrewModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getCrews();
  }

  Future<void> replaceAllCrews(List<CrewModel> crews) async {
    final storage = ref.read(localStorageProvider);
    state = crews;
    await storage.saveCrews(crews);
  }

  Future<void> addCrew(CrewModel crew) async {
    final storage = ref.read(localStorageProvider);
    await storage.removeDeletedId(crew.id);
    final current = List<CrewModel>.from(state)..add(crew);
    state = current;
    await storage.saveCrews(current);
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncCrewsToCloud(current);
    }
  }

  Future<void> updateCrew(CrewModel crew) async {
    final storage = ref.read(localStorageProvider);
    final current = List<CrewModel>.from(state);
    final idx = current.indexWhere((c) => c.id == crew.id);
    if (idx >= 0) {
      current[idx] = crew;
      state = current;
      await storage.saveCrews(current);
      if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
        await SupabaseSyncService.syncCrewsToCloud(current);
      }
    }
  }

  Future<void> deleteCrew(String crewId) async {
    final storage = ref.read(localStorageProvider);
    await storage.addDeletedId(crewId);
    final current = state.where((c) => c.id != crewId).toList();
    state = current;
    await storage.saveCrews(current);
    if (SupabaseConfig.isConfigured) {
      await SupabaseSyncService.deleteCrewFromCloud(crewId);
    }
  }

  Future<void> addMemberToCrew(String crewId, String memberName) async {
    final storage = ref.read(localStorageProvider);
    final current = List<CrewModel>.from(state);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx >= 0) {
      final members = List<String>.from(current[idx].memberNames);
      if (!members.contains(memberName)) {
        members.add(memberName);
        current[idx] = current[idx].copyWith(memberNames: members);
        state = current;
        await storage.saveCrews(current);
        if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
          await SupabaseSyncService.syncCrewsToCloud(current);
        }
      }
    }
  }

  Future<void> removeMemberFromCrew(String crewId, String memberName) async {
    final storage = ref.read(localStorageProvider);
    final current = List<CrewModel>.from(state);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx >= 0) {
      final members = List<String>.from(current[idx].memberNames)..remove(memberName);
      current[idx] = current[idx].copyWith(memberNames: members);
      state = current;
      await storage.saveCrews(current);
      if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
        await SupabaseSyncService.syncCrewsToCloud(current);
      }
    }
  }
}

final crewsProvider =
    NotifierProvider<CrewsNotifier, List<CrewModel>>(CrewsNotifier.new);

// Proveedor de Protocolos y Plantillas Técnicas Maestras (Riverpod 3 Notifier)
class TaskTemplatesNotifier extends Notifier<List<TaskTemplateModel>> {
  @override
  List<TaskTemplateModel> build() {
    final storage = ref.watch(localStorageProvider);
    return storage.getTaskTemplates();
  }

  Future<void> _persistTemplates(List<TaskTemplateModel> updated) async {
    final storage = ref.read(localStorageProvider);
    state = updated;
    await storage.saveTaskTemplates(updated);
    if (SupabaseConfig.isConfigured && ref.read(isOnlineStateProvider)) {
      await SupabaseSyncService.syncTemplatesToCloud(updated);
    }
  }

  Future<void> replaceAllTemplates(List<TaskTemplateModel> templates) async {
    final storage = ref.read(localStorageProvider);
    state = templates;
    await storage.saveTaskTemplates(templates);
  }

  void addOrUpdateTemplate(TaskTemplateModel template) {
    final storage = ref.read(localStorageProvider);
    storage.removeDeletedId(template.id);
    final current = List<TaskTemplateModel>.from(state);
    final idx = current.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      current[idx] = template;
    } else {
      current.insert(0, template);
    }
    _persistTemplates(current);
  }

  Future<void> deleteTemplate(String id) async {
    final storage = ref.read(localStorageProvider);
    await storage.addDeletedId(id);
    final updated = state.where((t) => t.id != id).toList();
    state = updated;
    await storage.saveTaskTemplates(updated);
    if (SupabaseConfig.isConfigured) {
      await SupabaseSyncService.deleteTemplateFromCloud(id);
    }
  }

  void addStageToTemplate(String templateId, WorkflowStageModel stage) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final stages = List<WorkflowStageModel>.from(t.resolvedStages)..add(stage);
        return t.copyWith(stages: stages);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }

  void updateStageInTemplate(String templateId, WorkflowStageModel updatedStage) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final stages = t.resolvedStages.map((s) => s.id == updatedStage.id ? updatedStage : s).toList();
        final steps = t.steps.map((s) => s.stageId == updatedStage.id ? s.copyWith(stageName: updatedStage.name) : s).toList();
        return t.copyWith(stages: stages, steps: steps);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }

  void deleteStageFromTemplate(String templateId, String stageId) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final stages = t.resolvedStages.where((s) => s.id != stageId).toList();
        final steps = t.steps.where((s) => s.stageId != stageId).toList();
        return t.copyWith(stages: stages, steps: steps);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }

  void addStepToTemplate(String templateId, ChecklistItemModel step) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final steps = List<ChecklistItemModel>.from(t.steps)..add(step);
        return t.copyWith(steps: steps);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }

  void updateStepInTemplate(String templateId, ChecklistItemModel updatedStep) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final steps = t.steps.map((s) => s.id == updatedStep.id ? updatedStep : s).toList();
        return t.copyWith(steps: steps);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }

  void deleteStepFromTemplate(String templateId, String stepId) {
    final updated = state.map((t) {
      if (t.id == templateId) {
        final steps = t.steps.where((s) => s.id != stepId).toList();
        return t.copyWith(steps: steps);
      }
      return t;
    }).toList();
    _persistTemplates(updated);
  }
}

final taskTemplatesProvider =
    NotifierProvider<TaskTemplatesNotifier, List<TaskTemplateModel>>(TaskTemplatesNotifier.new);

