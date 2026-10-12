import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/spare_part_model.dart';
import '../models/sync_item_model.dart';
import '../models/user_model.dart';
import '../models/work_order_model.dart';
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

