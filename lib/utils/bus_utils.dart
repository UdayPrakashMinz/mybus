String formatBusLabel({required String? name, dynamic number}) {
  final nStr = (number ?? '').toString();
  final parsed = int.tryParse(nStr.replaceAll(RegExp(r'[^0-9]'), ''));
  final numPart = (parsed != null && parsed > 0)
      ? ' #${parsed.toString().padLeft(2, '0')}'
      : '';
  final base = (name ?? '').toString();
  if (base.isEmpty) return numPart.isNotEmpty ? numPart.trim() : 'Unknown';
  return base + numPart;
}
