import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_model.dart';
import '../models/crew_model.dart';
import '../models/spare_part_model.dart';
import '../models/stock_movement_model.dart';
import '../models/sync_item_model.dart';
import '../models/task_template_model.dart';
import '../models/user_model.dart';
import '../models/work_order_model.dart';
import 'mock_data_service.dart';

class LocalStorageService {
  static const String _keyWorkOrders = 'maxi_work_orders_v1';
  static const String _keyAssets = 'maxi_assets_v1';
  static const String _keySpareParts = 'maxi_spare_parts_v1';
  static const String _keySyncQueue = 'maxi_sync_queue_v1';
  static const String _keyCurrentUser = 'cauquen_current_user_v1';
  static const String _keyUsers = 'maxi_users_v1';
  static const String _keyCrews = 'maxi_crews_v1';
  static const String _keyStockMovements = 'maxi_stock_movements_v1';
  static const String _keyTaskTemplates = 'maxi_task_templates_v1';
  static const String _keyDeletedIds = 'maxi_deleted_ids_v1';
  static const String _keyShowcaseSeeded = 'maxi_showcase_v2_seeded';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = LocalStorageService(prefs);
    await service._seedInitialDataIfNeeded();
    return service;
  }

  Future<void> _seedInitialDataIfNeeded() async {
    final initialOrders = MockDataService.getInitialWorkOrders();
    final showcaseAlreadySeeded = _prefs.getBool(_keyShowcaseSeeded) ?? false;

    if (!_prefs.containsKey(_keyWorkOrders)) {
      await saveWorkOrders(initialOrders);
      await _prefs.setBool(_keyShowcaseSeeded, true);
    } else if (!showcaseAlreadySeeded) {
      // Sembrar por única vez la Tarea Demo Completa ('wo-showcase-2026') si no fue sembrada antes
      final existing = getWorkOrders();
      final showcaseOrder = initialOrders.where((o) => o.id == 'wo-showcase-2026').firstOrNull;
      if (showcaseOrder != null && !existing.any((o) => o.id == 'wo-showcase-2026')) {
        existing.insert(0, showcaseOrder);
        await saveWorkOrders(existing);
      }
      await _prefs.setBool(_keyShowcaseSeeded, true);
    }
    if (!_prefs.containsKey(_keyAssets)) {
      final initialAssets = MockDataService.getAssets();
      await saveAssets(initialAssets);
    }
    if (!_prefs.containsKey(_keySpareParts)) {
      final initialParts = MockDataService.getSpareParts();
      await saveSpareParts(initialParts);
    }
    if (!_prefs.containsKey(_keyUsers)) {
      final initialUsers = MockDataService.getMockUsers();
      await saveUsers(initialUsers);
    }
    if (!_prefs.containsKey(_keyCrews)) {
      final initialCrews = [
        const CrewModel(
          id: 'crw-1',
          name: 'Cuadrilla Alfa - Mecánica & Neumática',
          shift: 'Turno Mañana (06:00 - 14:00)',
          specialty: 'Mantenimiento Mecánico, Bombas y Válvulas',
          leaderName: 'Carlos Méndez',
          leaderBadge: 'SUP-1020',
          memberNames: ['Maximiliano Rossi', 'Lucas Varela'],
          notes: 'Asignada a Naves A y B de extrusión y calderas',
        ),
        const CrewModel(
          id: 'crw-2',
          name: 'Cuadrilla Beta - Electricidad & PLC',
          shift: 'Turno Tarde (14:00 - 22:00)',
          specialty: 'Tableros Eléctricos, Variadores y Automatización',
          leaderName: 'Carlos Méndez',
          leaderBadge: 'SUP-1020',
          memberNames: ['Lucas Varela'],
          notes: 'Mantenimiento de subestaciones y controladores lógicos',
        ),
      ];
      await saveCrews(initialCrews);
    }
    final defaultTemplates = TaskTemplateModel.getDefaultTemplates();
    if (!_prefs.containsKey(_keyTaskTemplates)) {
      await saveTaskTemplates(defaultTemplates);
    } else if (!showcaseAlreadySeeded) {
      final existingTemplates = getTaskTemplates();
      final showcaseTpl = defaultTemplates.where((t) => t.id == 'tpl-maintainx-multistage').firstOrNull;
      if (showcaseTpl != null && !existingTemplates.any((t) => t.id == 'tpl-maintainx-multistage')) {
        existingTemplates.insert(0, showcaseTpl);
        await saveTaskTemplates(existingTemplates);
      }
    }
  }

  // --- Registro de IDs Eliminados (Tombstones para evitar resurrección en sync) ---
  Set<String> getDeletedIds() {
    final list = _prefs.getStringList(_keyDeletedIds);
    return list != null ? list.toSet() : <String>{};
  }

  Future<void> addDeletedId(String id) async {
    final current = getDeletedIds()..add(id);
    await _prefs.setStringList(_keyDeletedIds, current.toList());
  }

  Future<void> removeDeletedId(String id) async {
    final current = getDeletedIds()..remove(id);
    await _prefs.setStringList(_keyDeletedIds, current.toList());
  }

  // --- Órdenes de Trabajo ---
  List<WorkOrderModel> getWorkOrders() {
    final rawJson = _prefs.getString(_keyWorkOrders);
    if (rawJson == null) return [];
    try {
      final deleted = getDeletedIds();
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((e) => WorkOrderModel.fromMap(e as Map<String, dynamic>))
          .where((o) => !deleted.contains(o.id))
          .toList();
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
      final deleted = getDeletedIds();
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((e) => SparePartModel.fromMap(e as Map<String, dynamic>))
          .where((p) => !deleted.contains(p.id))
          .toList();
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

  Future<void> removeSyncItemsByEntityId(String entityId) async {
    final current = getSyncQueue();
    current.removeWhere((e) => e.entityId == entityId);
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

  // --- Personal / Usuarios ---
  List<UserModel> getUsers() {
    final raw = _prefs.getString(_keyUsers);
    if (raw == null) return [];
    try {
      final deleted = getDeletedIds();
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => UserModel.fromMap(e as Map<String, dynamic>))
          .where((u) => !deleted.contains(u.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUsers(List<UserModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyUsers, raw);
  }

  // --- Cuadrillas de Planta ---
  List<CrewModel> getCrews() {
    final raw = _prefs.getString(_keyCrews);
    if (raw == null) return [];
    try {
      final deleted = getDeletedIds();
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => CrewModel.fromMap(e as Map<String, dynamic>))
          .where((c) => !deleted.contains(c.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCrews(List<CrewModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyCrews, raw);
  }

  // --- Movimientos Manuales de Stock ---
  List<StockMovementModel> getStockMovements() {
    final raw = _prefs.getString(_keyStockMovements);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => StockMovementModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveStockMovements(List<StockMovementModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyStockMovements, raw);
  }

  // --- Plantillas y Protocolos Técnicos Maestros ---
  List<TaskTemplateModel> getTaskTemplates() {
    final deleted = getDeletedIds();
    final raw = _prefs.getString(_keyTaskTemplates);
    if (raw == null) {
      return TaskTemplateModel.getDefaultTemplates()
          .where((t) => !deleted.contains(t.id))
          .toList();
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TaskTemplateModel.fromMap(e as Map<String, dynamic>))
          .where((t) => !deleted.contains(t.id))
          .toList();
    } catch (_) {
      return TaskTemplateModel.getDefaultTemplates()
          .where((t) => !deleted.contains(t.id))
          .toList();
    }
  }

  Future<void> saveTaskTemplates(List<TaskTemplateModel> list) async {
    final raw = jsonEncode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyTaskTemplates, raw);
  }
}
