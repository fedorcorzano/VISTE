import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';

void main() {
  test('ProjectModel and ProjectSessionModel JSON serialization and deserialization', () {
    final project = ProjectModel(
      contacto: 'Minera Chinalco',
      direccion: 'Toromocho, Junín',
      celular: '955281424',
      correo: 'seguridad@chinalco.com',
      proyecto: 'Relevamiento CCTV PTAR',
      fecha: '2026-09-19',
      mapa: 'https://maps.google.com/?q=-11.75,-76.15',
      responsable: 'Fedor Corzano',
      areaSector: 'Subestación Eléctrica 220kV',
      peligros: ['Riesgo Eléctrico', 'Trabajo en Altura'],
      estructuras: ['Poste de concreto', 'Escalera tipo tijera'],
      materiales: ['Cámara Domo PTZ', 'Cable UTP Cat6'],
      herramientas: ['Multímetro', 'Ponchadora RJ45'],
      accesorios: ['Conectores RJ45 blindados', 'Cinta vulcanizante'],
    );

    final session = ProjectSessionModel(project: project);
    session.addPhoto(
      SessionEvidenceRecord(
        photoNumber: 1,
        areaSector: 'Subestación Eléctrica 220kV',
        localImagePath: 'test_image_1.png',
        pngBytes: Uint8List.fromList([1, 2, 3, 4]),
        clientPngBytes: Uint8List.fromList([5, 6]),
        estructuras: ['Poste de concreto'],
        materiales: ['Cámara Domo PTZ'],
        peligros: ['Riesgo Eléctrico'],
        herramientas: ['Multímetro'],
        accesorios: ['Conectores RJ45 blindados'],
        timestamp: DateTime(2026, 9, 19, 10, 0),
      ),
    );

    session.excludedTools.add('Ponchadora RJ45');
    session.additionalMaterials.add('Tornillos autoperforantes');
    session.customHierarchyResponsibles['epp'] = 'Ing. SST Residente';

    // Serialize
    final json = session.toJson();
    expect(json['id'], isNotEmpty);
    expect(json['project']['contacto'], equals('Minera Chinalco'));
    expect(json['photos'].length, equals(1));
    expect(json['excludedTools'], contains('Ponchadora RJ45'));
    expect(json['additionalMaterials'], contains('Tornillos autoperforantes'));

    // Deserialize
    final restoredSession = ProjectSessionModel.fromJson(json);
    expect(restoredSession.project.contacto, equals('Minera Chinalco'));
    expect(restoredSession.project.proyecto, equals('Relevamiento CCTV PTAR'));
    expect(restoredSession.photos.length, equals(1));
    expect(restoredSession.photos.first.areaSector, equals('Subestación Eléctrica 220kV'));
    expect(restoredSession.photos.first.peligros, contains('Riesgo Eléctrico'));
    expect(restoredSession.excludedTools, contains('Ponchadora RJ45'));
    expect(restoredSession.additionalMaterials, contains('Tornillos autoperforantes'));
    expect(restoredSession.customHierarchyResponsibles['epp'], equals('Ing. SST Residente'));
  });

  test('Check welcome_bg.png file exists and is valid', () {
    final file = File('assets/images/welcome_bg.png');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10000));
  });
}
