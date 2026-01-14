import 'package:flutter/material.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppScaffold(
      title: 'Projects',
      children: [
        const EmptyStateCard(
          icon: Icons.workspaces_outline,
          title: 'Projects (MVP direction)',
          description:
              'A cross‑device workspace for planning and brainstorming that stays connected to execution (days + tasks).',
        ),
        Gap.h16,
        const SectionHeader(title: 'What this tab will be (simple, but powerful)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goal',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                Text(
                  'One place to capture “working notes” and turn them into lightweight projects — synced with Supabase across devices.',
                  style: theme.textTheme.bodyMedium,
                ),
                Gap.h16,
                Text(
                  'Core behaviors (v1)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'Fast “Inbox” for notes (zero friction).',
                    'Project notes with a small structure: goal, status, next actions, resources.',
                    'Daily scratchpad (auto-created) so ideas land somewhere instantly.',
                    'Linking between notes ⇄ tasks ⇄ dates so planning becomes execution.',
                    'Search + quick filters: recent, pinned, active.',
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Competitor-inspired MVP patterns'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PatternTitle(
                  title: 'Daily scratchpad',
                  subtitle:
                      'Inspired by Obsidian/NotePlan: daily notes that are always there.',
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'One “Today” scratchpad note, created automatically each day.',
                    'Optional template so it starts with structure (e.g. “Ideas”, “Decisions”, “Next”).',
                    'A note can link back to a day (YYYY‑MM‑DD) for fast recall.',
                  ],
                ),
                Gap.h16,
                _PatternTitle(
                  title: 'Project notes = context + next actions',
                  subtitle:
                      'Inspired by NotePlan: a project page that holds the “why” and the “next”.',
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'Goal + status + next actions (keep it small).',
                    'Backlinks: see which tasks/days reference this project.',
                    'Pin active projects so they’re always one tap away.',
                  ],
                ),
                Gap.h16,
                _PatternTitle(
                  title: 'Task context without becoming a project manager',
                  subtitle:
                      'Inspired by Amplenote: “project” as a note reference (backlink).',
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'Tasks can reference a project note for context.',
                    'From a task, view linked note(s) or a short context preview.',
                    'Keep Today/Tasks fast — details load only when you open them.',
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Sync approach (Supabase)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Principles',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'Offline-first UX: edits never block on the network.',
                    'Sync via Supabase when available; keep state consistent across devices.',
                    'Clear conflict policy (MVP: last-write-wins + “updated just now” cues).',
                    'Keep attachments as a follow-up; text sync first.',
                  ],
                ),
                Gap.h12,
                Text(
                  'Note: this screen is still the product sheet (UI only) — implementation comes next.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Obsidian connection (future-friendly)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Potential integrations',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                const _Bullets(
                  items: [
                    'Export projects/notes as Markdown files (one file per note).',
                    'Import from a selected Obsidian vault folder.',
                    'Use Obsidian-style linking ([[note]]) where it adds value.',
                  ],
                ),
                Gap.h12,
                Text(
                  'Export-first keeps this optional and user-controlled.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PatternTitle extends StatelessWidget {
  const _PatternTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Gap.h4,
        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: style),
              Expanded(child: Text(item, style: style)),
            ],
          ),
          Gap.h8,
        ],
      ],
    );
  }
}

