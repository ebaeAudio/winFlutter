import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/focus/focus_policy.dart';
import 'focus_policy_repository.dart';

class LocalFocusPolicyRepository implements FocusPolicyRepository {
  LocalFocusPolicyRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _policiesKey = 'focus_policies_v1';

  @override
  Future<List<FocusPolicy>> listPolicies() async {
    final raw = _prefs.getString(_policiesKey);
    if (raw == null || raw.isEmpty) return const [];
    return FocusPolicy.listFromJsonString(raw);
  }

  @override
  Future<FocusPolicy?> getPolicy(String id) async {
    final all = await listPolicies();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> upsertPolicy(FocusPolicy policy) async {
    final existing = await listPolicies();
    final now = DateTime.now();
    final updated = [
      for (final p in existing)
        if (p.id != policy.id) p,
      policy.copyWith(updatedAt: now),
    ]..sort((a, b) => (b.updatedAt ?? b.createdAt ?? now)
        .compareTo(a.updatedAt ?? a.createdAt ?? now));

    await _prefs.setString(_policiesKey, FocusPolicy.listToJsonString(updated));
  }

  @override
  Future<void> deletePolicy(String id) async {
    final existing = await listPolicies();
    final updated = existing.where((p) => p.id != id).toList(growable: false);
    await _prefs.setString(_policiesKey, FocusPolicy.listToJsonString(updated));
  }
}


