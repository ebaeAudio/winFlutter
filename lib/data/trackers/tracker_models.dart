import 'dart:convert';

enum TargetCadence {
  daily,
  weekly,
  yearly;

  static TargetCadence? tryParse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    return TargetCadence.values.firstWhere(
      (e) => e.name.toLowerCase() == v,
      orElse: () => TargetCadence.daily,
    );
  }
}

class TrackerItem {
  const TrackerItem({
    required this.key,
    required this.emoji,
    required this.description,
    this.targetCadence,
    this.targetValue,
  });

  /// Stable per-tracker item key; used to join tallies.
  final String key;
  final String emoji;
  final String description;

  final TargetCadence? targetCadence;
  final int? targetValue;

  bool get hasTarget => (targetValue ?? 0) > 0 && targetCadence != null;

  TrackerItem copyWith({
    String? emoji,
    String? description,
    TargetCadence? targetCadence,
    int? targetValue,
    bool clearTarget = false,
  }) {
    return TrackerItem(
      key: key,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      targetCadence: clearTarget ? null : (targetCadence ?? this.targetCadence),
      targetValue: clearTarget ? null : (targetValue ?? this.targetValue),
    );
  }

  Map<String, Object?> toJson() => {
        'key': key,
        'emoji': emoji,
        'description': description,
        'targetCadence': targetCadence?.name,
        'targetValue': targetValue,
      };

  static TrackerItem fromJson(Map<String, Object?> json) {
    return TrackerItem(
      key: (json['key'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      targetCadence: TargetCadence.tryParse(json['targetCadence'] as String?),
      targetValue: (json['targetValue'] as num?)?.toInt(),
    );
  }
}

class Tracker {
  const Tracker({
    required this.id,
    required this.name,
    required this.items,
    required this.archived,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String name;
  final List<TrackerItem> items; // must be length 3
  final bool archived;
  final int createdAtMs;
  final int updatedAtMs;

  Tracker copyWith({
    String? name,
    List<TrackerItem>? items,
    bool? archived,
    int? updatedAtMs,
  }) {
    return Tracker(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      archived: archived ?? this.archived,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'items': [for (final i in items) i.toJson()],
        'archived': archived,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  static Tracker fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final items = <TrackerItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, Object?>) {
          items.add(TrackerItem.fromJson(it));
        } else if (it is Map) {
          items.add(TrackerItem.fromJson(Map<String, Object?>.from(it)));
        }
      }
    }
    return Tracker(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      items: items,
      archived: (json['archived'] as bool?) ?? false,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrackerTally {
  const TrackerTally({
    required this.trackerId,
    required this.itemKey,
    required this.ymd,
    required this.count,
  });

  final String trackerId;
  final String itemKey;

  /// YYYY-MM-DD
  final String ymd;

  final int count;

  Map<String, Object?> toJson() => {
        'trackerId': trackerId,
        'itemKey': itemKey,
        'ymd': ymd,
        'count': count,
      };

  static TrackerTally fromJson(Map<String, Object?> json) {
    return TrackerTally(
      trackerId: (json['trackerId'] as String?) ?? '',
      itemKey: (json['itemKey'] as String?) ?? '',
      ymd: (json['ymd'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

String encodeItemsJson(List<TrackerItem> items) => jsonEncode(
      [for (final i in items) i.toJson()],
    );

List<TrackerItem> decodeItemsJson(dynamic raw) {
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is List) {
      return [
        for (final it in decoded)
          if (it is Map<String, Object?>)
            TrackerItem.fromJson(it)
          else if (it is Map)
            TrackerItem.fromJson(Map<String, Object?>.from(it)),
      ];
    }
  } catch (_) {
    // ignore
  }
  return const [];
}
