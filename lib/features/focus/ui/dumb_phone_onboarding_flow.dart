import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/user_settings.dart';
import '../../../platform/restriction_engine/restriction_engine.dart';
import '../../../ui/components/info_banner.dart';
import '../../../ui/spacing.dart';
import '../focus_policy_controller.dart';
import '../focus_providers.dart';
import '../restriction_permissions_provider.dart';

/// A modern step-by-step onboarding wizard for Dumb Phone Mode.
///
/// Uses progressive disclosure and contextual education to guide new users
/// through setup without overwhelming them.
class DumbPhoneOnboardingFlow extends ConsumerStatefulWidget {
  const DumbPhoneOnboardingFlow({
    super.key,
    required this.initialPermissions,
  });

  final RestrictionPermissions initialPermissions;

  @override
  ConsumerState<DumbPhoneOnboardingFlow> createState() =>
      _DumbPhoneOnboardingFlowState();
}

class _DumbPhoneOnboardingFlowState
    extends ConsumerState<DumbPhoneOnboardingFlow> {
  late final PageController _pageController;
  int _currentStep = 0;

  // Track completion of optional steps
  bool _permissionsGranted = false;

  static const _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _permissionsGranted = widget.initialPermissions.isAuthorized;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as complete
    await ref
        .read(userSettingsControllerProvider.notifier)
        .setDumbPhoneOnboardingComplete(true);

    // Refresh permissions state
    ref.invalidate(restrictionPermissionsProvider);

    if (!mounted) return;
    // Navigate to the dashboard
    context.go('/focus');
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(restrictionPermissionsProvider).valueOrNull ??
        widget.initialPermissions;

    // Update permission state if it changes
    if (perms.isAuthorized && !_permissionsGranted) {
      _permissionsGranted = true;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _OnboardingProgress(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _IntroStep(onNext: _nextStep),
                  _PermissionsStep(
                    permissions: perms,
                    onGranted: () {
                      setState(() => _permissionsGranted = true);
                      _nextStep();
                    },
                    onBack: _prevStep,
                  ),
                  _ReadyStep(
                    permissionsGranted: _permissionsGranted,
                    onComplete: _completeOnboarding,
                    onBack: _prevStep,
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

/// Progress indicator showing current step.
class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Setup',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${currentStep + 1} of $totalSteps',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Gap.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 1: Introduction - What is Dumb Phone Mode?
class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero illustration area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.s32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                Gap.h16,
                Text(
                  'Dumb Phone Mode',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Gap.h24,
          // Key benefits
          Text(
            'Focus without distractions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap.h16,
          const _BenefitRow(
            icon: Icons.block,
            title: 'Block distracting apps',
            description: 'Temporarily block apps so you can focus on what matters.',
          ),
          Gap.h12,
          const _BenefitRow(
            icon: Icons.timer,
            title: 'Set your focus time',
            description: 'Choose how long you want to focus—from 5 minutes to 3 hours.',
          ),
          Gap.h12,
          const _BenefitRow(
            icon: Icons.psychology,
            title: 'Built-in friction',
            description: 'Make ending early intentionally harder to build better habits.',
          ),
          const Spacer(),
          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get started'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2: Grant required permissions
class _PermissionsStep extends ConsumerWidget {
  const _PermissionsStep({
    required this.permissions,
    required this.onGranted,
    required this.onBack,
  });

  final RestrictionPermissions permissions;
  final VoidCallback onGranted;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final engine = ref.read(restrictionEngineProvider);
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final isGranted = permissions.isAuthorized;

    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.s24),
            decoration: BoxDecoration(
              color: isGranted
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.security,
                  size: 64,
                  color: isGranted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                Gap.h12,
                Text(
                  isGranted ? 'Permissions granted' : 'Permission required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Gap.h24,
          Text(
            'Why we need this',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap.h12,
          Text(
            isIOS
                ? 'We use Screen Time to temporarily shield distracting apps during your focus session.'
                : isAndroid
                    ? 'We use an Accessibility Service to detect which app is open and show a blocking screen for non-allowed apps.'
                    : 'This platform may have limited app blocking support.',
            style: theme.textTheme.bodyMedium,
          ),
          Gap.h16,
          InfoBanner(
            tone: InfoBannerTone.neutral,
            title: 'Your privacy is protected',
            message: isIOS
                ? 'We never see which apps you use. Apple handles all Screen Time enforcement privately on your device.'
                : 'The app only checks which app is in the foreground. No data leaves your device.',
          ),
          Gap.h16,
          if (!isGranted) ...[
            // Show what to do
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIOS ? 'What to do' : 'What to do',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap.h8,
                    Text(
                      isIOS
                          ? '1. Tap "Grant permission" below\n2. Allow Screen Time access when prompted'
                          : '1. Tap "Grant permission" below\n2. Find "Win the Year Focus Service" in the list\n3. Toggle it ON\n4. Tap the back button to return here',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Actions
          if (isGranted) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGranted,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await engine.requestPermissions();
                  ref.invalidate(restrictionPermissionsProvider);
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Grant permission'),
              ),
            ),
            Gap.h12,
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  // Re-check permissions (user might have granted via settings)
                  ref.invalidate(restrictionPermissionsProvider);
                },
                child: const Text('I already did this'),
              ),
            ),
          ],
          Gap.h8,
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 3: Ready to go!
class _ReadyStep extends ConsumerStatefulWidget {
  const _ReadyStep({
    required this.permissionsGranted,
    required this.onComplete,
    required this.onBack,
  });

  final bool permissionsGranted;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  @override
  ConsumerState<_ReadyStep> createState() => _ReadyStepState();
}

class _ReadyStepState extends ConsumerState<_ReadyStep> {
  bool _creatingPolicy = false;

  Future<void> _ensureDefaultPolicy() async {
    final policies = ref.read(focusPolicyListProvider).valueOrNull ?? [];
    if (policies.isNotEmpty) return;

    setState(() => _creatingPolicy = true);

    try {
      await ref.read(focusPolicyListProvider.notifier).createDefaultPolicy();
    } finally {
      if (mounted) {
        setState(() => _creatingPolicy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _StepContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success celebration
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.s32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.5),
                  theme.colorScheme.secondaryContainer.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.rocket_launch,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                Gap.h16,
                Text(
                  'You\'re all set!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Gap.h24,
          Text(
            'Setup complete',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap.h16,
          // Status checklist
          _ChecklistItem(
            isComplete: widget.permissionsGranted,
            title: 'Permissions granted',
            subtitle: widget.permissionsGranted
                ? 'App blocking is ready'
                : 'Limited functionality without permissions',
          ),
          Gap.h24,
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      Gap.w8,
                      Text(
                        'Tip',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Gap.h8,
                  Text(
                    'Start with a short 15-25 minute session to see how it feels. You can adjust friction settings later.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          Gap.h16,
          Text(
            'Tap "Start focusing" to create your default focus policy. Then go to Focus → Policies and choose the apps to block.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _creatingPolicy
                  ? null
                  : () async {
                      await _ensureDefaultPolicy();
                      widget.onComplete();
                    },
              icon: _creatingPolicy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_creatingPolicy ? 'Setting up...' : 'Start focusing'),
            ),
          ),
          Gap.h8,
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Container for each step with consistent padding and scrolling.
class _StepContainer extends StatelessWidget {
  const _StepContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

/// A benefit row with icon, title, and description.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.s8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap.h4,
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A checklist item showing completion status.
class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.isComplete,
    required this.title,
    required this.subtitle,
  });

  final bool isComplete;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.circle_outlined,
          size: 24,
          color: isComplete
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
