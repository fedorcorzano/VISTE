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
import 'package:vistec/services/technical_catalog_icons.dart';

void main() {
  testWidgets('VistecApp loads welcome screen smoke test and FormScreen HUD works', (WidgetTester tester) async {
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

    // Verify navigation to FormScreen with yellow #E3A51A background
    expect(find.byType(FormScreen), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, equals(const Color(0xFFE3A51A)));

    // Initially, HUD text fields are collapsed (showing only their icons)
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    // Tap the Contact HUD icon to expand it from left to right
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now the TextFormField is visible inside the expanded HUD pill
    expect(find.byType(TextFormField), findsOneWidget);
  });

  test('TechnicalCatalogIcons returns representative icons for project system types', () {
    expect(
      TechnicalCatalogIcons.getProjectSystemIcon('Cámaras de videovigilancia (CCTV)'),
      Icons.videocam_rounded,
    );
    expect(
      TechnicalCatalogIcons.getProjectSystemIcon('Control de Accesos y Asistencia'),
      Icons.fingerprint_rounded,
    );
    expect(
      TechnicalCatalogIcons.getProjectSystemIcon('Alarmas Contra Incendio (Detección)'),
      Icons.local_fire_department_rounded,
    );
    expect(
      TechnicalCatalogIcons.getProjectSystemIcon('Cableado Estructurado y Redes'),
      Icons.lan_rounded,
    );
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
