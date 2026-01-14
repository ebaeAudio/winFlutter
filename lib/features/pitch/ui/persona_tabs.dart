import 'package:flutter/material.dart';

import '../../../app/analytics/track.dart';
import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class PersonaTabs extends StatefulWidget {
  const PersonaTabs({
    super.key,
    required this.content,
    required this.analyticsEvent,
  });

  final PitchPersonasContent content;
  final String analyticsEvent;

  @override
  State<PersonaTabs> createState() => _PersonaTabsState();
}

class _PersonaTabsState extends State<PersonaTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.content.personas.length, vsync: this)
      ..addListener(() {
        if (_controller.indexIsChanging) return;
        final p = widget.content.personas[_controller.index];
        track(
          widget.analyticsEvent,
          {'kind': 'persona_tab_changed', 'id': p.id, 'index': _controller.index},
        );
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final personas = widget.content.personas;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _controller,
              isScrollable: true,
              tabs: [
                for (final p in personas) Tab(text: p.tabLabel),
              ],
            ),
            Gap.h12,
            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _controller,
                children: [
                  for (final p in personas)
                    _PersonaPanel(
                      persona: p,
                      fgMuted: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaPanel extends StatelessWidget {
  const _PersonaPanel({required this.persona, required this.fgMuted});

  final PitchPersona persona;
  final Color fgMuted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: persona.tabLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            persona.headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Gap.h8,
          Text(
            persona.body,
            style: theme.textTheme.bodyMedium?.copyWith(color: fgMuted),
          ),
          Gap.h12,
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final b in persona.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check, size: 18),
                        ),
                        Gap.w12,
                        Expanded(
                          child: Text(
                            b,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

