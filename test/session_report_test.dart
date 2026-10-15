import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/services/internal_report_pdf_service.dart';
import 'package:vistec/services/warehouse_report_pdf_service.dart';
import 'package:vistec/services/purchasing_report_pdf_service.dart';
import 'package:vistec/services/client_report_pdf_service.dart';
import 'package:vistec/services/project_manager_report_pdf_service.dart';
import 'package:vistec/services/catalog_visual_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectSessionModel and Frequency Tests', () {
    late ProjectSessionModel session;

    setUp(() {
      final project = ProjectModel(
        contacto: 'Juan Pérez',
        direccion: 'Av. Industrial 450',
        celular: '999888777',
        correo: 'juan@empresa.com',
        proyecto: 'Planta Industrial Central',
        fecha: '2026-09-14',
        mapa: '-12.046374, -77.042793',
        responsable: 'Carlos Supervisor',
      );

      session = ProjectSessionModel(project: project);

      // Foto 1: Fachada Principal (Concreto + Tubo EMT)
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Fachada Principal',
          localImagePath: '/dummy/path1.png',
          pngBytes: Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Header
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
          ]),
          estructuras: ['Concreto'],
          materiales: ['Tubo EMT'],
          peligros: ['Trabajo en Altura'],
          herramientas: [
            'Rotomartillo SDS Plus / Max',
            'Doblador de tubo EMT (Hickey / Curvadora)',
          ],
          accesorios: ['Conectores EMT rectos', 'Uniones EMT'],
          timestamp: DateTime.now(),
        ),
      );

      // Foto 2: Pasadizo Eléctrico (Concreto + Tubo EMT + Canaletas)
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 2,
          areaSector: 'Pasadizo Eléctrico',
          localImagePath: '/dummy/path2.png',
          pngBytes: Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
          ]),
          estructuras: ['Concreto', 'Drywall'],
          materiales: ['Tubo EMT', 'Canaletas'],
          peligros: ['Riesgo Eléctrico'],
          herramientas: [
            'Rotomartillo SDS Plus / Max',
            'Doblador de tubo EMT (Hickey / Curvadora)',
            'Tijera cortacanaletas / Ingletadora',
          ],
          accesorios: [
            'Conectores EMT rectos',
            'Codos planos para canaleta',
          ],
          timestamp: DateTime.now(),
        ),
      );

      // Foto 3: Almacén Secundario (Drywall + Canaletas)
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 3,
          areaSector: 'Almacén Secundario',
          localImagePath: '/dummy/path3.png',
          pngBytes: Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
          ]),
          estructuras: ['Drywall'],
          materiales: ['Canaletas'],
          peligros: [],
          herramientas: [
            'Tijera cortacanaletas / Ingletadora',
            'Atornillador inalámbrico para drywall',
          ],
          accesorios: ['Codos planos para canaleta', 'Uniones para canaleta'],
          timestamp: DateTime.now(),
        ),
      );
    });

    test('Total photos in session is correct', () {
      expect(session.totalPhotos, equals(3));
    });

    test('Tools frequency and indispensable classification', () {
      final tools = session.getToolsWithFrequency();
      expect(tools, isNotEmpty);

      // Rotomartillo SDS: presente en Foto 1 y 2 (2 de 3 fotos = 66.6%) -> INDISPENSABLE
      final rotomartillo = tools.firstWhere((t) => t.name == 'Rotomartillo SDS Plus / Max');
      expect(rotomartillo.count, equals(2));
      expect(rotomartillo.percentage, closeTo(66.6, 0.5));
      expect(rotomartillo.isIndispensable, isTrue);
      expect(rotomartillo.priorityLabel, equals('INDISPENSABLE / CRÍTICO'));

      // Doblador EMT: presente en Foto 1 y 2 (2 de 3 fotos = 66.6%) -> INDISPENSABLE
      final doblador = tools.firstWhere((t) => t.name == 'Doblador de tubo EMT (Hickey / Curvadora)');
      expect(doblador.count, equals(2));
      expect(doblador.isIndispensable, isTrue);

      // Tijera cortacanaletas: presente en Foto 2 y 3 (2 de 3 fotos) -> INDISPENSABLE
      final tijera = tools.firstWhere((t) => t.name == 'Tijera cortacanaletas / Ingletadora');
      expect(tijera.count, equals(2));
      expect(tijera.isIndispensable, isTrue);

      // Atornillador drywall: presente en solo 1 foto (Foto 3) -> 1 de 3 (33%) -> NO indispensable
      final drywallTool = tools.firstWhere((t) => t.name == 'Atornillador inalámbrico para drywall');
      expect(drywallTool.count, equals(1));
      expect(drywallTool.percentage, closeTo(33.3, 0.5));
      expect(drywallTool.isIndispensable, isFalse);
    });

    test('Materials frequency and indispensable classification', () {
      final materials = session.getMaterialsWithFrequency();
      expect(materials, isNotEmpty);

      // Tubo EMT: presente en Foto 1 y 2 -> 2 de 3 (66%) -> INDISPENSABLE
      final emt = materials.firstWhere((m) => m.name == 'Tubo EMT');
      expect(emt.count, equals(2));
      expect(emt.isIndispensable, isTrue);

      // Canaletas: presente en Foto 2 y 3 -> 2 de 3 (66%) -> INDISPENSABLE
      final canaletas = materials.firstWhere((m) => m.name == 'Canaletas');
      expect(canaletas.count, equals(2));
      expect(canaletas.isIndispensable, isTrue);
    });

    test('Consolidated accessories and hazards', () {
      final accessories = session.getConsolidatedAccessories();
      expect(accessories.contains('Conectores EMT rectos'), isTrue);
      expect(accessories.contains('Codos planos para canaleta'), isTrue);
      expect(accessories.contains('Uniones para canaleta'), isTrue);

      final hazards = session.getConsolidatedHazards();
      expect(hazards.contains('Trabajo en Altura'), isTrue);
      expect(hazards.contains('Riesgo Eléctrico'), isTrue);

      final hazardsByArea = session.getHazardsByArea();
      expect(hazardsByArea['Fachada Principal'], contains('Trabajo en Altura'));
      expect(hazardsByArea['Pasadizo Eléctrico'], contains('Riesgo Eléctrico'));
      expect(hazardsByArea.containsKey('Almacén Secundario'), isFalse);
    });

    test('WarehouseReportPdfService generates valid PDF bytes with vital tool images', () async {
      final pdfBytes = await WarehouseReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('PurchasingReportPdfService generates valid PDF bytes with executive table', () async {
      final pdfBytes = await PurchasingReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('InternalReportPdfService generates valid PDF bytes', () async {
      final pdfBytes = await InternalReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('ClientReportPdfService generates valid PDF bytes with images and SST', () async {
      final pdfBytes = await ClientReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('ClientReportPdfService generates valid PDF with cover page and preloaded satellite map', () async {
      final dummySatelliteJpg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
        0x00, 0xBF, 0x00, 0xFF, 0xD9
      ]);

      final pdfBytes = await ClientReportPdfService.generatePdf(
        session,
        preloadedSatelliteMap: dummySatelliteJpg,
      );
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('ProjectManagerReportPdfService generates valid PDF bytes with all metadata', () async {
      final pdfBytes = await ProjectManagerReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('ProjectSessionModel validation excludes items and customizes SST responsibles', () {
      final initialTools = session.getValidatedToolsWithFrequency();
      expect(initialTools.isNotEmpty, isTrue);
      final toolToExclude = initialTools.first.name;

      session.excludedTools.add(toolToExclude);
      final afterExclusion = session.getValidatedToolsWithFrequency();
      expect(afterExclusion.any((t) => t.name == toolToExclude), isFalse);

      session.customHierarchyResponsibles['eliminacion'] = 'VIGILARTE como parte del servicio';
      expect(
        session.getHierarchyResponsible('eliminacion', 'Cliente / Mantenimiento'),
        'VIGILARTE como parte del servicio',
      );
    });
  });

  group('CatalogVisualService Tests', () {
    test('setSingleItem updates memory and getItemInfo retrieves it', () {
      final item = VisualCatalogItem(
        title: 'Herramienta de Prueba 2026',
        category: 'Herramienta',
        commercialName: 'Prueba Pro Max',
        specification: 'Prueba unitaria de catálogo',
        imageUrl: 'https://example.com/foto_prueba.jpg',
        fallbackIcon: Icons.handyman,
      );

      CatalogVisualService.setSingleItem(item);

      final retrieved = CatalogVisualService.getItemInfo('Herramienta de Prueba 2026');
      expect(retrieved.commercialName, 'Prueba Pro Max');
      expect(retrieved.imageUrl, 'https://example.com/foto_prueba.jpg');
      expect(CatalogVisualService.hasRealImage('Herramienta de Prueba 2026'), isTrue);
      expect(CatalogVisualService.hasRealImage('Item Inexistente Totalmente 12345'), isFalse);

      final allItems = CatalogVisualService.getAllRegisteredItems();
      expect(allItems.any((i) => i.title == 'Herramienta de Prueba 2026'), isTrue);
    });
  });

  group('Technical Status and Image Exclusivity Tests', () {
    final samplePng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82
    ]);

    test('effectiveTechnicalStatus calculates no_apto, condicionado, apto, and manual override', () {
      // 1. Critical danger -> no_apto
      final rCritical = SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Tablero Principal',
        localImagePath: '',
        pngBytes: samplePng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: ['Riesgo Eléctrico / Tensión Viva'],
        timestamp: DateTime.now(),
      );
      expect(rCritical.effectiveTechnicalStatus, 'no_apto');

      // 2. Non-critical danger -> condicionado
      final rNonCritical = SessionEvidenceRecord(
        photoNumber: 2,
        areaSector: 'Techo Almacén',
        localImagePath: '',
        pngBytes: samplePng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: ['Trabajo en Altura'],
        timestamp: DateTime.now(),
      );
      expect(rNonCritical.effectiveTechnicalStatus, 'condicionado');

      // 3. No danger -> apto
      final rSafe = SessionEvidenceRecord(
        photoNumber: 3,
        areaSector: 'Oficina Gerencia',
        localImagePath: '',
        pngBytes: samplePng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: [],
        timestamp: DateTime.now(),
      );
      expect(rSafe.effectiveTechnicalStatus, 'apto');

      // 4. Manual override has highest precedence
      final rOverride = rCritical.copyWith(
        technicalStatus: 'condicionado',
        technicalObservation: 'Personal técnico calificado con EPP dieléctrico clase 0',
      );
      expect(rOverride.effectiveTechnicalStatus, 'condicionado');
      expect(rOverride.technicalObservation, contains('EPP dieléctrico'));
    });

    test('clientImageBytes returns clean image when no dangers or clientPngBytes when present', () {
      final sstOnlyPng = Uint8List.fromList([1, 2, 3]);
      final cleanPng = Uint8List.fromList([4, 5, 6]);

      // When clientPngBytes is set, it is returned
      final rWithSst = SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Sector 1',
        localImagePath: '',
        pngBytes: samplePng,
        clientPngBytes: sstOnlyPng,
        cleanPngBytes: cleanPng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: ['Riesgo Eléctrico'],
        timestamp: DateTime.now(),
      );
      expect(rWithSst.clientImageBytes, sstOnlyPng);

      // When clientPngBytes is null and no hazards, returns cleanPngBytes
      final rNoHazards = SessionEvidenceRecord(
        photoNumber: 2,
        areaSector: 'Sector 2',
        localImagePath: '',
        pngBytes: samplePng,
        cleanPngBytes: cleanPng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: [],
        timestamp: DateTime.now(),
      );
      expect(rNoHazards.clientImageBytes, cleanPng);
    });

    test('ClientReportPdfService generates PDF with dynamic technical status and observations', () async {
      final project = ProjectModel(
        contacto: 'Cliente Test',
        direccion: 'Av. Test 123',
        celular: '999111222',
        correo: 'test@cliente.com',
        proyecto: 'Proyecto Validación SST',
        fecha: '2026-10-15',
        mapa: '-12.0, -77.0',
        responsable: 'Gestor Test',
      );
      final testSession = ProjectSessionModel(project: project);

      testSession.addPhoto(SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Sala Eléctrica',
        localImagePath: '',
        pngBytes: samplePng,
        clientPngBytes: samplePng,
        estructuras: const ['Concreto'],
        materiales: const ['Tubo EMT'],
        herramientas: const [],
        accesorios: const [],
        peligros: ['Riesgo Eléctrico'],
        technicalStatus: 'no_apto',
        technicalObservation: 'No apto: requerida desenergización previa.',
        timestamp: DateTime.now(),
      ));

      testSession.addPhoto(SessionEvidenceRecord(
        photoNumber: 2,
        areaSector: 'Pasillo Principal',
        localImagePath: '',
        pngBytes: samplePng,
        clientPngBytes: samplePng,
        estructuras: const [],
        materiales: const [],
        herramientas: const [],
        accesorios: const [],
        peligros: [],
        technicalStatus: 'apto',
        technicalObservation: 'Apto: libre de interferencias.',
        timestamp: DateTime.now(),
      ));

      final pdfBytes = await ClientReportPdfService.generatePdf(testSession);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
