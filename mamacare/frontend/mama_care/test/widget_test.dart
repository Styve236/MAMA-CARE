// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/main.dart';

void main() {
  testWidgets('MamaCare affiche l écran de bienvenue', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MamaCareApp());

    expect(find.text('MamaCare'), findsOneWidget);
    expect(find.text('Le suivi intelligent de votre grossesse'), findsOneWidget);
  });
}
