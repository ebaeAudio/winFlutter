import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart' show sharedPreferencesProvider;
import 'dashboard_section_id.dart';

final dashboardLayoutControllerProvider = StateNotifierProvider<
    DashboardLayoutController, List<DashboardSectionId>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DashboardLayoutController(prefs: prefs);
});

class DashboardLayoutController extends StateNotifier<List<DashboardSectionId>> {
  DashboardLayoutController({
    required SharedPreferences prefs,
  })  : _prefs = prefs,
        super(_loadMerged(prefs)) {
    // Ensure we persist a merged layout once (future-proof for newly added sections).
    // This is synchronous SharedPreferences, so it's safe to do here.
    _save(state);
  }

  final SharedPreferences _prefs;

  static const String _kOrderKey = 'today_dashboard_section_order_v1';

  List<DashboardSectionId> get orderedSections => state;

  void onReorder(int oldIndex, int newIndex) {
    final current = [...state];
    if (oldIndex < 0 || oldIndex >= current.length) return;

    var target = newIndex;
    // ReorderableListView's newIndex is the "insertion index" after removing
    // the old item, so when moving down we must adjust.
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > current.length - 1) target = current.length - 1;

    final item = current.removeAt(oldIndex);
    current.insert(target, item);
    state = current;
    _save(state);
  }

  void resetToDefault() {
    state = [...DashboardSectionId.defaultOrder];
    _save(state);
  }

  static List<DashboardSectionId> _loadMerged(SharedPreferences prefs) {
    final stored = prefs.getStringList(_kOrderKey) ?? const <String>[];
    final ids = <DashboardSectionId>[];

    final seen = <DashboardSectionId>{};
    final hidden = DashboardSectionId.hiddenSectionIds;
    for (final raw in stored) {
      final id = DashboardSectionId.tryParse(raw);
      if (id == null) continue;
      if (id == DashboardSectionId.niceToDo) continue;
      if (hidden.contains(id)) continue;
      if (seen.contains(id)) continue;
      seen.add(id);
      ids.add(id);
    }

    // Append any new sections (not present in stored layout) in default order.
    for (final id in DashboardSectionId.defaultOrder) {
      if (hidden.contains(id)) continue;
      if (seen.contains(id)) continue;
      ids.add(id);
      seen.add(id);
    }

    return ids;
  }

  void _save(List<DashboardSectionId> order) {
    _prefs.setStringList(_kOrderKey, [for (final id in order) id.name]);
  }
}

