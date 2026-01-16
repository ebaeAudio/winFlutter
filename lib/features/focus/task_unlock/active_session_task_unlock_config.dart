import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class ActiveSessionTaskUnlockConfig {
  const ActiveSessionTaskUnlockConfig({
    required this.sessionId,
    required this.ymd,
    required this.requiredCount,
    required this.requiredTaskIds,
  });

  final String sessionId;
  final String ymd;

  /// How many tasks must be completed to end early.
  final int requiredCount;

  /// Task IDs required to unlock early exit.
  ///
  /// v1 rule: should contain exactly [requiredCount] unique ids, but we tolerate
  /// bad persisted data and treat missing slots as incomplete.
  final List<String> requiredTaskIds;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'ymd': ymd,
        'requiredCount': requiredCount,
        'requiredTaskIds': requiredTaskIds,
      };

  String toJsonString() => jsonEncode(toJson());

  static ActiveSessionTaskUnlockConfig? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  static ActiveSessionTaskUnlockConfig fromJson(Map<String, Object?> json) {
    final rawIds = json['requiredTaskIds'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final v in rawIds) {
        if (v is String && v.trim().isNotEmpty) ids.add(v);
      }
    }
    return ActiveSessionTaskUnlockConfig(
      sessionId: (json['sessionId'] as String?) ?? '',
      ymd: (json['ymd'] as String?) ?? '',
      requiredCount: (json['requiredCount'] as num?)?.toInt() ?? 0,
      requiredTaskIds: ids,
    );
  }
}

