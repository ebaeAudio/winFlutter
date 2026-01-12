import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/errors.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import 'feedback_models.dart';
import 'feedback_submitter.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.entryPoint,
  });

  final String? entryPoint;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _detailsController = TextEditingController();

  FeedbackKind _kind = FeedbackKind.bug;
  bool _includeContext = true;

  bool _submitting = false;
  bool _submitted = false;

  static const int _descriptionSoftLimit = 280;
  static const int _detailsSoftLimit = 2000;

  @override
  void dispose() {
    _descriptionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  String? _validateDescription(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Add a short description.';
    if (raw.length < 10) return 'Add a bit more detail (at least 10 characters).';

    final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return 'Use a couple of words so we can triage it.';

    return null;
  }

  String _guidanceText() {
    return switch (_kind) {
      FeedbackKind.bug =>
        'Include what you expected, what happened, and how to reproduce it.',
      FeedbackKind.improvement =>
        'Describe what you’re trying to do and what a better experience would look like.',
    };
  }

  String _privacyText() {
    return 'We only send what you type. If you enable context, we also include app version, OS, locale, and a timestamp. No screenshots or personal data are captured automatically.';
  }

  String _friendlySubmitError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('connection timed out')) {
      return 'You appear to be offline. Try again later.';
    }
    return friendlyError(e);
  }

  Future<void> _submit() async {
    final submitter = ref.read(feedbackSubmitterProvider);
    if (submitter == null) {
      await showErrorDialog(
        context,
        title: 'Feedback unavailable',
        error: StateError('Feedback submission not configured'),
        message:
            'Feedback submission isn’t available in demo mode or before Supabase is configured.',
        includeRawDetails: false,
      );
      return;
    }

    final valid = _formKey.currentState?.validate() == true;
    if (!valid) return;

    setState(() => _submitting = true);
    try {
      await submitter.submit(
        FeedbackDraft(
          kind: _kind,
          description: _descriptionController.text,
          details: _detailsController.text,
          entryPoint: widget.entryPoint,
          includeContext: _includeContext,
        ),
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlySubmitError(e))),
      );
    }
  }

  void _reset() {
    _descriptionController.clear();
    _detailsController.clear();
    setState(() {
      _kind = FeedbackKind.bug;
      _includeContext = true;
      _submitted = false;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = !_submitting && !_submitted;

    return AppScaffold(
      title: 'Feedback',
      children: [
        Text(
          'Help improve the app',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Gap.h8,
        Text(
          'Send a bug report or a product idea. Keep it short — we’ll follow up only if we need more details.',
          style: theme.textTheme.bodyMedium,
        ),
        Gap.h16,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: _submitted
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sent',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Gap.h8,
                      const Text(
                        'Thanks — your feedback helps us prioritize what to fix and build next.',
                      ),
                      Gap.h16,
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Done'),
                            ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: FilledButton(
                              onPressed: _reset,
                              child: const Text('Send another'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Type'),
                        SegmentedButton<FeedbackKind>(
                          segments: [
                            ButtonSegment(
                              value: FeedbackKind.bug,
                              label: Text(FeedbackKind.bug.label),
                              icon: const Icon(Icons.bug_report_outlined),
                            ),
                            ButtonSegment(
                              value: FeedbackKind.improvement,
                              label: Text(FeedbackKind.improvement.label),
                              icon: const Icon(Icons.auto_awesome_outlined),
                            ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (set) {
                            setState(() => _kind = set.first);
                          },
                        ),
                        Gap.h12,
                        Text(
                          _guidanceText(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Gap.h16,
                        const SectionHeader(title: 'Short description'),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: canSubmit,
                          validator: _validateDescription,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: _descriptionSoftLimit,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          decoration: const InputDecoration(
                            hintText: 'Example: Tasks sometimes duplicate when I tap Save.',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        Gap.h12,
                        const SectionHeader(title: 'Optional details'),
                        TextFormField(
                          controller: _detailsController,
                          enabled: canSubmit,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: _detailsSoftLimit,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          decoration: const InputDecoration(
                            hintText:
                                'Steps to reproduce, what you were doing, or any extra context.',
                          ),
                        ),
                        Gap.h16,
                        const SectionHeader(title: 'Context'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _includeContext,
                          onChanged: canSubmit
                              ? (v) => setState(() => _includeContext = v)
                              : null,
                          title: const Text('Include app context'),
                          subtitle: Text(_privacyText()),
                        ),
                        Gap.h16,
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: canSubmit
                                    ? () => Navigator.of(context).maybePop()
                                    : null,
                                child: const Text('Cancel'),
                              ),
                            ),
                            Gap.w12,
                            Expanded(
                              child: FilledButton(
                                onPressed: canSubmit ? _submit : null,
                                child: _submitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Send'),
                              ),
                            ),
                          ],
                        ),
                        if ((widget.entryPoint ?? '').trim().isNotEmpty) ...[
                          Gap.h12,
                          Text(
                            'Entry point: ${widget.entryPoint}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

