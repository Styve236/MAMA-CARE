/// Aide a la lecture et a la saisie de la glycemie.
///
/// L'unite du systeme est le **mmol/L**. Ce choix est volontaire : il permet
/// de saisir des nombres entiers (5) et evite donc d'avoir a taper le
/// separateur decimal au clavier, ce qui pose probleme sur certains
/// telephones.
///
/// 1 mmol/L de glucose = 18,0182 mg/dL = 0,180182 g/L.
library;

const double _mgDlPerMmol = 18.0182;
const double _glPerMmol = 0.180182;

/// Seuils de reference en mmol/L (seuils identiques a ceux du prompt IA).
const double glucoseMalaise = 3.3;
const double glucoseBasse = 3.9;
const double glucoseHaute = 7.0;
const double glucoseTresElevee = 11.1;

double glucoseToMgDl(double mmol) => mmol * _mgDlPerMmol;

/// Convertit une valeur historique stockee en g/L vers le mmol/L.
double glucoseGlToMmol(double gl) => gl / _glPerMmol;

enum GlucoseStatus { veryLow, low, normal, high, veryHigh }

GlucoseStatus glucoseStatus(double mmol) {
  if (mmol <= glucoseMalaise) return GlucoseStatus.veryLow;
  if (mmol < glucoseBasse) return GlucoseStatus.low;
  if (mmol <= glucoseHaute) return GlucoseStatus.normal;
  if (mmol < glucoseTresElevee) return GlucoseStatus.high;
  return GlucoseStatus.veryHigh;
}

String glucoseStatusLabel(GlucoseStatus status) {
  switch (status) {
    case GlucoseStatus.veryLow:
      return 'Très basse, hypoglycémie';
    case GlucoseStatus.low:
      return 'Un peu basse';
    case GlucoseStatus.normal:
      return 'Normale';
    case GlucoseStatus.high:
      return 'Élevée';
    case GlucoseStatus.veryHigh:
      return 'Très élevée';
  }
}

/// Formate une glycemie stockee en mmol/L pour l'affichage.
/// Exemple : 5.2 -> "5,2 mmol/L".
String formatGlucose(Object? value) {
  final parsed = _toDouble(value);
  if (parsed == null) return '--';
  return '${_trim(parsed)} mmol/L';
}

/// Equivalent en mg/dL, affiche pour que la patiente puisse comparer a son
/// appareil. Exemple : 5.2 -> "94 mg/dL".
String formatGlucoseMgDl(Object? value) {
  final parsed = _toDouble(value);
  if (parsed == null) return '';
  return '${glucoseToMgDl(parsed).round()} mg/dL';
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim().replaceAll(',', '.'));
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1).replaceAll('.', ',');
}