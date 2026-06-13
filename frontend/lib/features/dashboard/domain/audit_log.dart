class AuditLog {
  AuditLog({
    required this.id,
    required this.createdAt,
    required this.actorId,
    required this.action,
    required this.entity,
    this.entityId,
    this.meta,
  });

  final String id;
  final DateTime createdAt;
  final String actorId;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, dynamic>? meta;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      actorId: json['actorId'] as String,
      action: json['action'] as String,
      entity: json['entity'] as String,
      entityId: json['entityId'] as String?,
      meta: json['meta'] != null ? Map<String, dynamic>.from(json['meta'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'actorId': actorId,
      'action': action,
      'entity': entity,
      'entityId': entityId,
      'meta': meta,
    };
  }
}
