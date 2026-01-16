import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

final nfcCardServiceProvider = Provider<NfcCardService>((ref) {
  return const NfcCardService();
});

class NfcReadAttempt {
  const NfcReadAttempt({
    required this.keyHash,
    required this.diagnostics,
  });

  final String? keyHash;

  /// Human-readable debug info, safe to copy/paste.
  ///
  /// Important: this should avoid including raw tag contents/UID bytes.
  final String diagnostics;
}

class NfcCardService {
  const NfcCardService();

  /// Returns a stable SHA-256 hash (hex) for this tag.
  ///
  /// Preferred source is the first non-empty value in the tag's NDEF message.
  /// If the tag has no readable NDEF, we fall back to hashing the tag's
  /// identifier bytes (when available).
  ///
  /// Why the fallback exists:
  /// - iOS Shortcuts automations can trigger on "any NFC tag" (often by UID),
  ///   but third-party apps frequently encounter tags without NDEF content.
  /// - For Dumb Phone Mode pairing, a stable per-tag hash is sufficient.
  Future<String?> tryReadPairedKeyHashFromTag(NfcTag tag) async {
    final attempt = await readKeyHashWithDiagnostics(tag);
    return attempt.keyHash;
  }

  Future<NfcReadAttempt> readKeyHashWithDiagnostics(NfcTag tag) async {
    final lines = <String>[];
    final keys = tag.data.keys.whereType<String>().toList(growable: false);
    keys.sort();
    lines.add('Tag tech keys: ${keys.isEmpty ? '(none)' : keys.join(', ')}');

    final ndef = Ndef.from(tag);
    lines.add('NDEF: ${ndef == null ? 'not present' : 'present'}');

    if (ndef != null) {
      try {
        NdefMessage? msg = ndef.cachedMessage;
        msg ??= await ndef.read();

        final recordCount = msg.records.length;
        lines.add('NDEF records: $recordCount');
        if (recordCount > 0) {
          final types =
              msg.records.map((r) => _recordTypeLabel(r.type)).toList();
          lines.add('NDEF types: ${types.join(', ')}');
        }

        final key = extractKeyStringFromMessage(msg);
        if (key == null) {
          lines.add('Extracted key: (none)');
        } else {
          final len = utf8.encode(key.trim()).length;
          lines.add('Extracted key bytes: $len');
          final normalized = normalizeKey(key);
          if (normalized == null) {
            lines.add('Normalize: rejected (too short / low entropy)');
          } else {
            lines.add('Normalize: accepted');
            final hash = sha256HexOfUtf8(normalized);
            lines.add('Hash source: NDEF-derived string');
            return NfcReadAttempt(
              keyHash: hash,
              diagnostics: lines.join('\n'),
            );
          }
        }
      } catch (e) {
        lines.add('NDEF read error: $e');
      }
    }

    String? idSource;
    Uint8List? idBytes;

    // Try tech-key specific identifier (so diagnostics can show where it came from).
    const techKeys = <String>[
      'mifare',
      'iso7816',
      'iso15693',
      'nfca',
      'nfcb',
      'nfcf',
      'nfcv',
      'isodep',
      'mifareclassic',
      'mifareultralight',
      'ndef',
    ];
    for (final k in techKeys) {
      final v = tag.data[k];
      final bytes = _identifierBytesFromTechMap(v);
      if (bytes != null && bytes.isNotEmpty) {
        idBytes = bytes;
        idSource = k;
        break;
      }
    }

    // Fallback: top-level identifier.
    idBytes ??= _identifierBytesFromTechMap(tag.data);
    idSource ??=
        (idBytes != null && idBytes.isNotEmpty) ? 'top-level' : null;

    if (idBytes == null || idBytes.isEmpty) {
      lines.add('Identifier bytes: (none)');
      return NfcReadAttempt(keyHash: null, diagnostics: lines.join('\n'));
    }

    lines.add('Identifier bytes: ${idBytes.length} (source: $idSource)');
    final hash = sha256HexOfBytes(idBytes);
    lines.add('Hash source: tag identifier bytes');
    return NfcReadAttempt(keyHash: hash, diagnostics: lines.join('\n'));
  }

  String? extractKeyStringFromMessage(NdefMessage msg) {
    for (final record in msg.records) {
      final value = _recordToString(record);
      if (value == null) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Minimal normalization + safety: reject short/low-entropy values.
  ///
  /// Returns normalized key or null if it should be rejected.
  String? normalizeKey(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    // Require at least 16 bytes once encoded, so casual/short strings aren't accepted.
    if (utf8.encode(v).length < 16) return null;
    return v;
  }

  String sha256HexOfUtf8(String key) {
    final digest = sha256.convert(utf8.encode(key));
    return digest.toString(); // hex
  }

  String sha256HexOfBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString(); // hex
  }

  bool constantTimeEquals(String a, String b) {
    final aa = utf8.encode(a);
    final bb = utf8.encode(b);
    if (aa.length != bb.length) return false;
    var diff = 0;
    for (var i = 0; i < aa.length; i++) {
      diff |= (aa[i] ^ bb[i]);
    }
    return diff == 0;
  }

  String? _recordToString(NdefRecord r) {
    // NFC Forum RTD: Text ('T') and URI ('U') are the safest cross-platform.
    final type = r.type;
    if (type.length == 1 && type[0] == 0x54 /* 'T' */) {
      return _decodeWellKnownText(r.payload);
    }
    if (type.length == 1 && type[0] == 0x55 /* 'U' */) {
      return _decodeWellKnownUri(r.payload);
    }

    // Fallback: stable encoding of payload bytes.
    if (r.payload.isEmpty) return null;
    return base64UrlEncode(r.payload);
  }

  /// Attempts to find stable identifier bytes across the various tag technologies.
  ///
  /// `nfc_manager` exposes tag technology maps under keys like 'nfca', 'isodep',
  /// etc. Each often contains an 'identifier' field with raw bytes.
  Uint8List? tryExtractIdentifierBytes(NfcTag tag) {
    final data = tag.data;

    // Most common tech keys in nfc_manager payloads.
    const techKeys = <String>[
      // iOS CoreNFC tech keys (nfc_manager iOS translator)
      'mifare',
      'iso7816',
      'iso15693',

      'nfca',
      'nfcb',
      'nfcf',
      'nfcv',
      'isodep',
      'mifareclassic',
      'mifareultralight',
      // Sometimes the identifier is only exposed under ndef.
      'ndef',
    ];

    for (final key in techKeys) {
      final v = data[key];
      final bytes = _identifierBytesFromTechMap(v);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    // Last-resort: some platforms/plugins expose a top-level identifier.
    final top = _identifierBytesFromTechMap(data);
    if (top != null && top.isNotEmpty) return top;

    return null;
  }

  Uint8List? _identifierBytesFromTechMap(Object? v) {
    if (v is! Map) return null;
    final id = v['identifier'];
    if (id is Uint8List) return id;
    if (id is List) {
      try {
        final ints = id.whereType<int>().toList(growable: false);
        if (ints.isEmpty) return null;
        return Uint8List.fromList(ints);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _recordTypeLabel(Uint8List type) {
    if (type.length == 1 && type[0] == 0x54 /* 'T' */) return 'Text (T)';
    if (type.length == 1 && type[0] == 0x55 /* 'U' */) return 'URI (U)';
    if (type.isEmpty) return 'Unknown';
    // Best-effort: printable ASCII.
    try {
      final s = ascii.decode(type);
      final ok = s.runes.every((c) => c >= 32 && c <= 126);
      if (ok) return 'Other("$s")';
    } catch (_) {}
    return 'Other(${type.length} bytes)';
  }

  String? _decodeWellKnownText(Uint8List payload) {
    // payload: [status][langCode...][text...]
    if (payload.isEmpty) return null;
    final status = payload[0];
    final langLen = status & 0x3F;
    final isUtf16 = (status & 0x80) != 0;
    final start = 1 + langLen;
    if (start > payload.length) return null;

    final textBytes = payload.sublist(start);
    if (textBytes.isEmpty) return null;
    try {
      if (isUtf16) {
        // Best effort: decode as UTF-16BE (common in NDEF Text records).
        // If this fails, fall back to utf8.
        final bd = ByteData.sublistView(textBytes);
        final codeUnits = <int>[];
        for (var i = 0; i + 1 < bd.lengthInBytes; i += 2) {
          codeUnits.add(bd.getUint16(i, Endian.big));
        }
        return String.fromCharCodes(codeUnits);
      }
      return utf8.decode(textBytes);
    } catch (_) {
      try {
        return utf8.decode(textBytes);
      } catch (_) {
        return null;
      }
    }
  }

  String? _decodeWellKnownUri(Uint8List payload) {
    if (payload.isEmpty) return null;
    final prefixCode = payload[0];
    final rest = payload.sublist(1);
    final prefix = _uriPrefix(prefixCode);
    if (prefix == null) return null;
    try {
      return prefix + utf8.decode(rest);
    } catch (_) {
      return null;
    }
  }

  String? _uriPrefix(int code) {
    return switch (code) {
      0x00 => '',
      0x01 => 'http://www.',
      0x02 => 'https://www.',
      0x03 => 'http://',
      0x04 => 'https://',
      _ => null,
    };
  }
}

