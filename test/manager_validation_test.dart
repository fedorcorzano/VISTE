import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/project_model.dart';
import 'package:vistec/models/session_evidence_model.dart';
import 'package:vistec/widgets/manager_validation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  testWidgets('ManagerValidationSheet renders 3 tabs and manages SST responsibles', (WidgetTester tester) async {
    final project = ProjectModel(
      contacto: 'Cliente Test',
      direccion: 'Av. Las Begonias 123',
      celular: '999888777',
      correo: 'cliente@test.com',
      proyecto: 'Proyecto Test',
      fecha: '2026-10-01',
      mapa: '-12.046374, -77.042793',
      responsable: 'Carlos Supervisor',
      clasificacion: 'Comercial',
    );
    final session = ProjectSessionModel(project: project);
    
    // Add a photo with materials, tools, hazards
    final photo = SessionEvidenceRecord(
      photoNumber: 1,
      areaSector: 'Recepción',
      localImagePath: '',
      pngBytes: Uint8List(0),
      materiales: ['CANALETAS'],
      herramientas: ['Rotomartillo SDS Plus / Max'],
      peligros: ['TRABAJO EN ALTURA'],
      estructuras: ['CONCRETO'],
      linearMeasurements: [],
      placedPins: [],
      accesorios: ['Codos planos para canaleta'],
      timestamp: DateTime.now(),
    );
    session.addPhoto(photo);

    bool saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showManagerValidationSheet(
                  context: context,
                  session: session,
                  onSaved: () {
                    saved = true;
                  },
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open bottom sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify tabs are present
    expect(find.textContaining('Herramientas'), findsOneWidget);
    expect(find.textContaining('Materiales'), findsOneWidget);
    expect(find.text('Responsables SST'), findsOneWidget);

    // Verify tools tab content
    expect(find.text('Rotomartillo SDS Plus / Max'), findsOneWidget);

    // Switch to Responsables SST tab
    await tester.tap(find.text('Responsables SST'));
    await tester.pumpAndSettle();

    // Verify SST Hierarchy level exists
    expect(find.text('1. Eliminación'), findsOneWidget);

    // Save and verify callback
    final saveFinder = find.widgetWithText(ElevatedButton, 'Guardar Validación y Actualizar Reportes');
    expect(saveFinder, findsOneWidget);
    await tester.tap(saveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(session.customHierarchyResponsibles.containsKey('eliminacion'), isTrue);
  });
}
