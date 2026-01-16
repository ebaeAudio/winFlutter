import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../platform/nfc/nfc_card_service.dart';
import '../../platform/nfc/nfc_scan_help.dart';
import '../../platform/nfc/nfc_scan_purpose.dart';
import '../components/info_banner.dart';
import '../spacing.dart';

class NfcScanSheetResult {
  const NfcScanSheetResult._({
    required this.keyHash,
  });

  final String keyHash;
}

class NfcScanSheet extends ConsumerStatefulWidget {
  const NfcScanSheet({
    super.key,
    required this.purpose,
  });

  final NfcScanPurpose purpose;

  static Future<NfcScanSheetResult?> show(
    BuildContext context, {
    required NfcScanPurpose purpose,
  }) {
    assert(
      defaultTargetPlatform != TargetPlatform.iOS,
      'NfcScanSheet is an Android fallback. On iOS, use the system NFC prompt via NfcScanService.',
    );
    return showModalBottomSheet<NfcScanSheetResult?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: NfcScanSheet(purpose: purpose),
      ),
    );
  }

  @override
  ConsumerState<NfcScanSheet> createState() => _NfcScanSheetState();
}

class _NfcScanSheetState extends ConsumerState<NfcScanSheet> {
  String? _error;
  bool _scanning = false;
  bool? _available;
  String? _lastDiagnostics;

  @override
  void initState() {
    super.initState();
    // Kick off scan after first frame so the sheet is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  @override
  void dispose() {
    _stopSessionSilently();
    super.dispose();
  }

  Future<void> _stopSessionSilently() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() {
      _error = null;
      _scanning = true;
    });

    final available = await NfcManager.instance.isAvailable();
    _available = available;
    if (!available) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error =
            'NFC is not available. Turn on NFC in system settings, or use a device that supports NFC.';
      });
      return;
    }

    final svc = ref.read(nfcCardServiceProvider);

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          final attempt = await svc.readKeyHashWithDiagnostics(tag);
          if (!mounted) return;

          if (attempt.keyHash == null || attempt.keyHash!.isEmpty) {
            setState(() {
              _error =
                  'Couldn’t read this tag. Try again, or use a different NFC tag/card.';
              _lastDiagnostics = attempt.diagnostics;
            });
            await _stopSessionSilently();
            // Restart automatically after a short beat so the user can rescan.
            if (!mounted) return;
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (!mounted) return;
            setState(() => _scanning = false);
            await _startScan();
            return;
          }

          await _stopSessionSilently();
          if (!mounted) return;
          Navigator.of(context)
              .pop(NfcScanSheetResult._(keyHash: attempt.keyHash!));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Failed to start NFC scan: $e';
        _lastDiagnostics = 'Failed to start NFC scan: $e';
      });
    }
  }

  String _titleFor(NfcScanPurpose p) {
    return switch (p) {
      NfcScanPurpose.pair => 'Pair NFC card',
      NfcScanPurpose.validateStart => 'Scan card to start',
      NfcScanPurpose.validateEnd => 'Scan card to end',
      NfcScanPurpose.validateUnpair => 'Scan card to confirm unpair',
    };
  }

  String _bodyFor(NfcScanPurpose p) {
    return switch (p) {
      NfcScanPurpose.pair =>
        'Hold your card near the top of your phone. We store only a hash (not the raw tag data).',
      NfcScanPurpose.validateStart =>
        'Hold your paired card near the top of your phone to start Dumb Phone Mode.',
      NfcScanPurpose.validateEnd =>
        'Hold your paired card near the top of your phone to end Dumb Phone Mode.',
      NfcScanPurpose.validateUnpair =>
        'To unpair, scan the currently paired card.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleFor(widget.purpose),
                style: theme.textTheme.titleLarge,
              ),
              Gap.h8,
              Text(
                _bodyFor(widget.purpose),
                style: theme.textTheme.bodyMedium,
              ),
              Gap.h16,
              InfoBanner(
                title: 'How to scan',
                message: nfcHowToScanChecklist(widget.purpose),
                tone: InfoBannerTone.neutral,
              ),
              Gap.h12,
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpace.s12),
                title: const Text('Troubleshooting & debug'),
                subtitle: const Text('What to try if scanning fails'),
                children: [
                  InfoBanner(
                    title: 'Troubleshooting',
                    message: nfcTroubleshootingChecklist(
                      purpose: widget.purpose,
                      platform: defaultTargetPlatform,
                    ),
                    tone: InfoBannerTone.warning,
                  ),
                  if (_available != null || _lastDiagnostics != null) ...[
                    Gap.h12,
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Debug info',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Gap.h8,
                            SelectableText(
                              [
                                if (_available != null)
                                  'NFC available: $_available',
                                'Scanning: $_scanning',
                                if (_error != null) 'Last error: $_error',
                                if (_lastDiagnostics != null) ...[
                                  '',
                                  _lastDiagnostics!,
                                ],
                              ].join('\n'),
                              style: theme.textTheme.bodySmall,
                            ),
                            Gap.h12,
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    final text = [
                                      'NFC debug info',
                                      'Purpose: ${widget.purpose.name}',
                                      'Platform: $defaultTargetPlatform',
                                      if (_available != null)
                                        'NFC available: $_available',
                                      'Scanning: $_scanning',
                                      if (_error != null) 'Last error: $_error',
                                      if (_lastDiagnostics != null)
                                        _lastDiagnostics!,
                                    ].join('\n');
                                    await Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Debug info copied.')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy debug info'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Gap.h8,
              Row(
                children: [
                  Icon(
                    _error == null ? Icons.nfc : Icons.error_outline,
                    color: _error == null ? cs.primary : cs.error,
                  ),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      _error ??
                          (_scanning
                              ? 'Scanning…'
                              : 'Ready to scan. Tap “Try again” if needed.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: _error == null ? cs.onSurface : cs.error,
                            fontWeight:
                                _error == null ? FontWeight.w500 : FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              Gap.h16,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _stopSessionSilently();
                        if (!mounted) return;
                        Navigator.of(context).pop(null);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: FilledButton(
                      onPressed: _scanning
                          ? null
                          : () async {
                              await _startScan();
                            },
                      child: const Text('Try again'),
                    ),
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

