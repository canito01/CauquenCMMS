import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_model.dart';
import '../models/spare_part_model.dart';
import '../models/sync_item_model.dart';
import '../models/user_model.dart';
import '../models/work_order_model.dart';
import 'mock_data_service.dart';

class LocalStorageService {
  static const String _keyWorkOrders = 'maxi_work_orders_v1';
  static const String _keyAssets = 'maxi_assets_v1';
  static const String _keySpareParts = 'maxi_spare_parts_v1';
  static const String _keySyncQueue = 'maxi_sync_queue_v1';
  static const String _keyCurrentUser = 'cauquen_current_user_v1';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = LocalStorageService(prefs);
    await service._seedInitialDataIfNeeded();
    return service;
  }

  Future<void> _seedInitialDataIfNeeded() async {
    if (!_prefs.containsKey(_keyWorkOrders)) {
      final initialOrders = MockDataService.getInitialWorkOrders();
      await saveWorkOrders(initialOrders);
    }
    if (!_prefs.containsKey(_keyAssets)) {
      final initialAssets = MockDataService.getAssets();
      await saveAssets(initialAssets);
    }
    if (!_prefs.containsKey(_keySpareParts)) {
      final initialParts = MockDataService.getSpareParts();
      await saveSpareParts(initialParts);
    }
  }

  // --- Órdenes de Trabajo ---
  List<WorkOrderModel> getWorkOrders() {
    final rawJson = _prefs.getString(_keyWorkOrders);
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => WorkOrderModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWorkOrders(List<WorkOrderModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyWorkOrders, raw);
  }

  Future<void> updateWorkOrder(WorkOrderModel updated) async {
    final current = getWorkOrders();
    final index = current.indexWhere((e) => e.id == updated.id);
    if (index >= 0) {
      current[index] = updated;
    } else {
      current.insert(0, updated);
    }
    await saveWorkOrders(current);
  }

  WorkOrderModel? getWorkOrderById(String id) {
    final list = getWorkOrders();
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Activos ---
  List<AssetModel> getAssets() {
    final rawJson = _prefs.getString(_keyAssets);
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => AssetModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAssets(List<AssetModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyAssets, raw);
  }

  // --- Repuestos ---
  List<SparePartModel> getSpareParts() {
    final rawJson = _prefs.getString(_keySpareParts);
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => SparePartModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSpareParts(List<SparePartModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keySpareParts, raw);
  }

  // --- Cola de Sincronización ---
  List<SyncQueueItem> getSyncQueue() {
    final rawJson = _prefs.getString(_keySyncQueue);
    if (rawJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => SyncQueueItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSyncQueue(List<SyncQueueItem> queue) async {
    final raw = jsonEncode(queue.map((e) => e.toMap()).toList());
    await _prefs.setString(_keySyncQueue, raw);
  }

  Future<void> enqueueSyncItem(SyncQueueItem item) async {
    final current = getSyncQueue();
    current.add(item);
    await saveSyncQueue(current);
  }

  Future<void> removeSyncItem(String id) async {
    final current = getSyncQueue();
    current.removeWhere((e) => e.id == id);
    await saveSyncQueue(current);
  }

  Future<void> clearSyncQueue() async {
    await _prefs.remove(_keySyncQueue);
  }

  // --- Sesión de Usuario (Offline-First) ---
  UserModel? getCurrentUser() {
    final raw = _prefs.getString(_keyCurrentUser);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCurrentUser(UserModel? user) async {
    if (user == null) {
      await _prefs.remove(_keyCurrentUser);
    } else {
      await _prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
    }
  }

  Future<void> clearCurrentUser() async {
    await _prefs.remove(_keyCurrentUser);
  }
}

