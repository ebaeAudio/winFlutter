import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/admin.dart';
import '../features/today/today_controller.dart';
import '../features/today/today_models.dart';
import '../platform/dock_badge/dock_badge_controller.dart';
import '../platform/shortcuts/app_shortcuts.dart';
import 'components/command_palette.dart';
import 'components/quick_capture.dart';
import 'spacing.dart';

/// Navigation shell for desktop platforms (macOS, Windows, Linux).
///
/// Features a collapsible sidebar instead of bottom navigation tabs.
class DesktopNavShell extends ConsumerStatefulWidget {
  const DesktopNavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DesktopNavShell> createState() => _DesktopNavShellState();
}

class _DesktopNavShellState extends ConsumerState<DesktopNavShell> {
  bool _isExpanded = true;
  bool _isCommandPaletteOpen = false;
  bool _isQuickCaptureOpen = false;

  static const _collapsedWidth = 72.0;
  static const _expandedWidth = 220.0;

  void _toggleSidebar() {
    setState(() => _isExpanded = !_isExpanded);
  }

  void _openCommandPalette() async {
    if (_isCommandPaletteOpen) return;
    setState(() => _isCommandPaletteOpen = true);
    await showCommandPalette(context);
    if (mounted) {
      setState(() => _isCommandPaletteOpen = false);
    }
  }

  void _openQuickCapture() async {
    if (_isQuickCaptureOpen) return;
    setState(() => _isQuickCaptureOpen = true);
    final result = await showQuickCapture(context);
    if (mounted) {
      setState(() => _isQuickCaptureOpen = false);
    }
    if (result != null && mounted) {
      _handleQuickCaptureResult(result);
    }
  }

  Future<void> _handleQuickCaptureResult(QuickCaptureResult result) async {
    final today = _formatYmd(result.targetDate ?? DateTime.now());

    switch (result.type) {
      case QuickCaptureType.task:
        await _createTask(
          title: result.text,
          type: TodayTaskType.niceToDo,
          ymd: today,
        );
      case QuickCaptureType.mustWin:
        await _createTask(
          title: result.text,
          type: TodayTaskType.mustWin,
          ymd: today,
        );
      case QuickCaptureType.habit:
        await _createHabit(name: result.text, ymd: today);
      case QuickCaptureType.note:
        await _appendToReflection(text: result.text, ymd: today);
      case QuickCaptureType.focusStart:
        await _startFocusTimer(durationText: result.text);
    }
  }

  Future<void> _createTask({
    required String title,
    required TodayTaskType type,
    required String ymd,
  }) async {
    final controller = ref.read(todayControllerProvider(ymd).notifier);
    final success = await controller.addTask(title: title, type: type);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${type == TodayTaskType.mustWin ? "Must-Win" : "Task"} added: "$title"'
              : 'Failed to add task',
        ),
        action: success
            ? SnackBarAction(label: 'View', onPressed: () => _navigateTo(2))
            : null,
      ),
    );
  }

  Future<void> _createHabit({required String name, required String ymd}) async {
    final controller = ref.read(todayControllerProvider(ymd).notifier);
    final success = await controller.addHabit(name: name);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Habit added: "$name"' : 'Failed to add habit'),
        action: success
            ? SnackBarAction(label: 'View', onPressed: () => _navigateTo(2))
            : null,
      ),
    );
  }

  Future<void> _appendToReflection({
    required String text,
    required String ymd,
  }) async {
    final controller = ref.read(todayControllerProvider(ymd).notifier);
    final state = ref.read(todayControllerProvider(ymd));
    final existing = state.reflection.trim();
    final newReflection =
        existing.isEmpty ? text : '$existing\n\n$text';
    await controller.setReflection(newReflection);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note added to reflection'),
        action: SnackBarAction(label: 'View', onPressed: () => _navigateTo(2)),
      ),
    );
  }

  Future<void> _startFocusTimer({required String durationText}) async {
    // Parse duration from text (e.g., "25" -> 25 minutes).
    final minutes = int.tryParse(durationText.trim()) ?? 25;

    // Navigate to Focus screen first.
    _navigateTo(3);

    // Show instruction - actual focus start requires policy selection.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Start a ${minutes}min focus session from the Focus tab'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _navigateTo(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep dock badge in sync with task count (macOS only).
    ref.watch(dockBadgeSyncProvider);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAdminAsync = ref.watch(isAdminProvider);

    // Define navigation items matching the mobile NavShell.
    final destinations = <_NavItem>[
      _NavItem(
        icon: Icons.workspaces_outline,
        selectedIcon: Icons.workspaces,
        label: 'Projects',
        shortcut: '⌘4',
        routeIndex: 0,
      ),
      _NavItem(
        icon: Icons.check_circle_outline,
        selectedIcon: Icons.check_circle,
        label: 'Tasks',
        shortcut: null,
        routeIndex: 1,
      ),
      _NavItem(
        icon: Icons.today_outlined,
        selectedIcon: Icons.today,
        label: 'Now',
        shortcut: '⌘1',
        routeIndex: 2,
      ),
      _NavItem(
        icon: Icons.lock_outline,
        selectedIcon: Icons.lock,
        label: 'Focus',
        shortcut: '⌘2',
        routeIndex: 3,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
        shortcut: '⌘,',
        routeIndex: 4,
      ),
    ];

    // Add admin dashboard if user is admin
    if (isAdminAsync.valueOrNull == true) {
      destinations.add(
        _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'Admin',
          shortcut: null,
          routeIndex: 5,
          isAdmin: true,
        ),
      );
    }

    final sidebarWidth = _isExpanded ? _expandedWidth : _collapsedWidth;

    return Shortcuts(
      shortcuts: AppShortcuts.shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) => _openCommandPalette(),
          ),
          OpenQuickCaptureIntent: CallbackAction<OpenQuickCaptureIntent>(
            onInvoke: (_) => _openQuickCapture(),
          ),
          GoToTodayIntent: CallbackAction<GoToTodayIntent>(
            onInvoke: (_) => _navigateTo(2),
          ),
          GoToFocusIntent: CallbackAction<GoToFocusIntent>(
            onInvoke: (_) => _navigateTo(3),
          ),
          GoToProjectsIntent: CallbackAction<GoToProjectsIntent>(
            onInvoke: (_) => _navigateTo(0),
          ),
          GoToTasksIntent: CallbackAction<GoToTasksIntent>(
            onInvoke: (_) => _navigateTo(1),
          ),
          GoToSettingsIntent: CallbackAction<GoToSettingsIntent>(
            onInvoke: (_) => _navigateTo(4),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                // ─────────────────────────────────────────────────────────────
                // Sidebar
                // ─────────────────────────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: sidebarWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border(
                        right: BorderSide(
                          color: scheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ─────────────────────────────────────────────────────
                        // Header with app name / collapse toggle
                        // ─────────────────────────────────────────────────────
                        _SidebarHeader(
                          isExpanded: _isExpanded,
                          onToggle: _toggleSidebar,
                        ),

                        Gap.h8,

                        // ─────────────────────────────────────────────────────
                        // Command Palette Button
                        // ─────────────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s12,
                          ),
                          child: _CommandPaletteButton(
                            isExpanded: _isExpanded,
                            onPressed: _openCommandPalette,
                          ),
                        ),

                        Gap.h16,

                        // ─────────────────────────────────────────────────────
                        // Navigation Items
                        // ─────────────────────────────────────────────────────
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s8,
                            ),
                            itemCount: destinations.length,
                            itemBuilder: (context, index) {
                              final item = destinations[index];
                              // Check if this item is selected by comparing route index or path
                              final currentPath = GoRouterState.of(context).uri.path;
                              final isSelected = item.isAdmin == true
                                  ? currentPath == '/admin' || currentPath.startsWith('/admin')
                                  : item.routeIndex == widget.navigationShell.currentIndex;

                              return _SidebarNavItem(
                                icon: isSelected ? item.selectedIcon : item.icon,
                                label: item.label,
                                shortcut: item.shortcut,
                                isSelected: isSelected,
                                isExpanded: _isExpanded,
                                onTap: () {
                                  if (item.isAdmin == true) {
                                    // Navigate to admin route directly
                                    context.go('/admin');
                                  } else {
                                    _navigateTo(item.routeIndex);
                                  }
                                },
                              );
                            },
                          ),
                        ),

                        // ─────────────────────────────────────────────────────
                        // Footer (version, etc.)
                        // ─────────────────────────────────────────────────────
                        if (_isExpanded)
                          Padding(
                            padding: const EdgeInsets.all(AppSpace.s16),
                            child: Text(
                              'Win the Year',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ─────────────────────────────────────────────────────────────
                // Main Content
                // ─────────────────────────────────────────────────────────────
                Expanded(
                  child: widget.navigationShell,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.routeIndex,
    this.shortcut,
    this.isAdmin = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? shortcut;
  final int routeIndex;
  final bool isAdmin;
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.isExpanded,
    required this.onToggle,
  });

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!isExpanded) {
      // Collapsed layout: stack icon and button vertically to fit in 72px width
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'W',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Gap.h4,
            // Toggle button
            IconButton(
              icon: const Icon(
                Icons.keyboard_double_arrow_right,
                size: 18,
              ),
              onPressed: onToggle,
              tooltip: 'Expand sidebar',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      );
    }

    // Expanded layout
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          // App icon.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'W',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Text(
              'Win',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.keyboard_double_arrow_left,
              size: 20,
            ),
            onPressed: onToggle,
            tooltip: 'Collapse sidebar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CommandPaletteButton extends StatelessWidget {
  const _CommandPaletteButton({
    required this.isExpanded,
    required this.onPressed,
  });

  final bool isExpanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!isExpanded) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: onPressed,
        tooltip: 'Command Palette (⌘K)',
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                'Search...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⌘K',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.shortcut,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bgColor = isSelected
        ? scheme.primaryContainer.withOpacity(0.6)
        : Colors.transparent;
    final iconColor = isSelected ? scheme.primary : scheme.onSurfaceVariant;
    final textColor = isSelected ? scheme.onSurface : scheme.onSurfaceVariant;
    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? AppSpace.s12 : AppSpace.s16,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              if (isExpanded) ...[
                Gap.w12,
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
                if (shortcut != null)
                  Text(
                    shortcut!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
