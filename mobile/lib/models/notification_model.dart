class NotificationModel {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  static DateTime _parseUtcToLocal(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true).toLocal();
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return DateTime.now();

    final numeric = int.tryParse(str);
    if (numeric != null && str.length > 10) {
      return DateTime.fromMillisecondsSinceEpoch(numeric, isUtc: true).toLocal();
    }

    // Check if timezone indicator is present (Z, or +HH:mm / -HH:mm after time component)
    final timePart = str.contains('T') ? str.split('T').last : str;
    final hasTimeZone = str.endsWith('Z') || timePart.contains('+') || timePart.contains('-');

    final utcStr = hasTimeZone ? str : '${str}Z';
    return DateTime.parse(utcStr).toLocal();
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['read'] as bool? ?? false,
      createdAt: _parseUtcToLocal(json['createdAt']),
    );
  }
}
