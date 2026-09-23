// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/main.dart';
import 'package:vistec/views/form_screen.dart';
import 'package:vistec/models/sticker_model.dart';

void main() {
  testWidgets('VistecApp loads welcome screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VistecApp());

    // Verify that the welcome screen actions and password field are present
    expect(find.text('Mis proyectos'), findsOneWidget);
    expect(find.text('Buscar proyectos'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Enter VGL into password field - auto-navigates to FormScreen
    await tester.enterText(find.byType(TextField), 'VGL');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify navigation to FormScreen
    expect(find.byType(FormScreen), findsOneWidget);
  });

  test('TechnicalCatalogMatrix deduces prioritized tools and accessories', () {
    final accessories = TechnicalCatalogMatrix.deduceAccesorios(
      materiales: ['CANALETAS', 'TUBO EMT'],
    );
    expect(accessories, isNotEmpty);
    expect(accessories.contains('Codos planos para canaleta'), isTrue);
    expect(accessories.contains('Conectores EMT rectos'), isTrue);

    final tools = TechnicalCatalogMatrix.deduceHerramientas(
      estructuras: ['CONCRETO', 'DRYWALL'],
      materiales: ['CANALETAS'],
    );
    expect(tools, isNotEmpty);
    expect(tools.contains('Rotomartillo SDS Plus / Max'), isTrue);
    expect(tools.contains('Tijera cortacanaletas / Ingletadora'), isTrue);
  });
}
