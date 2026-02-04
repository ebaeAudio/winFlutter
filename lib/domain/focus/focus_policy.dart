import 'dart:convert';

import 'app_identifier.dart';
import 'focus_friction.dart';

class FocusPolicy {
  const FocusPolicy({
    required this.id,
    required this.name,
    required this.allowedApps,
    required this.friction,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// Allowlist semantics (product requirement):
  /// during a FocusSession, only these apps should remain accessible.
  ///
  /// Platform notes:
  /// - iOS Screen Time APIs are more naturally "shield selected apps".
  ///   Our iOS engine will interpret this allowlist according to platform
  ///   capabilities (see risks/limitations).
  /// - Android uses package names and can enforce allowlist strictly via
  ///   AccessibilityService + blocking screen.
  final List<AppIdentifier> allowedApps;

  final FocusFrictionSettings friction;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  FocusPolicy copyWith({
    String? name,
    List<AppIdentifier>? allowedApps,
    FocusFrictionSettings? friction,
    DateTime? updatedAt,
  }) {
    return FocusPolicy(
      id: id,
      name: name ?? this.name,
      allowedApps: allowedApps ?? this.allowedApps,
      friction: friction ?? this.friction,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'allowedApps':
            allowedApps.map((a) => a.toJson()).toList(growable: false),
        'friction': friction.toJson(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  static FocusPolicy fromJson(Map<String, Object?> json) {
    final appsRaw = json['allowedApps'];
    final frictionRaw = json['friction'];
    return FocusPolicy(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Focus',
      allowedApps: appsRaw is List
          ? appsRaw
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => AppIdentifier.fromJson(m.cast<String, Object?>()))
              .toList(growable: false)
          : const [],
      friction: frictionRaw is Map
          ? FocusFrictionSettings.fromJson(frictionRaw.cast<String, Object?>())
          : FocusFrictionSettings.defaults,
      createdAt: _dt(json['createdAt']),
      updatedAt: _dt(json['updatedAt']),
    );
  }

  static DateTime? _dt(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  static List<FocusPolicy> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => FocusPolicy.fromJson(m.cast<String, Object?>()))
        .toList(growable: false);
  }

  static String listToJsonString(List<FocusPolicy> policies) =>
      jsonEncode(policies.map((p) => p.toJson()).toList(growable: false));
}
