import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../platform/nfc/nfc_models.dart';
import '../../platform/nfc/nfc_service.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/spacing.dart';

enum NfcScanStatus { idle, scanning, tagFound, error }

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen> {
  final NfcService _service = NfcService();
  NfcScanStatus _status = NfcScanStatus.idle;
  String? _error;
  NfcScanResult? _lastResult;
  bool _available = false;
  bool _checkingAvailability = false;

  @override
  void initState() {
    super.initState();
    _refreshAvailability();
  }

  Future<void> _refreshAvailability() async {
    setState(() => _checkingAvailability = true);
    final available = await _service.isAvailable();
    if (!mounted) return;
    setState(() {
      _available = available;
      _checkingAvailability = false;
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _status = NfcScanStatus.scanning;
      _error = null;
    });

    if (!_available) {
      await _refreshAvailability();
    }

    if (!_available) {
      setState(() {
        _status = NfcScanStatus.error;
        _error =
            'NFC is not available. Use a CoreNFC-capable iPhone or enable NFC on Android.';
      });
      return;
    }

    await _service.startSession(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _status = NfcScanStatus.tagFound;
          _lastResult = result;
          _error = null;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _status = NfcScanStatus.error;
          _error = message;
        });
      },
    );
  }

  Future<void> _stopScan() async {
    await _service.stopSession();
    if (!mounted) return;
    setState(() {
      _status = NfcScanStatus.idle;
    });
  }

  Future<void> _copyLastResult() async {
    final result = _lastResult;
    if (result == null) return;
    final formatted = _formatResult(result);
    await Clipboard.setData(ClipboardData(text: formatted));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan result copied.')),
    );
  }

  void _simulateResult() {
    final textPayload = Uint8List.fromList([
      0x02,
      0x65,
      0x6e,
      0x48,
      0x65,
      0x6c,
      0x6c,
      0x6f,
      0x20,
      0x4e,
      0x46,
      0x43,
    ]);
    final uriPayload = Uint8List.fromList([
      0x01,
      0x65,
      0x78,
      0x61,
      0x6d,
      0x70,
      0x6c,
      0x65,
      0x2e,
      0x63,
      0x6f,
      0x6d,
    ]);

    final fakeTag = <String, dynamic>{
      'ndef': {
        'cachedMessage': {
          'records': 2,
        },
      },
      'techs': ['Ndef', 'NfcA'],
      'id': '04a224caff12',
    };

    final fakeResult = NfcScanResult(
      scannedAt: DateTime.now(),
      tag: fakeTag,
      decodedRecords: [
        NdefDecodedRecord(
          tnf: 'well-known',
          type: 'T',
          id: '',
          payloadHex: NfcHexCodec.encode(textPayload),
          text: 'Hello NFC',
        ),
        NdefDecodedRecord(
          tnf: 'well-known',
          type: 'U',
          id: '',
          payloadHex: NfcHexCodec.encode(uriPayload),
          uri: 'http://www.example.com',
        ),
      ],
      rawTagJson: NfcJsonEncoder.prettyPrint(fakeTag),
    );

    setState(() {
      _status = NfcScanStatus.tagFound;
      _lastResult = fakeResult;
      _error = null;
    });
  }

  String _formatResult(NfcScanResult result) {
    final lines = <String>[
      'Scanned at: ${result.scannedAt.toIso8601String()}',
      'Status: ${_statusLabel(NfcScanStatus.tagFound)}',
      '',
      'Tag:',
      result.rawTagJson,
      '',
      'Records:',
    ];

    if (result.decodedRecords.isEmpty) {
      lines.add('Empty NDEF message.');
    } else {
      for (var i = 0; i < result.decodedRecords.length; i += 1) {
        final record = result.decodedRecords[i];
        lines.add('Record ${i + 1}');
        lines.add('  TNF: ${record.tnf}');
        lines.add('  Type: ${record.type}');
        lines.add('  Id: ${record.id}');
        lines.add('  Payload (hex): ${record.payloadHex}');
        if (record.text != null) lines.add('  Text: ${record.text}');
        if (record.uri != null) lines.add('  URI: ${record.uri}');
        if (record.mimeType != null) lines.add('  MIME: ${record.mimeType}');
        if (record.externalType != null) {
          lines.add('  External: ${record.externalType}');
        }
      }
    }

    return lines.join('\n');
  }

  String _statusLabel(NfcScanStatus status) {
    return switch (status) {
      NfcScanStatus.idle => 'Idle',
      NfcScanStatus.scanning => 'Scanning',
      NfcScanStatus.tagFound => 'Tag Found',
      NfcScanStatus.error => 'Error',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = _lastResult;

    return AppScaffold(
      title: 'NFC Scan',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        ),
        Gap.h8,
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _status == NfcScanStatus.scanning ? null : _startScan,
                child: const Text('Start Scan'),
              ),
            ),
            Gap.w12,
            Expanded(
              child: OutlinedButton(
                onPressed: _status == NfcScanStatus.scanning ? _stopScan : null,
                child: const Text('Stop Scan'),
              ),
            ),
          ],
        ),
        Gap.h12,
        Row(
          children: [
            Icon(
              _status == NfcScanStatus.error
                  ? Icons.error_outline
                  : Icons.nfc,
              color: _status == NfcScanStatus.error ? cs.error : cs.primary,
            ),
            Gap.w12,
            Expanded(
              child: Text(
                _statusLabel(_status),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_checkingAvailability)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                _available ? 'NFC available' : 'NFC unavailable',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _available ? cs.primary : cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          Gap.h8,
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
        ],
        Gap.h16,
        Row(
          children: [
            Expanded(
              child: Text(
                'Scan Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: result == null ? null : _copyLastResult,
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
        Gap.h8,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: SizedBox(
              height: AppSpace.s32 * 8,
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: result == null
                      ? Text(
                          'No scan result yet. Tap “Start Scan” and hold an NTAG215 near the top of your phone.',
                          style: theme.textTheme.bodyMedium,
                        )
                      : _buildResultDetails(result),
                ),
              ),
            ),
          ),
        ),
        if (kDebugMode) ...[
          Gap.h12,
          OutlinedButton.icon(
            onPressed: _simulateResult,
            icon: const Icon(Icons.bug_report),
            label: const Text('Simulate Result'),
          ),
        ],
      ],
    );
  }

  Widget _buildResultDetails(NfcScanResult result) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scanned at: ${result.scannedAt.toLocal().toIso8601String()}',
          style: theme.textTheme.bodySmall,
        ),
        Gap.h8,
        Text(
          'Tag tech + raw data',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Gap.h4,
        SelectableText(
          result.rawTagJson,
          style: theme.textTheme.bodySmall,
        ),
        Gap.h12,
        Text(
          'NDEF records',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Gap.h8,
        if (result.decodedRecords.isEmpty)
          Text(
            'Empty NDEF message.',
            style: theme.textTheme.bodyMedium,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < result.decodedRecords.length; i += 1)
                _recordCard(result.decodedRecords[i], i + 1),
            ],
          ),
      ],
    );
  }

  Widget _recordCard(NdefDecodedRecord record, int index) {
    final theme = Theme.of(context);
    final items = <String>[
      'TNF: ${record.tnf}',
      'Type: ${record.type}',
      'Id: ${record.id.isEmpty ? '—' : record.id}',
      'Payload (hex): ${record.payloadHex.isEmpty ? '—' : record.payloadHex}',
      if (record.text != null) 'Text: ${record.text}',
      if (record.uri != null) 'URI: ${record.uri}',
      if (record.mimeType != null) 'MIME: ${record.mimeType}',
      if (record.externalType != null) 'External: ${record.externalType}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record $index',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Gap.h8,
            SelectableText(
              items.join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
