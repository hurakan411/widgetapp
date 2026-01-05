enum ResetType { none, daily, interval }

class Task {
  final String id;
  final String title;
  final bool isDone;
  final DateTime? doneAt;
  final DateTime createdAt;
  
  // Reset Configuration
  final ResetType resetType;
  final int? resetValue; // For daily: HHmm (e.g. 400 for 04:00), For interval: minutes
  final DateTime? scheduledResetAt; // The exact time when it should revert to undone
  
  // Target Partner (Who manages this task?)
  final String? targetPartnerId;

  // Confirmation
  final bool isConfirmed;
  final DateTime? confirmedAt;

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    this.doneAt,
    required this.createdAt,
    this.resetType = ResetType.none,
    this.resetValue,
    this.scheduledResetAt,
    this.targetPartnerId,
    this.isConfirmed = false,
    this.confirmedAt,
  });

  // Create a copy with updated fields
  Task copyWith({
    String? title,
    bool? isDone,
    DateTime? doneAt,
    ResetType? resetType,
    int? resetValue,
    DateTime? scheduledResetAt,
    String? targetPartnerId,
    bool? isConfirmed,
    DateTime? confirmedAt,
  }) {
    return Task(
      id: this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      doneAt: doneAt ?? this.doneAt,
      createdAt: this.createdAt,
      resetType: resetType ?? this.resetType,
      resetValue: resetValue ?? this.resetValue,
      scheduledResetAt: scheduledResetAt ?? this.scheduledResetAt,
      targetPartnerId: targetPartnerId ?? this.targetPartnerId,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  // Convert to JSON for storage/widget
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_done': isDone,
      'done_at': doneAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'reset_type': resetType.index,
      'reset_value': resetValue,
      'scheduled_reset_at': scheduledResetAt?.toIso8601String(),
      'target_partner_id': targetPartnerId,
      'is_confirmed': isConfirmed,
      'confirmed_at': confirmedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['is_done'] ?? false,
      doneAt: json['done_at'] != null ? DateTime.parse(json['done_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      resetType: ResetType.values[json['reset_type'] ?? 0],
      resetValue: json['reset_value'],
      scheduledResetAt: json['scheduled_reset_at'] != null ? DateTime.parse(json['scheduled_reset_at']) : null,
      targetPartnerId: json['target_partner_id'],
      isConfirmed: json['is_confirmed'] ?? false,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
    );
  }
}
