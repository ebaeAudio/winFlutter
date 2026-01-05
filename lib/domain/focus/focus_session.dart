import 'dart:convert';

enum FocusSessionStatus {
  active,
  ended;
}

enum FocusSessionEndReason {
  completed,
  userEarlyExit,
  emergencyException,
  engineFailure,
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.policyId,
    required this.startedAt,
    required this.plannedEndAt,
    required this.status,
    this.endedAt,
    this.endReason,
    required this.emergencyUnlocksUsed,
  });

  final String id;
  final String policyId;

  final DateTime startedAt;
  final DateTime plannedEndAt;

  final FocusSessionStatus status;
  final DateTime? endedAt;
  final FocusSessionEndReason? endReason;

  final int emergencyUnlocksUsed;

  bool get isActive => status == FocusSessionStatus.active;

  Map<String, Object?> toJson() => {
        'id': id,
        'policyId': policyId,
        'startedAt': startedAt.toIso8601String(),
        'plannedEndAt': plannedEndAt.toIso8601String(),
        'status': status.name,
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (endReason != null) 'endReason': endReason!.name,
        'emergencyUnlocksUsed': emergencyUnlocksUsed,
      };

  static FocusSession fromJson(Map<String, Object?> json) => FocusSession(
        id: (json['id'] as String?) ?? '',
        policyId: (json['policyId'] as String?) ?? '',
        startedAt: _dt((json['startedAt'] as String?)) ?? DateTime.now(),
        plannedEndAt: _dt((json['plannedEndAt'] as String?)) ?? DateTime.now(),
        status: FocusSessionStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String?),
          orElse: () => FocusSessionStatus.ended,
        ),
        endedAt: _dt(json['endedAt'] as String?),
        endReason: FocusSessionEndReason.values.cast<FocusSessionEndReason?>().firstWhere(
              (r) => r?.name == (json['endReason'] as String?),
              orElse: () => null,
            ),
        emergencyUnlocksUsed: (json['emergencyUnlocksUsed'] as num?)?.toInt() ?? 0,
      );

  static DateTime? _dt(String? raw) => raw == null ? null : DateTime.tryParse(raw);

  static List<FocusSession> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => FocusSession.fromJson(m.cast<String, Object?>()))
        .toList(growable: false);
  }

  static String listToJsonString(List<FocusSession> sessions) =>
      jsonEncode(sessions.map((s) => s.toJson()).toList(growable: false));
}


