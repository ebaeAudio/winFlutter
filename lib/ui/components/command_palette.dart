import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../spacing.dart';

/// A command that can be executed from the command palette.
class CommandPaletteItem {
  const CommandPaletteItem({
    required this.id,
    required this.label,
    required this.icon,
    this.shortcut,
    this.category,
    this.keywords = const [],
    required this.onExecute,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? shortcut;
  final String? category;
  final List<String> keywords;
  final VoidCallback onExecute;
}

/// Shows the command palette as a modal overlay.
///
/// Returns the executed command ID, or null if dismissed.
Future<String?> showCommandPalette(
  BuildContext context, {
  List<CommandPaletteItem>? additionalCommands,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => CommandPaletteDialog(
      additionalCommands: additionalCommands ?? const [],
    ),
  );
}

/// The command palette dialog widget.
class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    this.additionalCommands = const [],
  });

  final List<CommandPaletteItem> additionalCommands;

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  late List<CommandPaletteItem> _allCommands;
  List<CommandPaletteItem> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    _allCommands = [
      ..._buildDefaultCommands(context),
      ...widget.additionalCommands,
    ];
    _filteredCommands = _allCommands;
    _controller.addListener(_onQueryChanged);

    // Auto-focus the search field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = _allCommands;
      } else {
        _filteredCommands = _allCommands.where((cmd) {
          // Match label, category, or keywords.
          if (cmd.label.toLowerCase().contains(query)) return true;
          if (cmd.category?.toLowerCase().contains(query) ?? false) return true;
          for (final kw in cmd.keywords) {
            if (kw.toLowerCase().contains(query)) return true;
          }
          return false;
        }).toList();
      }
      // Reset selection when filter changes.
      _selectedIndex = 0;
    });
  }

  void _executeSelected() {
    if (_filteredCommands.isEmpty) return;
    final cmd = _filteredCommands[_selectedIndex];
    Navigator.of(context).pop(cmd.id);
    cmd.onExecute();
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta).clamp(0, _filteredCommands.length - 1);
    });
  }

  List<CommandPaletteItem> _buildDefaultCommands(BuildContext context) {
    return [
      // ─────────────────────────────────────────────────────────────────────
      // Navigation
      // ─────────────────────────────────────────────────────────────────────
      CommandPaletteItem(
        id: 'nav.today',
        label: 'Go to Now',
        icon: Icons.today,
        shortcut: '⌘1',
        category: 'Navigation',
        keywords: ['home', 'dashboard'],
        onExecute: () => context.go('/today'),
      ),
      CommandPaletteItem(
        id: 'nav.focus',
        label: 'Go to Focus',
        icon: Icons.lock,
        shortcut: '⌘2',
        category: 'Navigation',
        keywords: ['dumb phone', 'session'],
        onExecute: () => context.go('/focus'),
      ),
      CommandPaletteItem(
        id: 'nav.rollups',
        label: 'Go to Rollups',
        icon: Icons.bar_chart,
        shortcut: '⌘3',
        category: 'Navigation',
        keywords: ['analytics', 'stats', 'charts'],
        onExecute: () => context.go('/rollups'),
      ),
      CommandPaletteItem(
        id: 'nav.projects',
        label: 'Go to Projects',
        icon: Icons.workspaces_outline,
        shortcut: '⌘4',
        category: 'Navigation',
        keywords: ['linear', 'issues'],
        onExecute: () => context.go('/projects'),
      ),
      CommandPaletteItem(
        id: 'nav.tasks',
        label: 'Go to All Tasks',
        icon: Icons.check_circle_outline,
        category: 'Navigation',
        keywords: ['list', 'todo'],
        onExecute: () => context.go('/tasks'),
      ),
      CommandPaletteItem(
        id: 'nav.settings',
        label: 'Go to Settings',
        icon: Icons.settings,
        shortcut: '⌘,',
        category: 'Navigation',
        keywords: ['preferences', 'config'],
        onExecute: () => context.go('/settings'),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // Actions
      // ─────────────────────────────────────────────────────────────────────
      CommandPaletteItem(
        id: 'action.new_task',
        label: 'New Task',
        icon: Icons.add_task,
        shortcut: '⌘N',
        category: 'Actions',
        keywords: ['create', 'add'],
        onExecute: () {
          // Navigate to today and focus quick-add.
          context.go('/today');
          // The actual focus happens via the Today screen's state.
        },
      ),
      CommandPaletteItem(
        id: 'action.new_must_win',
        label: 'New Must-Win',
        icon: Icons.flag,
        shortcut: '⌘⇧N',
        category: 'Actions',
        keywords: ['create', 'add', 'important'],
        onExecute: () {
          context.go('/today');
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Group commands by category for display.
    final Map<String?, List<CommandPaletteItem>> grouped = {};
    for (final cmd in _filteredCommands) {
      grouped.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _moveSelection(1);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _moveSelection(-1);
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _executeSelected();
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 480),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─────────────────────────────────────────────────────────────
                // Search Field
                // ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: scheme.onSurfaceVariant,
                      ),
                      Gap.w12,
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Type a command or search...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                          style: theme.textTheme.bodyLarge,
                          onSubmitted: (_) => _executeSelected(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'esc',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: scheme.outlineVariant),

                // ─────────────────────────────────────────────────────────────
                // Results List
                // ─────────────────────────────────────────────────────────────
                Flexible(
                  child: _filteredCommands.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpace.s24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: scheme.onSurfaceVariant.withOpacity(0.4),
                              ),
                              Gap.h12,
                              Text(
                                'No commands found',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s8,
                          ),
                          shrinkWrap: true,
                          itemCount: _filteredCommands.length,
                          itemBuilder: (context, index) {
                            final cmd = _filteredCommands[index];
                            final isSelected = index == _selectedIndex;

                            // Check if this is the first item of a new category.
                            final prevCategory = index > 0
                                ? _filteredCommands[index - 1].category
                                : null;
                            final showCategoryHeader =
                                cmd.category != null &&
                                    cmd.category != prevCategory;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showCategoryHeader) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpace.s16,
                                      AppSpace.s12,
                                      AppSpace.s16,
                                      AppSpace.s4,
                                    ),
                                    child: Text(
                                      cmd.category!,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                _CommandItem(
                                  item: cmd,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() => _selectedIndex = index);
                                    _executeSelected();
                                  },
                                  onHover: () {
                                    setState(() => _selectedIndex = index);
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                ),

                // ─────────────────────────────────────────────────────────────
                // Footer
                // ─────────────────────────────────────────────────────────────
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s8,
                  ),
                  child: Row(
                    children: [
                      _FooterHint(label: '↑↓', description: 'navigate'),
                      Gap.w16,
                      _FooterHint(label: '⏎', description: 'select'),
                      Gap.w16,
                      _FooterHint(label: 'esc', description: 'close'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandItem extends StatelessWidget {
  const _CommandItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  final CommandPaletteItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s8,
          ),
          color: isSelected
              ? scheme.primaryContainer.withOpacity(0.4)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              Gap.w12,
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? scheme.onSurface : scheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (item.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.shortcut!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          description,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
