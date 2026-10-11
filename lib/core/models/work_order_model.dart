import 'asset_model.dart';
import 'checklist_item_model.dart';
import 'spare_part_model.dart';

enum WorkOrderStatus {
  pendiente,
  enProceso,
  pausada,
  finalizada,
}

enum WorkOrderPriority {
  baja,
  normal,
  alta,
  urgente,
}

enum WorkOrderType {
  correctivo,
  preventivo,
  predictivo,
  rutina,
}

enum SyncStatus {
  synced,
  pendingSync,
  syncError,
}

class WorkOrderModel {
  final String id;
  final String orderNumber;
  final String title;
  final String description;
  final WorkOrderType type;
  final WorkOrderPriority priority;
  final WorkOrderStatus status;
  final AssetModel asset;
  final String technicianName;
  final String technicianBadge;
  final DateTime scheduledDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int elapsedMinutes;
  final String? pauseReason;
  final List<String> safetyProtocols;
  final List<ChecklistItemModel> checklist;
  final List<SparePartModel> spareParts;
  final String? rootCause;
  final String? technicianNotes;
  final String? supervisorSignature;
  final List<String> evidencePhotos;
  final SyncStatus syncStatus;
  final DateTime updatedAt;

  const WorkOrderModel({
    required this.id,
    required this.orderNumber,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.asset,
    required this.technicianName,
    required this.technicianBadge,
    required this.scheduledDate,
    this.startedAt,
    this.completedAt,
    this.elapsedMinutes = 0,
    this.pauseReason,
    this.safetyProtocols = const [],
    this.checklist = const [],
    this.spareParts = const [],
    this.evidencePhotos = const [],
    this.rootCause,
    this.technicianNotes,
    this.supervisorSignature,
    this.syncStatus = SyncStatus.synced,
    required this.updatedAt,
  });

  int get completedTasksCount => checklist.where((item) => item.isCompleted).length;
  int get totalTasksCount => checklist.length;
  double get progressPercentage => totalTasksCount == 0 ? 0 : completedTasksCount / totalTasksCount;

  WorkOrderModel copyWith({
    String? id,
    String? orderNumber,
    String? title,
    String? description,
    WorkOrderType? type,
    WorkOrderPriority? priority,
    WorkOrderStatus? status,
    AssetModel? asset,
    String? technicianName,
    String? technicianBadge,
    DateTime? scheduledDate,
    DateTime? startedAt,
    DateTime? completedAt,
    int? elapsedMinutes,
    String? pauseReason,
    List<String>? safetyProtocols,
    List<ChecklistItemModel>? checklist,
    List<SparePartModel>? spareParts,
    String? rootCause,
    String? technicianNotes,
    String? supervisorSignature,
    List<String>? evidencePhotos,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
  }) {
    return WorkOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      asset: asset ?? this.asset,
      technicianName: technicianName ?? this.technicianName,
      technicianBadge: technicianBadge ?? this.technicianBadge,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      elapsedMinutes: elapsedMinutes ?? this.elapsedMinutes,
      pauseReason: pauseReason ?? this.pauseReason,
      safetyProtocols: safetyProtocols ?? this.safetyProtocols,
      checklist: checklist ?? this.checklist,
      spareParts: spareParts ?? this.spareParts,
      evidencePhotos: evidencePhotos ?? this.evidencePhotos,
      rootCause: rootCause ?? this.rootCause,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      supervisorSignature: supervisorSignature ?? this.supervisorSignature,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'status': status.name,
      'asset': asset.toMap(),
      'technicianName': technicianName,
      'technicianBadge': technicianBadge,
      'scheduledDate': scheduledDate.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'elapsedMinutes': elapsedMinutes,
      'pauseReason': pauseReason,
      'safetyProtocols': safetyProtocols,
      'checklist': checklist.map((x) => x.toMap()).toList(),
      'spareParts': spareParts.map((x) => x.toMap()).toList(),
      'rootCause': rootCause,
      'technicianNotes': technicianNotes,
      'supervisorSignature': supervisorSignature,
      'evidencePhotos': evidencePhotos,
      'syncStatus': syncStatus.name,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WorkOrderModel.fromMap(Map<String, dynamic> map) {
    return WorkOrderModel(
      id: map['id'] as String,
      orderNumber: map['orderNumber'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: WorkOrderType.values.byName(map['type'] as String? ?? 'correctivo'),
      priority: WorkOrderPriority.values.byName(map['priority'] as String? ?? 'normal'),
      status: WorkOrderStatus.values.byName(map['status'] as String? ?? 'pendiente'),
      asset: AssetModel.fromMap(map['asset'] as Map<String, dynamic>),
      technicianName: map['technicianName'] as String,
      technicianBadge: map['technicianBadge'] as String,
      scheduledDate: DateTime.parse(map['scheduledDate'] as String),
      startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt'] as String) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      elapsedMinutes: (map['elapsedMinutes'] as num?)?.toInt() ?? 0,
      pauseReason: map['pauseReason'] as String?,
      safetyProtocols: List<String>.from(map['safetyProtocols'] as List? ?? []),
      checklist: (map['checklist'] as List? ?? [])
          .map((item) => ChecklistItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      spareParts: (map['spareParts'] as List? ?? [])
          .map((item) => SparePartModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      rootCause: map['rootCause'] as String?,
      technicianNotes: map['technicianNotes'] as String?,
      supervisorSignature: map['supervisorSignature'] as String?,
      evidencePhotos: List<String>.from(map['evidencePhotos'] as List? ?? []),
      syncStatus: SyncStatus.values.byName(map['syncStatus'] as String? ?? 'synced'),
      updatedAt: DateTime.parse(map['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

