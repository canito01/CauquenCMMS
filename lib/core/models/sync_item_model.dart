enum SyncActionType {
  statusChange,
  checklistUpdate,
  sparePartConsumed,
  completionSignature,
}

class SyncQueueItem {
  final String id;
  final String entityId; // ID de la OT
  final String entityType; // 'work_order'
  final SyncActionType actionType;
  final String description;
  final DateTime createdAt;
  final int retryCount;
  final bool hasFailed;
  final String? errorMessage;

  const SyncQueueItem({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.actionType,
    required this.description,
    required this.createdAt,
    this.retryCount = 0,
    this.hasFailed = false,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityId': entityId,
      'entityType': entityType,
      'actionType': actionType.name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'hasFailed': hasFailed,
      'errorMessage': errorMessage,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as String,
      entityId: map['entityId'] as String,
      entityType: map['entityType'] as String,
      actionType: SyncActionType.values.byName(map['actionType'] as String),
      description: map['description'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      hasFailed: map['hasFailed'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

