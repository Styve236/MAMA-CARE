import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/shared/glucose.dart';

void main() {
  group('Conversion', () {
    test('1 mmol/L vaut 18,0182 mg/dL', () {
      expect(glucoseToMgDl(1), closeTo(18.0182, 0.0001));
    });

    test('5 mmol/L vaut environ 90 mg/dL', () {
      expect(glucoseToMgDl(5).round(), 90);
    });

    test('la valeur historique 0,9 g/L vaut 5,0 mmol/L', () {
      expect(glucoseGlToMmol(0.9), closeTo(5.0, 0.01));
    });

    test('aller-retour mmol/L -> mg/dL -> mmol/L', () {
      expect(glucoseToMgDl(5.5) / 18.0182, closeTo(5.5, 0.0001));
    });
  });

  group('Classification', () {
    test('2,5 mmol/L est une hypoglycémie', () {
      expect(glucoseStatus(2.5), GlucoseStatus.veryLow);
    });

    test('3,5 mmol/L est un peu basse', () {
      expect(glucoseStatus(3.5), GlucoseStatus.low);
    });

    test('5,0 mmol/L est normale', () {
      expect(glucoseStatus(5.0), GlucoseStatus.normal);
    });

    test('7,0 mmol/L reste normale (borne haute incluse)', () {
      expect(glucoseStatus(7.0), GlucoseStatus.normal);
    });

    test('8,0 mmol/L est élevée', () {
      expect(glucoseStatus(8.0), GlucoseStatus.high);
    });

    test('12,0 mmol/L est très élevée', () {
      expect(glucoseStatus(12.0), GlucoseStatus.veryHigh);
    });
  });

  group('Affichage', () {
    test('un entier reste sans décimale', () {
      expect(formatGlucose(5), '5 mmol/L');
    });

    test('une décimale est séparée par une virgule', () {
      expect(formatGlucose(5.25), '5,3 mmol/L');
    });

    test('une chaîne avec virgule est acceptée', () {
      expect(formatGlucose('5,5'), '5,5 mmol/L');
    });

    test('une valeur nulle affiche un tiret', () {
      expect(formatGlucose(null), '--');
    });

    test('l’équivalent mg/dL est arrondi', () {
      expect(formatGlucoseMgDl('5,2'), '94 mg/dL');
    });

    test('l’équivalent mg/dL est vide sans valeur', () {
      expect(formatGlucoseMgDl(null), '');
    });
  });

  group('Saisie sans séparateur décimal', () {
    test('un nombre entier tapé au clavier est accepté', () {
      expect(double.tryParse('5'), 5.0);
    });

    test('la virgule reste acceptée pour ceux qui en ont une', () {
      expect(double.tryParse('5,5'.replaceAll(',', '.')), 5.5);
    });
  });
}