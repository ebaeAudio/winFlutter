import 'package:intl/intl.dart';

DateTime? parseYmd(String ymd) {
  final trimmed = ymd.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('-');
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

String formatYmd(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

String friendlyYmd(String ymd) {
  final dt = parseYmd(ymd);
  if (dt == null) return ymd;
  return DateFormat('EEE, MMM d').format(dt);
}
