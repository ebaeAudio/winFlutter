import 'package:flutter/material.dart';

import '../../data/linear/linear_issue_meta.dart';
import '../spacing.dart';

/// A compact chip displaying Linear issue assignee with optional avatar.
///
/// Returns empty if assignee is null.
class LinearAssigneeChip extends StatelessWidget {
  const LinearAssigneeChip({
    super.key,
    required this.assignee,
  });

  final LinearAssigneeMeta? assignee;

  @override
  Widget build(BuildContext context) {
    if (assignee == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = assignee!.name.trim();
    if (name.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(scheme, name),
        Gap.w4,
        Flexible(
          child: Text(
            name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(ColorScheme scheme, String name) {
    final avatarUrl = assignee?.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 10,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: scheme.surfaceContainerHighest,
        onBackgroundImageError: (_, __) {},
      );
    }

    // Fallback: initials avatar
    final initials = _getInitials(name);
    return CircleAvatar(
      radius: 10,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
