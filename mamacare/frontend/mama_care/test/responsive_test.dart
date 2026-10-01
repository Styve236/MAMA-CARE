import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/shared/responsive.dart';

/// Tailles representatives : petits telephones, telephone courant, grand
/// telephone, tablette portrait/paysage, portable, grand ecran.
const Map<String, Size> kTestSizes = {
  'iphone-se-320x568': Size(320, 568),
  'iphone-8-375x667': Size(375, 667),
  'android-360x800': Size(360, 800),
  'iphone-pro-max-430x932': Size(430, 932),
  'ipad-portrait-768x1024': Size(768, 1024),
  'iphone-paysage-844x390': Size(844, 390),
  'ipad-paysage-1024x768': Size(1024, 768),
  'laptop-1280x800': Size(1280, 800),
  'desktop-1920x1080': Size(1920, 1080),
};

/// Enveloppe un widget dans un Scaffold et surface les overflows Flutter
/// comme des erreurs de test explicites.
Future<void> pumpAtSize(
  WidgetTester tester,
  Widget child,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('Breakpoints', () {
    test('classent correctement les tailles', () {
      expect(Breakpoints.isMobile(320), isTrue);
      expect(Breakpoints.isMobile(599), isTrue);
      expect(Breakpoints.isTablet(600), isTrue);
      expect(Breakpoints.isTablet(768), isTrue);
      expect(Breakpoints.isDesktop(900), isTrue);
      expect(Breakpoints.isDesktop(1920), isTrue);
    });

    test('gridColumns respecte min et max', () {
      expect(Breakpoints.gridColumns(300, min: 1, max: 4), 1);
      expect(Breakpoints.gridColumns(500, min: 1, max: 4), 2);
      expect(Breakpoints.gridColumns(700, min: 1, max: 4), 2);
      expect(Breakpoints.gridColumns(1000, min: 1, max: 4), 3);
      expect(Breakpoints.gridColumns(1400, min: 1, max: 4), 4);
      expect(Breakpoints.gridColumns(1400, max: 2), 2);
    });
  });

  group('ResponsiveBody ne deborde sur aucune taille', () {
    for (final entry in kTestSizes.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpAtSize(
          tester,
          const ResponsiveBody(
            child: Column(
              children: [
                Text(
                  'Un contenu suffisamment long pour forcer le retour a la '
                  'ligne sur un ecran etroit, afin de verifier que rien ne '
                  'deborde horizontalement.',
                ),
              ],
            ),
          ),
          entry.value,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ResponsiveRow empile sur mobile', () {
    testWidgets('ne deborde pas a 320px', (tester) async {
      await pumpAtSize(
        tester,
        const ResponsiveRow(
          children: [
            Card(child: SizedBox(height: 60, child: Text('A'))),
            Card(child: SizedBox(height: 60, child: Text('B'))),
            Card(child: SizedBox(height: 60, child: Text('C'))),
          ],
        ),
        const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('place les enfants en ligne sur desktop', (tester) async {
      await pumpAtSize(
        tester,
        const ResponsiveRow(
          children: [
            Card(child: SizedBox(height: 60, child: Text('A'))),
            Card(child: SizedBox(height: 60, child: Text('B'))),
          ],
        ),
        const Size(1400, 900),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Row), findsWidgets);
    });
  });

  group('ResponsiveGrid s adapte', () {
    testWidgets('1 colonne sur petit ecran, plus sur grand', (tester) async {
      await pumpAtSize(
        tester,
        ResponsiveGrid(
          children: List.generate(
            4,
            (i) => Card(child: SizedBox(height: 40, child: Text('C$i'))),
          ),
        ),
        const Size(320, 568),
      );
      expect(tester.takeException(), isNull);

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, lessThanOrEqualTo(2));
    });
  });

  group('Padding adaptatif', () {
    testWidgets('plus serre sur telephone que sur desktop', (tester) async {
      double? mobilePadding;
      await pumpAtSize(
        tester,
        Builder(
          builder: (context) {
            mobilePadding = context.pagePadding.horizontal;
            return const SizedBox.shrink();
          },
        ),
        const Size(360, 800),
      );

      double? desktopPadding;
      await pumpAtSize(
        tester,
        Builder(
          builder: (context) {
            desktopPadding = context.pagePadding.horizontal;
            return const SizedBox.shrink();
          },
        ),
        const Size(1400, 900),
      );

      expect(mobilePadding, lessThan(desktopPadding!));
    });
  });

  group('Texte long dans une Row bornee', () {
    for (final entry in kTestSizes.entries) {
      testWidgets('ne deborde pas - ${entry.key}', (tester) async {
        await pumpAtSize(
          tester,
          const ResponsiveRow(
            children: [
              FlexibleText(
                'Un libelle tres long qui doit etre tronque plutot que de '
                'provoquer un debordement de la ligne',
                maxLines: 2,
              ),
              FlexibleText('Court'),
            ],
          ),
          entry.value,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
