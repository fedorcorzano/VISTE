import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/linear_measurement_model.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';

void main() {
  group('6-Screen Workflow & Model Integration Tests', () {
    test('SessionEvidenceRecord correctly handles SST hierarchy responsibility and controls', () {
      final record = SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Tablero Principal',
        localImagePath: '',
        pngBytes: Uint8List(0),
        estructuras: ['Concreto', 'Tablero'],
        materiales: ['Tubo EMT', 'Canaletas'],
        peligros: ['Riesgo Eléctrico'],
        herramientas: ['Taladro percutor', 'Destornillador'],
        accesorios: ['Curvas EMT', 'Uniones EMT'],
        photoHierarchyResponsibility: {
          'eliminacion': 'CLIENTE',
          'sustitucion': 'CLIENTE',
          'ingenieria': 'VIGILARTE',
          'administrativo': 'CLIENTE',
          'epp': 'VIGILARTE',
        },
        photoHierarchyControls: {
          'eliminacion': 'Desenergización total de la acometida por el cliente',
          'ingenieria': 'Instalación de bandeja y entubado hermético EMT',
          'epp': 'Uso de guantes dieléctricos 1000V clase 0 y careta',
        },
        timestamp: DateTime.now(),
      );

      // Verify explicit responsibilities
      expect(record.getResponsibility('eliminacion'), equals('CLIENTE'));
      expect(record.getResponsibility('ingenieria'), equals('VIGILARTE'));
      expect(record.getResponsibility('epp'), equals('VIGILARTE'));

      // Verify descriptions
      expect(record.getControlDescription('eliminacion'), contains('Desenergización'));
      expect(record.getControlDescription('ingenieria'), contains('bandeja y entubado'));
      expect(record.getControlDescription('epp'), contains('dieléctricos'));

      // Serialization roundtrip
      final json = record.toJson();
      expect(json['photoHierarchyResponsibility']['epp'], equals('VIGILARTE'));
      expect(json['photoHierarchyControls']['epp'], contains('dieléctricos'));

      final fromJson = SessionEvidenceRecord.fromJson(json);
      expect(fromJson.getResponsibility('epp'), equals('VIGILARTE'));
      expect(fromJson.getControlDescription('epp'), contains('dieléctricos'));
    });

    test('ProjectSessionModel conduit calculation correctly determines tiras (3m lengths)', () {
      final project = ProjectModel(
        contacto: 'Juan Pérez',
        direccion: 'Av. Industrial 123',
        celular: '999888777',
        correo: 'juan@cliente.com',
        proyecto: 'Instalación Cámaras Planta 1',
        clasificacion: 'Industrial',
        fecha: '2026-10-01',
        mapa: '-12.046374, -77.042793',
        responsable: 'Fedor Corzano',
      );

      final session = ProjectSessionModel(project: project);

      // Foto 1 con 25.0 metros de Tubo EMT y 10.0 metros de Canaleta
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Área Producción',
          localImagePath: '',
          pngBytes: Uint8List(0),
          estructuras: const [],
          materiales: ['Tubo EMT', 'Canaleta'],
          peligros: const [],
          herramientas: const [],
          accesorios: const [],
          linearMeasurements: [
            LinearMeasurement(id: 'm1', material: 'Tubo EMT', longitudMetros: 25.0),
            LinearMeasurement(id: 'm2', material: 'Canaleta 40x25', longitudMetros: 10.0),
          ],
          timestamp: DateTime.now(),
        ),
      );

      // Foto 2 con 11.0 metros adicionales de Tubo EMT
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 2,
          areaSector: 'Área Almacén',
          localImagePath: '',
          pngBytes: Uint8List(0),
          estructuras: const [],
          materiales: ['Tubo EMT'],
          peligros: const [],
          herramientas: const [],
          accesorios: const [],
          linearMeasurements: [
            LinearMeasurement(id: 'm3', material: 'Tubo EMT', longitudMetros: 11.0),
          ],
          timestamp: DateTime.now(),
        ),
      );

      // Total Tubo EMT = 36.0 metros -> 36.0 / 3.0 = 12 tiras
      // Total Canaleta 40x25 = 10.0 metros -> 10.0 / 3.0 = 3.33 -> 4 tiras
      final conduitCalc = session.getConduitCalculation();
      expect(conduitCalc.length, equals(2));

      final emtCalc = conduitCalc.firstWhere((c) => c['material'] == 'Tubo EMT');
      expect(emtCalc['meters'], equals(36.0));
      expect(emtCalc['pieces'], equals(12));

      final canaletaCalc = conduitCalc.firstWhere((c) => c['material'] == 'Canaleta 40x25');
      expect(canaletaCalc['meters'], equals(10.0));
      expect(canaletaCalc['pieces'], equals(4));

      expect(session.totalLinearMeters, equals(46.0));
    });

    test('ProjectSessionModel updates photo hierarchy controls dynamically', () {
      final project = ProjectModel(
        contacto: 'Ana Gómez',
        direccion: 'Calle Los Cedros 456',
        celular: '987654321',
        correo: 'ana@empresa.com',
        proyecto: 'Control de Accesos',
        clasificacion: 'Comercial',
        fecha: '2026-10-01',
        mapa: '0.0, 0.0',
        responsable: 'Fedor Corzano',
      );

      final session = ProjectSessionModel(project: project);
      session.addPhoto(
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Puerta Principal',
          localImagePath: '',
          pngBytes: Uint8List(0),
          estructuras: const [],
          materiales: const [],
          peligros: const [],
          herramientas: const [],
          accesorios: const [],
          timestamp: DateTime.now(),
        ),
      );

      session.setPhotoHierarchy(
        0,
        responsibilities: {'epp': 'VIGILARTE', 'eliminacion': 'CLIENTE'},
        controls: {'epp': 'Casco dieléctrico con barbiquejo'},
      );

      expect(session.photos[0].getResponsibility('epp'), equals('VIGILARTE'));
      expect(session.photos[0].getResponsibility('eliminacion'), equals('CLIENTE'));
      expect(session.photos[0].getControlDescription('epp'), equals('Casco dieléctrico con barbiquejo'));
    });
  });
}
