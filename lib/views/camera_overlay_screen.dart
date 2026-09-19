import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../config/constants.dart';
import '../models/project_model.dart';
import '../models/session_evidence_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import 'project_summary_report_screen.dart';

/// Rota la imagen 90° en segundo plano en un Isolate para no bloquear la interfaz (evita ANR y OOM)
Uint8List? _performRotation(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final rotated = img.copyRotate(decoded, angle: 90);
    // Si la imagen rotada excede 1920px en alguna dimensión, la reescalamos proporcionalmente
    img.Image finalImage = rotated;
    if (rotated.width > 1920 || rotated.height > 1920) {
      finalImage = img.copyResize(
        rotated,
        width: rotated.width > rotated.height ? 1920 : null,
        height: rotated.height >= rotated.width ? 1920 : null,
      );
    }
    // Usar encodeJpg en lugar de encodePng: 10x más rápido y reduce drásticamente el consumo de RAM
    return Uint8List.fromList(img.encodeJpg(finalImage, quality: 88));
  } catch (e) {
    debugPrint('Error en rotación background: $e');
    return null;
  }
}

// ============================================================================
// 1. PALETA DE STICKERS DINÁMICOS DESDE EXCEL CON PESTAÑAS Y BUSCADOR
// ============================================================================

class StickerPaletteSheet extends StatefulWidget {
  final Map<String, List<String>> catalogs;
  final Function(StickerModel) onStickerSelected;
  final String? title;

  const StickerPaletteSheet({
    super.key,
    required this.catalogs,
    required this.onStickerSelected,
    this.title,
  });

  @override
  State<StickerPaletteSheet> createState() => _StickerPaletteSheetState();
}

class _StickerPaletteSheetState extends State<StickerPaletteSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filterList(List<String> items) {
    if (_searchQuery.trim().isEmpty) return items;
    return items
        .where((item) =>
            item.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final estructuras = widget.catalogs['estructuras'] ?? [];
    final materiales = widget.catalogs['materiales'] ?? [];
    final peligros = widget.catalogs['peligros'] ?? widget.catalogs['riesgos'] ?? [];

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Barra superior indicadora
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.label_important, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title ?? 'Seleccionar elemento desde Excel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Buscador
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar material, estructura o peligro...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF38BDF8), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Pestañas
            TabBar(
              indicatorColor: const Color(0xFF38BDF8),
              indicatorWeight: 3,
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  icon: const Icon(Icons.foundation, size: 18),
                  text: 'Estructuras (${estructuras.length})',
                ),
                Tab(
                  icon: const Icon(Icons.hardware, size: 18),
                  text: 'Materiales (${materiales.length})',
                ),
                Tab(
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  text: 'Peligros (${peligros.length})',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contenido de cada pestaña
            Expanded(
              child: TabBarView(
                children: [
                  _buildCatalogGrid(
                    items: _filterList(estructuras),
                    category: StickerCategory.estructuras,
                  ),
                  _buildCatalogGrid(
                    items: _filterList(materiales),
                    category: StickerCategory.materiales,
                  ),
                  _buildCatalogGrid(
                    items: _filterList(peligros),
                    category: StickerCategory.peligros,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogGrid({
    required List<String> items,
    required StickerCategory category,
  }) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron elementos.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final sticker = StickerModel.fromCatalog(item, category);
          return InkWell(
            onTap: () => widget.onStickerSelected(sticker),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sticker.backgroundColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sticker.accentColor, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sticker.icon, color: sticker.accentColor, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// 2. PANTALLA PRINCIPAL DE CÁMARA Y OVERLAY DE STICKERS
// ============================================================================

class CameraOverlayScreen extends StatefulWidget {
  final ProjectModel project;
  final Uint8List? initialImageBytes;

  const CameraOverlayScreen({
    super.key,
    required this.project,
    this.initialImageBytes,
  });

  @override
  State<CameraOverlayScreen> createState() => _CameraOverlayScreenState();
}

class _CameraOverlayScreenState extends State<CameraOverlayScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final ImagePicker _imagePicker = ImagePicker();

  final TransformationController _transformationController = TransformationController();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _cameraError = false;

  Uint8List? _capturedImageBytes;
  double _imageAspectRatio = 9 / 16; // Proporción adaptable horizontal o vertical
  bool _isProcessing = false;
  final List<PlacedSticker> _placedStickers = [];

  // Sesión continua multiproyecto (VISTEC V2 & V3)
  int _sessionPhotoNumber = 1;
  int _savedPhotosCount = 0;
  late final ProjectSessionModel _sessionModel;

  Map<String, List<String>> _catalogs = {
    'estructuras': TechnicalCatalogMatrix.defaultEstructuras,
    'materiales': TechnicalCatalogMatrix.defaultMateriales,
    'peligros': [
      'Riesgo Eléctrico',
      'Trabajo en Altura',
      'Piso irregular / Objeto en el suelo',
      'Falta de Señalización',
      'Falta de Orden y Limpieza',
    ],
  };

  @override
  void initState() {
    super.initState();
    _sessionModel = ProjectSessionModel(project: widget.project);
    if (widget.initialImageBytes != null) {
      _capturedImageBytes = widget.initialImageBytes;
      _updateImageAspectRatio(widget.initialImageBytes!);
    }
    _initializeCamera();
    _loadCatalogsFromExcel();
  }

  Future<void> _updateImageAspectRatio(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      if (height > 0 && width > 0 && mounted) {
        setState(() {
          _imageAspectRatio = width / height;
        });
        debugPrint('Dimensiones de foto calculadas: $width x $height (Ratio: $_imageAspectRatio)');
      }
    } catch (e) {
      debugPrint('Error al calcular relación de aspecto de la foto: $e');
    }
  }

  /// Rotar la foto capturada 90° en sentido horario para relevamiento panorámico horizontal
  Future<void> _rotateCapturedImage() async {
    if (_capturedImageBytes == null) return;
    setState(() => _isProcessing = true);
    try {
      final newBytes = await compute(_performRotation, _capturedImageBytes!);
      if (newBytes != null && mounted) {
        setState(() {
          _capturedImageBytes = newBytes;
          _placedStickers.clear();
          _resetZoom();
        });
        await _updateImageAspectRatio(newBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto rotada 90°. Encuadre panorámico ajustado.'),
              backgroundColor: Color(0xFF38BDF8),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error rotando imagen: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _loadCatalogsFromExcel() async {
    try {
      final data = await _sheetsService.fetchCatalogs();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _catalogs = data;
        });
      }
    } catch (e) {
      debugPrint('Error al precargar catálogos en cámara: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.veryHigh, // 1080p Full HD óptimo, sin fugas ni saturación de memoria
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraError = false;
          });
        }
      } else {
        setState(() => _cameraError = true);
      }
    } catch (e) {
      debugPrint('Error al inicializar cámara: $e');
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final Matrix4 current = _transformationController.value;
    final Matrix4 copy = Matrix4.copy(current)..scaleByVector3(Vector3(1.4, 1.4, 1.0));
    _transformationController.value = copy;
  }

  void _zoomOut() {
    final Matrix4 current = _transformationController.value;
    final Matrix4 copy = Matrix4.copy(current)..scaleByVector3(Vector3(0.714, 0.714, 1.0));
    _transformationController.value = copy;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();
      setState(() {
        _capturedImageBytes = bytes;
      });
      _updateImageAspectRatio(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _placedStickers.clear();
          _resetZoom();
        });
        _updateImageAspectRatio(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openStickerSelector({
    String? title,
    Offset? initialPosition,
    PlacedSticker? existingPin,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StickerPaletteSheet(
        title: title,
        catalogs: _catalogs,
        onStickerSelected: (StickerModel sticker) {
          Navigator.pop(ctx);
          setState(() {
            if (existingPin != null) {
              existingPin.sticker = sticker;
            } else {
              // Posicionar en el toque del usuario o en posición predeterminada
              final Offset pos = initialPosition ?? const Offset(120, 200);
              _placedStickers.add(
                PlacedSticker(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  sticker: sticker,
                  position: pos,
                ),
              );
            }
          });
        },
      ),
    );
  }

  /// Confirmar finalización de la sesión multiproyecto
  Future<void> _confirmEndSession() async {
    final bool? end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.flag_circle, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Text('¿Finalizar Proyecto?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'Se han registrado exitosamente $_savedPhotosCount foto(s) para el proyecto "${widget.project.proyecto}".\n\n¿Deseas cerrar la sesión y regresar a la pantalla principal?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar sesión', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Finalizar Proyecto'),
          ),
        ],
      ),
    );

    if (end == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectSummaryReportScreen(session: _sessionModel),
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  /// Muestra el Kit Técnico de Herramientas y Accesorios deducidos en tiempo real
  void _showKitTecnicoSheet() {
    final estructurasTags = _placedStickers
        .where((s) => s.sticker.category == StickerCategory.estructuras)
        .map((s) => s.sticker.title)
        .toSet();

    final materialesTags = _placedStickers
        .where((s) => s.sticker.category == StickerCategory.materiales)
        .map((s) => s.sticker.title)
        .toSet();

    final tools = TechnicalCatalogMatrix.deduceHerramientas(
      estructuras: estructurasTags,
      materiales: materialesTags,
    );

    final accessories = TechnicalCatalogMatrix.deduceAccesorios(
      materiales: materialesTags,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.handyman, color: Color(0xFF38BDF8), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Kit Técnico Deducido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
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
              Text(
                'Herramientas y accesorios deducidos automáticamente a partir de los pines colocados en la Foto #$_sessionPhotoNumber',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildKitSection(
                      title: '🔩 Accesorios requeridos por Material (${accessories.length})',
                      color: const Color(0xFF10B981),
                      items: accessories,
                      emptyText: 'Coloca pines de Material (Canaletas, Tubo PVC/EMT, etc.) para vincular accesorios automáticamente.',
                    ),
                    const SizedBox(height: 16),
                    _buildKitSection(
                      title: '🛠️ Herramientas requeridas (${tools.length})',
                      color: const Color(0xFF38BDF8),
                      items: tools,
                      emptyText: 'Coloca pines de Estructura o Material para vincular herramientas de instalación.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKitSection({
    required String title,
    required Color color,
    required List<String> items,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.asMap().entries.map((e) {
                return Chip(
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                  avatar: CircleAvatar(
                    backgroundColor: color,
                    radius: 9,
                    child: Text(
                      '${e.key + 1}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    e.value,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Guarda la foto fusionada localmente en la carpeta designada y la sincroniza con Excel/Drive
  Future<void> _saveAndSyncEvidence() async {
    // 1. Asegurar que no haya teclados abiertos y restablecer zoom al encuadre completo al 100%
    FocusManager.instance.primaryFocus?.unfocus();
    _resetZoom();
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    // 2. Renderizar la imagen combinada con los stickers a resolución completa garantizada (1549 x 2560)
    // Se captura ANTES de abrir el diálogo de sector para que el teclado en pantalla no comprima el viewport vertical
    RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo encontrar el contexto visual para renderizar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Esperar si la dimensión estuviese comprimida momentáneamente
    int retries = 0;
    while (boundary.size.shortestSide < 100 && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      retries++;
    }
    if (!mounted) return;

    // Calcular escala optimizada HD (~1280 px) para sincronización ultra-rápida y reportes livianos
    final double maxDimension = math.max(boundary.size.width, boundary.size.height);
    final double targetRatio = (maxDimension > 0)
        ? (1280.0 / maxDimension).clamp(1.0, 2.0)
        : 1.5;

    Uint8List pngBytes;
    Uint8List clientPngBytes;
    try {
      // 2.1 Imagen completa para Gestor de Proyectos (todos los pines y metadata en formato liviano)
      ui.Image image = await boundary.toImage(pixelRatio: targetRatio);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Error al codificar imagen combinada en PNG.');
      }
      pngBytes = byteData.buffer.asUint8List();
      clientPngBytes = pngBytes; // Por defecto
      debugPrint('Imagen optimizada capturada: ${image.width} x ${image.height} (${(pngBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)');

      // 2.2 Imagen exclusiva para Cliente (SOLO marcadores de seguridad SST)
      final allStickersBackup = List<PlacedSticker>.from(_placedStickers);
      final hasNonSafety = _placedStickers.any((s) => s.sticker.category != StickerCategory.peligros);
      if (hasNonSafety) {
        setState(() {
          _placedStickers.removeWhere((s) => s.sticker.category != StickerCategory.peligros);
        });
        await Future.delayed(const Duration(milliseconds: 30));
        ui.Image clientImg = await boundary.toImage(pixelRatio: targetRatio);
        ByteData? clientBd = await clientImg.toByteData(format: ui.ImageByteFormat.png);
        if (clientBd != null) {
          clientPngBytes = clientBd.buffer.asUint8List();
          debugPrint('Imagen exclusiva de cliente SST capturada: ${clientImg.width} x ${clientImg.height}');
        }
        setState(() {
          _placedStickers.clear();
          _placedStickers.addAll(allStickersBackup);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al renderizar imagen: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;

    // 3. Solicitar nombre de Área / Sector opcional (o Foto #N por defecto)
    final TextEditingController areaController = TextEditingController();
    final bool? confirmSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_photo_alternate, color: Color(0xFF38BDF8), size: 24),
            const SizedBox(width: 10),
            Text(
              'Guardar Foto #$_sessionPhotoNumber',
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proyecto: ${widget.project.proyecto}',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nombre de Área / Sector (Opcional):',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: areaController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ej. Fachada Principal (Defecto: Foto #$_sessionPhotoNumber)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            // Mini resumen de vinculaciones
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 Pines colocados: ${_placedStickers.length}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🔩 Accesorios deducidos: ${TechnicalCatalogMatrix.deduceAccesorios(materiales: _placedStickers.where((s) => s.sticker.category == StickerCategory.materiales).map((s) => s.sticker.title)).length}',
                    style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11),
                  ),
                  Text(
                    '🛠️ Herramientas deducidas: ${TechnicalCatalogMatrix.deduceHerramientas(estructuras: _placedStickers.where((s) => s.sticker.category == StickerCategory.estructuras).map((s) => s.sticker.title), materiales: _placedStickers.where((s) => s.sticker.category == StickerCategory.materiales).map((s) => s.sticker.title)).length}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Subir y Guardar'),
          ),
        ],
      ),
    );

    if (confirmSave != true) return;

    final String finalAreaSector = areaController.text.trim().isEmpty
        ? 'Foto #$_sessionPhotoNumber'
        : areaController.text.trim();

    setState(() => _isProcessing = true);

    try {

      // 3. Almacenar la imagen en la carpeta designada del dispositivo móvil
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory designatedFolder =
          Directory('${appDir.path}/${Constants.localFolderName}');
      if (!await designatedFolder.exists()) {
        await designatedFolder.create(recursive: true);
      }

      final String cleanContact = widget.project.contacto
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final String cleanArea = finalAreaSector
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final String timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
      final String localFileName = 'VISTE_${cleanContact}_Foto${_sessionPhotoNumber}_${cleanArea}_$timestamp.png';
      final File localFile = File('${designatedFolder.path}/$localFileName');
      await localFile.writeAsBytes(pngBytes);
      final String localFilePath = localFile.path;
      debugPrint('Imagen guardada localmente en: $localFilePath');

      // 4. Extraer etiquetas colocadas
      final List<String> peligrosTags = _placedStickers
          .where((s) => s.sticker.category == StickerCategory.peligros)
          .map((s) => s.sticker.title)
          .toSet()
          .toList();

      final List<String> estructurasTags = _placedStickers
          .where((s) => s.sticker.category == StickerCategory.estructuras)
          .map((s) => TechnicalCatalogMatrix.formatTitleCase(s.sticker.title))
          .toSet()
          .toList();

      final List<String> materialesTags = _placedStickers
          .where((s) => s.sticker.category == StickerCategory.materiales)
          .map((s) => TechnicalCatalogMatrix.formatTitleCase(s.sticker.title))
          .toSet()
          .toList();

      // 5. Deducir herramientas y accesorios automáticamente (VISTEC V2)
      final List<String> deducedHerramientas = TechnicalCatalogMatrix.deduceHerramientas(
        estructuras: estructurasTags,
        materiales: materialesTags,
      );

      final List<String> deducedAccesorios = TechnicalCatalogMatrix.deduceAccesorios(
        materiales: materialesTags,
      );

      // Registrar evidencia en la sesión consolidada (VISTEC V3)
      _sessionModel.addPhoto(
        SessionEvidenceRecord(
          photoNumber: _sessionPhotoNumber,
          areaSector: finalAreaSector,
          localImagePath: localFilePath,
          pngBytes: pngBytes,
          clientPngBytes: clientPngBytes,
          estructuras: estructurasTags,
          materiales: materialesTags,
          peligros: peligrosTags,
          herramientas: deducedHerramientas,
          accesorios: deducedAccesorios,
          timestamp: DateTime.now(),
        ),
      );

      // 6. Preparar modelo con foto Base64 y metadatos completos
      final String base64Image = base64Encode(pngBytes);
      final ProjectModel finalProject = widget.project.copyWith(
        fotoBase64: base64Image,
        localImagePath: localFilePath,
        peligros: peligrosTags,
        estructuras: estructurasTags,
        materiales: materialesTags,
        numFoto: _sessionPhotoNumber,
        areaSector: finalAreaSector,
        herramientas: deducedHerramientas,
        accesorios: deducedAccesorios,
      );

      // 7. Enviar a Google Apps Script para almacenar en Drive y registrar en Excel
      final syncResult = await _sheetsService.syncProject(finalProject);

      if (!mounted) return;

      if (syncResult.isSuccess) {
        // Mostrar diálogo de decisión de sesión (Siguiente Foto vs Finalizar Proyecto)
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Foto #$_sessionPhotoNumber Registrada!',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sector: "$finalAreaSector" guardado exitosamente en el proyecto.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.folder_special,
                    label: 'Archivo local guardado:',
                    value: localFilePath,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.table_chart,
                    label: 'Google Sheets ("Proyectos_Terreno"):',
                    value: 'Foto #$_sessionPhotoNumber • Accesorios: ${deducedAccesorios.length} • Herramientas: ${deducedHerramientas.length}',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.cloud_done,
                    label: 'Dirección en Drive:',
                    value: syncResult.message,
                  ),
                  if (deducedAccesorios.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.category,
                      label: 'Accesorios deducidos:',
                      value: deducedAccesorios.join(', '),
                    ),
                  ],
                  if (deducedHerramientas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.handyman,
                      label: 'Herramientas deducidas:',
                      value: deducedHerramientas.join(', '),
                    ),
                  ],
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('🏁 Finalizar Proyecto'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectSummaryReportScreen(session: _sessionModel),
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(context, true); // Retorna a form_screen indicando fin de proyecto
                  }
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text(
                  '📸 Siguiente Foto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _savedPhotosCount++;
                    _sessionPhotoNumber++;
                    _capturedImageBytes = null;
                    _placedStickers.clear();
                    _resetZoom();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Listo para capturar Foto #$_sessionPhotoNumber'),
                      backgroundColor: const Color(0xFF38BDF8),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar con Excel: ${syncResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ocurrió un error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _capturedImageBytes == null
                  ? 'Cámara • Foto #$_sessionPhotoNumber'
                  : 'Edición • Foto #$_sessionPhotoNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.project.proyecto} • Sesión ($_savedPhotosCount guardadas)',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_sessionModel.totalPhotos > 0) ...[
            IconButton(
              icon: const Icon(Icons.assessment_outlined, color: Color(0xFF38BDF8)),
              tooltip: 'Ver Resumen y Reportes PDF',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectSummaryReportScreen(session: _sessionModel),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.flag_circle, color: Color(0xFF10B981), size: 18),
              label: const Text(
                'Finalizar',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: _confirmEndSession,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Cargar foto de la memoria / galería',
            onPressed: _pickFromGallery,
          ),
          if (_capturedImageBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Rotar foto 90° (Panorámica / Horizontal)',
              onPressed: _isProcessing ? null : _rotateCapturedImage,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.amberAccent),
              tooltip: 'Tomar otra foto con la cámara',
              onPressed: () {
                setState(() {
                  _capturedImageBytes = null;
                  _placedStickers.clear();
                  _resetZoom();
                });
              },
            ),
          ],
        ],
      ),
      body: _capturedImageBytes == null
          ? _buildCameraView()
          : _buildStickerEditorView(),
    );
  }

  Widget _buildCameraView() {
    if (_cameraError || (!_isCameraInitialized && _cameras?.isEmpty == true)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Cámara no disponible en este entorno',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes seleccionar una imagen desde la galería para continuar con el etiquetado de stickers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Abrir Galería de Fotos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(_cameraController!)),
        CustomPaint(painter: GridGuidePainter()),

        // Guía superior con nombre de proyecto
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Proyecto: ${widget.project.proyecto} • Foto #$_sessionPhotoNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botón obturador inferior
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón Galería
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.photo_library, color: Colors.white70),
                tooltip: 'Galería',
                onPressed: _pickFromGallery,
              ),

              // Disparador principal
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF38BDF8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF0F172A),
                      size: 38,
                    ),
                  ),
                ),
              ),

              // Placeholder balance
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickerEditorView() {
    return Column(
      children: [
        // Instrucción rápida
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          color: const Color(0xFF1E293B),
          child: const Text(
            '💡 Toca la foto para colocar un Pin (①, ②, ③). Toca un pin para cambiarlo o eliminarlo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Área de foto con stickers y zoom interactivo
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 6.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _imageAspectRatio,
                        child: RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              // Centrar el pin en el punto exacto del toque
                              final Offset tapPosition = Offset(
                                details.localPosition.dx,
                                details.localPosition.dy,
                              );
                              _openStickerSelector(
                                title: 'Añadir Pin #${_placedStickers.length + 1}',
                                initialPosition: tapPosition,
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_capturedImageBytes!, fit: BoxFit.fill),

                                // Marca de agua técnica ultra-compacta (mínima altura y fuentes pequeñas)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.verified,
                                              color: Color(0xFF38BDF8),
                                              size: 8,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'VISTE • ${widget.project.proyecto.toUpperCase()} • FOTO #$_sessionPhotoNumber',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.bold,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${widget.project.contacto} | ${widget.project.fecha}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 6.5,
                                            height: 1.0,
                                          ),
                                        ),
                                        if (widget.project.mapa.isNotEmpty && widget.project.mapa != '0.0, 0.0') ...[
                                          const SizedBox(height: 0.5),
                                          Text(
                                            'GPS: ${widget.project.mapa}',
                                            style: const TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 6.5,
                                              fontWeight: FontWeight.w500,
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                // Pines numerados colocados arrastrables (sin leyenda superpuesta dentro de la foto)
                                for (int i = 0; i < _placedStickers.length; i++)
                                  _buildNumberedPin(_placedStickers[i], i),

                                // Leyenda técnica ultra-compacta y translúcida al pie de la imagen
                                if (_placedStickers.isNotEmpty)
                                  Positioned(
                                    bottom: 5,
                                    left: 5,
                                    right: 5,
                                    child: _buildInPhotoTranslucentLegend(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Controles flotantes de Zoom en la esquina superior derecha
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_in, color: Color(0xFF38BDF8), size: 22),
                            tooltip: 'Acercar imagen (+)',
                            onPressed: _zoomIn,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                          Container(width: 1, height: 18, color: Colors.white24),
                          IconButton(
                            icon: const Icon(Icons.zoom_out, color: Color(0xFF38BDF8), size: 22),
                            tooltip: 'Alejar imagen (-)',
                            onPressed: _zoomOut,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                          Container(width: 1, height: 18, color: Colors.white24),
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong, color: Colors.white70, size: 20),
                            tooltip: 'Restablecer zoom (1x)',
                            onPressed: _resetZoom,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Barra inferior de controles
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Botón Añadir Pin
                ElevatedButton.icon(
                  onPressed: () => _openStickerSelector(
                    title: 'Añadir Pin #${_placedStickers.length + 1}',
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Pin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Botón Kit Técnico
                ElevatedButton.icon(
                  onPressed: _showKitTecnicoSheet,
                  icon: const Icon(Icons.handyman_outlined, size: 18, color: Color(0xFF38BDF8)),
                  label: const Text('Kit', style: TextStyle(color: Color(0xFF38BDF8))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Botón Cargar otra foto de la memoria
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white70, size: 22),
                  tooltip: 'Cargar otra foto de la memoria (Galería)',
                  onPressed: _pickFromGallery,
                ),
                const Spacer(),

                // Botón Guardar y Sincronizar
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _saveAndSyncEvidence,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isProcessing ? 'Guardando...' : 'Guardar Foto #$_sessionPhotoNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(StickerCategory category) {
    switch (category) {
      case StickerCategory.estructuras:
        return const Color(0xFF00B0FF); // Azul eléctrico ultra-vibrante
      case StickerCategory.materiales:
        return const Color(0xFF00E676); // Verde neón ultra-vibrante
      case StickerCategory.peligros:
        return const Color(0xFFFFD600); // Amarillo seguridad eléctrico y vibrante
    }
  }

  /// Construye el distintivo visual del Pin según su categoría y forma geométrica (Norma ISO 7010 / OSHA)
  /// Con lente HUD completamente translúcido (sin sombras que oscurezcan) para observar claramente las estructuras debajo.
  Widget _buildPinBadge(StickerCategory category, int number) {
    switch (category) {
      case StickerCategory.peligros:
        // ▲ TRIÁNGULO AMARILLO DE ADVERTENCIA VIBRANTE (Lente translúcido de alta visibilidad)
        return SizedBox(
          width: 18,
          height: 16,
          child: CustomPaint(
            painter: WarningTrianglePainter(
              fillColor: const Color(0x35FFD600), // ~20% de opacidad: se ve completamente la estructura detrás
              borderColor: const Color(0xFFFFD600), // Borde amarillo eléctrico de máxima visibilidad
              borderWidth: 1.3,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 3.5),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 8.0,
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0x3000B0FF), // ~19% de opacidad: cristalino sin fondo opaco
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: const Color(0xFF00B0FF), // Borde azul eléctrico de alto impacto
              width: 1.3,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 7.5,
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0x3000E676), // ~19% de opacidad: cristalino sin fondo opaco
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00E676), // Borde verde neón ultra-vibrante
              width: 1.3,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 7.5,
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

  /// Distintivo ampliado para la ventana modal de opciones del Pin
  Widget _buildModalPinBadge(StickerCategory category, int number) {
    switch (category) {
      case StickerCategory.peligros:
        return SizedBox(
          width: 44,
          height: 40,
          child: CustomPaint(
            painter: WarningTrianglePainter(
              fillColor: const Color(0xFFFFD600),
              borderColor: Colors.black,
              borderWidth: 2.2,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );

      case StickerCategory.estructuras:
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00B0FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                height: 1.0,
              ),
            ),
          ),
        );

      case StickerCategory.materiales:
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                height: 1.0,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildNumberedPin(PlacedSticker placed, int index) {
    // Zona táctil invisible de 36x36 px para tocar y arrastrar con máxima soltura sobre la pantalla táctil
    return Positioned(
      left: placed.position.dx - 18,
      top: placed.position.dy - 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            placed.position = Offset(
              placed.position.dx + details.delta.dx,
              placed.position.dy + details.delta.dy,
            );
          });
        },
        onTap: () {
          _showPinOptionsModal(placed, index);
        },
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          color: Colors.transparent, // Zona táctil de comodidad sin bordes rígidos
          child: _buildPinBadge(placed.sticker.category, index + 1),
        ),
      ),
    );
  }

  void _showPinOptionsModal(PlacedSticker placed, int index) {
    final Color categoryColor = _getCategoryColor(placed.sticker.category);
    final String categoryName = placed.sticker.category == StickerCategory.estructuras
        ? 'Estructura'
        : (placed.sticker.category == StickerCategory.materiales
            ? 'Material'
            : 'Peligro SST');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildModalPinBadge(placed.sticker.category, index + 1),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin #${index + 1} • $categoryName',
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          placed.sticker.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Botón Cambiar Valor
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openStickerSelector(
                    title: 'Cambiar elemento para el Pin #${index + 1}',
                    existingPin: placed,
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 22),
                label: const Text(
                  'Cambiar elemento (Seleccionar de Excel)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Botón Eliminar Pin
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _placedStickers.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pin #${index + 1} eliminado.'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                label: const Text(
                  'Eliminar este Pin',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Panel de Leyenda Ultra-Compacta y Translúcida dentro de la foto
  /// Diseñada con mínima altura, separación reducida y fondo al 48% para no obstruir las estructuras
  Widget _buildInPhotoTranslucentLegend() {
    final List<MapEntry<int, PlacedSticker>> sstPins = [];
    final List<MapEntry<int, PlacedSticker>> matPins = [];
    final List<MapEntry<int, PlacedSticker>> structPins = [];

    for (int i = 0; i < _placedStickers.length; i++) {
      final s = _placedStickers[i];
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
        color: Colors.black.withValues(alpha: 0.48), // Fondo translúcido para visibilidad
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
                'PINES RELEVADOS (${_placedStickers.length})',
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
      children: pins.map((entry) {
        final int index = entry.key;
        final PlacedSticker placed = entry.value;
        return InkWell(
          onTap: () => _showPinOptionsModal(placed, index),
          borderRadius: BorderRadius.circular(3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniLegendBadge(placed.sticker.category, index + 1),
                const SizedBox(width: 3.5),
                Text(
                  placed.sticker.title,
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
      }).toList(),
    );
  }

  /// Distintivo miniatura ultra-compacto para la leyenda al pie de la foto
  Widget _buildMiniLegendBadge(StickerCategory category, int number) {
    switch (category) {
      case StickerCategory.peligros:
        return SizedBox(
          width: 12,
          height: 11,
          child: CustomPaint(
            painter: WarningTrianglePainter(
              fillColor: const Color(0xFFFFD600),
              borderColor: Colors.black,
              borderWidth: 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 2.2),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 5.5,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );

      case StickerCategory.estructuras:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF00B0FF),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: Colors.white,
              width: 0.6,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 5.5,
                height: 1.0,
              ),
            ),
          ),
        );

      case StickerCategory.materiales:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 0.6,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 5.5,
                height: 1.0,
              ),
            ),
          ),
        );
    }
  }
}

/// Pintor geométrico del Triángulo Amarillo de Advertencia (Norma ISO 7010 / OSHA)
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

    // Relleno de seguridad (100% traslúcido sin sombra que oscurezca)
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

// Pintor de cuadrícula para composición fotográfica
class GridGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
