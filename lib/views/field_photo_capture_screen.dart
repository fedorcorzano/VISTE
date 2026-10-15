import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/linear_measurement_model.dart';
import '../models/project_model.dart';
import '../models/session_evidence_model.dart';
import '../models/sticker_model.dart';
import '../services/dual_scale_controller.dart';
import '../services/google_sheets_service.dart';
import '../services/project_storage_service.dart';
import '../services/ssoma_ai_service.dart';
import '../services/voice_recognition_service.dart';
import '../widgets/compact_photo_info_badge.dart';
import '../widgets/measurement_overlay_widget.dart';
import '../widgets/technical_structure_icons.dart';
import '../widgets/voice_input_button.dart';
import 'desk_analysis_screen.dart';

/// Procesa y hornea la orientación EXIF real de la cámara sin forzar giros arbitrarios de 90°
Uint8List? _performFieldOrientation(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // Corrige automáticamente según los metadatos EXIF del sensor
    // (Mantiene horizontal como horizontal y vertical como vertical)
    final oriented = img.bakeOrientation(decoded);
    img.Image finalImage = oriented;
    if (oriented.width > 1920 || oriented.height > 1920) {
      finalImage = img.copyResize(
        oriented,
        width: oriented.width > oriented.height ? 1920 : null,
        height: oriented.height >= oriented.width ? 1920 : null,
      );
    }
    return Uint8List.fromList(img.encodeJpg(finalImage, quality: 88));
  } catch (e) {
    debugPrint('Error en orientación de foto: $e');
    return null;
  }
}

/// ============================================================================
/// PANTALLA DE CAPTURA RÁPIDA EN CAMPO (FLUJO MINIMALISTA CON REEL DE FOTOS)
/// ============================================================================
class FieldPhotoCaptureScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectSessionModel? existingSession;

  const FieldPhotoCaptureScreen({
    super.key,
    required this.project,
    this.existingSession,
  });

  @override
  State<FieldPhotoCaptureScreen> createState() => _FieldPhotoCaptureScreenState();
}

class _FieldPhotoCaptureScreenState extends State<FieldPhotoCaptureScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final ImagePicker _imagePicker = ImagePicker();
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();

  late ProjectSessionModel _sessionModel;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraError = false;
  bool _isProcessing = false;

  // Estado del flujo fotográfico:
  // _activePhotoIndex == null -> Modo visor de cámara en vivo
  // _activePhotoIndex >= 0    -> Modo edición de la foto seleccionada del Reel
  int? _activePhotoIndex;

  // Datos en edición de la foto activa
  Uint8List? _activeImageBytes;
  double _imageAspectRatio = 9 / 16;
  final List<LinearMeasurement> _activeMeasurements = [];
  final List<PlacedSticker> _activePins = [];
  final TextEditingController _areaController = TextEditingController();

  // Herramientas de edición en foto activa
  bool _isCotaDrawingMode = false;
  Offset? _guidedOriginA;
  Offset? _guidedTargetB;
  bool _isGuidingOriginA = false;
  bool _isGuidingDestinationB = false;
  bool _showLoupe = false;
  Offset? _loupeFocalPoint;
  String? _selectedMeasurementId;
  String? _activeDragHandle; // 'A' o 'B' para reubicar puntas de cota
  Offset? _floatingPinMenuPos; // Posición de menú flotante contextual de pines al tocar la foto
  bool _showLegendPreview = true;
  bool _isExportingForSave = false;
  String? _exportMode; // null, 'pines', 'medidas', 'sst'

  Future<void> _renderFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
    await Future.delayed(const Duration(milliseconds: 35));
  }

  // Control de zoom continuo con dos dedos
  final TransformationController _transformationController = TransformationController();
  late final DualScaleController _dualScaleController;
  double _currentScale = 1.0;

  Map<String, List<String>> _catalogs = {};

  @override
  void initState() {
    super.initState();
    _dualScaleController = DualScaleController(controller: _transformationController);
    _sessionModel = widget.existingSession ?? ProjectSessionModel(project: widget.project);
    _initCamera();
    _loadCatalogs();

    // Si ya venían fotos previas de la sesión, cargar la última en pantalla
    if (_sessionModel.photos.isNotEmpty) {
      _loadPhotoIntoEditor(_sessionModel.photos.length - 1);
    } else {
      _updateAreaDefault();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _areaController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _dualScaleController.reset();
    setState(() {
      _transformationController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _updateAreaDefault() {
    final nextNumber = _sessionModel.photos.length + 1;
    _areaController.text = 'Ambiente #$nextNumber';
  }

  Future<void> _loadCatalogs() async {
    try {
      final cats = await _sheetsService.fetchCatalogs();
      if (mounted) setState(() => _catalogs = cats);
    } catch (e) {
      debugPrint('Error cargando catálogos en campo: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _cameraError = false);
      } else {
        if (mounted) setState(() => _cameraError = true);
      }
    } catch (e) {
      debugPrint('Error inicializando cámara: $e');
      if (mounted) setState(() => _cameraError = true);
    }
  }

  void _updateImageAspectRatio(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        setState(() {
          _imageAspectRatio = decoded.width / decoded.height;
        });
      }
    } catch (_) {}
  }

  List<String> _getContextualConduits() {
    return TechnicalCatalogMatrix.materialesPorClasificacion[widget.project.clasificacion] ??
        ['Tubo EMT 3/4"', 'Canaleta 40x25', 'Tubo PVC SAP 3/4"'];
  }

  // ============================================================================
  // DISPARO Y CAPTURA DE FOTOS
  // ============================================================================

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final XFile photo = await _cameraController!.takePicture();
      final rawBytes = await photo.readAsBytes();

      // Orientación exacta y real (sin giros invertidos)
      final orientedBytes = await compute(_performFieldOrientation, rawBytes) ?? rawBytes;

      final docDir = await getApplicationDocumentsDirectory();
      final photoNum = _sessionModel.photos.length + 1;
      final fileName = 'field_photo_${photoNum}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${docDir.path}/$fileName');
      await file.writeAsBytes(orientedBytes);

      final areaName = _areaController.text.trim().isEmpty ? 'Ambiente #$photoNum' : _areaController.text.trim();

      final newRecord = SessionEvidenceRecord(
        photoNumber: photoNum,
        areaSector: areaName,
        localImagePath: file.path,
        cleanPngBytes: orientedBytes,
        pngBytes: orientedBytes,
        linearMeasurements: const [],
        placedPins: const [],
        estructuras: const [],
        materiales: const [],
        peligros: const [],
        herramientas: const [],
        accesorios: const [],
        timestamp: DateTime.now(),
      );

      _sessionModel.photos.add(newRecord);
      await ProjectStorageService.saveSession(_sessionModel);

      // Cargar inmediatamente la foto tomada en el editor para permitir pines/cotas
      _loadPhotoIntoEditor(_sessionModel.photos.length - 1);
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error al capturar foto en campo: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (file != null) {
        final rawBytes = await file.readAsBytes();
        final orientedBytes = await compute(_performFieldOrientation, rawBytes) ?? rawBytes;

        final docDir = await getApplicationDocumentsDirectory();
        final photoNum = _sessionModel.photos.length + 1;
        final fileName = 'gallery_photo_${photoNum}_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedFile = File('${docDir.path}/$fileName');
        await savedFile.writeAsBytes(orientedBytes);

        final areaName = _areaController.text.trim().isEmpty ? 'Ambiente #$photoNum' : _areaController.text.trim();

        final newRecord = SessionEvidenceRecord(
          photoNumber: photoNum,
          areaSector: areaName,
          localImagePath: savedFile.path,
          cleanPngBytes: orientedBytes,
          pngBytes: orientedBytes,
          linearMeasurements: const [],
          placedPins: const [],
          estructuras: const [],
          materiales: const [],
          peligros: const [],
          herramientas: const [],
          accesorios: const [],
          timestamp: DateTime.now(),
        );

        _sessionModel.photos.add(newRecord);
        await ProjectStorageService.saveSession(_sessionModel);
        _loadPhotoIntoEditor(_sessionModel.photos.length - 1);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  // ============================================================================
  // GESTIÓN DEL REEL Y TRANSICIÓN DE FOTOS
  // ============================================================================

  /// Carga una foto específica del reel en el editor con sus pines y cotas
  void _loadPhotoIntoEditor(int index) {
    if (index < 0 || index >= _sessionModel.photos.length) return;

    final photo = _sessionModel.photos[index];
    setState(() {
      _activePhotoIndex = index;
      _activeImageBytes = photo.baseImageBytes;
      _activeMeasurements.clear();
      _activeMeasurements.addAll(photo.linearMeasurements);
      _activePins.clear();
      _activePins.addAll(photo.placedPins);
      _areaController.text = photo.areaSector;
      _isCotaDrawingMode = false;
      _guidedOriginA = null;
      _guidedTargetB = null;
      _selectedMeasurementId = null;
      _floatingPinMenuPos = null;
      _isProcessing = false;
      _resetZoom();
    });
    _updateImageAspectRatio(photo.baseImageBytes);
  }

  /// Guarda los pines, cotas y nombre del área de la foto actual
  Future<void> _saveCurrentPhotoEdits() async {
    if (_activePhotoIndex == null || _activePhotoIndex! >= _sessionModel.photos.length) return;

    final currentRecord = _sessionModel.photos[_activePhotoIndex!];
    final areaName = _areaController.text.trim().isEmpty ? currentRecord.areaSector : _areaController.text.trim();

    if (_floatingPinMenuPos != null) {
      setState(() => _floatingPinMenuPos = null);
    }

    Uint8List pngBytes = currentRecord.pngBytes;
    Uint8List? measurementsPngBytes;
    Uint8List? clientPngBytes;

    final RenderRepaintBoundary? boundary =
        _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary != null) {
      try {
        // 1. Captura de Pines con Leyenda (sin cotas)
        setState(() {
          _isExportingForSave = true;
          _exportMode = 'pines';
        });
        await _renderFrame();
        final ui.Image imgPines = await boundary.toImage(pixelRatio: 1.5);
        final ByteData? bdPines = await imgPines.toByteData(format: ui.ImageByteFormat.png);
        if (bdPines != null) {
          pngBytes = bdPines.buffer.asUint8List();
        }

        // 2. Si hay cotas/medidas trazadas, captura exclusiva de Cotas Técnicas (sin pines)
        if (_activeMeasurements.isNotEmpty) {
          setState(() {
            _exportMode = 'medidas';
          });
          await _renderFrame();
          final ui.Image imgMeas = await boundary.toImage(pixelRatio: 1.5);
          final ByteData? bdMeas = await imgMeas.toByteData(format: ui.ImageByteFormat.png);
          if (bdMeas != null) {
            measurementsPngBytes = bdMeas.buffer.asUint8List();
          }
        }

        // 3. Captura exclusiva para Cliente SST (solo riesgos SST, sin cotas ni materiales/estructuras)
        setState(() {
          _exportMode = 'sst';
        });
        await _renderFrame();
        final ui.Image imgSst = await boundary.toImage(pixelRatio: 1.5);
        final ByteData? bdSst = await imgSst.toByteData(format: ui.ImageByteFormat.png);
        if (bdSst != null) {
          clientPngBytes = bdSst.buffer.asUint8List();
        }
      } catch (e) {
        debugPrint('Error exportando fotos excluyentes en campo: $e');
      } finally {
        if (mounted) {
          setState(() {
            _exportMode = null;
            _isExportingForSave = false;
          });
        }
      }
    }

    // Extraer materiales de pines y cotas
    final cotaMaterials = _activeMeasurements
        .map((m) => m.material)
        .where((m) => m.isNotEmpty && m != 'Por definir' && m != 'Solo Medida');
    final pinMaterials = _activePins
        .where((p) => p.sticker.category == StickerCategory.materiales)
        .map((p) => p.sticker.title);

    final cleanPhotoBytes = currentRecord.cleanPngBytes ?? _activeImageBytes ?? currentRecord.baseImageBytes;

    final updatedRecord = currentRecord.copyWith(
      photoNumber: currentRecord.photoNumber,
      areaSector: areaName,
      localImagePath: currentRecord.localImagePath,
      cleanPngBytes: cleanPhotoBytes,
      pngBytes: pngBytes,
      measurementsPngBytes: measurementsPngBytes,
      clientPngBytes: clientPngBytes ?? (_activePins.any((p) => p.sticker.category == StickerCategory.peligros) ? null : cleanPhotoBytes),
      linearMeasurements: List<LinearMeasurement>.from(_activeMeasurements),
      placedPins: List<PlacedSticker>.from(_activePins),
      estructuras: _activePins
          .where((p) => p.sticker.category == StickerCategory.estructuras)
          .map((p) => p.sticker.title)
          .toList(),
      materiales: {...pinMaterials, ...cotaMaterials}.toList(),
      peligros: _activePins
          .where((p) => p.sticker.category == StickerCategory.peligros)
          .map((p) => p.sticker.title)
          .toList(),
      herramientas: TechnicalCatalogMatrix.deduceHerramientas(
        estructuras: _activePins
            .where((p) => p.sticker.category == StickerCategory.estructuras)
            .map((p) => p.sticker.title)
            .toList(),
        materiales: {...pinMaterials, ...cotaMaterials}.toList(),
      ),
      accesorios: TechnicalCatalogMatrix.deduceAccesorios(
        materiales: {...pinMaterials, ...cotaMaterials}.toList(),
      ),
      timestamp: currentRecord.timestamp,
    );

    _sessionModel.photos[_activePhotoIndex!] = updatedRecord;
    await ProjectStorageService.saveSession(_sessionModel);
  }

  /// Pasa a la siguiente foto: guarda la actual y abre la cámara en vivo
  Future<void> _nextPhotoAndOpenCamera() async {
    if (_activePhotoIndex != null) {
      await _saveCurrentPhotoEdits();
    }
    setState(() {
      _activePhotoIndex = null;
      _activeImageBytes = null;
      _activeMeasurements.clear();
      _activePins.clear();
      _isCotaDrawingMode = false;
      _guidedOriginA = null;
      _guidedTargetB = null;
      _selectedMeasurementId = null;
      _updateAreaDefault();
    });
  }

  /// Finaliza y avanza a Gabinete / Generación de Reportes
  Future<void> _finishFieldAndGoToDesk() async {
    if (_activePhotoIndex != null) {
      await _saveCurrentPhotoEdits();
    }
    if (!mounted) return;

    if (_sessionModel.photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura al menos 1 fotografía antes de generar reportes.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeskAnalysisScreen(session: _sessionModel),
      ),
    );
  }

  // ============================================================================
  // INTERACCIÓN CON PINES: CAMBIAR, MOVER O ELIMINAR (Req. 4)
  // ============================================================================

  PlacedSticker? _findNearestPin(Offset tapPos, {double maxDistance = 28.0}) {
    PlacedSticker? closest;
    double minDistance = maxDistance;
    for (final pin in _activePins) {
      final dist = (tapPos - pin.position).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closest = pin;
      }
    }
    return closest;
  }

  int _getCategoryPinNumber(PlacedSticker targetPin) {
    int count = 1;
    for (final pin in _activePins) {
      if (pin.id == targetPin.id) return count;
      if (pin.sticker.category == targetPin.sticker.category) count++;
    }
    return count;
  }

  Color _getCategoryColor(StickerCategory category) {
    switch (category) {
      case StickerCategory.peligros:
        return const Color(0xFFFFD600);
      case StickerCategory.materiales:
        return const Color(0xFF00E676);
      case StickerCategory.estructuras:
        return const Color(0xFF00B0FF);
    }
  }

  /// Menú contextual directo al tocar un Pin: Cambiar o Eliminar (Req. 4)
  void _showPinContextMenu(PlacedSticker pin) {
    final catNum = _getCategoryPinNumber(pin);
    final String categoryName = pin.sticker.category == StickerCategory.estructuras
        ? 'Estructura'
        : (pin.sticker.category == StickerCategory.materiales ? 'Material' : 'Peligro SST');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TechnicalStructureIconWidget(
                      name: pin.sticker.title,
                      category: pin.sticker.category,
                      size: 28,
                      color: _getCategoryColor(pin.sticker.category),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$categoryName #$catNum',
                            style: TextStyle(
                              color: _getCategoryColor(pin.sticker.category),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            pin.sticker.title,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Opción: Cambiar pin
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openPinCategorySelector(existingPin: pin);
                        },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Opción: Eliminar pin
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _activePins.removeWhere((p) => p.id == pin.id);
                          });
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🗑️ Pin eliminado'),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Abre selector de categoría para añadir o cambiar un Pin con iconos representativos
  void _openPinCategorySelector({PlacedSticker? existingPin, Offset? tapPosition}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_location_alt, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    existingPin != null ? 'Cambiar Pin por Categoría' : 'Seleccionar Tipo de Pin',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 1. Estructura (Viga H, Concreto, Teja)
              ListTile(
                tileColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B0FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00B0FF), width: 1.2),
                  ),
                  child: const Center(
                    child: TechnicalStructureIconWidget(name: 'fierro', size: 20, color: Color(0xFF00B0FF)),
                  ),
                ),
                title: const Text('Estructura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Fierro (H-Beam), Concreto, Teja, Drywall, etc.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(ctx);
                  _openItemsGridForCategory(StickerCategory.estructuras, existingPin: existingPin, initialPosition: tapPosition);
                },
              ),
              const SizedBox(height: 8),
              // 2. Material
              ListTile(
                tileColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                  ),
                  child: const Center(
                    child: TechnicalStructureIconWidget(name: 'tubo emt', category: StickerCategory.materiales, size: 20, color: Color(0xFF00E676)),
                  ),
                ),
                title: const Text('Material de Canalización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tubo EMT, IMC, PVC SAP/SEL, Canaleta, etc.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(ctx);
                  _openItemsGridForCategory(StickerCategory.materiales, existingPin: existingPin, initialPosition: tapPosition);
                },
              ),
              const SizedBox(height: 8),
              // 3. Peligro SST
              ListTile(
                tileColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD600), width: 1.2),
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD600), size: 22),
                  ),
                ),
                title: const Text('Peligro SST / SSOMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Riesgo eléctrico, trabajos en altura, etc.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(ctx);
                  _openItemsGridForCategory(StickerCategory.peligros, existingPin: existingPin, initialPosition: tapPosition);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _highIncidenceHazards = [
    'riesgo eléctrico',
    'contacto eléctrico',
    'trabajo en altura',
    'trabajos en altura',
    'caída de objetos',
    'caida de objetos',
    'caída al mismo nivel',
    'caida al mismo nivel',
    'piso resbaloso',
    'espacio confinado',
    'corte',
    'atrapamiento',
    'ergonom',
    'postura',
    'ruido',
    'polvo',
    'incendio',
  ];

  static const List<String> _highIncidenceMaterials = [
    'tubo emt 3/4',
    'tubo emt 1',
    'tubo emt 1/2',
    'tubo emt',
    'canaleta 40x25',
    'canaleta',
    'tubo pvc sap 3/4',
    'tubo pvc sap',
    'liquid tight',
    'bandeja portacables',
    'bandeja',
    'caja de pase',
    'tubo imc',
    'corrugado',
  ];

  int _getIncidenceScore(String item, StickerCategory category) {
    final lower = item.toLowerCase();
    int sessionUsage = 0;
    for (final photo in _sessionModel.photos) {
      if (category == StickerCategory.materiales) {
        if (photo.materiales.any((m) => m.toLowerCase().contains(lower) || lower.contains(m.toLowerCase()))) {
          sessionUsage += 5;
        }
      } else if (category == StickerCategory.peligros) {
        if (photo.peligros.any((p) => p.toLowerCase().contains(lower) || lower.contains(p.toLowerCase()))) {
          sessionUsage += 5;
        }
      }
    }

    int baseScore = 0;
    if (category == StickerCategory.materiales) {
      for (int i = 0; i < _highIncidenceMaterials.length; i++) {
        if (lower.contains(_highIncidenceMaterials[i])) {
          baseScore = (_highIncidenceMaterials.length - i) * 2;
          break;
        }
      }
      final prioClasif = TechnicalCatalogMatrix.materialesPorClasificacion[widget.project.clasificacion] ?? [];
      for (final p in prioClasif) {
        if (lower.contains(p.toLowerCase())) {
          baseScore += 10;
          break;
        }
      }
    } else if (category == StickerCategory.peligros) {
      for (int i = 0; i < _highIncidenceHazards.length; i++) {
        if (lower.contains(_highIncidenceHazards[i])) {
          baseScore = (_highIncidenceHazards.length - i) * 2;
          break;
        }
      }
    }

    return sessionUsage + baseScore;
  }

  void _openItemsGridForCategory(
    StickerCategory category, {
    PlacedSticker? existingPin,
    Offset? initialPosition,
  }) {
    List<String> items = [];
    if (category == StickerCategory.estructuras) {
      items = _catalogs['estructuras'] ?? ['Fierro / Acero', 'Concreto', 'Teja', 'Drywall / Yeso', 'Madera', 'Ladrillo', 'Vidrio / Fachada'];
    } else if (category == StickerCategory.materiales) {
      items = _catalogs['materiales'] ?? ['Tubo EMT 3/4"', 'Tubo EMT 1"', 'Canaleta 40x25', 'Tubo PVC SAP 3/4"', 'Liquid Tight 3/4"'];
    } else {
      items = _catalogs['peligros'] ?? ['Riesgo Eléctrico', 'Trabajo en Altura', 'Caída de Objetos', 'Paso Peatonal', 'Espacio Confinado'];
    }

    final Color themeColor = _getCategoryColor(category);
    final String categoryName = category == StickerCategory.estructuras
        ? 'Estructuras de Montaje'
        : (category == StickerCategory.materiales ? 'Materiales Técnicos' : 'Peligros y Riesgos SST');

    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final String query = VoiceRecognitionService.normalizeText(searchController.text);
            final List<String> filteredItems = query.isEmpty
                ? List<String>.from(items)
                : items.where((item) {
                    final cleanItem = VoiceRecognitionService.normalizeText(item);
                    return cleanItem.contains(query);
                  }).toList();

            // Ordenar por mayor incidencia en la parte alta para materiales y peligros
            filteredItems.sort((a, b) {
              final scoreA = _getIncidenceScore(a, category);
              final scoreB = _getIncidenceScore(b, category);
              if (scoreA != scoreB) {
                return scoreB.compareTo(scoreA); // Mayor incidencia primero
              }
              return a.compareTo(b);
            });

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera del modal
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            category == StickerCategory.peligros
                                ? Icons.warning_amber_rounded
                                : (category == StickerCategory.materiales
                                    ? Icons.hardware
                                    : Icons.foundation),
                            color: themeColor,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              existingPin != null ? 'Cambiar $categoryName' : 'Agregar Pin: $categoryName',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Barra de búsqueda PERSISTENTE (Texto + Dictado por voz) - NO desaparece al scrollear
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar o dictar por voz $categoryName...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {});
                                  },
                                ),
                              VoiceInputButton(
                                controller: searchController,
                                voiceService: _voiceService,
                                onChanged: () => setModalState(() {}),
                                tooltip: 'Dictar nombre por voz',
                                iconSize: 18,
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // Cuadrícula de elementos con mayor incidencia al inicio
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off, color: Colors.white38, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se encontró "$query"',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 3.2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, idx) {
                                final item = filteredItems[idx];
                                final isHighIncidence = _getIncidenceScore(item, category) > 0;

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    if (existingPin != null) {
                                      setState(() {
                                        existingPin.sticker = StickerModel.fromCatalog(item, category);
                                      });
                                      HapticFeedback.lightImpact();
                                    } else {
                                      final newPin = PlacedSticker(
                                        id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
                                        sticker: StickerModel.fromCatalog(item, category),
                                        position: initialPosition ?? const Offset(150, 150),
                                      );
                                      setState(() {
                                        _activePins.add(newPin);
                                      });
                                      HapticFeedback.lightImpact();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isHighIncidence
                                            ? const Color(0xFFFBBF24) // Acento dorado para mayor incidencia
                                            : themeColor.withValues(alpha: 0.5),
                                        width: isHighIncidence ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        TechnicalStructureIconWidget(
                                          name: item,
                                          category: category,
                                          size: 20,
                                          color: isHighIncidence ? const Color(0xFFFBBF24) : themeColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (isHighIncidence)
                                                const Text(
                                                  '★ Mayor incidencia',
                                                  style: TextStyle(
                                                    color: Color(0xFFFBBF24),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Ejecuta el Agente Auditor SSOMA con IA en la pantalla de fotos de campo
  Future<void> _openSsomaAiWizard() async {
    Uint8List? targetBytes = _activeImageBytes;
    if (targetBytes == null && _sessionModel.photos.isNotEmpty) {
      targetBytes = _sessionModel.photos.last.pngBytes;
    }

    if (targetBytes == null || targetBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura o selecciona una foto para realizar la auditoría SSOMA con IA.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final suggestions = await SsomaAiService.auditScene(
        imageBytes: targetBytes,
        detectedMateriales: _activePins
            .where((p) => p.sticker.category == StickerCategory.materiales)
            .map((p) => p.sticker.title)
            .toList(),
        detectedEstructuras: _activePins
            .where((p) => p.sticker.category == StickerCategory.estructuras)
            .map((p) => p.sticker.title)
            .toList(),
        areaSector: _areaController.text.trim().isNotEmpty
            ? _areaController.text.trim()
            : 'Ambiente en Campo',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se detectaron riesgos adicionales en la foto.')),
        );
        return;
      }

      final Set<int> selectedAiIndices = <int>{};

      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.72,
                maxChildSize: 0.92,
                minChildSize: 0.45,
                expand: false,
                builder: (c, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFFBBF24),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Auditoría SSOMA (IA)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Marca con un check los peligros que deseas incorporar a la foto activa:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: suggestions.length,
                            itemBuilder: (context, idx) {
                              final sug = suggestions[idx];
                              final isChecked = selectedAiIndices.contains(idx);

                              return Card(
                                color: isChecked
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF334155),
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isChecked
                                        ? const Color(0xFFFBBF24)
                                        : Colors.white12,
                                    width: isChecked ? 1.5 : 0.8,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isChecked) {
                                        selectedAiIndices.remove(idx);
                                      } else {
                                        selectedAiIndices.add(idx);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFFFBBF24),
                                          checkColor: const Color(0xFF001F2F),
                                          onChanged: (val) {
                                            setModalState(() {
                                              if (val == true) {
                                                selectedAiIndices.add(idx);
                                              } else {
                                                selectedAiIndices.remove(idx);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: Color(0xFFFBBF24),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      sug.hazardName,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                sug.riskDescription,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Jerarquía: ${sug.hierarchyLevel} • Responsable: ${sug.costResponsible}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF38BDF8),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: selectedAiIndices.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  int count = 0;
                                  for (final idx in selectedAiIndices) {
                                    final item = suggestions[idx];
                                    final double dx = 120.0 + (count * 24.0);
                                    final double dy = 160.0 + (count * 32.0);

                                    final pin = PlacedSticker(
                                      id: 'pin_ssoma_${DateTime.now().millisecondsSinceEpoch}_$count',
                                      sticker: StickerModel.fromCatalog(
                                        item.hazardName,
                                        StickerCategory.peligros,
                                      ),
                                      position: Offset(dx, dy),
                                    );
                                    setState(() {
                                      _activePins.add(pin);
                                    });
                                    count++;
                                  }
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ Se añadieron $count peligros auditados por SSOMA IA.'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.check, color: Color(0xFF001F2F)),
                          label: Text(
                            'Incorporar (${selectedAiIndices.length}) a la Foto',
                            style: const TextStyle(
                              color: Color(0xFF001F2F),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            disabledBackgroundColor: Colors.white24,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error en auditoría SSOMA IA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ejecutar auditoría SSOMA: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================================
  // INTERACCIÓN CON COTAS: FLECHA (MOVER) VS VALOR NUMÉRICO (MODIFICAR) (Req. 4)
  // ============================================================================

  LinearMeasurement? _findNearestCota(Offset tapPos, {double maxDistance = 26.0}) {
    LinearMeasurement? closest;
    double minDistance = maxDistance;

    for (final m in _activeMeasurements) {
      final dist = _pointToSegmentDistance(tapPos, m.startOffset, m.endOffset);
      if (dist < minDistance) {
        minDistance = dist;
        closest = m;
      }
    }
    return closest;
  }

  double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final double l2 = (b.dx - a.dx) * (b.dx - a.dx) + (b.dy - a.dy) * (b.dy - a.dy);
    if (l2 == 0) return (p - a).distance;
    final double t = (((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2).clamp(0.0, 1.0);
    final Offset projection = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return (p - projection).distance;
  }

  /// Diálogo directo al tocar el valor numérico: Modificar longitud y elegir material relacionado (Req. 4)
  Future<void> _editCotaNumericAndMaterial(LinearMeasurement measurement) async {
    final result = await showDialog<MeasurementModalResult>(
      context: context,
      builder: (ctx) => MeasurementCaptureModal(
        start: measurement.startOffset,
        end: measurement.endOffset,
        onlyDistance: false, // Permite modificar valor numérico Y elegir material relacionado
        contextualConduits: _getContextualConduits(),
        voiceService: _voiceService,
        existingMeasurement: measurement,
        clasificacion: widget.project.clasificacion,
        allAvailableMaterials: _catalogs['materiales'],
      ),
    );

    if (result != null) {
      setState(() {
        if (result.action == MeasurementModalAction.deleted) {
          _activeMeasurements.removeWhere((m) => m.id == measurement.id);
          _selectedMeasurementId = null;
        } else if (result.action == MeasurementModalAction.saved && result.measurement != null) {
          final idx = _activeMeasurements.indexWhere((m) => m.id == measurement.id);
          if (idx != -1) {
            _activeMeasurements[idx] = result.measurement!;
          }
        }
      });
      HapticFeedback.lightImpact();
    }
  }

  /// Activa el modo de reubicación de manijas A y B al tocar la flecha / línea de la cota (Req. 4)
  void _selectCotaForRelocation(LinearMeasurement measurement) {
    setState(() {
      _selectedMeasurementId = measurement.id;
      _activeDragHandle = null;
    });
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📐 Cota seleccionada: Arrastra las manijas A o B para reubicar los puntos de medición.'),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // WIDGETS DE PANTALLA: REEL, TÍTULO, CÁMARA Y EDITOR
  // ============================================================================

  /// 1. Reel superior horizontal de fotos capturadas
  Widget _buildTopPhotoReel() {
    if (_sessionModel.photos.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 76,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sessionModel.photos.length,
        itemBuilder: (context, idx) {
          final photo = _sessionModel.photos[idx];
          final isSelected = _activePhotoIndex == idx;
          final totalItems = photo.placedPins.length + photo.linearMeasurements.length;

          return GestureDetector(
            onTap: () async {
              if (_activePhotoIndex != null && _activePhotoIndex != idx) {
                await _saveCurrentPhotoEdits();
              }
              _loadPhotoIntoEditor(idx);
            },
            child: Container(
              width: 76,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
                  width: isSelected ? 2.2 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), blurRadius: 6)]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo.pngBytes.isNotEmpty
                      ? Image.memory(photo.pngBytes, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.image, size: 20, color: Colors.white38)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${photo.photoNumber}',
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (totalItems > 0)
                    Positioned(
                      top: 2,
                      right: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$totalItems',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 2,
                    left: 3,
                    right: 3,
                    child: Text(
                      photo.areaSector,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 2. Barra de título del ambiente / sector con entrada de voz
  Widget _buildAreaTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _areaController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                labelText: _activePhotoIndex != null
                    ? 'Nombre del Ambiente (Foto #${_activePhotoIndex! + 1})'
                    : 'Nombre del Ambiente para siguiente foto',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                prefixIcon: const Icon(Icons.meeting_room_outlined, color: Color(0xFF38BDF8), size: 18),
                suffixIcon: VoiceInputButton(
                  controller: _areaController,
                  tooltip: 'Dictar ambiente',
                  iconSize: 18,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_activePhotoIndex != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              tooltip: 'Eliminar esta foto',
              onPressed: () {
                final idx = _activePhotoIndex!;
                setState(() {
                  _sessionModel.photos.removeAt(idx);
                  if (_sessionModel.photos.isEmpty) {
                    _activePhotoIndex = null;
                    _activeImageBytes = null;
                    _updateAreaDefault();
                  } else {
                    final nextIdx = (idx >= _sessionModel.photos.length) ? _sessionModel.photos.length - 1 : idx;
                    _loadPhotoIntoEditor(nextIdx);
                  }
                });
                ProjectStorageService.saveSession(_sessionModel);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 3. Modo Cámara en Vivo: obturador grande y botón de galería
  Widget _buildLiveCameraView() {
    if (_cameraError || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text('Cámara no disponible en este dispositivo', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Importar de Galería'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Botón prominente de culminar toma de fotos si ya hay fotos capturadas
        if (_sessionModel.photos.isNotEmpty)
          Positioned(
            bottom: 116,
            left: 24,
            right: 24,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _finishFieldAndGoToDesk,
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                label: Text(
                  '✓ Culminar Toma Fotográfica (${_sessionModel.photos.length} fotos) ➔',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  elevation: 8,
                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),

        // Barra inferior con obturador gigante
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                color: Colors.white,
                iconSize: 32,
                tooltip: 'Importar de Galería',
              ),
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _isProcessing
                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 36)),
                ),
              ),
              IconButton(
                onPressed: _finishFieldAndGoToDesk,
                icon: const Icon(Icons.check_circle_outline),
                color: const Color(0xFF10B981),
                iconSize: 34,
                tooltip: 'Culminar Toma Fotográfica',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 4. Modo Edición de Foto Activa: Lienzo con Pines, Cotas y Barra de Herramientas
  Widget _buildPhotoEditorView() {
    if (_activeImageBytes == null) return const SizedBox.shrink();

    final nextPhotoNum = (_activePhotoIndex ?? 0) + 1;

    return Column(
      children: [
        // Lienzo de la foto con zoom, pines y cotas
        Expanded(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: !_isCotaDrawingMode && _activeDragHandle == null && _currentScale > 1.05,
                  scaleEnabled: !_isCotaDrawingMode && _activeDragHandle == null,
                  minScale: 1.0,
                  maxScale: 5.0,
                  onInteractionUpdate: (details) {
                    final scale = _transformationController.value.getMaxScaleOnAxis();
                    if ((scale - _currentScale).abs() > 0.05) {
                      setState(() => _currentScale = scale);
                    }
                  },
                  child: AspectRatio(
                    aspectRatio: _imageAspectRatio,
                    child: RepaintBoundary(
                      key: _repaintBoundaryKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Imagen de fondo
                              Image.memory(_activeImageBytes!, fit: BoxFit.contain),

                              // Dibujo de cotas lineales (excluyente: visible en modo medidas o trazo interactivo, NUNCA en modo pines ni sst)
                              if (_exportMode != 'pines' &&
                                  _exportMode != 'sst' &&
                                  (_exportMode == 'medidas' || _isCotaDrawingMode || _activeMeasurements.isNotEmpty))
                                CustomPaint(
                                  size: canvasSize,
                                  painter: MeasurementLinesPainter(
                                    measurements: _activeMeasurements,
                                    selectedMeasurementId: _isExportingForSave ? null : _selectedMeasurementId,
                                    guidedOriginA: _isExportingForSave ? null : _guidedOriginA,
                                    currentEnd: _isExportingForSave ? null : _guidedTargetB,
                                  ),
                                ),

                              // Pines interactivos colocados sobre la foto (excluyente: NUNCA en modo medidas)
                              if (_exportMode != 'medidas')
                                ..._activePins
                                    .where((p) => _exportMode != 'sst' || p.sticker.category == StickerCategory.peligros)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final pin = entry.value;
                                  final catNum = _getCategoryPinNumber(pin);

                                  return Positioned(
                                    left: pin.position.dx - 18,
                                    top: pin.position.dy - 18,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      // Mover pin con arrastre de 1 dedo, con zona segura para evitar traslape con cinta inferior (Req. 2)
                                      onPanUpdate: _isCotaDrawingMode
                                          ? null
                                          : (details) {
                                              setState(() {
                                                final newX = (pin.position.dx + details.delta.dx).clamp(16.0, canvasSize.width - 16.0);
                                                final newY = (pin.position.dy + details.delta.dy).clamp(16.0, canvasSize.height - 50.0);
                                                pin.position = Offset(newX, newY);
                                              });
                                            },
                                      // Tocar pin: Menú contextual Cambiar o Eliminar (Req. 4)
                                      onTap: _isCotaDrawingMode ? null : () => _showPinContextMenu(pin),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        color: Colors.transparent,
                                        child: _buildPinBadgeWidget(pin.sticker.category, catNum),
                                      ),
                                    ),
                                  );
                                }),

                              // Ficha técnica en esquina superior izquierda
                              Positioned(
                                top: 6,
                                left: 6,
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: CompactPhotoInfoBadge(
                                    proyecto: widget.project.proyecto,
                                    contacto: widget.project.contacto,
                                    ambiente: _areaController.text.trim().isNotEmpty
                                        ? _areaController.text.trim()
                                        : 'Ambiente #$nextPhotoNum',
                                    fecha: widget.project.fecha,
                                    photoNumber: nextPhotoNum,
                                  ),
                                ),
                              ),

                              // Cinta / Leyenda técnica ultra-compacta al pie (excluyente: NUNCA en modo medidas)
                              if (_exportMode != 'medidas' &&
                                  _showLegendPreview &&
                                  (_exportMode == 'sst'
                                      ? _activePins.any((p) => p.sticker.category == StickerCategory.peligros)
                                      : (_activePins.isNotEmpty || _activeMeasurements.isNotEmpty)))
                                Positioned(
                                  bottom: 4,
                                  left: 6,
                                  right: 6,
                                  child: _buildUltraCompactFooterTape(),
                                ),

                              // Lupa de precisión al mover manijas o trazar
                              if (!_isExportingForSave && _showLoupe && _loupeFocalPoint != null)
                                LoupeMagnifierWidget(
                                  touchPosition: _loupeFocalPoint!,
                                  canvasSize: canvasSize,
                                  accentColor: const Color(0xFFE3A51A),
                                ),

                              // Capa táctil principal:
                              // - 2 dedos: Zoom natural
                              // - 1 dedo en pin: mover o menú contextual
                              // - 1 dedo en cota (número): modificar valor y material
                              // - 1 dedo en cota (flecha): reubicar puntos A y B
                              // - 1 dedo en espacio libre: trazar cota (si está activo el modo cota) o añadir pin
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapUp: (details) {
                                  // En modo cota los toques son capturados por el gestor de escala/arrastre
                                  if (_isCotaDrawingMode) return;

                                  final pos = details.localPosition;

                                  // 1. Verificar si tocó un pin
                                  final hitPin = _findNearestPin(pos, maxDistance: 24.0);
                                  if (hitPin != null) {
                                    _showPinContextMenu(hitPin);
                                    return;
                                  }

                                  // 2. Verificar si tocó una cota
                                  final hitCota = _findNearestCota(pos, maxDistance: 26.0);
                                  if (hitCota != null) {
                                    final mid = Offset(
                                      (hitCota.startOffset.dx + hitCota.endOffset.dx) / 2,
                                      (hitCota.startOffset.dy + hitCota.endOffset.dy) / 2,
                                    );
                                    // Si tocó sobre o muy cerca del valor numérico -> MODIFICAR VALOR Y MATERIAL (Req. 4)
                                    if ((pos - mid).distance <= 26.0) {
                                      _editCotaNumericAndMaterial(hitCota);
                                    } else {
                                      // Si tocó la flecha / línea -> SELECCIONAR Y MOVER / REUBICAR (Req. 4)
                                      _selectCotaForRelocation(hitCota);
                                    }
                                    return;
                                  }

                                  // 3. Si no tocó elementos existentes y no estamos trazando, deseleccionar o mostrar menú flotante de pines
                                  if (_selectedMeasurementId != null) {
                                    setState(() => _selectedMeasurementId = null);
                                    return;
                                  }

                                  setState(() {
                                    _floatingPinMenuPos = pos;
                                  });
                                  HapticFeedback.selectionClick();
                                },
                                onScaleStart: (details) {
                                  if (details.pointerCount >= 2) {
                                    _dualScaleController.onScaleStart(details);
                                    return;
                                  }

                                  final pos = details.localFocalPoint;

                                  // Si hay una cota seleccionada y no estamos trazando, verificar manijas A o B
                                  if (!_isCotaDrawingMode && _selectedMeasurementId != null) {
                                    final sel = _activeMeasurements.where((m) => m.id == _selectedMeasurementId).firstOrNull;
                                    if (sel != null) {
                                      if ((pos - sel.startOffset).distance <= 32.0) {
                                        _activeDragHandle = 'A';
                                        _showLoupe = true;
                                        _loupeFocalPoint = sel.startOffset;
                                        HapticFeedback.selectionClick();
                                        return;
                                      } else if ((pos - sel.endOffset).distance <= 32.0) {
                                        _activeDragHandle = 'B';
                                        _showLoupe = true;
                                        _loupeFocalPoint = sel.endOffset;
                                        HapticFeedback.selectionClick();
                                        return;
                                      }
                                    }
                                  }

                                  // Iniciar trazo de cota si el modo cota está activo (soporta toque simple o arrastre continuo)
                                  if (_isCotaDrawingMode) {
                                    setState(() {
                                      _selectedMeasurementId = null;
                                      _activeDragHandle = null;
                                      _showLoupe = true;
                                      _loupeFocalPoint = pos;
                                      if (_guidedOriginA == null) {
                                        _guidedOriginA = pos;
                                        _guidedTargetB = pos;
                                        _isGuidingOriginA = true;
                                        _isGuidingDestinationB = false;
                                      } else {
                                        _guidedTargetB = pos;
                                        _isGuidingDestinationB = true;
                                      }
                                    });
                                    HapticFeedback.selectionClick();
                                    return;
                                  }
                                },
                                onScaleUpdate: (details) {
                                  if (details.pointerCount >= 2 || _dualScaleController.isZooming) {
                                    _dualScaleController.onScaleUpdate(details, canvasSize);
                                    final scale = _transformationController.value.getMaxScaleOnAxis();
                                    if ((scale - _currentScale).abs() > 0.05) {
                                      setState(() => _currentScale = scale);
                                    }
                                    return;
                                  }

                                  final pos = details.localFocalPoint;

                                  // Reubicación continua de manija A o B de la cota seleccionada (Req. 4)
                                  if (_selectedMeasurementId != null && _activeDragHandle != null) {
                                    final idx = _activeMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                    if (idx != -1) {
                                      final cur = _activeMeasurements[idx];
                                      setState(() {
                                        _loupeFocalPoint = pos;
                                        if (_activeDragHandle == 'A') {
                                          _activeMeasurements[idx] = LinearMeasurement(
                                            id: cur.id,
                                            startOffset: pos,
                                            endOffset: cur.endOffset,
                                            longitudMetros: cur.longitudMetros,
                                            material: cur.material,
                                            esMetradoMaterial: cur.esMetradoMaterial,
                                          );
                                        } else if (_activeDragHandle == 'B') {
                                          _activeMeasurements[idx] = LinearMeasurement(
                                            id: cur.id,
                                            startOffset: cur.startOffset,
                                            endOffset: pos,
                                            longitudMetros: cur.longitudMetros,
                                            material: cur.material,
                                            esMetradoMaterial: cur.esMetradoMaterial,
                                          );
                                        }
                                      });
                                    }
                                    return;
                                  }

                                  // Actualizar trazo de cota en vivo (Mantiene fijo el Punto A y estira el Punto B)
                                  if (_isCotaDrawingMode) {
                                    setState(() {
                                      _loupeFocalPoint = pos;
                                      _guidedTargetB = pos;
                                    });
                                    return;
                                  }
                                },
                                onScaleEnd: (details) async {
                                  if (_dualScaleController.isZooming) {
                                    _dualScaleController.onScaleEnd(details);
                                    return;
                                  }

                                  // Finalizar reubicación de manija A o B
                                  if (_activeDragHandle != null) {
                                    setState(() {
                                      _activeDragHandle = null;
                                      _showLoupe = false;
                                    });
                                    HapticFeedback.lightImpact();
                                    return;
                                  }

                                  // Finalizar trazo de cota
                                  if (_isCotaDrawingMode) {
                                    setState(() => _showLoupe = false);

                                    if (_guidedOriginA != null) {
                                      final start = _guidedOriginA!;
                                      final end = _guidedTargetB ?? start;
                                      final dist = (end - start).distance;

                                      if (dist > 18.0) {
                                        // Arrastre fluido o segundo toque con distancia suficiente -> Crear cota
                                        await _completeCotaCreation(start, end);
                                      } else {
                                        // Toque simple (< 18px): si fue el primer toque, fijar punto A y esperar punto B
                                        if (_isGuidingOriginA && !_isGuidingDestinationB) {
                                          setState(() {
                                            _isGuidingOriginA = false;
                                            _isGuidingDestinationB = true;
                                            _guidedTargetB = null;
                                          });
                                          HapticFeedback.lightImpact();
                                        }
                                      }
                                    }
                                    return;
                                  }
                                },
                              ),

                              // Indicador de toque para menú flotante de pines
                              if (_floatingPinMenuPos != null)
                                Positioned(
                                  left: _floatingPinMenuPos!.dx - 10,
                                  top: _floatingPinMenuPos!.dy - 10,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                        border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                                      ),
                                    ),
                                  ),
                                ),

                              // Botones flotantes contextuales: Estructura, Material, Peligro SST
                              if (!_isExportingForSave && _floatingPinMenuPos != null)
                                _buildFloatingPinMenu(canvasSize),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Botón de reset de zoom flotante
              if (_currentScale > 1.05)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _resetZoom,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_out_map, size: 14, color: Color(0xFF38BDF8)),
                            SizedBox(width: 4),
                            Text('1.0x', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Banner flotante superior de guía de cota activa
              if (_isCotaDrawingMode)
                Positioned(
                  top: 10,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001F2F).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE3A51A), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straighten, color: Color(0xFFE3A51A), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _guidedOriginA == null
                                ? 'Toca o arrastra desde el Punto A'
                                : 'Toca o arrastra hacia el Punto B',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCotaDrawingMode = false;
                                _guidedOriginA = null;
                                _guidedTargetB = null;
                                _isGuidingOriginA = false;
                                _isGuidingDestinationB = false;
                                _showLoupe = false;
                              });
                            },
                            child: const Icon(Icons.close, color: Colors.white70, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 5. Barra inferior minimalista de herramientas (Pines, Cotas, Siguiente Foto)
        _buildMinimalistBottomToolbar(),
      ],
    );
  }

  /// Menú flotante contextual de selección de pin al tocar sobre la fotografía
  Widget _buildFloatingPinMenu(Size canvasSize) {
    if (_floatingPinMenuPos == null) return const SizedBox.shrink();

    const menuWidth = 280.0;
    const menuHeight = 52.0;
    final left = (_floatingPinMenuPos!.dx - (menuWidth / 2))
        .clamp(8.0, canvasSize.width - menuWidth - 8.0);
    final top = _floatingPinMenuPos!.dy > 70
        ? (_floatingPinMenuPos!.dy - 60.0).clamp(8.0, canvasSize.height - menuHeight - 8.0)
        : (_floatingPinMenuPos!.dy + 24.0).clamp(8.0, canvasSize.height - menuHeight - 8.0);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Estructuras
              _buildFloatingPinOption(
                label: 'Estructuras',
                icon: Icons.foundation,
                color: const Color(0xFF00B0FF),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openItemsGridForCategory(StickerCategory.estructuras, initialPosition: target);
                },
              ),
              const SizedBox(width: 4),

              // Botón Materiales
              _buildFloatingPinOption(
                label: 'Materiales',
                icon: Icons.hardware,
                color: const Color(0xFF00E676),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openItemsGridForCategory(StickerCategory.materiales, initialPosition: target);
                },
              ),
              const SizedBox(width: 4),

              // Botón Peligros
              _buildFloatingPinOption(
                label: 'Peligros',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFBBF24),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openItemsGridForCategory(StickerCategory.peligros, initialPosition: target);
                },
              ),
              const SizedBox(width: 4),

              // Botón Cerrar
              InkWell(
                onTap: () => setState(() => _floatingPinMenuPos = null),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPinOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Finaliza la captura de una cota lineal y abre el modal técnico para ingresar distancia y material
  Future<void> _completeCotaCreation(Offset start, Offset end) async {
    setState(() {
      _isGuidingOriginA = false;
      _isGuidingDestinationB = false;
      _guidedOriginA = null;
      _guidedTargetB = null;
      _isCotaDrawingMode = false;
      _showLoupe = false;
    });

    final result = await showDialog<MeasurementModalResult>(
      context: context,
      builder: (ctx) => MeasurementCaptureModal(
        start: start,
        end: end,
        onlyDistance: false,
        contextualConduits: _getContextualConduits(),
        voiceService: _voiceService,
        clasificacion: widget.project.clasificacion,
        allAvailableMaterials: _catalogs['materiales'],
      ),
    );

    if (result != null &&
        result.action == MeasurementModalAction.saved &&
        result.measurement != null) {
      setState(() {
        _activeMeasurements.add(result.measurement!);
        _selectedMeasurementId = result.measurement!.id;
      });
      HapticFeedback.mediumImpact();
    }
  }

  /// Distintivo HUD de Pin con su número por categoría
  Widget _buildPinBadgeWidget(StickerCategory category, int number) {
    switch (category) {
      case StickerCategory.peligros:
        return SizedBox(
          width: 20,
          height: 18,
          child: CustomPaint(
            painter: WarningTrianglePainter(
              fillColor: const Color(0x35FFD600),
              borderColor: const Color(0xFFFFD600),
              borderWidth: 1.4,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 8.5,
                    height: 1.0,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3.0)],
                  ),
                ),
              ),
            ),
          ),
        );

      case StickerCategory.estructuras:
        return Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: const Color(0x3000B0FF),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF00B0FF), width: 1.4),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 8.5,
                height: 1.0,
                shadows: [Shadow(color: Colors.black, blurRadius: 3.0)],
              ),
            ),
          ),
        );

      case StickerCategory.materiales:
        return Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: const Color(0x3000E676),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00E676), width: 1.4),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 8.5,
                height: 1.0,
                shadows: [Shadow(color: Colors.black, blurRadius: 3.0)],
              ),
            ),
          ),
        );
    }
  }

  /// Cinta ultra-compacta al pie de la imagen sin traslape con pines
  Widget _buildUltraCompactFooterTape() {
    final String label;
    if (_exportMode == 'sst') {
      final sstCount = _activePins.where((p) => p.sticker.category == StickerCategory.peligros).length;
      label = 'PELIGROS SST ($sstCount)';
    } else if (_exportMode == 'pines') {
      label = 'PINES TÉCNICOS (${_activePins.length})';
    } else if (_exportMode == 'medidas') {
      label = 'COTAS TÉCNICAS (${_activeMeasurements.length})';
    } else {
      label = 'PINES (${_activePins.length}) • COTAS (${_activeMeasurements.length})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, color: Color(0xFF38BDF8), size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 7.5, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Text(
            'Desarrollado por: Fedor Corzano',
            style: TextStyle(color: Colors.white54, fontSize: 6.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  /// 5. Barra inferior minimalista (Pines, Cotas, Siguiente Foto, Finalizar)
  Widget _buildMinimalistBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Botón 📍 Pin
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openPinCategorySelector(),
              icon: const Icon(Icons.add_location_alt, size: 16),
              label: const Text('📍 Pin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: const Color(0xFF38BDF8),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón 📐 Cota
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isCotaDrawingMode = !_isCotaDrawingMode;
                  _guidedOriginA = null;
                  _guidedTargetB = null;
                  _selectedMeasurementId = null;
                });
                if (_isCotaDrawingMode) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📐 Modo cota activo: Toca el punto A y luego arrastra al punto B.'),
                      backgroundColor: Color(0xFF0F172A),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.straighten,
                size: 16,
                color: _isCotaDrawingMode ? const Color(0xFF001F2F) : const Color(0xFFE3A51A),
              ),
              label: Text(
                _isCotaDrawingMode ? 'Trazando...' : '📐 Cota',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isCotaDrawingMode ? const Color(0xFF001F2F) : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCotaDrawingMode ? const Color(0xFFE3A51A) : const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón 📸 Siguiente Foto
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextPhotoAndOpenCamera,
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: const Text('📸 Siguiente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.project.proyecto.isEmpty ? 'VIGILARTE' : widget.project.proyecto,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${widget.project.contacto.isEmpty ? "Proyecto" : widget.project.contacto} • ${_sessionModel.photos.length} fotos',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          // 1. Ícono de Leyenda (Mostrar / Ocultar)
          IconButton(
            icon: Icon(
              _showLegendPreview ? Icons.subtitles : Icons.subtitles_off_outlined,
              color: _showLegendPreview ? const Color(0xFF38BDF8) : Colors.white54,
              size: 20,
            ),
            tooltip: _showLegendPreview ? 'Ocultar leyenda' : 'Mostrar leyenda',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => setState(() => _showLegendPreview = !_showLegendPreview),
          ),

          // 2. Botón textual SSOMA IA (Texto 'SSOMA IA' prominente y exacto)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
            child: ElevatedButton(
              onPressed: _openSsomaAiWizard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3A51A),
                foregroundColor: const Color(0xFF001F2F),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
                elevation: 2,
              ),
              child: const Text(
                'SSOMA IA',
                style: TextStyle(
                  color: Color(0xFF001F2F),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // 3. Botón Culminar Fotos (diseño compacto que NO oculta los íconos de leyenda ni SSOMA IA)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 3.0),
            child: ElevatedButton.icon(
              onPressed: _finishFieldAndGoToDesk,
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
              label: Text(
                'Culminar (${_sessionModel.photos.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Reel superior horizontal de fotos capturadas
            _buildTopPhotoReel(),

            // 2. Campo de Título del Área / Ambiente
            _buildAreaTitleBar(),

            // 3. Vista principal: Visor de cámara en vivo O Editor de foto activa
            Expanded(
              child: _activePhotoIndex == null ? _buildLiveCameraView() : _buildPhotoEditorView(),
            ),
          ],
        ),
      ),
    );
  }
}
