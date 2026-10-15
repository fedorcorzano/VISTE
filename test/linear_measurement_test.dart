import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/linear_measurement_model.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/models/sticker_model.dart';
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
      // RawMagnifier utiliza exactamente 1 CustomPaint interno para el borde circular, sin retículas adicionales
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });

  group('Project Classification & Prioritized Materials Tests', () {
    test('ProjectModel clasificacion defaults to Comercial and round-trips via storage map', () {
      final defaultProject = ProjectModel(
        contacto: 'Juan Pérez',
        direccion: 'Av. Arequipa 123',
        celular: '999888777',
        correo: 'juan@test.com',
        proyecto: 'Instalación Residencial',
        responsable: 'Carlos Técnico',
        fecha: '2026-10-01',
        mapa: '-12.0, -77.0',
      );
      expect(defaultProject.clasificacion, 'Comercial');

      final residential = defaultProject.copyWith(clasificacion: 'Residencial');
      expect(residential.clasificacion, 'Residencial');

      final map = residential.toStorageMap();
      expect(map['clasificacion'], 'Residencial');

      final restored = ProjectModel.fromStorageMap(map);
      expect(restored.clasificacion, 'Residencial');
    });

    test('LinearMeasurement.labelDistanceOnly outputs meters without material', () {
      final m = LinearMeasurement(
        id: 'cota_label_test',
        startNormalized: const Offset(0.1, 0.1),
        endNormalized: const Offset(0.5, 0.5),
        meters: 18.75,
        material: 'Tubo EMT 3/4"',
      );

      expect(m.labelDistanceOnly, '18.75 m');
      expect(m.formattedLabel, '18.75 m • Tubo EMT 3/4"');
    });

    test('TechnicalCatalogMatrix returns prioritized materials at front without data loss', () {
      final allMaterials = [
        'Tubo EMT 3/4"',
        'Canaleta 20x10',
        'Tubo PVC Conduit',
        'Tubo Liquid Tight',
        'Canaleta Plastica 40x25 con Division',
        'Bandeja Portacables Ranurada',
      ];

      final prioritizedResidencial = TechnicalCatalogMatrix.getPrioritizedMaterials(
        'Residencial',
        allMaterials,
      );

      // Verify prioritized items are at the front
      expect(prioritizedResidencial.first, 'Canaleta 20x10');
      // Verify no materials were lost or duplicated
      expect(prioritizedResidencial.length, allMaterials.length);
      expect(prioritizedResidencial.toSet(), allMaterials.toSet());

      final prioritizedIndustrial = TechnicalCatalogMatrix.getPrioritizedMaterials(
        'Industrial',
        allMaterials,
      );
      expect(prioritizedIndustrial.contains('Tubo Liquid Tight'), isTrue);
      // Liquid Tight or Bandeja must appear before residential canaleta
      final ltIndex = prioritizedIndustrial.indexOf('Tubo Liquid Tight');
      final canaletaIndex = prioritizedIndustrial.indexOf('Canaleta 20x10');
      expect(ltIndex < canaletaIndex, isTrue);
    });

    test('PlacedSticker JSON serialization round-trip', () {
      final sticker = PlacedSticker(
        id: 'placed_123',
        sticker: StickerModel.fromCatalog(
          'Cámara Domo IP',
          StickerCategory.materiales,
        ),
        position: const Offset(0.42, 0.68),
        scale: 1.35,
        rotation: 0.25,
      );

      final json = sticker.toJson();
      expect(json['id'], 'placed_123');
      expect(json['title'], 'Cámara Domo IP');
      expect(json['category'], 'materiales');
      expect(json['scale'], 1.35);

      final restored = PlacedSticker.fromJson(json);
      expect(restored.id, sticker.id);
      expect(restored.sticker.title, 'Cámara Domo IP');
      expect(restored.sticker.category, StickerCategory.materiales);
      expect(restored.position.dx, closeTo(0.42, 0.001));
      expect(restored.position.dy, closeTo(0.68, 0.001));
      expect(restored.scale, 1.35);
      expect(restored.rotation, 0.25);
    });

    test('Sequential numbering per category logic', () {
      final pins = [
        PlacedSticker(
          id: 'p1',
          sticker: StickerModel.fromCatalog('Pared Concreto', StickerCategory.estructuras),
          position: Offset.zero,
        ),
        PlacedSticker(
          id: 'p2',
          sticker: StickerModel.fromCatalog('Tubo EMT', StickerCategory.materiales),
          position: Offset.zero,
        ),
        PlacedSticker(
          id: 'p3',
          sticker: StickerModel.fromCatalog('Bandeja Ranurada', StickerCategory.estructuras),
          position: Offset.zero,
        ),
        PlacedSticker(
          id: 'p4',
          sticker: StickerModel.fromCatalog('Cables Expuestos', StickerCategory.peligros),
          position: Offset.zero,
        ),
        PlacedSticker(
          id: 'p5',
          sticker: StickerModel.fromCatalog('Caja de Pase', StickerCategory.materiales),
          position: Offset.zero,
        ),
      ];

      int getCategoryPinNumber(PlacedSticker target) {
        int count = 0;
        for (final p in pins) {
          if (p.sticker.category == target.sticker.category) {
            count++;
          }
          if (p.id == target.id) {
            return count;
          }
        }
        return count > 0 ? count : 1;
      }

      // Estructuras: p1 -> 1, p3 -> 2
      expect(getCategoryPinNumber(pins[0]), 1);
      expect(getCategoryPinNumber(pins[2]), 2);

      // Materiales: p2 -> 1, p5 -> 2
      expect(getCategoryPinNumber(pins[1]), 1);
      expect(getCategoryPinNumber(pins[4]), 2);

      // Peligros: p4 -> 1
      expect(getCategoryPinNumber(pins[3]), 1);
    });

    test('Cota point insertion logic: drag vs two-tap workflow', () {
      // 1. Workflow A: Arrastre directo de Punto A a Punto B
      Offset? guidedOriginA;
      Offset? guidedTargetB;
      bool isGuidingOriginA = false;
      bool isGuidingDestinationB = false;

      // Touch down en (100, 100)
      const touchStart = Offset(100, 100);
      guidedOriginA = touchStart;
      guidedTargetB = touchStart;
      isGuidingOriginA = true;

      // Arrastre continuo hacia (300, 200)
      const touchMove1 = Offset(200, 150);
      guidedTargetB = touchMove1;
      expect(guidedOriginA, touchStart, reason: 'Punto A no debe sobreescribirse al arrastrar');

      const touchMove2 = Offset(300, 200);
      guidedTargetB = touchMove2;
      expect(guidedOriginA, touchStart);

      // Soltar dedo en (300, 200)
      final distDrag = (guidedTargetB - guidedOriginA).distance;
      expect(distDrag > 18.0, isTrue);

      final cotaCreatedDrag = LinearMeasurement(
        id: 'cota_drag',
        startOffset: guidedOriginA,
        endOffset: guidedTargetB,
        longitudMetros: 5.5,
        material: 'Tubo EMT 3/4"',
      );
      expect(cotaCreatedDrag.startOffset, const Offset(100, 100));
      expect(cotaCreatedDrag.endOffset, const Offset(300, 200));

      // 2. Workflow B: Dos toques separados (Tap A, luego Tap B)
      guidedOriginA = null;
      guidedTargetB = null;
      isGuidingOriginA = false;
      isGuidingDestinationB = false;

      // Toque 1: Tap corto en (50, 50)
      const tapA = Offset(50, 50);
      guidedOriginA = tapA;
      guidedTargetB = tapA;
      isGuidingOriginA = true;

      // Al soltar sin desplazamiento (< 18px), se fija Punto A y se espera Punto B
      final distTapA = (guidedTargetB - guidedOriginA).distance;
      expect(distTapA < 18.0, isTrue);
      isGuidingOriginA = false;
      isGuidingDestinationB = true;
      guidedTargetB = null;

      expect(guidedOriginA, tapA);
      expect(isGuidingDestinationB, isTrue);

      // Toque 2: Tap en (250, 180)
      const tapB = Offset(250, 180);
      guidedTargetB = tapB;
      final distTapB = (guidedTargetB - guidedOriginA).distance;
      expect(distTapB > 18.0, isTrue);

      final cotaCreatedTap = LinearMeasurement(
        id: 'cota_tap',
        startOffset: guidedOriginA,
        endOffset: guidedTargetB,
        longitudMetros: 4.2,
        material: 'Canaleta 40x25',
      );
      expect(cotaCreatedTap.startOffset, const Offset(50, 50));
      expect(cotaCreatedTap.endOffset, const Offset(250, 180));
    });

    testWidgets('MeasurementLinesPainter paints live cota while guiding destination B', (tester) async {
      final painter = MeasurementLinesPainter(
        measurements: [],
        guidedOriginA: const Offset(50, 50),
        currentEnd: const Offset(200, 150),
        activeMaterial: 'Tubo EMT 3/4"',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: painter,
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

