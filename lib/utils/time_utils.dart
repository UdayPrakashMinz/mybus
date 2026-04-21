import 'package:intl/intl.dart';

String formatTime12h(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  final value = raw.trim();
  try {
    // If already AM/PM, normalize.
    if (value.toLowerCase().contains('am') ||
        value.toLowerCase().contains('pm')) {
      final parsed = DateFormat.jm().parseLoose(value);
      return DateFormat.jm().format(parsed);
    }
    // Assume 24h like HH:mm.
    final parsed24 = DateFormat('HH:mm').parse(value);
    return DateFormat.jm().format(parsed24);
  } catch (_) {
    return value;
  }
}
