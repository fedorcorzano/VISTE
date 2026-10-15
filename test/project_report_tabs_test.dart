import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/views/project_summary_report_screen.dart';

void main() {
  testWidgets('ProjectSummaryReportScreen renders the 5 merged tabs in exact order and Dashboard/Gestor requirements',
      (WidgetTester tester) async {
    final project = ProjectModel(
      contacto: 'EMPRESA TEST',
      direccion: 'Av. Test 123',
      celular: '999999999',
      correo: 'test@empresa.com',
      proyecto: 'REPORTE TEST',
      fecha: '2026-10-13',
      mapa: '',
      responsable: 'Ing. Test',
    );

    final dummyPng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Header
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82
    ]);

    final session = ProjectSessionModel(project: project);
    session.photos.add(
      SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Almacén Central',
        localImagePath: '',
        pngBytes: dummyPng,
        estructuras: ['CONCRETO'],
        materiales: ['CANALETAS'],
        peligros: ['TRABAJO EN ALTURA'],
        herramientas: ['Taladro percutor'],
        accesorios: ['Codos planos para canaleta'],
        timestamp: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectSummaryReportScreen(session: session),
      ),
    );

    await tester.pump();

    // 1. Verify exact 5 tabs in order
    final tabFinder = find.byType(Tab);
    expect(tabFinder, findsNWidgets(5));

    final tabWidgets = tester.widgetList<Tab>(tabFinder).toList();
    expect(tabWidgets[0].text, equals('Dashboard/Gestor'));
    expect(tabWidgets[1].text, equals('Control SST'));
    expect(tabWidgets[2].text, equals('Almacén'));
    expect(tabWidgets[3].text, equals('Compras'));
    expect(tabWidgets[4].text, equals('Cliente SST'));

    // 2. Dashboard/Gestor tab content assertions:
    // Permanece: Sincronización en la Nube
    expect(find.textContaining('Sincronizar con Google Sheets & Drive'), findsOneWidget);

    // Permanece: Ver Tarjetas de Catálogo Visual
    final catalogTile = find.textContaining('Ver Tarjetas de Catálogo Visual');
    expect(catalogTile, findsOneWidget);
    await tester.tap(catalogTile);
    await tester.pump();
    expect(find.text('Actualizar Enlaces desde Drive'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);

    // Permanece al final: Reporte de Gestor de Proyecto (Metadata)
    expect(find.text('REPORTE DE GESTOR DE PROYECTO (METADATA)'), findsOneWidget);

    // Eliminados / Desaparecidos:
    expect(find.text('Herramientas Críticas'), findsNothing);
    expect(find.text('Materiales Clave'), findsNothing);
    expect(find.text('Base Visual de Herramientas & Materiales'), findsNothing);
    expect(find.text('Gestionar / Incorporar Fotos'), findsNothing);
    expect(find.text('Frecuencia de Herramientas en Fotos'), findsNothing);
  });
}
