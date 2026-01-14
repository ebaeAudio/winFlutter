import 'package:flutter/material.dart';

import '../../../app/analytics/track.dart';
import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class ScreenshotCarouselDialog extends StatefulWidget {
  const ScreenshotCarouselDialog({
    super.key,
    required this.content,
    required this.analyticsEvent,
  });

  final PitchScreenshotCarouselContent content;
  final String analyticsEvent;

  @override
  State<ScreenshotCarouselDialog> createState() =>
      _ScreenshotCarouselDialogState();
}

class _ScreenshotCarouselDialogState extends State<ScreenshotCarouselDialog> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goTo(int next) async {
    if (next < 0 || next >= widget.content.slides.length) return;
    await _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slides = widget.content.slides;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.s16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.content.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.content.closeLabel),
                  ),
                ],
              ),
              Gap.h12,
              AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest.withOpacity(0.5),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      onPageChanged: (i) {
                        final s = slides[i];
                        track(
                          widget.analyticsEvent,
                          {
                            'kind': 'carousel_page_changed',
                            'id': s.id,
                            'index': i,
                          },
                        );
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => _PlaceholderSlide(
                        content: widget.content,
                        slide: slides[i],
                      ),
                    ),
                  ),
                ),
              ),
              Gap.h12,
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _index <= 0 ? null : () => _goTo(_index - 1),
                    child: Text(widget.content.previousLabel),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_index + 1} / ${slides.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Gap.w12,
                  FilledButton(
                    onPressed: _index >= slides.length - 1
                        ? null
                        : () => _goTo(_index + 1),
                    child: Text(widget.content.nextLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderSlide extends StatelessWidget {
  const _PlaceholderSlide({
    required this.content,
    required this.slide,
  });

  final PitchScreenshotCarouselContent content;
  final PitchCarouselSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: content.placeholderLabel,
            child: Icon(Icons.image_outlined, size: 56, color: scheme.primary),
          ),
          Gap.h12,
          Text(
            slide.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          Gap.h8,
          Text(
            slide.body,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

