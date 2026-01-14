import 'package:flutter/material.dart';

/// All copy + display config for the Pitch / How-To screen.
///
/// No user-visible strings should live in widgets; they should live here.
const pitchContent = PitchContent(
  navEntry: PitchNavEntry(
    title: 'Pitch / How‑To',
    subtitle: 'A quick walkthrough of how the app works',
  ),
  analytics: PitchAnalyticsConfig(
    viewEvent: 'pitch_viewed',
    ctaEvent: 'pitch_cta_clicked',
    interactionEvent: 'pitch_interaction',
  ),
  navigation: PitchNavigationConfig(
    primaryCtaDefaultRoute: '/today',
  ),
  hero: PitchHeroContent(
    headline: 'Win today. Repeat.',
    subheadline:
        'Plan your Must‑Wins, knock out Nice‑to‑Dos, stay consistent with Habits, and reflect—one day at a time.',
    primaryCtaLabel: 'Go to Today',
    secondaryCtaLabel: 'See examples',
  ),
  howItWorks: PitchHowItWorksContent(
    title: 'How it works',
    steps: [
      PitchStep(
        id: 'pick_date',
        title: 'Pick a date',
        body: 'Navigate days to plan ahead or review what happened.',
        icon: Icons.today_outlined,
      ),
      PitchStep(
        id: 'set_must_wins',
        title: 'Set Must‑Wins',
        body: 'Choose the few tasks that make the day a win.',
        icon: Icons.flag_outlined,
      ),
      PitchStep(
        id: 'do_habits',
        title: 'Check Habits',
        body: 'Mark habits complete to stay consistent.',
        icon: Icons.check_circle_outline,
      ),
      PitchStep(
        id: 'reflect_score',
        title: 'Reflect + score',
        body: 'Write a quick note and see your day’s score.',
        icon: Icons.insights_outlined,
      ),
    ],
  ),
  featureGrid: PitchFeatureGridContent(
    title: 'What you get',
    features: [
      PitchFeature(
        id: 'tasks_two_lanes',
        icon: Icons.view_agenda_outlined,
        title: 'Two task lanes',
        body: 'Separate Must‑Wins from Nice‑to‑Dos.',
      ),
      PitchFeature(
        id: 'habits_daily',
        icon: Icons.repeat_outlined,
        title: 'Daily habits',
        body: 'One list, check off per day.',
      ),
      PitchFeature(
        id: 'reflection',
        icon: Icons.edit_note_outlined,
        title: 'Reflection',
        body: 'A short note that keeps you honest.',
      ),
      PitchFeature(
        id: 'rollups',
        icon: Icons.bar_chart_outlined,
        title: 'Rollups',
        body: 'See week/month/year trends.',
      ),
      PitchFeature(
        id: 'assistant',
        icon: Icons.auto_awesome_outlined,
        title: 'Assistant',
        body: 'Use simple commands to add and update.',
      ),
      PitchFeature(
        id: 'focus_mode',
        icon: Icons.lock_clock_outlined,
        title: 'Focus mode',
        body: 'Timebox work and reduce distractions.',
      ),
    ],
  ),
  personas: PitchPersonasContent(
    title: 'Who it’s for',
    personas: [
      PitchPersona(
        id: 'builder',
        tabLabel: 'Builder',
        headline: 'You want momentum, not perfection.',
        body:
            'Pick 1–3 Must‑Wins, keep the list short, and ship something every day.',
        bullets: [
          'Use Must‑Wins for the “non‑negotiables”.',
          'Keep Nice‑to‑Dos as optional overflow.',
          'Reflect to spot what’s slowing you down.',
        ],
      ),
      PitchPersona(
        id: 'steady',
        tabLabel: 'Steady',
        headline: 'You want consistency.',
        body:
            'Build habits that compound and keep your daily plan lightweight.',
        bullets: [
          'Add a small habit list you can actually finish.',
          'Use Today as a daily checklist.',
          'Use Rollups to see weekly consistency.',
        ],
      ),
      PitchPersona(
        id: 'reset',
        tabLabel: 'Reset',
        headline: 'You’re getting back on track.',
        body:
            'Start with one Must‑Win and one habit. Make “showing up” the win.',
        bullets: [
          'Shrink scope until you can succeed.',
          'Score days without punishing yourself.',
          'Use reflection to learn (not judge).',
        ],
      ),
    ],
  ),
  faq: PitchFaqContent(
    title: 'FAQ',
    items: [
      PitchFaqItem(
        id: 'must_win_definition',
        question: 'What’s a Must‑Win?',
        answer:
            'A Must‑Win is a task that makes the day successful. Keep it to a few high‑impact items.',
      ),
      PitchFaqItem(
        id: 'nice_to_do_definition',
        question: 'What are Nice‑to‑Dos?',
        answer:
            'Nice‑to‑Dos are optional tasks. They’re great for momentum, but they don’t define success.',
      ),
      PitchFaqItem(
        id: 'habits_scope',
        question: 'Are habits per day or global?',
        answer:
            'Habits are a global list. Each day you can mark them complete (or not).',
      ),
      PitchFaqItem(
        id: 'scoring',
        question: 'How is the daily score calculated?',
        answer:
            'It’s a weighted completion score across Must‑Wins, Nice‑to‑Dos, and Habits (empty groups don’t penalize you).',
      ),
      PitchFaqItem(
        id: 'rollups',
        question: 'What are Rollups?',
        answer:
            'Rollups summarize your scores and activity over week/month/year so you can see trends.',
      ),
      PitchFaqItem(
        id: 'assistant_privacy',
        question: 'What does the Assistant do?',
        answer:
            'The Assistant helps translate simple commands into actions (like creating or completing tasks).',
      ),
    ],
  ),
  finalCta: PitchFinalCtaContent(
    title: 'Ready to win today?',
    body: 'Start small. Pick your Must‑Wins. Then execute.',
    primaryCtaLabel: 'Open Today',
  ),
  stickyCtaBar: PitchStickyCtaBarContent(
    semanticsLabel: 'Primary call to action',
  ),
  screenshotCarousel: PitchScreenshotCarouselContent(
    title: 'Examples',
    closeLabel: 'Close',
    previousLabel: 'Previous',
    nextLabel: 'Next',
    placeholderLabel: 'Example screenshot placeholder',
    slides: [
      PitchCarouselSlide(
        id: 'today',
        title: 'Today',
        body: 'Your Must‑Wins, Nice‑to‑Dos, habits, reflection, and score.',
      ),
      PitchCarouselSlide(
        id: 'rollups',
        title: 'Rollups',
        body: 'Weekly and monthly trends to keep you honest.',
      ),
      PitchCarouselSlide(
        id: 'settings',
        title: 'Settings',
        body: 'Themes, trackers, integrations, and support.',
      ),
    ],
  ),
);

@immutable
class PitchContent {
  const PitchContent({
    required this.navEntry,
    required this.analytics,
    required this.navigation,
    required this.hero,
    required this.howItWorks,
    required this.featureGrid,
    required this.personas,
    required this.faq,
    required this.finalCta,
    required this.stickyCtaBar,
    required this.screenshotCarousel,
  });

  final PitchNavEntry navEntry;
  final PitchAnalyticsConfig analytics;
  final PitchNavigationConfig navigation;

  final PitchHeroContent hero;
  final PitchHowItWorksContent howItWorks;
  final PitchFeatureGridContent featureGrid;
  final PitchPersonasContent personas;
  final PitchFaqContent faq;
  final PitchFinalCtaContent finalCta;
  final PitchStickyCtaBarContent stickyCtaBar;
  final PitchScreenshotCarouselContent screenshotCarousel;
}

@immutable
class PitchNavEntry {
  const PitchNavEntry({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

@immutable
class PitchAnalyticsConfig {
  const PitchAnalyticsConfig({
    required this.viewEvent,
    required this.ctaEvent,
    required this.interactionEvent,
  });

  final String viewEvent;
  final String ctaEvent;
  final String interactionEvent;
}

@immutable
class PitchNavigationConfig {
  const PitchNavigationConfig({required this.primaryCtaDefaultRoute});
  final String primaryCtaDefaultRoute;
}

@immutable
class PitchHeroContent {
  const PitchHeroContent({
    required this.headline,
    required this.subheadline,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
  });

  final String headline;
  final String subheadline;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
}

@immutable
class PitchHowItWorksContent {
  const PitchHowItWorksContent({required this.title, required this.steps});
  final String title;
  final List<PitchStep> steps;
}

@immutable
class PitchStep {
  const PitchStep({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
  });
  final String id;
  final String title;
  final String body;
  final IconData icon;
}

@immutable
class PitchFeatureGridContent {
  const PitchFeatureGridContent({required this.title, required this.features});
  final String title;
  final List<PitchFeature> features;
}

@immutable
class PitchFeature {
  const PitchFeature({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });
  final String id;
  final IconData icon;
  final String title;
  final String body;
}

@immutable
class PitchPersonasContent {
  const PitchPersonasContent({required this.title, required this.personas});
  final String title;
  final List<PitchPersona> personas;
}

@immutable
class PitchPersona {
  const PitchPersona({
    required this.id,
    required this.tabLabel,
    required this.headline,
    required this.body,
    required this.bullets,
  });
  final String id;
  final String tabLabel;
  final String headline;
  final String body;
  final List<String> bullets;
}

@immutable
class PitchFaqContent {
  const PitchFaqContent({required this.title, required this.items});
  final String title;
  final List<PitchFaqItem> items;
}

@immutable
class PitchFaqItem {
  const PitchFaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });
  final String id;
  final String question;
  final String answer;
}

@immutable
class PitchFinalCtaContent {
  const PitchFinalCtaContent({
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
  });
  final String title;
  final String body;
  final String primaryCtaLabel;
}

@immutable
class PitchStickyCtaBarContent {
  const PitchStickyCtaBarContent({required this.semanticsLabel});
  final String semanticsLabel;
}

@immutable
class PitchScreenshotCarouselContent {
  const PitchScreenshotCarouselContent({
    required this.title,
    required this.closeLabel,
    required this.previousLabel,
    required this.nextLabel,
    required this.placeholderLabel,
    required this.slides,
  });

  final String title;
  final String closeLabel;
  final String previousLabel;
  final String nextLabel;
  final String placeholderLabel;
  final List<PitchCarouselSlide> slides;
}

@immutable
class PitchCarouselSlide {
  const PitchCarouselSlide({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;
}

