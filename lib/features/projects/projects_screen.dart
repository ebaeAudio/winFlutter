import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/empty_state_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

const _projectsMaxDelaySeconds = 1.35;
const _projectsLongestAnimationDurationMs = 600;

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final totalDurationMs =
        (1000 * _projectsMaxDelaySeconds).round() +
            _projectsLongestAnimationDurationMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDurationMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Projects',
      children: [
        _AnimatedCard(
          delay: 0.0,
          animation: _controller,
          child: const _SecretNotesEntryCard(),
        ),
        Gap.h16,
        _AnimatedCard(
          delay: 0.1,
          animation: _controller,
          child: const EmptyStateCard(
            icon: Icons.workspaces_outline,
            title: 'Notes & Projects',
            description:
                'A powerful notes workspace that connects your ideas to execution. Capture thoughts instantly, organize projects, and link everything to your daily tasks.',
          ),
        ),
        Gap.h16,
        _AnimatedCard(
          delay: 0.2,
          animation: _controller,
          child: const SectionHeader(title: 'Vision: Your Second Brain'),
        ),
        _AnimatedCard(
          delay: 0.25,
          animation: _controller,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Problem',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  Text(
                    'One place to capture "working notes" and turn them into lightweight projects — synced with Supabase across devices.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Gap.h16,
                  Text(
                    'The Solution',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Fast "Inbox" for notes (zero friction).',
                      'Project notes with a small structure: goal, status, next actions, resources.',
                      'Daily scratchpad (auto-created) so ideas land somewhere instantly.',
                      'Linking between notes ⇄ tasks ⇄ dates so planning becomes execution.',
                      'Search + quick filters: recent, pinned, active.',
                    ],
                    animation: _controller,
                    startDelay: 0.35,
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap.h16,
        _AnimatedCard(
          delay: 0.4,
          animation: _controller,
          child: const SectionHeader(title: 'Key Patterns & Use Cases'),
        ),
        _AnimatedCard(
          delay: 0.45,
          animation: _controller,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PatternTitle(
                    title: 'Daily Scratchpad',
                    subtitle:
                        'Your daily thinking space — auto-created, always accessible.',
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'One "Today" scratchpad note, created automatically each day.',
                      'Optional template so it starts with structure (e.g. "Ideas", "Decisions", "Next").',
                      'A note can link back to a day (YYYY‑MM‑DD) for fast recall.',
                    ],
                    animation: _controller,
                    startDelay: 0.55,
                  ),
                  Gap.h16,
                  const _PatternTitle(
                    title: 'Project notes = context + next actions',
                    subtitle:
                        'Inspired by NotePlan: a project page that holds the "why" and the "next".',
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Goal + status + next actions (keep it small).',
                      'Backlinks: see which tasks/days reference this project.',
                      'Pin active projects so they\'re always one tap away.',
                    ],
                    animation: _controller,
                    startDelay: 0.65,
                  ),
                  Gap.h16,
                  const _PatternTitle(
                    title: 'Task context without becoming a project manager',
                    subtitle:
                        'Inspired by Amplenote: "project" as a note reference (backlink).',
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Use [[Note Name]] syntax (Obsidian-style) to link between notes',
                      'Tasks can link to project notes for context',
                      'View backlinks: see all notes/tasks that reference the current note',
                      'Navigate by tapping links — no context switching',
                    ],
                    animation: _controller,
                    startDelay: 0.75,
                  ),
                  Gap.h16,
                  const _PatternTitle(
                    title: 'Inbox for Quick Capture',
                    subtitle:
                        'Zero friction — capture ideas instantly, organize later.',
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Quick capture from anywhere in the app',
                      'Simple notes with no required structure',
                      'Convert to project notes or link to tasks when ready',
                      'Archive or delete when no longer needed',
                    ],
                    animation: _controller,
                    startDelay: 0.85,
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap.h16,
        _AnimatedCard(
          delay: 0.9,
          animation: _controller,
          child: const SectionHeader(title: 'Technical Foundation'),
        ),
        _AnimatedCard(
          delay: 0.95,
          animation: _controller,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline-First Architecture',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Offline-first UX: edits never block on the network.',
                      'Sync via Supabase when available; keep state consistent across devices.',
                      'Clear conflict policy (MVP: last-write-wins + "updated just now" cues).',
                      'Keep attachments as a follow-up; text sync first.',
                    ],
                    animation: _controller,
                    startDelay: 1.05,
                  ),
                  Gap.h16,
                  Text(
                    'Data & Privacy',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Encrypted at rest via Supabase',
                      'Full-text search with PostgreSQL indexes',
                      'Export to Markdown (Obsidian-compatible) — you own your data',
                      'Import from external sources (future)',
                    ],
                    animation: _controller,
                    startDelay: 1.15,
                  ),
                  Gap.h12,
                  _AnimatedInfoBox(
                    animation: _controller,
                    delay: 1.25,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.s12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: theme.colorScheme.primary,),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              'Architecture document: See docs/NOTES_ARCHITECTURE.md for full technical details and implementation roadmap.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap.h16,
        _AnimatedCard(
          delay: 1.3,
          animation: _controller,
          child: const SectionHeader(title: 'Future Enhancements'),
        ),
        _AnimatedCard(
          delay: 1.35,
          animation: _controller,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phase 2+ Features',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      '📋 Templates: Custom note templates (meeting notes, project kickoff, daily review)',
                      '🏷️ Tags: Organize notes with tags, filter by tag, tag autocomplete',
                      '📎 Attachments: Images and files in notes (with cloud storage)',
                      '🤖 AI Integration: Summarize notes, extract action items, suggest related notes',
                      '📤 Export/Import: Full Obsidian vault compatibility, batch operations',
                      '🔔 Notifications: Reminders for project deadlines, follow-ups on notes',
                    ],
                    animation: _controller,
                    startDelay: 1.45,
                  ),
                  Gap.h16,
                  Text(
                    'Integration Opportunities',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Gap.h8,
                  _Bullets(
                    items: const [
                      'Calendar: Link notes to calendar events, auto-create notes for meetings',
                      'Email: Save important emails as notes with context',
                      'Web Clipper: Save web pages and articles as notes',
                      'Voice Notes: Transcribe voice to text (mobile)',
                      'Command Palette: Quick note creation from anywhere',
                    ],
                    animation: _controller,
                    startDelay: 1.55,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated card wrapper that fades in and slides up with a delay
class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({
    required this.delay,
    required this.animation,
    required this.child,
  });

  final double delay;
  final AnimationController animation;
  final Widget child;
  static const _duration = Duration(milliseconds: 600);

  Animation<double> _progress() {
    final totalMs = animation.duration?.inMilliseconds ?? _duration.inMilliseconds;
    if (totalMs <= 0) return animation;
    final delayMs = (delay * 1000).round();
    final start = (delayMs / totalMs).clamp(0.0, 1.0);
    if (start >= 1.0) return const AlwaysStoppedAnimation(1.0);
    final end =
        ((delayMs + _duration.inMilliseconds) / totalMs).clamp(start, 1.0);
    return CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Animated info box with a subtle scale and fade
class _AnimatedInfoBox extends StatelessWidget {
  const _AnimatedInfoBox({
    required this.animation,
    required this.delay,
    required this.child,
  });

  final AnimationController animation;
  final double delay;
  final Widget child;
  static const _duration = Duration(milliseconds: 500);

  Animation<double> _progress() {
    final totalMs = animation.duration?.inMilliseconds ?? _duration.inMilliseconds;
    if (totalMs <= 0) return animation;
    final delayMs = (delay * 1000).round();
    final start = (delayMs / totalMs).clamp(0.0, 1.0);
    if (start >= 1.0) return const AlwaysStoppedAnimation(1.0);
    final end =
        ((delayMs + _duration.inMilliseconds) / totalMs).clamp(start, 1.0);
    return CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.95 + (0.05 * t),
            child: child,
          ),
        );
      },
    );
  }
}

class _SecretNotesEntryCard extends StatefulWidget {
  const _SecretNotesEntryCard();

  @override
  State<_SecretNotesEntryCard> createState() => _SecretNotesEntryCardState();
}

class _SecretNotesEntryCardState extends State<_SecretNotesEntryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Secret notes. Long press to open.',
      child: Tooltip(
        message: 'Long press to open',
        child: Card(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tip: press and hold to open')),
              );
            },
            onLongPress: () async {
              await HapticFeedback.mediumImpact();
              if (!context.mounted) return;
              unawaited(context.push('/settings/projects/secret-notes'));
            },
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseValue = _pulseController.value;
                final opacity = 0.3 + (0.2 * (1 - pulseValue));
                
                return AnimatedScale(
                  scale: _isPressed ? 0.98 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer.withOpacity(opacity * 0.3),
                          scheme.primaryContainer.withOpacity(0),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s16),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: pulseValue * 0.05,
                            duration: const Duration(milliseconds: 2000),
                            child: Icon(Icons.lock_outline, color: scheme.primary),
                          ),
                          Gap.w12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Secret notes',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Gap.h4,
                                Text(
                                  'Press and hold to open the draft notes page.',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Gap.w12,
                          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
  const _Bullets({
    required this.items,
    required this.animation,
    required this.startDelay,
  });

  final List<String> items;
  final AnimationController animation;
  final double startDelay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    const itemDelay = 0.08; // Delay between each bullet item

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              final itemStart = startDelay + (i * itemDelay);
              final progress = (animation.value - itemStart).clamp(0.0, 1.0) / (1.0 - itemStart);
              final animatedValue = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
              
              return Opacity(
                opacity: animatedValue,
                child: Transform.translate(
                  offset: Offset(-10 * (1 - animatedValue), 0),
                  child: child,
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: Text(items[i], style: style)),
              ],
            ),
          ),
          Gap.h8,
        ],
      ],
    );
  }
}
