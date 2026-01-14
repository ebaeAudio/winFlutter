import 'package:flutter/material.dart';

import '../../../app/analytics/track.dart';
import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class FaqAccordion extends StatefulWidget {
  const FaqAccordion({
    super.key,
    required this.content,
    required this.analyticsEvent,
  });

  final PitchFaqContent content;
  final String analyticsEvent;

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s8,
        ),
        child: ExpansionPanelList.radio(
          expandedHeaderPadding: EdgeInsets.zero,
          elevation: 0,
          initialOpenPanelValue: _openId,
          expansionCallback: (panelIndex, isExpanded) {
            final item = widget.content.items[panelIndex];
            final nextOpen = isExpanded ? null : item.id;
            track(
              widget.analyticsEvent,
              {
                'kind': 'faq_toggled',
                'id': item.id,
                'index': panelIndex,
                'expanded': !isExpanded,
              },
            );
            setState(() => _openId = nextOpen);
          },
          children: [
            for (var i = 0; i < widget.content.items.length; i++)
              _panelFor(theme, widget.content.items[i], i),
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _panelFor(ThemeData theme, PitchFaqItem item, int index) {
    return ExpansionPanelRadio(
      value: item.id,
      canTapOnHeader: true,
      headerBuilder: (context, isExpanded) {
        return Semantics(
          button: true,
          label: item.question,
          child: ListTile(
            title: Text(
              item.question,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
      body: Padding(
        padding: const EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          bottom: AppSpace.s16,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(item.answer, style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}

