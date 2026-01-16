import 'dart:convert';
import 'dart:typed_data';

class NfcScanResult {
  const NfcScanResult({
    required this.scannedAt,
    required this.tag,
    required this.decodedRecords,
    required this.rawTagJson,
  });

  final DateTime scannedAt;
  final Map<String, dynamic> tag;
  final List<NdefDecodedRecord> decodedRecords;
  final String rawTagJson;
}

class NdefDecodedRecord {
  const NdefDecodedRecord({
    required this.tnf,
    required this.type,
    required this.id,
    required this.payloadHex,
    this.text,
    this.uri,
    this.mimeType,
    this.externalType,
  });

  final String tnf;
  final String type;
  final String id;
  final String payloadHex;
  final String? text;
  final String? uri;
  final String? mimeType;
  final String? externalType;
}

class NfcJsonEncoder {
  static String prettyPrint(Map<String, dynamic> data) {
    return const JsonEncoder.withIndent('  ').convert(_sanitize(data));
  }

  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    return _sanitize(data);
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return NfcHexCodec.encode(value);
    if (value is List<int>) return NfcHexCodec.encode(Uint8List.fromList(value));
    if (value is List) return value.map(_sanitizeValue).toList();
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _sanitizeValue(val)),
      );
    }
    return value;
  }
}

class NfcHexCodec {
  static String encode(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String asciiOrHex(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final isAscii = bytes.every((b) => b >= 32 && b <= 126);
    if (isAscii) {
      return String.fromCharCodes(bytes);
    }
    return encode(bytes);
  }
}
