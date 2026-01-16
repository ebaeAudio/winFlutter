import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../ui/components/nfc_scan_sheet.dart';
import 'nfc_card_service.dart';
import 'nfc_scan_help.dart';
import 'nfc_scan_purpose.dart';

/// Injectable interface for NFC scan flows.
///
/// This exists primarily to make the UX flows testable (pair/validate/unpair)
/// without depending on `nfc_manager` platform channels in widget tests.
abstract class NfcScanServiceBase {
  Future<String?> scanKeyHash(
    BuildContext context, {
    required NfcScanPurpose purpose,
  });
}

// We want to avoid "silent no-op" taps. On iOS, `startSession()` can fail
// (notably on the simulator), and that used to just return null with no UI.
// We still treat user-cancel as a normal exit path and show nothing.
enum _NfcScanNullReason { userCanceled, sessionStartFailed, sessionError }

class _NfcScanOutcome {
  const _NfcScanOutcome.success(this.keyHash)
      : reason = null,
        message = null;

  const _NfcScanOutcome.none(this.reason, {this.message}) : keyHash = null;

  final String? keyHash;
  final _NfcScanNullReason? reason;
  final String? message;
}

final nfcScanServiceProvider = Provider<NfcScanServiceBase>((ref) {
  return NfcScanService(ref);
});

class NfcScanService implements NfcScanServiceBase {
  NfcScanService(this._ref);

  final Ref _ref;

  void _showFailure(
    BuildContext context, {
    required String summary,
    String? details,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final hasDetails = details != null && details.trim().isNotEmpty;
    messenger.showSnackBar(
      SnackBar(
        content: Text(summary),
        action: hasDetails
            ? SnackBarAction(
                label: 'Details',
                onPressed: () async {
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('NFC scan failed'),
                      content: SingleChildScrollView(
                        child: SelectableText(details),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: details),
                            );
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Details copied.')),
                            );
                          },
                          child: const Text('Copy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  @override
  Future<String?> scanKeyHash(
    BuildContext context, {
    required NfcScanPurpose purpose,
  }) async {
    if (kIsWeb) {
      _showFailure(
        context,
        summary: 'NFC scanning isn’t supported on web.',
      );
      return null;
    }

    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      _showFailure(
        context,
        summary: isIos
            ? 'NFC isn’t available. Use a compatible iPhone (not the simulator).'
            : 'NFC isn’t available. Turn on NFC in system settings.',
        details: [
          nfcHowToScanChecklist(purpose),
          '',
          nfcTroubleshootingChecklist(purpose: purpose, platform: defaultTargetPlatform),
        ].join('\n'),
      );
      return null;
    }

    // iOS: use the native system prompt (“Ready to Scan”).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final outcome = await _scanWithSystemPrompt(purpose: purpose);
      if (outcome.keyHash != null) return outcome.keyHash;

      // Only show feedback for real failures (not user cancel).
      if (outcome.reason == _NfcScanNullReason.sessionStartFailed) {
        _showFailure(
          context,
          summary:
              'Couldn’t start NFC scan. This build may be missing the iOS “NFC Tag Reading” capability.',
          details: [
            nfcHowToScanChecklist(purpose),
            '',
            nfcTroubleshootingChecklist(
              purpose: purpose,
              platform: defaultTargetPlatform,
            ),
            if (outcome.message != null && outcome.message!.trim().isNotEmpty) ...[
              '',
              'Debug:',
              outcome.message!,
            ],
          ].join('\n'),
        );
      } else if (outcome.reason == _NfcScanNullReason.sessionError) {
        _showFailure(
          context,
          summary: 'NFC scan failed. Try again.',
          details: [
            nfcHowToScanChecklist(purpose),
            '',
            nfcTroubleshootingChecklist(
              purpose: purpose,
              platform: defaultTargetPlatform,
            ),
            if (outcome.message != null && outcome.message!.trim().isNotEmpty) ...[
              '',
              'Debug:',
              outcome.message!,
            ],
          ].join('\n'),
        );
      }
      return null;
    }

    // Android: keep our in-app sheet UX (Android doesn't provide an equivalent
    // standard system scan sheet).
    final result = await NfcScanSheet.show(context, purpose: purpose);
    return result?.keyHash;
  }

  Future<_NfcScanOutcome> _scanWithSystemPrompt({
    required NfcScanPurpose purpose,
  }) async {
    final cardSvc = _ref.read(nfcCardServiceProvider);
    final completer = Completer<_NfcScanOutcome>();

    Future<void> completeOnce(_NfcScanOutcome value) async {
      if (completer.isCompleted) return;
      completer.complete(value);
    }

    try {
      await NfcManager.instance.startSession(
        alertMessage: nfcStartAlertMessage(purpose),
        invalidateAfterFirstRead: true,
        onDiscovered: (tag) async {
          final attempt = await cardSvc.readKeyHashWithDiagnostics(tag);
          if (attempt.keyHash == null || attempt.keyHash!.isEmpty) {
            // Show an error in the native NFC popup.
            await NfcManager.instance.stopSession(
              errorMessage:
                  'Couldn’t read this tag. Try a different NFC card/tag.',
            );
            await completeOnce(
              _NfcScanOutcome.none(
                _NfcScanNullReason.sessionError,
                message: attempt.diagnostics,
              ),
            );
            return;
          }

          await NfcManager.instance.stopSession(
            alertMessage: nfcSuccessAlertMessage(purpose),
          );
          await completeOnce(_NfcScanOutcome.success(attempt.keyHash!));
        },
        onError: (error) async {
          // userCanceled is a normal exit path; do not show extra UI.
          if (error.type != NfcErrorType.userCanceled) {
            // Best-effort: if the session is still active, show a native error.
            try {
              await NfcManager.instance.stopSession(
                errorMessage: error.message,
              );
            } catch (_) {}
            await completeOnce(
              _NfcScanOutcome.none(
                _NfcScanNullReason.sessionError,
                // Don't leak overly-technical copy into UX unless we have to.
                message: [
                  'NfcErrorType: ${error.type}',
                  if (error.message.isNotEmpty) 'Message: ${error.message}',
                ].join('\n'),
              ),
            );
            return;
          }
          await completeOnce(
            const _NfcScanOutcome.none(_NfcScanNullReason.userCanceled),
          );
        },
      );
    } catch (e) {
      // If startSession fails, we can't show the native prompt. Caller will
      // treat this as "no scan".
      await completeOnce(
        _NfcScanOutcome.none(
          _NfcScanNullReason.sessionStartFailed,
          message: e.toString(),
        ),
      );
    }

    return completer.future;
  }
}

