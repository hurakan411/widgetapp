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
  final bool requiresConfirmation;
  final bool isConfirmed;

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
    this.requiresConfirmation = false,
    this.isConfirmed = false,
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
    bool? requiresConfirmation,
    bool? isConfirmed,
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
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  // Convert to JSON for storage/widget
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'doneAt': doneAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'resetType': resetType.index,
      'resetValue': resetValue,
      'scheduledResetAt': scheduledResetAt?.toIso8601String(),
      'targetPartnerId': targetPartnerId,
      'requiresConfirmation': requiresConfirmation,
      'isConfirmed': isConfirmed,
    };
  }

  // Create from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['isDone'] ?? false,
      doneAt: json['doneAt'] != null ? DateTime.parse(json['doneAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      resetType: ResetType.values[json['resetType'] ?? 0],
      resetValue: json['resetValue'],
      scheduledResetAt: json['scheduledResetAt'] != null ? DateTime.parse(json['scheduledResetAt']) : null,
      targetPartnerId: json['targetPartnerId'],
      requiresConfirmation: json['requiresConfirmation'] ?? false,
      isConfirmed: json['isConfirmed'] ?? false,
    );
  }
}
