import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/linear_measurement_model.dart';
import '../models/session_evidence_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import '../services/project_storage_service.dart';
import '../services/ssoma_ai_service.dart';
import '../services/technical_catalog_icons.dart';
import '../services/voice_recognition_service.dart';
import '../widgets/compact_photo_info_badge.dart';
import '../widgets/measurement_overlay_widget.dart';
import '../widgets/voice_input_button.dart';
import 'project_summary_report_screen.dart';

/// ============================================================================
/// PANTALLA 4: ANÁLISIS DE GABINETE / ESCRITORIO (VISTEC V3)
/// Interfaz para el Gestor de Proyectos:
/// - Carrusel superior de fotos tomadas en campo
/// - Colocación de Pines numerados (Estructuras: 1,2.. Materiales con ★: 1,2.. Peligros SST: 1,2..)
/// - Asignación y refinamiento de materiales reales a las cotas tomadas en campo
/// - Asistencia con IA SSOMA y Validación del Gestor
/// - Transición a Generación de Reportes y Control SST (Pantalla 5)
/// ============================================================================
class DeskAnalysisScreen extends StatefulWidget {
  final ProjectSessionModel session;

  const DeskAnalysisScreen({
    super.key,
    required this.session,
  });

  @override
  State<DeskAnalysisScreen> createState() => _DeskAnalysisScreenState();
}

enum DeskDisplayMode { pines, medidas }

class _DeskAnalysisScreenState extends State<DeskAnalysisScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();

  late ProjectSessionModel _sessionModel;
  int _selectedPhotoIndex = 0;
  DeskDisplayMode _displayMode = DeskDisplayMode.pines;
  bool _isProcessing = false;

  // Datos de la foto activa
  Uint8List? _currentImageBytes;
  double _imageAspectRatio = 9 / 16;
  final List<PlacedSticker> _placedPins = [];
  final List<LinearMeasurement> _linearMeasurements = [];

  // Botón flotante contextual al tocar la imagen en modo pines
  Offset? _floatingPinMenuPos;

  // Trazado de nuevas cotas en gabinete si se requiere
  bool _isDrawingCota = false;
  Offset? _guidedOriginA;
  Offset? _guidedTargetB;
  bool _isGuidingOriginA = false;
  bool _isGuidingDestinationB = false;
  bool _showLoupe = false;
  Offset? _loupeFocalPoint;
  String? _selectedMeasurementId;
  String? _activeDragHandle;

  // Control de exportación y leyenda no bloqueante
  bool _isExportingForSave = false;
  bool _showLegendPreview = true;

  Map<String, List<String>> _catalogs = {};

  // Control de zoom interactivo nativo con dos dedos (Req. 1)
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    if (mounted) setState(() => _currentScale = 1.0);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sessionModel = widget.session;
    _loadCatalogs();
    if (_sessionModel.photos.isNotEmpty) {
      _loadPhotoData(0);
    }
  }

  Future<void> _loadCatalogs() async {
    try {
      final cats = await _sheetsService.fetchCatalogs();
      if (mounted) setState(() => _catalogs = cats);
    } catch (e) {
      debugPrint('Error cargando catálogos en gabinete: $e');
    }
  }

  void _loadPhotoData(int index) {
    if (index < 0 || index >= _sessionModel.photos.length) return;

    final record = _sessionModel.photos[index];
    Uint8List imgBytes = record.baseImageBytes;

    _resetZoom();

    setState(() {
      _selectedPhotoIndex = index;
      _currentImageBytes = imgBytes;
      _placedPins.clear();
      _placedPins.addAll(record.placedPins.map((p) => p.copyWith()));
      _linearMeasurements.clear();
      _linearMeasurements.addAll(record.linearMeasurements.map((m) => m.copyWith()));
      _selectedMeasurementId = null;
      _isDrawingCota = false;
      _guidedOriginA = null;
      _guidedTargetB = null;
    });

    _updateImageAspectRatio(imgBytes);
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

  /// Guarda los cambios de pines y cotas de la foto activa dentro del modelo de sesión
  Future<void> _saveActivePhotoChanges() async {
    if (_selectedPhotoIndex < 0 || _selectedPhotoIndex >= _sessionModel.photos.length) return;

    final currentRecord = _sessionModel.photos[_selectedPhotoIndex];

    // Extraer etiquetas de estructuras, materiales y peligros desde los pines
    final estructuras = _placedPins
        .where((p) => p.sticker.category == StickerCategory.estructuras)
        .map((p) => p.sticker.title)
        .toList();

    final materiales = _placedPins
        .where((p) => p.sticker.category == StickerCategory.materiales)
        .map((p) => p.sticker.title)
        .toList();

    // Sumar materiales de cotas lineales
    for (final m in _linearMeasurements) {
      if (m.material.isNotEmpty && m.material != 'Por definir' && !materiales.contains(m.material)) {
        materiales.add(m.material);
      }
    }

    final peligros = _placedPins
        .where((p) => p.sticker.category == StickerCategory.peligros)
        .map((p) => p.sticker.title)
        .toList();

    final herramientas = TechnicalCatalogMatrix.deduceHerramientas(
      estructuras: estructuras,
      materiales: materiales,
    );

    final accesorios = TechnicalCatalogMatrix.deduceAccesorios(materiales: materiales);

    // Renderizar imagen compuesta actualizada con pines
    Uint8List finalPngBytes = currentRecord.pngBytes;
    Uint8List? clientPngBytes = currentRecord.clientPngBytes;
    Uint8List? measurementsPngBytes = currentRecord.measurementsPngBytes;

    try {
      setState(() => _isExportingForSave = true);
      await Future.delayed(const Duration(milliseconds: 60));
      final RenderRepaintBoundary? boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          finalPngBytes = byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Aviso en renderizado de foto: $e');
    } finally {
      if (mounted) setState(() => _isExportingForSave = false);
    }

    final updatedRecord = currentRecord.copyWith(
      cleanPngBytes: currentRecord.cleanPngBytes ?? currentRecord.baseImageBytes,
      pngBytes: finalPngBytes,
      clientPngBytes: clientPngBytes ?? finalPngBytes,
      measurementsPngBytes: measurementsPngBytes ?? finalPngBytes,
      placedPins: List<PlacedSticker>.from(_placedPins),
      linearMeasurements: List<LinearMeasurement>.from(_linearMeasurements),
      estructuras: estructuras,
      materiales: materiales,
      peligros: peligros,
      herramientas: herramientas,
      accesorios: accesorios,
    );

    _sessionModel.updatePhoto(_selectedPhotoIndex, updatedRecord);
    await ProjectStorageService.saveSession(_sessionModel);
  }

  /// Calcula el número correlativo del pin dentro de su respectiva categoría (1, 2, 3...)
  int _getCategoryPinNumber(PlacedSticker target) {
    int count = 0;
    for (final pin in _placedPins) {
      if (pin.sticker.category == target.sticker.category) {
        count++;
        if (pin.id == target.id) return count;
      }
    }
    return count > 0 ? count : 1;
  }

  /// Determina si un material es prioritario según la clasificación del proyecto
  bool _isPriorityMaterial(String materialName) {
    final priorityList =
        TechnicalCatalogMatrix.materialesPorClasificacion[_sessionModel.project.clasificacion] ?? [];
    return priorityList.contains(materialName);
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
      if (_isPriorityMaterial(item)) {
        baseScore += 10;
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

  LinearMeasurement? _findNearestCota(Offset tapPos, {double maxDistance = 24.0}) {
    LinearMeasurement? closest;
    double minDistance = maxDistance;

    for (final m in _linearMeasurements) {
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

  Color _getCategoryColor(StickerCategory category) {
    switch (category) {
      case StickerCategory.estructuras:
        return const Color(0xFF00B0FF);
      case StickerCategory.materiales:
        return const Color(0xFF00E676);
      case StickerCategory.peligros:
        return const Color(0xFFFFD600);
    }
  }

  /// Abre selector para agregar o cambiar un pin en la foto (Cuadros de selección rápida + voz)
  void _openAddPinSelector(
    StickerCategory category, {
    Offset? initialPosition,
    PlacedSticker? existingPin,
  }) {
    List<String> items = [];
    String categoryName = '';
    Color themeColor = Colors.blue;

    switch (category) {
      case StickerCategory.estructuras:
        items = _catalogs['estructuras'] ?? TechnicalCatalogMatrix.defaultEstructuras;
        categoryName = 'Estructuras';
        themeColor = const Color(0xFF00B0FF);
        break;
      case StickerCategory.materiales:
        items = _catalogs['materiales'] ?? TechnicalCatalogMatrix.defaultMateriales;
        categoryName = 'Materiales y Canalizaciones';
        themeColor = const Color(0xFF00E676);
        break;
      case StickerCategory.peligros:
        items = _catalogs['peligros'] ??
            const [
              'Riesgo Eléctrico',
              'Trabajo en Altura',
              'Piso irregular / Objeto en el suelo',
              'Falta de Señalización',
              'Falta de Orden y Limpieza',
              'Espacio Confinado',
              'Superficie Caliente',
              'Riesgo de Atrapamiento',
            ];
        categoryName = 'Peligros y Riesgos SST';
        themeColor = const Color(0xFFFFC107);
        break;
    }

    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

            // Colocar elementos de mayor incidencia en la parte alta para materiales y peligros
            if (category == StickerCategory.materiales || category == StickerCategory.peligros) {
              filteredItems.sort((a, b) {
                final scoreA = _getIncidenceScore(a, category);
                final scoreB = _getIncidenceScore(b, category);
                if (scoreA != scoreB) {
                  return scoreB.compareTo(scoreA); // Mayor incidencia primero
                }
                return a.compareTo(b);
              });
            }

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
                              existingPin != null
                                  ? 'Cambiar $categoryName'
                                  : 'Agregar Pin de $categoryName',
                              style: const TextStyle(
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
                    ),

                    // Barra de búsqueda con dictado por voz universal (Req. 2 y 4)
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
                                tooltip: 'Dictar nombre de $categoryName',
                                iconSize: 18,
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Cuadrícula de cuadros de selección rápida (Req. 4)
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
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 6,
                                childAspectRatio: 5.6, // Altura reducida a la mitad exacta (Req. 4)
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, idx) {
                                final item = filteredItems[idx];
                                final isHighIncidence = (category == StickerCategory.materiales ||
                                        category == StickerCategory.peligros) &&
                                    _getIncidenceScore(item, category) > 0;
                                final Widget iconWidget = TechnicalCatalogIcons.buildIcon(
                                  item,
                                  category,
                                  size: 15,
                                  color: isHighIncidence ? const Color(0xFFFBBF24) : themeColor,
                                );

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    if (existingPin != null) {
                                      setState(() {
                                        existingPin.sticker =
                                            StickerModel.fromCatalog(item, category);
                                      });
                                      HapticFeedback.lightImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Pin actualizado a: $item'),
                                          backgroundColor: const Color(0xFF10B981),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } else {
                                      _addPinToPhoto(item, category, position: initialPosition);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isHighIncidence
                                          ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
                                          : const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isHighIncidence
                                            ? const Color(0xFFFBBF24)
                                            : themeColor.withValues(alpha: 0.4),
                                        width: isHighIncidence ? 1.4 : 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        iconWidget,
                                        const SizedBox(width: 5),
                                        if (isHighIncidence)
                                          const Text(
                                            '★ ',
                                            style: TextStyle(
                                              color: Color(0xFFFBBF24),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: TextStyle(
                                              color: isHighIncidence ? const Color(0xFFFDE68A) : Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: isHighIncidence ? FontWeight.bold : FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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

  /// Añade el pin en una posición visible o tocada del lienzo
  void _addPinToPhoto(String title, StickerCategory category, {Offset? position}) {
    final newPin = PlacedSticker(
      id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
      sticker: StickerModel.fromCatalog(title, category),
      position: position ?? const Offset(150, 150),
    );

    setState(() {
      _placedPins.add(newPin);
      _displayMode = DeskDisplayMode.pines;
    });

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Pin agregado: $title. Puedes arrastrarlo sobre la foto.'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Menú contextual ultra directo para un pin al dar click (Req. 2: Editar o Eliminar sin pasos extra)
  void _showPinOptionsModal(PlacedSticker pin) {
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
                    TechnicalCatalogIcons.buildIcon(
                      pin.sticker.title,
                      pin.sticker.category,
                      size: 26,
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
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openAddPinSelector(pin.sticker.category, existingPin: pin);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _placedPins.removeWhere((p) => p.id == pin.id);
                          });
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🗑️ Pin eliminado: ${pin.sticker.title}'),
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 2),
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

  /// Menú contextual ultra directo para una cota al dar click (Req. 2: Editar o Eliminar sin pasos extra)
  void _showCotaContextMenu(LinearMeasurement m) {
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
                    const Icon(Icons.straighten, color: Color(0xFFE3A51A), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cota de Medida',
                            style: TextStyle(color: Color(0xFFE3A51A), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            m.labelDistanceOnly,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (m.esMetradoMaterial && m.material.isNotEmpty && m.material != 'Solo Medida')
                            Text(
                              '📦 ${m.material}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
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
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editCotaMaterial(m);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _linearMeasurements.removeWhere((item) => item.id == m.id);
                            if (_selectedMeasurementId == m.id) {
                              _selectedMeasurementId = null;
                            }
                          });
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🗑️ Cota eliminada exitosamente'),
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

  /// Edita o asigna el material real a una cota existente
  Future<void> _editCotaMaterial(LinearMeasurement measurement) async {
    final conduits = TechnicalCatalogMatrix.materialesPorClasificacion[_sessionModel.project.clasificacion] ??
        ['Tubo EMT 3/4"', 'Canaleta 40x25', 'Tubo PVC SAP 3/4"'];

    final result = await showDialog<MeasurementModalResult>(
      context: context,
      builder: (ctx) => MeasurementCaptureModal(
        start: measurement.startOffset,
        end: measurement.endOffset,
        contextualConduits: conduits,
        voiceService: _voiceService,
        existingMeasurement: measurement,
        clasificacion: _sessionModel.project.clasificacion,
        allAvailableMaterials: _catalogs['materiales'],
      ),
    );

    if (result != null) {
      setState(() {
        if (result.action == MeasurementModalAction.deleted) {
          _linearMeasurements.removeWhere((m) => m.id == measurement.id);
        } else if (result.action == MeasurementModalAction.saved && result.measurement != null) {
          final idx = _linearMeasurements.indexWhere((m) => m.id == measurement.id);
          if (idx != -1) {
            _linearMeasurements[idx] = result.measurement!;
          }
        }
      });
      HapticFeedback.lightImpact();
    }
  }

  /// Ejecuta análisis con IA SSOMA sobre la foto activa
  Future<void> _runSsomaAiAnalysis() async {
    if (_currentImageBytes == null) return;

    setState(() => _isProcessing = true);
    try {
      final suggestions = await SsomaAiService.auditScene(
        imageBytes: _currentImageBytes!,
        detectedMateriales: _placedPins
            .where((p) => p.sticker.category == StickerCategory.materiales)
            .map((p) => p.sticker.title)
            .toList(),
        detectedEstructuras: _placedPins
            .where((p) => p.sticker.category == StickerCategory.estructuras)
            .map((p) => p.sticker.title)
            .toList(),
        areaSector: _sessionModel.photos.isNotEmpty ? _sessionModel.photos[_selectedPhotoIndex].areaSector : '',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se detectaron riesgos adicionales en la foto.')),
        );
        return;
      }

      // Mostrar diálogo con sugerencias de la IA con checks y botón de agregar
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
                        // Botón inferior para agregar todos los seleccionados y cerrar automáticamente
                        ElevatedButton.icon(
                          onPressed: selectedAiIndices.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  int count = 0;
                                  for (final idx in selectedAiIndices) {
                                    final item = suggestions[idx];
                                    // Distribuir posiciones iniciales para evitar apilamiento
                                    final offset = Offset(
                                      100.0 + (count * 32.0),
                                      120.0 + (count * 28.0),
                                    );
                                    _addPinToPhoto(
                                      item.hazardName,
                                      StickerCategory.peligros,
                                      position: offset,
                                    );
                                    count++;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✓ $count Peligros SST agregados a la foto sin apilar.',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            selectedAiIndices.isEmpty
                                ? 'Selecciona al menos 1 peligro'
                                : '+ Agregar Seleccionados (${selectedAiIndices.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF001F2F),
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white38,
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
      debugPrint('Error en análisis IA: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar análisis con IA: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Avanza a la Pantalla 5: Generación de Reportes y Control SST
  Future<void> _goToReportsAndSstControl() async {
    setState(() => _isProcessing = true);
    await _saveActivePhotoChanges();

    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSummaryReportScreen(session: _sessionModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePhoto = _sessionModel.photos.isNotEmpty ? _sessionModel.photos[_selectedPhotoIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.architecture, color: Color(0xFF10B981), size: 17),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Análisis y Marcación',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_selectedPhotoIndex + 1}/${_sessionModel.photos.length}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${_sessionModel.project.proyecto} • ${_sessionModel.project.clasificacion}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLegendPreview ? Icons.subtitles : Icons.subtitles_off_outlined,
              color: _showLegendPreview ? const Color(0xFF38BDF8) : Colors.white54,
            ),
            tooltip: _showLegendPreview ? 'Ocultar pie de página / leyenda' : 'Mostrar pie de página / leyenda',
            onPressed: () => setState(() => _showLegendPreview = !_showLegendPreview),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 4.0),
            child: ElevatedButton(
              onPressed: _runSsomaAiAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3A51A),
                foregroundColor: const Color(0xFF001F2F),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 16),
                    Text('Guardando y actualizando análisis...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : Column(
                children: [
                  // 1. Carrusel superior de fotos tomadas en campo
                  _buildPhotoFilmstripCarousel(),

                  // 2. Información del sector activo y selector de modo (Pines vs Cotas)
                  _buildSubHeader(activePhoto),

                  // 3. Lienzo interactivo de la foto activa
                  Expanded(
                    child: _buildPhotoCanvas(),
                  ),

                  // 4. Barra de herramientas de gabinete y botón de avance
                  _buildDeskToolbar(),
                ],
              ),
      ),
    );
  }

  // ============================================================================
  // WIDGETS DE SOPORTE GABINETE
  // ============================================================================

  Widget _buildPhotoFilmstripCarousel() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF1E293B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sessionModel.photos.length,
        itemBuilder: (context, idx) {
          final isSelected = idx == _selectedPhotoIndex;
          final photo = _sessionModel.photos[idx];

          return GestureDetector(
            onTap: () async {
              if (idx != _selectedPhotoIndex) {
                await _saveActivePhotoChanges();
                _loadPhotoData(idx);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 68,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo.pngBytes.isNotEmpty
                      ? Image.memory(photo.pngBytes, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.image, size: 24, color: Colors.white24)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 4,
                    right: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${photo.photoNumber}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        if (photo.linearMeasurements.isNotEmpty)
                          const Icon(Icons.straighten, color: Color(0xFFE3A51A), size: 10),
                      ],
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

  Widget _buildSubHeader(SessionEvidenceRecord? photo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo?.areaSector ?? 'Foto #${_selectedPhotoIndex + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_placedPins.length} pines • ${_linearMeasurements.length} cotas',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Modo exclusivo: Pines vs Cotas
          SegmentedButton<DeskDisplayMode>(
            segments: const [
              ButtonSegment(
                value: DeskDisplayMode.pines,
                icon: Icon(Icons.pin_drop, size: 16),
                label: Text('Pines', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: DeskDisplayMode.medidas,
                icon: Icon(Icons.straighten, size: 16),
                label: Text('Cotas', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {_displayMode},
            onSelectionChanged: (val) {
              setState(() => _displayMode = val.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF0284C7);
                }
                return const Color(0xFF1E293B);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Menú flotante contextual de selección de pin al tocar sobre la imagen (Req: Botones flotantes Estructura, Material, Peligro SST)
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
              // Botón Estructura
              _buildFloatingPinOption(
                label: 'Estructura',
                icon: Icons.foundation,
                color: const Color(0xFF00B0FF),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openAddPinSelector(StickerCategory.estructuras, initialPosition: target);
                },
              ),
              const SizedBox(width: 4),

              // Botón Material
              _buildFloatingPinOption(
                label: 'Material',
                icon: Icons.hardware,
                color: const Color(0xFF00E676),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openAddPinSelector(StickerCategory.materiales, initialPosition: target);
                },
              ),
              const SizedBox(width: 4),

              // Botón Peligro SST
              _buildFloatingPinOption(
                label: 'Peligro SST',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFBBF24),
                onTap: () {
                  final target = _floatingPinMenuPos!;
                  setState(() => _floatingPinMenuPos = null);
                  _openAddPinSelector(StickerCategory.peligros, initialPosition: target);
                },
              ),
              const SizedBox(width: 2),

              // Botón Cerrar
              InkWell(
                onTap: () => setState(() => _floatingPinMenuPos = null),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(5.0),
                  child: Icon(Icons.close, color: Colors.white60, size: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCanvas() {
    if (_currentImageBytes == null) {
      return const Center(child: Text('Cargando imagen...', style: TextStyle(color: Colors.white54)));
    }

    final activePhoto = _sessionModel.photos.isNotEmpty && _selectedPhotoIndex < _sessionModel.photos.length
        ? _sessionModel.photos[_selectedPhotoIndex]
        : null;

    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: !_isDrawingCota && _activeDragHandle == null && _currentScale > 1.05,
            scaleEnabled: !_isDrawingCota && _activeDragHandle == null,
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
                        // 1. Imagen técnica base
                        Image.memory(_currentImageBytes!, fit: BoxFit.contain),

                        // 2. Capa de Cotas (dimensiones con cotas y flechas - Req. 7)
                        if (_linearMeasurements.isNotEmpty || _isDrawingCota)
                          CustomPaint(
                            size: canvasSize,
                            painter: MeasurementLinesPainter(
                              measurements: _linearMeasurements,
                              selectedMeasurementId: _isExportingForSave ? null : _selectedMeasurementId,
                              guidedOriginA: _guidedOriginA,
                              currentEnd: _guidedTargetB,
                            ),
                          ),

                        // 3. Sensor táctil sobre el lienzo (Manejo de pines flotantes y secuencia de cotas)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final pos = details.localPosition;

                              // MODO COTA: Trazado en dos toques
                              // Toque 1 ubica primer punto, toque 2 ubica destino y abre valor
                              if (_isDrawingCota) {
                                if (_guidedOriginA == null) {
                                  setState(() {
                                    _guidedOriginA = pos;
                                    _guidedTargetB = pos;
                                    _isGuidingOriginA = false;
                                    _isGuidingDestinationB = true;
                                  });
                                  HapticFeedback.lightImpact();
                                } else {
                                  setState(() {
                                    _guidedTargetB = pos;
                                  });
                                  HapticFeedback.mediumImpact();
                                  _completeDeskCotaCreation(_guidedOriginA!, pos);
                                }
                                return;
                              }

                              // Verificar si tocó una cota existente
                              final nearestCota = _findNearestCota(pos, maxDistance: 28.0);
                              if (nearestCota != null) {
                                final mid = Offset(
                                  (nearestCota.startOffset.dx + nearestCota.endOffset.dx) / 2,
                                  (nearestCota.startOffset.dy + nearestCota.endOffset.dy) / 2,
                                );
                                // Si tocó el valor central -> Editar valor / material
                                if ((pos - mid).distance <= 26.0) {
                                  _editCotaMaterial(nearestCota);
                                } else {
                                  // Seleccionar cota
                                  setState(() {
                                    _selectedMeasurementId = nearestCota.id;
                                    _floatingPinMenuPos = null;
                                  });
                                  HapticFeedback.selectionClick();
                                }
                                return;
                              }

                              // "Si toco fuera de la flecha debe dejar el modo edicion de cota"
                              if (_selectedMeasurementId != null) {
                                setState(() {
                                  _selectedMeasurementId = null;
                                  _activeDragHandle = null;
                                });
                                return;
                              }

                              // "Toco una zona de la imagen y me deben aparecer como boton flotante: Estructura, Material o Peligro SST"
                              setState(() {
                                _floatingPinMenuPos = pos;
                              });
                              HapticFeedback.selectionClick();
                            },
                            onLongPressStart: (details) {
                              final pos = details.localPosition;

                              // "Si mantengo presionado la flecha debe aparecer el menú contextual editar o borrar."
                              final nearestCota = _findNearestCota(pos, maxDistance: 32.0);
                              if (nearestCota != null) {
                                if ((pos - nearestCota.startOffset).distance <= 28.0) {
                                  // Manija origen A: Lupa de precisión
                                  setState(() {
                                    _selectedMeasurementId = nearestCota.id;
                                    _activeDragHandle = 'A';
                                    _showLoupe = true;
                                    _loupeFocalPoint = nearestCota.startOffset;
                                  });
                                  HapticFeedback.selectionClick();
                                  return;
                                } else if ((pos - nearestCota.endOffset).distance <= 28.0) {
                                  // Manija destino B: Lupa de precisión
                                  setState(() {
                                    _selectedMeasurementId = nearestCota.id;
                                    _activeDragHandle = 'B';
                                    _showLoupe = true;
                                    _loupeFocalPoint = nearestCota.endOffset;
                                  });
                                  HapticFeedback.selectionClick();
                                  return;
                                } else {
                                  // Presión sobre la flecha/recta: Menú contextual Editar o Borrar
                                  HapticFeedback.mediumImpact();
                                  _showCotaContextMenu(nearestCota);
                                  return;
                                }
                              }

                              // "Si mantengo presionado el punto de origen o destino me debe aparecer la lupa para posicionamiento con mayor precisión."
                              if (_isDrawingCota) {
                                setState(() {
                                  _showLoupe = true;
                                  _loupeFocalPoint = pos;
                                  if (_guidedOriginA == null) {
                                    _guidedOriginA = pos;
                                    _guidedTargetB = pos;
                                    _isGuidingOriginA = true;
                                  } else {
                                    _guidedTargetB = pos;
                                    _isGuidingDestinationB = true;
                                  }
                                });
                                HapticFeedback.selectionClick();
                              }
                            },
                            onLongPressMoveUpdate: (details) {
                              final pos = details.localPosition;
                              if (_showLoupe) {
                                setState(() {
                                  _loupeFocalPoint = pos;
                                  if (_isDrawingCota) {
                                    if (_isGuidingOriginA) {
                                      _guidedOriginA = pos;
                                      _guidedTargetB = pos;
                                    } else if (_isGuidingDestinationB) {
                                      _guidedTargetB = pos;
                                    }
                                  } else if (_selectedMeasurementId != null && _activeDragHandle != null) {
                                    final idx = _linearMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                    if (idx != -1) {
                                      final sel = _linearMeasurements[idx];
                                      if (_activeDragHandle == 'A') {
                                        _linearMeasurements[idx] = sel.copyWith(startOffset: pos);
                                      } else if (_activeDragHandle == 'B') {
                                        _linearMeasurements[idx] = sel.copyWith(endOffset: pos);
                                      }
                                    }
                                  }
                                });
                              }
                            },
                            onLongPressEnd: (details) async {
                              if (_showLoupe) {
                                setState(() => _showLoupe = false);
                              }
                              if (_activeDragHandle != null) {
                                setState(() => _activeDragHandle = null);
                                HapticFeedback.lightImpact();
                              } else if (_isDrawingCota && _guidedOriginA != null && _guidedTargetB != null) {
                                if ((_guidedTargetB! - _guidedOriginA!).distance > 18.0) {
                                  await _completeDeskCotaCreation(_guidedOriginA!, _guidedTargetB!);
                                }
                              }
                            },
                            onScaleStart: (details) {
                              if (details.pointerCount >= 2) return;
                              final pos = details.localFocalPoint;
                              if (_isDrawingCota) {
                                setState(() {
                                  _showLoupe = true;
                                  _loupeFocalPoint = pos;
                                  if (_guidedOriginA == null) {
                                    _guidedOriginA = pos;
                                    _guidedTargetB = pos;
                                    _isGuidingOriginA = true;
                                  } else {
                                    _guidedTargetB = pos;
                                    _isGuidingDestinationB = true;
                                  }
                                });
                              } else if (_selectedMeasurementId != null) {
                                final idx = _linearMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                if (idx != -1) {
                                  final sel = _linearMeasurements[idx];
                                  if ((pos - sel.startOffset).distance <= 28.0) {
                                    _activeDragHandle = 'A';
                                    _showLoupe = true;
                                    _loupeFocalPoint = sel.startOffset;
                                  } else if ((pos - sel.endOffset).distance <= 28.0) {
                                    _activeDragHandle = 'B';
                                    _showLoupe = true;
                                    _loupeFocalPoint = sel.endOffset;
                                  }
                                }
                              }
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount >= 2) return;
                              final pos = details.localFocalPoint;
                              if (_isDrawingCota) {
                                setState(() {
                                  _loupeFocalPoint = pos;
                                  _guidedTargetB = pos;
                                });
                              } else if (_selectedMeasurementId != null && _activeDragHandle != null) {
                                final idx = _linearMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                if (idx != -1) {
                                  final sel = _linearMeasurements[idx];
                                  setState(() {
                                    _loupeFocalPoint = pos;
                                    if (_activeDragHandle == 'A') {
                                      _linearMeasurements[idx] = sel.copyWith(startOffset: pos);
                                    } else if (_activeDragHandle == 'B') {
                                      _linearMeasurements[idx] = sel.copyWith(endOffset: pos);
                                    }
                                  });
                                }
                              }
                            },
                            onScaleEnd: (details) async {
                              if (_activeDragHandle != null) {
                                setState(() {
                                  _activeDragHandle = null;
                                  _showLoupe = false;
                                });
                                HapticFeedback.lightImpact();
                                return;
                              }
                              if (_isDrawingCota) {
                                setState(() => _showLoupe = false);
                                if (_guidedOriginA != null && _guidedTargetB != null) {
                                  final dist = (_guidedTargetB! - _guidedOriginA!).distance;
                                  if (dist > 18.0) {
                                    await _completeDeskCotaCreation(_guidedOriginA!, _guidedTargetB!);
                                  }
                                }
                              }
                            },
                          ),
                        ),

                        // 4. Capa de Pines Numerados Interactivos (siempre visibles en la foto - Req. 7)
                        ..._placedPins.asMap().entries.map((entry) {
                          final pin = entry.value;
                          final catNum = _getCategoryPinNumber(pin);

                          return Positioned(
                            left: pin.position.dx - 18,
                            top: pin.position.dy - 18,
                            child: GestureDetector(
                              behavior: _displayMode == DeskDisplayMode.pines
                                  ? HitTestBehavior.opaque
                                  : HitTestBehavior.translucent,
                              onPanUpdate: _displayMode == DeskDisplayMode.pines && !_isDrawingCota
                                  ? (details) {
                                      setState(() {
                                        final newX = (pin.position.dx + details.delta.dx).clamp(16.0, canvasSize.width - 16.0);
                                        final newY = (pin.position.dy + details.delta.dy).clamp(16.0, canvasSize.height - 52.0);
                                        pin.position = Offset(newX, newY);
                                      });
                                    }
                                  : null,
                              onTap: _isDrawingCota ? null : () => _showPinOptionsModal(pin),
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

                        // Ficha técnica ultra-compacta dentro de la foto
                        Positioned(
                          top: 6,
                          left: 6,
                          child: IgnorePointer(
                            ignoring: true,
                            child: CompactPhotoInfoBadge(
                              proyecto: _sessionModel.project.proyecto,
                              contacto: _sessionModel.project.contacto,
                              ambiente: activePhoto?.areaSector ?? 'Ambiente #${_selectedPhotoIndex + 1}',
                              fecha: _sessionModel.project.fecha,
                              photoNumber: _selectedPhotoIndex + 1,
                            ),
                          ),
                        ),

                        // 5. Leyenda Técnica Translúcida integrada dentro de la foto (Pie de página garantizado)
                        if (_showLegendPreview && (_placedPins.isNotEmpty || _linearMeasurements.isNotEmpty))
                          Positioned(
                            bottom: 5,
                            left: 5,
                            right: 5,
                            child: IgnorePointer(
                              ignoring: true,
                              child: _buildInPhotoTranslucentLegend(),
                            ),
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

                        // 7. Lupa de precisión al trazar o mover manija de cota
                        if (!_isExportingForSave && _showLoupe && _loupeFocalPoint != null)
                          LoupeMagnifierWidget(
                            touchPosition: _loupeFocalPoint!,
                            canvasSize: canvasSize,
                            accentColor: const Color(0xFFE3A51A),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Botón flotante para restablecer zoom a 1.0x si está ampliado (Req. 1)
        if (_currentScale > 1.05)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: const Color(0xFF1E293B).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _resetZoom,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map, size: 14, color: Color(0xFF38BDF8)),
                      SizedBox(width: 4),
                      Text(
                        '1.0x',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Banner flotante superior de guía de cota activa en gabinete
        if (_isDrawingCota)
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
                          _isDrawingCota = false;
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
    );
  }

  /// Finaliza la captura de una cota en gabinete y abre el modal técnico
  Future<void> _completeDeskCotaCreation(Offset start, Offset end) async {
    setState(() {
      _isDrawingCota = false;
      _isGuidingOriginA = false;
      _isGuidingDestinationB = false;
      _guidedOriginA = null;
      _guidedTargetB = null;
      _showLoupe = false;
    });

    final conduits = TechnicalCatalogMatrix.materialesPorClasificacion[_sessionModel.project.clasificacion] ??
        ['Tubo EMT 3/4"', 'Canaleta 40x25', 'Tubo PVC SAP 3/4"'];

    final result = await showDialog<MeasurementModalResult>(
      context: context,
      builder: (ctx) => MeasurementCaptureModal(
        start: start,
        end: end,
        contextualConduits: conduits,
        voiceService: _voiceService,
        clasificacion: _sessionModel.project.clasificacion,
        allAvailableMaterials: _catalogs['materiales'],
      ),
    );

    if (result != null &&
        result.action == MeasurementModalAction.saved &&
        result.measurement != null) {
      setState(() {
        _linearMeasurements.add(result.measurement!);
        _selectedMeasurementId = result.measurement!.id;
        _displayMode = DeskDisplayMode.medidas;
      });
      HapticFeedback.mediumImpact();
    }
  }

  /// Distintivo HUD traslúcido para pines sobre la foto (Norma técnica VISTEC previa)
  Widget _buildPinBadgeWidget(StickerCategory category, int number) {
    switch (category) {
      case StickerCategory.peligros:
        // ▲ TRIÁNGULO AMARILLO DE ADVERTENCIA VIBRANTE (Lente translúcido de alta visibilidad)
        return SizedBox(
          width: 20,
          height: 18,
          child: CustomPaint(
            painter: WarningTrianglePainter(
              fillColor: const Color(0x35FFD600), // ~20% opacidad translúcida
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
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 2.5),
                      Shadow(color: Colors.black, blurRadius: 4.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      case StickerCategory.estructuras:
        // ■ CUADRADO AZUL TÉCNICO VIBRANTE (Lente translúcido cristalino)
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0x3000B0FF),
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: const Color(0xFF00B0FF),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 8.5,
                height: 1.0,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 2.5),
                  Shadow(color: Colors.black, blurRadius: 4.0),
                ],
              ),
            ),
          ),
        );

      case StickerCategory.materiales:
        // ● CÍRCULO VERDE NEÓN VIBRANTE (Lente translúcido cristalino)
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0x3000E676),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00E676),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 8.5,
                height: 1.0,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 2.5),
                  Shadow(color: Colors.black, blurRadius: 4.0),
                ],
              ),
            ),
          ),
        );
    }
  }



  /// Leyenda técnica translúcida dentro de la fotografía
  Widget _buildInPhotoTranslucentLegend() {
    if (_placedPins.isEmpty && _linearMeasurements.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<MapEntry<int, PlacedSticker>> sstPins = [];
    final List<MapEntry<int, PlacedSticker>> matPins = [];
    final List<MapEntry<int, PlacedSticker>> structPins = [];

    for (int i = 0; i < _placedPins.length; i++) {
      final s = _placedPins[i];
      if (s.sticker.category == StickerCategory.peligros) {
        sstPins.add(MapEntry(i, s));
      } else if (s.sticker.category == StickerCategory.materiales) {
        matPins.add(MapEntry(i, s));
      } else {
        structPins.add(MapEntry(i, s));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_bulleted, color: Color(0xFF38BDF8), size: 9),
              const SizedBox(width: 3),
              Text(
                'PINES Y COTAS (${_placedPins.length + _linearMeasurements.length})',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 7.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              const Text(
                'Desarrollado por: Fedor Corzano',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 6.0,
                  fontStyle: FontStyle.italic,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // 1. Peligros / SST (▲ Triángulos Amarillos)
          if (sstPins.isNotEmpty) ...[
            _buildInPhotoCategoryChipsRow(
              categoryColor: const Color(0xFFFFD600),
              pins: sstPins,
            ),
          ],

          // 2. Materiales (● Círculos Verdes)
          if (matPins.isNotEmpty) ...[
            if (sstPins.isNotEmpty) const SizedBox(height: 1.2),
            _buildInPhotoCategoryChipsRow(
              categoryColor: const Color(0xFF00E676),
              pins: matPins,
            ),
          ],

          // 3. Estructuras (■ Cuadrados Azules)
          if (structPins.isNotEmpty) ...[
            if (sstPins.isNotEmpty || matPins.isNotEmpty) const SizedBox(height: 1.2),
            _buildInPhotoCategoryChipsRow(
              categoryColor: const Color(0xFF00B0FF),
              pins: structPins,
            ),
          ],

          // 4. Medidas / Cotas
          if (_linearMeasurements.isNotEmpty) ...[
            if (sstPins.isNotEmpty || matPins.isNotEmpty || structPins.isNotEmpty) const SizedBox(height: 1.2),
            _buildInPhotoMeasurementsLegendRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildInPhotoCategoryChipsRow({
    required Color categoryColor,
    required List<MapEntry<int, PlacedSticker>> pins,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 1.5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in pins) ...[
          Builder(
            builder: (context) {
              final placed = entry.value;
              final catNumber = _getCategoryPinNumber(placed);
              final isPriority = placed.sticker.category == StickerCategory.materiales &&
                  _isPriorityMaterial(placed.sticker.title);

              return InkWell(
                onTap: () => _showPinOptionsModal(placed),
                borderRadius: BorderRadius.circular(3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPinBadgeWidget(placed.sticker.category, catNumber),
                      const SizedBox(width: 3.5),
                      Text(
                        isPriority ? '${placed.sticker.title} ★' : placed.sticker.title,
                        style: TextStyle(
                          color: isPriority ? const Color(0xFFFBBF24) : Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildInPhotoMeasurementsLegendRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 1.5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < _linearMeasurements.length; i++) ...[
          Builder(
            builder: (context) {
              final m = _linearMeasurements[i];
              return InkWell(
                onTap: () => _showCotaContextMenu(m),
                borderRadius: BorderRadius.circular(3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3A51A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '[${i + 1}]',
                          style: const TextStyle(
                            color: Color(0xFF001F2F),
                            fontWeight: FontWeight.w900,
                            fontSize: 6.0,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        '${m.labelDistanceOnly} • ${m.material.isEmpty ? "Por definir" : m.material}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDeskToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: Botones según el modo activo
          if (_displayMode == DeskDisplayMode.pines)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAddButton(
                  label: '+ Estructura',
                  icon: Icons.foundation,
                  color: const Color(0xFF00B0FF),
                  onTap: () => _openAddPinSelector(StickerCategory.estructuras),
                ),
                _buildQuickAddButton(
                  label: '+ Material ★',
                  icon: Icons.hardware,
                  color: const Color(0xFF00E676),
                  onTap: () => _openAddPinSelector(StickerCategory.materiales),
                ),
                _buildQuickAddButton(
                  label: '+ Peligro SST',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFFBBF24),
                  onTap: () => _openAddPinSelector(StickerCategory.peligros),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuickAddButton(
                  label: _isDrawingCota ? '✕ Cancelar Trazo' : '+ Trazar Cota de Medida',
                  icon: Icons.straighten,
                  color: const Color(0xFFE3A51A),
                  onTap: () {
                    setState(() {
                      _isDrawingCota = !_isDrawingCota;
                      _guidedOriginA = null;
                      _guidedTargetB = null;
                      _isGuidingOriginA = false;
                      _isGuidingDestinationB = false;
                      _showLoupe = false;
                    });
                  },
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Fila 2: Botón de Avance a Pantalla 5
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToReportsAndSstControl,
              icon: const Icon(Icons.assignment_turned_in, color: Colors.white, size: 20),
              label: const Text(
                'Generar Reportes y Control SST ➔',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                elevation: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class WarningTrianglePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  WarningTrianglePainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;

    // Vértice superior centrado en (w/2, 0)
    path.moveTo(w / 2, 0);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Relleno de seguridad
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Borde de alerta
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
