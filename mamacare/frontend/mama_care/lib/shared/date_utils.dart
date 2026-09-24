const _monthsFr = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

DateTime? _parse(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

String _pad(int n) => n.toString().padLeft(2, '0');

DateTime _local(DateTime d) => d.toLocal();

/// "24 sept. 2026 à 11:45"
String formatFullDate(Object? value) {
  final d = _parse(value);
  if (d == null) return '$value';
  final local = _local(d);
  return '${local.day} ${_monthsFr[local.month - 1]} ${local.year} à '
      '${_pad(local.hour)}:${_pad(local.minute)}';
}

/// "24/09 11:45"
String formatShortDateTime(Object? value) {
  final d = _parse(value);
  if (d == null) return '$value';
  final local = _local(d);
  return '${_pad(local.day)}/${_pad(local.month)} '
      '${_pad(local.hour)}:${_pad(local.minute)}';
}

/// "à l'instant", "il y a 5 min", "il y a 3 h", "hier", "12/09 08:00"
String timeAgo(Object? value) {
  final d = _parse(value);
  if (d == null) return '';
  final local = _local(d);
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inHours < 48) return 'hier ${_pad(local.hour)}:${_pad(local.minute)}';
  return formatShortDateTime(local);
}