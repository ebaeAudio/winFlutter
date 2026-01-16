import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

import 'nfc_models.dart';

class NfcService {
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    return NfcManager.instance.isAvailable();
  }

  Future<void> startSession({
    required void Function(NfcScanResult) onResult,
    required void Function(String) onError,
  }) async {
    if (kIsWeb) {
      onError('NFC scanning is not supported on web.');
      return;
    }

    try {
      await NfcManager.instance.startSession(
        invalidateAfterFirstRead: true,
        onDiscovered: (tag) async {
          try {
            final result = _decodeTag(tag);
            await _stopSessionSafely();
            onResult(result);
          } catch (e) {
            await _stopSessionSafely(
              errorMessage: e.toString(),
            );
            onError(e.toString());
          }
        },
        onError: (error) async {
          if (error.type == NfcErrorType.userCanceled) return;
          await _stopSessionSafely(errorMessage: error.message);
          onError(_formatNfcError(error));
        },
      );
    } catch (e) {
      onError('Failed to start NFC scan: $e');
    }
  }

  Future<void> stopSession() async {
    await _stopSessionSafely();
  }

  Future<void> _stopSessionSafely({String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(errorMessage: errorMessage);
    } catch (_) {
      // Best-effort; session may already be closed.
    }
  }

  NfcScanResult _decodeTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      throw Exception('Tag is not NDEF formatted.');
    }

    final sanitizedTag = NfcJsonEncoder.sanitizeMap(tag.data);
    final rawJson = NfcJsonEncoder.prettyPrint(sanitizedTag);
    final message = ndef.cachedMessage;
    final records = message?.records.map(_decodeRecord).toList() ?? [];

    return NfcScanResult(
      scannedAt: DateTime.now(),
      tag: sanitizedTag,
      decodedRecords: records,
      rawTagJson: rawJson,
    );
  }

  NdefDecodedRecord _decodeRecord(NdefRecord record) {
    final payload = record.payload;
    final typeBytes = record.type;
    final idBytes = record.identifier;

    final tnfLabel = _tnfLabel(record.typeNameFormat);
    final typeLabel = NfcHexCodec.asciiOrHex(typeBytes);
    final idLabel = NfcHexCodec.encode(idBytes);
    final payloadHex = NfcHexCodec.encode(payload);

    String? text;
    String? uri;
    String? mimeType;
    String? externalType;

    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        typeBytes.length == 1 &&
        typeBytes[0] == 0x54) {
      text = _decodeWellKnownText(payload);
    } else if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        typeBytes.length == 1 &&
        typeBytes[0] == 0x55) {
      uri = _decodeWellKnownUri(payload);
    } else if (record.typeNameFormat == NdefTypeNameFormat.media) {
      mimeType = NfcHexCodec.asciiOrHex(typeBytes);
    } else if (record.typeNameFormat == NdefTypeNameFormat.nfcExternal) {
      externalType = NfcHexCodec.asciiOrHex(typeBytes);
    }

    return NdefDecodedRecord(
      tnf: tnfLabel,
      type: typeLabel,
      id: idLabel,
      payloadHex: payloadHex,
      text: text,
      uri: uri,
      mimeType: mimeType,
      externalType: externalType,
    );
  }

  String _tnfLabel(NdefTypeNameFormat tnf) {
    return switch (tnf) {
      NdefTypeNameFormat.empty => 'empty',
      NdefTypeNameFormat.nfcWellknown => 'well-known',
      NdefTypeNameFormat.media => 'media',
      NdefTypeNameFormat.absoluteUri => 'absolute-uri',
      NdefTypeNameFormat.nfcExternal => 'external',
      NdefTypeNameFormat.unknown => 'unknown',
      NdefTypeNameFormat.unchanged => 'unchanged',
    };
  }

  String _decodeWellKnownText(Uint8List payload) {
    if (payload.isEmpty) return '';
    // NDEF Text RTD: status byte + language code + text.
    final status = payload[0];
    final isUtf16 = (status & 0x80) != 0;
    final langLength = status & 0x3F;
    final textStart = 1 + langLength;
    if (textStart > payload.length) return '';
    final textBytes = payload.sublist(textStart);
    if (isUtf16) {
      return _decodeUtf16(textBytes);
    }
    return String.fromCharCodes(textBytes);
  }

  String _decodeWellKnownUri(Uint8List payload) {
    if (payload.isEmpty) return '';
    // NDEF URI RTD: prefix byte + URI string.
    final prefix = _uriPrefixFor(payload[0]);
    final uriBody = payload.length > 1
        ? String.fromCharCodes(payload.sublist(1))
        : '';
    return '$prefix$uriBody';
  }

  String _decodeUtf16(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    // UTF-16 bytes may include BOM. Default to big-endian when absent.
    if (bytes.length >= 2) {
      final bom = (bytes[0] << 8) + bytes[1];
      if (bom == 0xFEFF) {
        return String.fromCharCodes(_decodeUtf16Units(bytes.sublist(2), true));
      }
      if (bom == 0xFFFE) {
        return String.fromCharCodes(_decodeUtf16Units(bytes.sublist(2), false));
      }
    }
    return String.fromCharCodes(_decodeUtf16Units(bytes, true));
  }

  List<int> _decodeUtf16Units(Uint8List bytes, bool bigEndian) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final unit = bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i];
      units.add(unit);
    }
    return units;
  }

  String _uriPrefixFor(int prefixCode) {
    const prefixes = [
      '',
      'http://www.',
      'https://www.',
      'http://',
      'https://',
      'tel:',
      'mailto:',
      'ftp://anonymous:anonymous@',
      'ftp://ftp.',
      'ftps://',
      'sftp://',
      'smb://',
      'nfs://',
      'ftp://',
      'dav://',
      'news:',
      'telnet://',
      'imap:',
      'rtsp://',
      'urn:',
      'pop:',
      'sip:',
      'sips:',
      'tftp:',
      'btspp://',
      'btl2cap://',
      'btgoep://',
      'tcpobex://',
      'irdaobex://',
      'file://',
      'urn:epc:id:',
      'urn:epc:tag:',
      'urn:epc:pat:',
      'urn:epc:raw:',
      'urn:epc:',
      'urn:nfc:',
    ];
    if (prefixCode < 0 || prefixCode >= prefixes.length) {
      return '';
    }
    return prefixes[prefixCode];
  }

  String _formatNfcError(NfcError error) {
    final base = 'NFC scan failed.';
    if (error.message.isEmpty) return base;
    return '$base ${error.message}';
  }
}
