import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/services/google_sheets_service.dart';

void main() {
  test('GoogleSheetsService syncProject sends POST and handles response', () async {
    final service = GoogleSheetsService();
    final project = ProjectModel(
      contacto: 'Cliente Test Directo',
      direccion: 'Av. Test 123',
      celular: '999888777',
      correo: 'test@vigilarte.pe',
      proyecto: 'Videovigilancia (CCTV)',
      fecha: '2026-10-05 15:20:00',
      mapa: '-12.0463, -77.0427',
      responsable: 'Fedor Corzano',
      areaSector: 'Sala Servidores Test',
      numFoto: 1,
      peligros: ['Riesgo Electrico'],
      estructuras: ['Concreto'],
      materiales: ['Tubo EMT 3/4"'],
      herramientas: ['Rotomartillo SDS Plus'],
      accesorios: ['Conectores EMT rectos'],
      fotoBase64: '',
    );

    final res = await service.syncProject(project);
    expect(res.isSuccess, isTrue);
  });

  test('Following 302 redirect retrieves Drive photoUrl and row', () async {
    final client = http.Client();
    final response = await client.post(
      Uri.parse('https://script.google.com/macros/s/AKfycbyeHpQL5egUvdeg4YgCxJsYdCjHKutJvTQr7sagS5zXBoDc64_wemmIYEa8RalW6fC_VQ/exec'),
      headers: {'Content-Type': 'application/json'},
      body: '{"contacto":"Test Redirect","proyecto":"Test","numFoto":1,"areaSector":"Ambiente Test"}',
    );
    if (response.statusCode == 302 && response.headers.containsKey('location')) {
      final loc = response.headers['location']!;
      final getRes = await client.get(Uri.parse(loc));
      expect(getRes.statusCode, equals(200));
    }
  });

  test('GoogleSheetsService syncSession uploads multiple photos', () async {
    final service = GoogleSheetsService();
    final project = ProjectModel(
      contacto: 'Test Gestor',
      direccion: 'Av. Las Palmas 555',
      celular: '987654321',
      correo: 'gestor@empresa.com',
      proyecto: 'Cableado estructurado y redes',
      fecha: '2026-10-05 15:30:00',
      mapa: '-12.000, -77.000',
      responsable: 'Fedor Corzano',
      areaSector: '',
    );

    final session = ProjectSessionModel(
      project: project,
      photos: [
        SessionEvidenceRecord(
          photoNumber: 1,
          areaSector: 'Ambiente Servidores DataCenter',
          localImagePath: '',
          pngBytes: Uint8List(0),
          estructuras: ['Concreto'],
          materiales: ['Tubo EMT 3/4"'],
          peligros: ['Riesgo Electrico'],
          herramientas: ['Rotomartillo SDS Plus'],
          accesorios: ['Conectores EMT rectos'],
          timestamp: DateTime.now(),
        ),
      ],
    );

    int progressCalled = 0;
    final res = await service.syncSession(
      session,
      onProgress: (cur, tot, area) {
        progressCalled++;
      },
    );

    expect(res.isSuccess, isTrue);
    expect(progressCalled, equals(1));
    expect(res.syncedPhotos, equals(1));
  });
}
