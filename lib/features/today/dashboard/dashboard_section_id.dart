/// Stable identifiers for Today dashboard sections.
///
/// IMPORTANT:
/// - Treat these as persistent IDs. Do not rename existing values.
/// - Only add new values (and include them in [defaultOrder]).
enum DashboardSectionId {
  date,
  assistant,
  focus,
  quickAdd,
  habits,
  trackers,
  mustWins,
  niceToDo,
  reflection;

  static DashboardSectionId? tryParse(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    for (final id in DashboardSectionId.values) {
      if (id.name == v) return id;
    }
    return null;
  }

  /// Default layout order for the Today dashboard.
  ///
  /// When new sections are added, include them here so older saved layouts
  /// can merge safely by appending missing IDs in this order.
  static const List<DashboardSectionId> defaultOrder = [
    DashboardSectionId.date,
    DashboardSectionId.focus,
    DashboardSectionId.quickAdd,
    DashboardSectionId.mustWins,
    DashboardSectionId.reflection,
  ];

  /// Section IDs that are no longer shown on the Today screen (hidden from layout).
  static const Set<DashboardSectionId> hiddenSectionIds = {
    DashboardSectionId.assistant,
    DashboardSectionId.habits,
    DashboardSectionId.trackers,
  };
}

