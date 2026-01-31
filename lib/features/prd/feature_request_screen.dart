import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/errors.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import 'prd_providers.dart';

class FeatureRequestScreen extends ConsumerStatefulWidget {
  const FeatureRequestScreen({super.key});

  @override
  ConsumerState<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends ConsumerState<FeatureRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const int _titleMaxChars = 140;
  static const int _descriptionMaxChars = 8000;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Add a feature title.';
    if (raw.length < 4) return 'Add a bit more detail (at least 4 characters).';
    if (raw.length > _titleMaxChars) return 'Keep it under $_titleMaxChars characters.';
    return null;
  }

  String? _validateDescription(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Describe the feature request.';
    if (raw.length < 20) return 'Add a bit more detail (at least 20 characters).';
    if (raw.length > _descriptionMaxChars) {
      return 'Keep it under $_descriptionMaxChars characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() == true;
    if (!ok) return;

    final ctrl = ref.read(prdGenerationControllerProvider.notifier);
    try {
      await ctrl.generate(
        title: _titleController.text,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  void _reset() {
    _titleController.clear();
    _descriptionController.clear();
    ref.read(prdGenerationControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncResult = ref.watch(prdGenerationControllerProvider);
    final result = asyncResult.valueOrNull;

    final canSubmit = !asyncResult.isLoading && result == null;

    return AppScaffold(
      title: 'Feature request → PRD',
      children: [
        Text(
          'Turn a feature request into a PRD',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Gap.h8,
        Text(
          'This generates a markdown PRD and commits it to the repo under docs/.',
          style: theme.textTheme.bodyMedium,
        ),
        Gap.h16,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: result != null
                ? _SuccessCard(
                    result: result,
                    onCopy: () => _copy(context, result.url),
                    onOpen: () => _open(context, result.url),
                    onAnother: _reset,
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Title'),
                        TextFormField(
                          controller: _titleController,
                          enabled: canSubmit,
                          validator: _validateTitle,
                          maxLength: _titleMaxChars,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Example: Daily review checklist for Today',
                          ),
                        ),
                        Gap.h12,
                        const SectionHeader(title: 'Description'),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: canSubmit,
                          validator: _validateDescription,
                          minLines: 6,
                          maxLines: 12,
                          maxLength: _descriptionMaxChars,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          decoration: const InputDecoration(
                            hintText:
                                'Describe the problem, who it’s for, constraints, and what success looks like.',
                          ),
                        ),
                        Gap.h16,
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: canSubmit ? () => Navigator.of(context).maybePop() : null,
                                child: const Text('Cancel'),
                              ),
                            ),
                            Gap.w12,
                            Expanded(
                              child: FilledButton(
                                onPressed: canSubmit ? _submit : null,
                                child: asyncResult.isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Generate PRD'),
                              ),
                            ),
                          ],
                        ),
                        if (asyncResult.hasError) ...[
                          Gap.h12,
                          Text(
                            'Error: ${friendlyError(asyncResult.error!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
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

  static Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      await _copy(context, url);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!context.mounted) return;
        await _copy(context, url);
      }
    } catch (_) {
      if (!context.mounted) return;
      await _copy(context, url);
    }
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.result,
    required this.onCopy,
    required this.onOpen,
    required this.onAnother,
  });

  final PrdGenerationResult result;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRD created',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        Gap.h8,
        Text(
          result.path,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        Gap.h12,
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
            ),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.link),
              label: const Text('Copy link'),
            ),
            TextButton.icon(
              onPressed: onAnother,
              icon: const Icon(Icons.add),
              label: const Text('Create another'),
            ),
          ],
        ),
      ],
    );
  }
}

