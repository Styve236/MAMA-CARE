const _daysFr = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _monthsFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Retourne "lundi 24 septembre 2026 à 11:45" (heure locale) à partir d'un
/// DateTime ou d'une chaîne ISO. Utilisé pour les notifications de RDV.
String formatAppointmentFr(Object? value) {
  DateTime? parsed;
  if (value is DateTime) {
    parsed = value;
  } else if (value is String) {
    parsed = DateTime.tryParse(value);
  }
  if (parsed == null) return '$value';
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${_daysFr[local.weekday - 1]} ${local.day} '
      '${_monthsFr[local.month - 1]} ${local.year} à $hh:$mm';
}