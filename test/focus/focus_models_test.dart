import 'package:flutter_test/flutter_test.dart';
import 'package:win_flutter/domain/focus/app_identifier.dart';
import 'package:win_flutter/domain/focus/focus_friction.dart';
import 'package:win_flutter/domain/focus/focus_policy.dart';
import 'package:win_flutter/domain/focus/focus_session.dart';

void main() {
  test('FocusPolicy JSON round-trip', () {
    final p = FocusPolicy(
      id: 'p1',
      name: 'My Policy',
      allowedApps: const [
        AppIdentifier(platform: AppPlatform.android, id: 'com.example.app'),
      ],
      friction: FocusFrictionSettings.defaults,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    final encoded = FocusPolicy.listToJsonString([p]);
    final decoded = FocusPolicy.listFromJsonString(encoded);

    expect(decoded, hasLength(1));
    expect(decoded.first.id, 'p1');
    expect(decoded.first.allowedApps.single.id, 'com.example.app');
    expect(decoded.first.friction.holdToUnlockSeconds,
        FocusFrictionSettings.defaults.holdToUnlockSeconds,);
  });

  test('FocusSession JSON round-trip', () {
    final s = FocusSession(
      id: 's1',
      policyId: 'p1',
      startedAt: DateTime.utc(2026, 1, 1, 10),
      plannedEndAt: DateTime.utc(2026, 1, 1, 11),
      status: FocusSessionStatus.active,
      emergencyUnlocksUsed: 1,
    );

    final raw = FocusSession.listToJsonString([s]);
    final decoded = FocusSession.listFromJsonString(raw);
    expect(decoded.single.id, 's1');
    expect(decoded.single.isActive, true);
  });
}
