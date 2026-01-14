import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/analytics/track.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/responsive.dart';
import '../../ui/spacing.dart';
import 'pitch_content.dart';
import 'ui/faq.dart';
import 'ui/feature_grid.dart';
import 'ui/final_cta.dart';
import 'ui/hero.dart';
import 'ui/how_it_works.dart';
import 'ui/persona_tabs.dart';
import 'ui/screenshot_carousel_dialog.dart';
import 'ui/sticky_cta_bar.dart';

class PitchPage extends StatefulWidget {
  const PitchPage({
    super.key,
    this.content = pitchContent,
    this.onPrimaryCta,
  });

  final PitchContent content;
  final VoidCallback? onPrimaryCta;

  @override
  State<PitchPage> createState() => _PitchPageState();
}

class _PitchPageState extends State<PitchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      track(widget.content.analytics.viewEvent);
    });
  }

  void _handlePrimaryCta() {
    track(widget.content.analytics.ctaEvent, const {'cta': 'primary'});
    final cb = widget.onPrimaryCta ??
        () => context.go(widget.content.navigation.primaryCtaDefaultRoute);
    cb();
  }

  Future<void> _handleSecondaryCta() async {
    track(widget.content.analytics.ctaEvent, const {'cta': 'secondary'});
    track(
      widget.content.analytics.interactionEvent,
      const {'kind': 'carousel_opened'},
    );
    await showDialog<void>(
      context: context,
      builder: (context) => ScreenshotCarouselDialog(
        content: widget.content.screenshotCarousel,
        analyticsEvent: widget.content.analytics.interactionEvent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final showSticky = isMobile(context);

    return AppScaffold(
      title: c.navEntry.title,
      bottomNavigationBar: showSticky
          ? StickyCtaBar(
              content: c.stickyCtaBar,
              primaryLabel: c.hero.primaryCtaLabel,
              onPrimaryPressed: _handlePrimaryCta,
            )
          : null,
      children: [
        HeroSection(
          content: c.hero,
          onPrimaryPressed: _handlePrimaryCta,
          onSecondaryPressed: _handleSecondaryCta,
        ),
        Gap.h16,
        SectionHeader(title: c.howItWorks.title),
        HowItWorks(
          content: c.howItWorks,
          analyticsEvent: c.analytics.interactionEvent,
        ),
        Gap.h16,
        SectionHeader(title: c.featureGrid.title),
        FeatureGrid(
          content: c.featureGrid,
          analyticsEvent: c.analytics.interactionEvent,
        ),
        Gap.h16,
        SectionHeader(title: c.personas.title),
        PersonaTabs(
          content: c.personas,
          analyticsEvent: c.analytics.interactionEvent,
        ),
        Gap.h16,
        SectionHeader(title: c.faq.title),
        FaqAccordion(
          content: c.faq,
          analyticsEvent: c.analytics.interactionEvent,
        ),
        Gap.h16,
        FinalCta(
          content: c.finalCta,
          onPrimaryPressed: _handlePrimaryCta,
        ),
        if (showSticky) ...[
          // Keep the final CTA visible above the sticky bar.
          Gap.h24,
        ],
      ],
    );
  }
}

