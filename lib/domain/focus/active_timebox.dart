import 'dart:convert';

/// Persisted per-day (local) timebox state for Focus v2.
///
/// Stored locally so it can be restored after app relaunch.
class ActiveTimebox {
  const ActiveTimebox({
    required this.taskId,
    required this.startedAt,
    required this.durationMinutes,
  });

  final String taskId;
  final DateTime startedAt;
  final int durationMinutes;

  DateTime get endsAt => startedAt.add(Duration(minutes: durationMinutes));

  bool get isExpired => DateTime.now().isAfter(endsAt);

  Map<String, Object?> toJson() => {
        'taskId': taskId,
        'startedAt': startedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
      };

  static ActiveTimebox? fromJson(Map<String, Object?> json) {
    final taskId = (json['taskId'] as String?) ?? '';
    if (taskId.trim().isEmpty) return null;

    final startedAtRaw = (json['startedAt'] as String?) ?? '';
    final startedAt = DateTime.tryParse(startedAtRaw);
    if (startedAt == null) return null;

    final durationMinutes = (json['durationMinutes'] as num?)?.toInt();
    if (durationMinutes == null) return null;

    return ActiveTimebox(
      taskId: taskId,
      startedAt: startedAt,
      durationMinutes: durationMinutes,
    );
  }

  static ActiveTimebox? fromJsonString(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  static String toJsonString(ActiveTimebox box) => jsonEncode(box.toJson());
}

