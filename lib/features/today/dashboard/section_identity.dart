import 'package:flutter/material.dart';

import 'dashboard_section_id.dart';

@immutable
class DashboardSectionIdentity {
  const DashboardSectionIdentity({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color accentColor;
}

extension DashboardSectionIdentityX on DashboardSectionId {
  DashboardSectionIdentity identity(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      DashboardSectionId.quickAdd => DashboardSectionIdentity(
          icon: Icons.bolt,
          accentColor: scheme.primary,
        ),
      DashboardSectionId.mustWins => DashboardSectionIdentity(
          icon: Icons.flag,
          accentColor: scheme.error,
        ),
      DashboardSectionId.niceToDo => DashboardSectionIdentity(
          icon: Icons.check_circle_outline,
          accentColor: scheme.tertiary,
        ),
      DashboardSectionId.habits => DashboardSectionIdentity(
          icon: Icons.repeat,
          accentColor: scheme.secondary,
        ),
      DashboardSectionId.trackers => DashboardSectionIdentity(
          icon: Icons.track_changes,
          accentColor: scheme.primaryContainer,
        ),
      DashboardSectionId.reflection => DashboardSectionIdentity(
          icon: Icons.edit_note,
          accentColor: scheme.secondaryContainer,
        ),
      DashboardSectionId.focus => DashboardSectionIdentity(
          icon: Icons.center_focus_strong,
          accentColor: scheme.primary,
        ),
      DashboardSectionId.assistant => DashboardSectionIdentity(
          icon: Icons.auto_awesome,
          accentColor: scheme.tertiary,
        ),
      DashboardSectionId.date => DashboardSectionIdentity(
          icon: Icons.calendar_today,
          accentColor: scheme.outline,
        ),
    };
  }
}

