import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/services/internal_report_pdf_service.dart';
import 'package:vistec/services/client_report_pdf_service.dart';
import 'package:vistec/services/project_manager_report_pdf_service.dart';

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

    test('ProjectManagerReportPdfService generates valid PDF bytes with all metadata', () async {
      final pdfBytes = await ProjectManagerReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
