import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/linear_integration_controller.dart';
import '../../../ui/spacing.dart';

class LinearIntegrationSheet extends ConsumerStatefulWidget {
  const LinearIntegrationSheet({super.key});

  @override
  ConsumerState<LinearIntegrationSheet> createState() =>
      _LinearIntegrationSheetState();
}

class _LinearIntegrationSheetState extends ConsumerState<LinearIntegrationSheet> {
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final rawKey = _keyController.text;
    
    // Check if key appears to have valid format before saving
    // (This is a quick pre-check; actual validation happens in saveApiKey)
    final trimmed = rawKey.trim();
    if (trimmed.isNotEmpty && 
        !trimmed.startsWith('lin_api_') && 
        !trimmed.startsWith('lin_oauth_')) {
      setState(() {
        _error = 'API key should start with "lin_api_" or "lin_oauth_". '
            'Make sure you copied the full key from Linear.';
        _success = null;
      });
      return;
    }
    
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await ref
          .read(linearIntegrationControllerProvider.notifier)
          .saveApiKey(rawKey);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = 'Saved. Tap "Test" to verify the connection.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await ref.read(linearIntegrationControllerProvider.notifier).clearApiKey();
      if (!mounted) return;
      _keyController.clear();
      setState(() {
        _busy = false;
        _success = 'Cleared.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _testConnection() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final viewer =
          await ref.read(linearIntegrationControllerProvider.notifier).testConnection();
      if (!mounted) return;
      setState(() {
        _busy = false;
        final who = (viewer.displayName ?? viewer.name ?? '').trim();
        _success = who.isEmpty ? 'Connected!' : 'Connected as $who!';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String friendlyError;
      if (msg.contains('401') || msg.contains('Unauthorized')) {
        friendlyError = 'Authentication failed (401). '
            'Please re-paste your API key. '
            'Tip: On iOS, try typing the key manually or use "Paste and Match Style".';
      } else if (msg.contains('400') || msg.contains('Bad Request')) {
        friendlyError = 'Invalid request (400). '
            'The API key may contain hidden characters. '
            'Try clearing and re-entering it.';
      } else if (msg.contains('SocketException') || msg.contains('ClientException')) {
        friendlyError = 'Network error. Check your internet connection.';
      } else {
        friendlyError = msg;
      }
      setState(() {
        _busy = false;
        _error = friendlyError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(linearIntegrationControllerProvider);
    final state = stateAsync.valueOrNull;

    final masked = (state?.maskedApiKey ?? '').trim();
    final hasKey = state?.hasApiKey == true;
    final lastSyncAtMs = state?.lastSyncAtMs;
    final lastSyncError = (state?.lastSyncError ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Linear',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              'Paste a Linear personal API key to enable issue previews and status sync.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h12,
            if (hasKey) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved key: $masked',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy masked',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: masked));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              Gap.h8,
            ],
            TextField(
              controller: _keyController,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Personal API key',
                hintText: 'lin_api_…',
              ),
            ),
            Gap.h4,
            Text(
              'Tip: If pasting doesn\'t work, try "Paste and Match Style" or type the key.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            Gap.h12,
            if (lastSyncAtMs != null || lastSyncError.isNotEmpty) ...[
              Text(
                lastSyncError.isNotEmpty
                    ? 'Last sync error: $lastSyncError'
                    : 'Last sync: ${DateTime.fromMillisecondsSinceEpoch(lastSyncAtMs!).toLocal()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: lastSyncError.isNotEmpty
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Gap.h8,
            ],
            if (_error != null) ...[
              SelectionArea(
                child: SelectableText(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              Gap.h8,
            ],
            if (_success != null) ...[
              Text(
                _success!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap.h8,
            ],
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: (_busy || stateAsync.isLoading) ? null : _clear,
                  child: const Text('Clear'),
                ),
                Gap.w8,
                OutlinedButton(
                  onPressed:
                      (_busy || stateAsync.isLoading || !hasKey) ? null : _testConnection,
                  child: const Text('Test'),
                ),
                Gap.w8,
                FilledButton(
                  onPressed: (_busy || stateAsync.isLoading) ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

