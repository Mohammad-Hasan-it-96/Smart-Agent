class NotificationModel {
  final int? id;
  final String title;
  final String body;
  final String type;
  final String action;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    this.action = '',
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'action': action,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int?,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      action: (map['action'] ?? '') as String,
      createdAt: DateTime.tryParse((map['created_at'] ?? '') as String) ?? DateTime.now(),
      isRead: (map['is_read'] ?? 0) == 1,
    );
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    String? action,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

