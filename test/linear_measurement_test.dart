import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/linear_measurement_model.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/services/project_manager_report_pdf_service.dart';
import 'package:vistec/services/purchasing_report_pdf_service.dart';
import 'package:vistec/services/voice_recognition_service.dart';
import 'package:vistec/widgets/measurement_overlay_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent PNG bytes for testing
  final dummyPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  group('LinearMeasurement Unit Tests', () {
    test('LinearMeasurement constructor and formatted label', () {
      final m = LinearMeasurement(
        id: 'cota_1',
        startNormalized: const Offset(0.1, 0.2),
        endNormalized: const Offset(0.5, 0.8),
        meters: 14.50,
        material: 'Tubo EMT 3/4"',
        startStructure: 'Tablero Principal',
        endStructure: 'Bandeja Portacables',
      );

      expect(m.id, 'cota_1');
      expect(m.meters, 14.50);
      expect(m.material, 'Tubo EMT 3/4"');
      expect(m.startStructure, 'Tablero Principal');
      expect(m.endStructure, 'Bandeja Portacables');
      expect(m.formattedLabel, '14.50 m • Tubo EMT 3/4"');
    });

    test('LinearMeasurement JSON serialization round-trip', () {
      final original = LinearMeasurement(
        id: 'm_test_99',
        startNormalized: const Offset(0.25, 0.35),
        endNormalized: const Offset(0.75, 0.85),
        meters: 8.25,
        material: 'Canaletas 40x25',
        startStructure: 'Pared Drywall',
        endStructure: 'Caja de Pase',
      );

      final map = original.toMap();
      final restored = LinearMeasurement.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.startNormalized.dx, closeTo(0.25, 0.0001));
      expect(restored.startNormalized.dy, closeTo(0.35, 0.0001));
      expect(restored.endNormalized.dx, closeTo(0.75, 0.0001));
      expect(restored.endNormalized.dy, closeTo(0.85, 0.0001));
      expect(restored.meters, 8.25);
      expect(restored.material, 'Canaletas 40x25');
      expect(restored.startStructure, 'Pared Drywall');
      expect(restored.endStructure, 'Caja de Pase');
    });

    test('LinearMeasurement distancePx calculation for rendering', () {
      final m = LinearMeasurement(
        id: 'cota_px',
        startNormalized: const Offset(0.0, 0.0),
        endNormalized: const Offset(0.3, 0.4), // 3-4-5 triangle
        meters: 5.0,
        material: 'Tubo PVC SAP',
      );

      const canvasSize = Size(1000, 1000);
      final pxDist = m.distancePx(canvasSize);
      // Normalized: sqrt(0.3^2 + 0.4^2) = 0.5; In 1000x1000: sqrt(300^2 + 400^2) = 500
      expect(pxDist, closeTo(500.0, 0.01));
    });
  });

  group('SessionEvidenceRecord & ProjectSessionModel Measurements Consolidation', () {
    late ProjectSessionModel session;

    setUp(() {
      final project = ProjectModel(
        contacto: 'Ing. Supervisor',
        direccion: 'Calle Las Begonias 443',
        celular: '987654321',
        correo: 'supervisor@viste.com',
        proyecto: 'Modernización Data Center',
        fecha: '2026-09-23',
        mapa: '-12.09, -77.03',
        responsable: 'Técnico de Campo',
      );

      session = ProjectSessionModel(project: project);

      // Foto 1 con 2 cotas
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Sala Servidores',
          localImagePath: '/dummy/foto1.png',
          pngBytes: dummyPng,
          measurementsPngBytes: dummyPng,
          estructuras: ['Bandeja Tipo Escalerilla', 'Riel Strut'],
          materiales: ['Tubo EMT 3/4"', 'Cable UTP Cat 6A'],
          peligros: ['Riesgo Eléctrico'],
          herramientas: ['Curvadora EMT', 'Taladro'],
          accesorios: ['Conectores EMT'],
          linearMeasurements: [
            LinearMeasurement(
              id: 'm1',
              startNormalized: const Offset(0.1, 0.1),
              endNormalized: const Offset(0.5, 0.1),
              meters: 12.0,
              material: 'Tubo EMT 3/4"',
              startStructure: 'Gabinete 1',
              endStructure: 'Gabinete 2',
            ),
            LinearMeasurement(
              id: 'm2',
              startNormalized: const Offset(0.5, 0.1),
              endNormalized: const Offset(0.8, 0.1),
              meters: 8.5,
              material: 'Tubo EMT 3/4"',
              startStructure: 'Gabinete 2',
              endStructure: 'Pared Pasante',
            ),
          ],
          timestamp: DateTime.now(),
        ),
      );

      // Foto 2 con 1 cota de diferente material
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 2,
          areaSector: 'Pasillo Distribución',
          localImagePath: '/dummy/foto2.png',
          pngBytes: dummyPng,
          measurementsPngBytes: dummyPng,
          estructuras: ['Concreto', 'Cielo Raso'],
          materiales: ['Canaletas 40x25'],
          peligros: ['Trabajo en Altura'],
          herramientas: ['Rotomartillo'],
          accesorios: ['Ángulos para canaleta'],
          linearMeasurements: [
            LinearMeasurement(
              id: 'm3',
              startNormalized: const Offset(0.2, 0.3),
              endNormalized: const Offset(0.6, 0.3),
              meters: 15.0,
              material: 'Canaletas 40x25',
              startStructure: 'Caja Distribución',
              endStructure: 'Cámara 01',
            ),
          ],
          timestamp: DateTime.now(),
        ),
      );
    });

    test('Consolidated linear meters and total meters calculation', () {
      final consolidated = session.getConsolidatedLinearMeters();

      // Tubo EMT: 12.0 + 8.5 = 20.5 m
      expect(consolidated['Tubo EMT 3/4"'], closeTo(20.5, 0.01));
      // Canaletas 40x25: 15.0 m
      expect(consolidated['Canaletas 40x25'], closeTo(15.0, 0.01));
      // Total general: 20.5 + 15.0 = 35.5 m
      expect(session.totalLinearMeters, closeTo(35.5, 0.01));

      final allM = session.getAllMeasurements();
      expect(allM.length, 3);
    });

    test('Project Manager PDF generation with dual photo pages and measurement table', () async {
      final pdfBytes = await ProjectManagerReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('Purchasing PDF generation uses real linear meters to calculate conduit tiras', () async {
      final pdfBytes = await PurchasingReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });

  group('UI / Optical Clarity Tests', () {
    testWidgets('MeasurementCaptureModal renders without overflow in constrained view', (tester) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasurementCaptureModal(
              start: const Offset(10, 10),
              end: const Offset(100, 100),
              contextualConduits: const ['Tubo EMT 3/4"'],
              voiceService: VoiceRecognitionService(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Registrar Cota de Medida'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoupeMagnifierWidget renders with external step badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                LoupeMagnifierWidget(
                  touchPosition: Offset(200, 200),
                  canvasSize: Size(400, 800),
                  label: 'ORIGEN (A)',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('ORIGEN (A)'), findsOneWidget);
      expect(find.byType(RawMagnifier), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
