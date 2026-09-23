import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/models/sticker_model.dart';
import 'package:vistec/services/voice_recognition_service.dart';
import 'package:vistec/services/ssoma_ai_service.dart';
import 'package:vistec/services/iperc_report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Recognition & Catalog Fuzzy Matching Tests', () {
    test('Matches spoken technical words to structures, materials, and hazards', () {
      const speech = 'Instalación de tubería emt y conduit en pared de concreto con riesgo de electrocución y trabajo en altura';

      final result = VoiceRecognitionService.matchVoiceToCatalog(
        speech,
        availableMateriales: TechnicalCatalogMatrix.defaultMateriales,
        availableEstructuras: TechnicalCatalogMatrix.defaultEstructuras,
        availablePeligros: [
          'Riesgo Eléctrico',
          'Trabajo en Altura',
          'Piso irregular / Objeto en el suelo',
        ],
      );

      expect(result.hasMatches, isTrue);
      expect(result.matchedMateriales.any((m) => m.toLowerCase().contains('emt')), isTrue);
      expect(result.matchedEstructuras.any((e) => e.toLowerCase().contains('concreto')), isTrue);
      expect(result.matchedPeligros.contains('Riesgo Eléctrico'), isTrue);
      expect(result.matchedPeligros.contains('Trabajo en Altura'), isTrue);
    });

    test('Matches colloquial synonyms like canaleta, drywall, cables', () {
      const speech = 'colocar canaletas en tabique drywall cables sueltos';

      final result = VoiceRecognitionService.matchVoiceToCatalog(
        speech,
        availableMateriales: TechnicalCatalogMatrix.defaultMateriales,
        availableEstructuras: TechnicalCatalogMatrix.defaultEstructuras,
        availablePeligros: [
          'Riesgo Eléctrico',
          'Trabajo en Altura',
        ],
      );

      expect(result.hasMatches, isTrue);
      expect(result.matchedMateriales.any((m) => m.toLowerCase().contains('canaleta')), isTrue);
      expect(result.matchedEstructuras.any((e) => e.toLowerCase().contains('drywall')), isTrue);
      expect(result.matchedPeligros.contains('Riesgo Eléctrico'), isTrue);
    });
  });

  group('SSOMA AI Service Offline Heuristic Engine Tests', () {
    test('Generates structured SSOMA suggestions with hierarchy and cost attribution', () async {
      final suggestions = await SsomaAiService.auditScene(
        detectedMateriales: ['Tubo EMT', 'Cables y Conductores'],
        detectedEstructuras: ['Techo / Tijerales Metálicos'],
        areaSector: 'Nave Industrial Sector A',
      );

      expect(suggestions.isNotEmpty, isTrue);

      // Debe incluir al menos riesgo de altura o contacto eléctrico
      final hasHeightOrElectric = suggestions.any(
        (s) => s.hazardName.toLowerCase().contains('altura') || s.hazardName.toLowerCase().contains('eléctrico'),
      );
      expect(hasHeightOrElectric, isTrue);

      for (final s in suggestions) {
        expect(s.hazardName.isNotEmpty, isTrue);
        expect(s.riskDescription.isNotEmpty, isTrue);
        expect(s.hierarchyLevel.isNotEmpty, isTrue);
        expect(s.preventiveMeasure.isNotEmpty, isTrue);
        expect(['VIGILARTE', 'CLIENTE'].contains(s.costResponsible), isTrue);
        expect(s.technicalBasis.isNotEmpty, isTrue);
      }
    });
  });

  group('IPERC Formal Report PDF Service Tests', () {
    test('Generates valid A4 Landscape IPERC Matrix PDF bytes', () async {
      final project = ProjectModel(
        contacto: 'Ing. Supervisor',
        direccion: 'Calle Los Ingenieros 123',
        celular: '987654321',
        correo: 'seguridad@empresa.com',
        proyecto: 'Subestación y Alimentadores Eléctricos',
        fecha: '2026-09-20',
        mapa: '-12.05, -77.03',
        responsable: 'Carlos SSOMA',
      );

      final session = ProjectSessionModel(project: project);
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Tableros Generales',
          localImagePath: '/tmp/test.png',
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
          estructuras: ['Concreto', 'Estructura Metálica'],
          materiales: ['Tubo EMT', 'Bandeja Portacables'],
          peligros: ['Riesgo Eléctrico', 'Trabajo en Altura'],
          herramientas: ['Rotomartillo', 'Escalera de Tijera'],
          accesorios: ['Riel Unistrut', 'Abrazaderas'],
          timestamp: DateTime.now(),
        ),
      );

      final pdfBytes = await IpercReportPdfService.generatePdf(session);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Validar magic number PDF (%PDF)
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });
  });
}
