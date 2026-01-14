import 'package:flutter/material.dart';

import '../../../app/analytics/track.dart';
import '../../../ui/responsive.dart';
import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class HowItWorks extends StatefulWidget {
  const HowItWorks({
    super.key,
    required this.content,
    required this.analyticsEvent,
  });

  final PitchHowItWorksContent content;
  final String analyticsEvent;

  @override
  State<HowItWorks> createState() => _HowItWorksState();
}

class _HowItWorksState extends State<HowItWorks> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final steps = widget.content.steps;
    final horizontal = isDesktop(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s8),
        child: Stepper(
          type: horizontal ? StepperType.horizontal : StepperType.vertical,
          currentStep: _current.clamp(0, steps.length - 1),
          onStepTapped: (idx) {
            final s = steps[idx];
            track(
              widget.analyticsEvent,
              {'kind': 'step_tapped', 'id': s.id, 'index': idx},
            );
            setState(() => _current = idx);
          },
          controlsBuilder: (context, details) => const SizedBox.shrink(),
          steps: [
            for (var i = 0; i < steps.length; i++)
              Step(
                title: Text(steps[i].title),
                subtitle: horizontal ? null : Text(steps[i].body),
                content: horizontal
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s8),
                        child: Text(steps[i].body),
                      )
                    : const SizedBox.shrink(),
                isActive: i == _current,
                state: i < _current ? StepState.complete : StepState.indexed,
              ),
          ],
        ),
      ),
    );
  }
}

