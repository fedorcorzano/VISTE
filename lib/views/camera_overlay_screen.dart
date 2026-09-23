import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';
import '../models/linear_measurement_model.dart';
import '../models/project_model.dart';
import '../models/session_evidence_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import '../services/project_storage_service.dart';
import '../services/ssoma_ai_service.dart';
import '../services/voice_recognition_service.dart';
import '../widgets/measurement_overlay_widget.dart';
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
  final int initialTabIndex;

  const StickerPaletteSheet({
    super.key,
    required this.catalogs,
    required this.onStickerSelected,
    this.title,
    this.initialTabIndex = 0,
  });

  @override
  State<StickerPaletteSheet> createState() => _StickerPaletteSheetState();
}

class _StickerPaletteSheetState extends State<StickerPaletteSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  bool _isListening = false;

  @override
  void dispose() {
    _searchController.dispose();
    if (_isListening) {
      _voiceService.stopListening();
    }
    super.dispose();
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      final available = await _voiceService.initialize();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Micrófono no disponible o permisos denegados'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (mounted) setState(() => _isListening = true);
      await _voiceService.startListening(
        onResult: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _searchController.text = words;
            _searchQuery = words;
            if (isFinal) {
              _isListening = false;
            }
          });
        },
      );
    }
  }

  List<String> _filterList(List<String> items) {
    if (_searchQuery.trim().isEmpty) return items;
    return items
        .where(
          (item) =>
              item.toLowerCase().contains(_searchQuery.toLowerCase().trim()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final estructuras = widget.catalogs['estructuras'] ?? [];
    final materiales = widget.catalogs['materiales'] ?? [];
    final peligros =
        widget.catalogs['peligros'] ?? widget.catalogs['riesgos'] ?? [];

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
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
                    widget.title ?? 'Seleccionar elemento',
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

            // Buscador con micrófono integrado para búsqueda por voz
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Escuchando tu voz...'
                    : 'Buscar o dictar por voz...',
                hintStyle: TextStyle(
                  color: _isListening ? const Color(0xFF38BDF8) : Colors.white38,
                  fontSize: 13,
                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                        size: 20,
                      ),
                      tooltip: _isListening ? 'Detener escucha' : 'Búsqueda por voz',
                      onPressed: _toggleVoiceSearch,
                    ),
                  ],
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _isListening
                      ? const BorderSide(color: Color(0xFF38BDF8), width: 1.5)
                      : BorderSide.none,
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.domain, size: 18),
                  text: 'Estructuras (${estructuras.length})',
                ),
                Tab(
                  icon: const Icon(Icons.construction, size: 18),
                  text: 'Materiales (${materiales.length})',
                ),
                Tab(
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  text: 'SSOMA (${peligros.length})',
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
  final ProjectSessionModel? existingSession;

  const CameraOverlayScreen({
    super.key,
    required this.project,
    this.initialImageBytes,
    this.existingSession,
  });

  @override
  State<CameraOverlayScreen> createState() => _CameraOverlayScreenState();
}

/// Modos excluyentes de visualización sobre la fotografía
enum OverlayDisplayMode { pines, medidas }

class _CameraOverlayScreenState extends State<CameraOverlayScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final ImagePicker _imagePicker = ImagePicker();

  final TransformationController _transformationController =
      TransformationController();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _cameraError = false;

  Uint8List? _capturedImageBytes;
  double _imageAspectRatio =
      9 / 16; // Proporción adaptable horizontal o vertical
  bool _isProcessing = false;
  final List<PlacedSticker> _placedStickers = [];

  // Modo de visualización excluyente: Pines vs Medidas
  OverlayDisplayMode _overlayMode = OverlayDisplayMode.pines;
  final List<LinearMeasurement> _linearMeasurements = [];
  Offset? _cotaDragStart;
  Offset? _cotaDragCurrent;
  bool _showLoupe = false;

  // Lupa táctica y retícula militar
  Offset? _loupeFocalPoint;
  String _loupeLabel = 'ORIGEN (A)';
  Color _loupeAccentColor = const Color(0xFF00E676);

  // Flujo guiado en 2 pasos con lupa (Paso 1: Origen A, Paso 2: Destino B)
  Offset? _guidedOriginA;
  Offset? _guidedTargetB;
  bool _isGuidingOriginA = false;
  bool _isGuidingDestinationB = false;

  /// Extrae materiales de canalización / tubería colocados como pines en la foto para el selector contextual
  List<String> _getContextualConduitMaterials() {
    final List<String> result = [];
    final placedMaterials = _placedStickers
        .where((s) => s.sticker.category == StickerCategory.materiales)
        .map((s) => s.sticker.title)
        .toSet();

    final conduitKeywords = ['TUBO', 'CANALETA', 'CONDUIT', 'BANDEJA', 'DUCTO', 'PVC', 'EMT'];
    for (final mat in placedMaterials) {
      final upper = mat.toUpperCase();
      if (conduitKeywords.any((k) => upper.contains(k))) {
        result.add(TechnicalCatalogMatrix.formatTitleCase(mat));
      }
    }
    return result;
  }

  // Cota seleccionada para centrado y edición de manijas A (Origen) y B (Destino)
  String? _selectedMeasurementId;
  bool _isDraggingHandleA = false;
  bool _isDraggingHandleB = false;

  LinearMeasurement? get _selectedMeasurement {
    if (_selectedMeasurementId == null) return null;
    try {
      return _linearMeasurements.firstWhere((m) => m.id == _selectedMeasurementId);
    } catch (_) {
      return null;
    }
  }

  /// Encuentra si un punto de toque colisiona con alguna cota o sus manijas
  int? _findHitMeasurementIndex(Offset tapPos) {
    for (int i = _linearMeasurements.length - 1; i >= 0; i--) {
      final m = _linearMeasurements[i];
      // 1. Manija A (Origen)
      if ((tapPos - m.startOffset).distance <= 34.0) {
        return i;
      }
      // 2. Manija B (Destino)
      if ((tapPos - m.endOffset).distance <= 34.0) {
        return i;
      }
      // 3. Etiqueta central de la cota
      final mid = Offset((m.startOffset.dx + m.endOffset.dx) / 2, (m.startOffset.dy + m.endOffset.dy) / 2);
      if ((tapPos - mid).distance <= 38.0) {
        return i;
      }
      // 4. Trazo lineal
      final distToLine = _distancePointToSegment(tapPos, m.startOffset, m.endOffset);
      if (distToLine <= 24.0) {
        return i;
      }
    }
    return null;
  }

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final double l2 = (b.dx - a.dx) * (b.dx - a.dx) + (b.dy - a.dy) * (b.dy - a.dy);
    if (l2 == 0) return (p - a).distance;
    final double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    final double clampedT = t.clamp(0.0, 1.0);
    final Offset projection = Offset(a.dx + clampedT * (b.dx - a.dx), a.dy + clampedT * (b.dy - a.dy));
    return (p - projection).distance;
  }

  /// Abre el diálogo para editar o eliminar una cota individual
  Future<void> _openEditMeasurementModal(LinearMeasurement m) async {
    final result = await showDialog<MeasurementModalResult>(
      context: context,
      builder: (ctx) => MeasurementCaptureModal(
        start: m.startOffset,
        end: m.endOffset,
        contextualConduits: _getContextualConduitMaterials(),
        voiceService: _voiceService,
        existingMeasurement: m,
      ),
    );

    if (result != null) {
      if (result.action == MeasurementModalAction.deleted) {
        setState(() {
          _linearMeasurements.removeWhere((item) => item.id == m.id);
          if (_selectedMeasurementId == m.id) {
            _selectedMeasurementId = null;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Cota eliminada correctamente.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else if (result.action == MeasurementModalAction.saved && result.measurement != null) {
        setState(() {
          final idx = _linearMeasurements.indexWhere((item) => item.id == m.id);
          if (idx != -1) {
            _linearMeasurements[idx] = result.measurement!;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Cota actualizada: ${result.measurement!.labelFormatted}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  /// Muestra una hoja inferior con el listado detallado de cotas, edición y eliminación individual
  void _showMeasurementsListSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
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
                      const Icon(Icons.straighten, color: Color(0xFFE3A51A), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cotas y Medidas Lineales',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_linearMeasurements.length} tramos • Total: ${_linearMeasurements.fold<double>(0.0, (acc, m) => acc + m.longitudMetros).toStringAsFixed(2)} m',
                              style: const TextStyle(color: Color(0xFFE3A51A), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_linearMeasurements.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No hay cotas registradas en esta foto.\nArrastra entre estructuras para añadir una.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _linearMeasurements.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (itemCtx, index) {
                          final m = _linearMeasurements[index];
                          final isSelected = m.id == _selectedMeasurementId;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F2744)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF334155),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3A51A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF001F2F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.longitudMetros.toStringAsFixed(2)} metros',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        m.material,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Botón Centrar / Ajustar manijas
                                IconButton(
                                  icon: const Icon(Icons.my_location, color: Color(0xFF38BDF8), size: 20),
                                  tooltip: 'Centrar y ajustar manijas A y B',
                                  onPressed: () {
                                    setState(() {
                                      _selectedMeasurementId = m.id;
                                    });
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('🎯 Cota #${index + 1} seleccionada. Arrastra las manijas A u B con la lupa.'),
                                        backgroundColor: const Color(0xFF0284C7),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                                // Botón Editar
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFE3A51A), size: 20),
                                  tooltip: 'Editar longitud o material',
                                  onPressed: () async {
                                    Navigator.pop(sheetCtx);
                                    await _openEditMeasurementModal(m);
                                  },
                                ),
                                // Botón Eliminar
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Eliminar cota',
                                  onPressed: () {
                                    setState(() {
                                      _linearMeasurements.removeAt(index);
                                      if (_selectedMeasurementId == m.id) {
                                        _selectedMeasurementId = null;
                                      }
                                    });
                                    setSheetState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Cota eliminada.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
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
      ),
    );
  }

  /// Banner flotante de asistencia técnica para el guiado milimétrico de cotas
  Widget _buildMeasurementStepGuidanceBanner() {
    if (_selectedMeasurementId != null) {
      return const SizedBox.shrink();
    }
    if (_guidedOriginA != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF001F2F).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00E676), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF00E676), size: 16),
              const SizedBox(width: 6),
              const Text(
                'Paso 2: Mantén presionado y guía hasta el Destino (B)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _guidedOriginA = null;
                    _guidedTargetB = null;
                  });
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Cancelar', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF001F2F).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3A51A), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.track_changes, color: Color(0xFFE3A51A), size: 16),
            SizedBox(width: 6),
            Text(
              'Paso 1: Mantén presionado y guía la lupa hasta el Origen (A)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sesión continua multiproyecto (VISTEC V2 & V3)
  int _sessionPhotoNumber = 1;
  int _savedPhotosCount = 0;
  late final ProjectSessionModel _sessionModel;

  // Reconocimiento de Voz y Asistente SSOMA IA
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();

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
    if (widget.existingSession != null) {
      _sessionModel = widget.existingSession!;
      _sessionPhotoNumber = _sessionModel.photos.length + 1;
      _savedPhotosCount = _sessionModel.photos.length;
    } else {
      _sessionModel = ProjectSessionModel(project: widget.project);
    }
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
        debugPrint(
          'Dimensiones de foto calculadas: $width x $height (Ratio: $_imageAspectRatio)',
        );
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
    _voiceService.cancelListening();
    _cameraController?.dispose();
    _transformationController.dispose();
    super.dispose();
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
    int initialTabIndex = 0,
    Offset? initialPosition,
    PlacedSticker? existingPin,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StickerPaletteSheet(
        title: title,
        initialTabIndex: initialTabIndex,
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
            Text(
              '¿Finalizar Proyecto?',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Se han registrado exitosamente $_savedPhotosCount foto(s) para el proyecto "${widget.project.proyecto}".\n\n¿Deseas cerrar la sesión y regresar a la pantalla principal?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Continuar sesión',
              style: TextStyle(color: Colors.white54),
            ),
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
          builder: (context) =>
              ProjectSummaryReportScreen(session: _sessionModel),
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // ==========================================================================
  // RECONOCIMIENTO Y BÚSQUEDA POR VOZ (MÓVIL & AUDÍFONOS/MANOS LIBRES BLUETOOTH)
  // ==========================================================================

  void _startVoiceRecognitionModal() async {
    final availableMateriales =
        _catalogs['materiales'] ?? TechnicalCatalogMatrix.defaultMateriales;
    final availableEstructuras =
        _catalogs['estructuras'] ?? TechnicalCatalogMatrix.defaultEstructuras;
    final availablePeligros =
        _catalogs['peligros'] ??
        [
          'Riesgo Eléctrico',
          'Trabajo en Altura',
          'Piso irregular / Objeto en el suelo',
          'Falta de Señalización',
          'Falta de Orden y Limpieza',
        ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String recognizedText = '';
        VoiceCatalogMatchResult? matchResult;
        bool isMicListening = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void startListeningInternal() async {
              setModalState(() {
                isMicListening = true;
                recognizedText = 'Escuchando... Di los materiales, estructuras o peligros...';
              });

              final initialized = await _voiceService.initialize();
              if (!initialized) {
                setModalState(() {
                  isMicListening = false;
                  recognizedText = 'No se pudo acceder al micrófono. Verifica permisos o compatibilidad del dispositivo.';
                });
                return;
              }

              await _voiceService.startListening(
                onResult: (words, isFinal) {
                  setModalState(() {
                    recognizedText = words;
                    matchResult = VoiceRecognitionService.matchVoiceToCatalog(
                      words,
                      availableMateriales: availableMateriales,
                      availableEstructuras: availableEstructuras,
                      availablePeligros: availablePeligros,
                    );
                    if (isFinal) {
                      isMicListening = false;
                    }
                  });
                },
              );
            }

            // Iniciar escucha automáticamente al abrir
            if (!isMicListening && recognizedText.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                startListeningInternal();
              });
            }

            final int totalMatches = matchResult?.totalMatches ?? 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF001F2F), // Azul Vigilarte
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3A51A)
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Color(0xFFE3A51A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Búsqueda & Selección por Voz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Micrófono del celular o Manos Libres Bluetooth',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () {
                            _voiceService.stopListening();
                            Navigator.pop(modalCtx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cuadro de texto reconocido en vivo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMicListening
                              ? const Color(0xFFE3A51A)
                              : const Color(0xFF334155),
                          width: isMicListening ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isMicListening
                                        ? Icons.hearing
                                        : Icons.mic_off,
                                    color: isMicListening
                                        ? const Color(0xFFE3A51A)
                                        : Colors.white38,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isMicListening
                                        ? 'Escuchando en vivo...'
                                        : 'Escucha en pausa',
                                    style: TextStyle(
                                      color: isMicListening
                                          ? const Color(0xFFE3A51A)
                                          : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (isMicListening)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recognizedText.isEmpty
                                ? 'Presiona el botón para hablar...'
                                : '"$recognizedText"',
                            style: TextStyle(
                              color: recognizedText.isEmpty
                                  ? Colors.white38
                                  : Colors.white,
                              fontSize: 13,
                              fontStyle: recognizedText.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título de elementos reconocidos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ELEMENTOS IDENTIFICADOS',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalMatches coincidencia(s)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Chips de elementos encontrados
                    Expanded(
                      child: totalMatches == 0
                          ? Center(
                              child: Text(
                                isMicListening
                                    ? 'Di por ejemplo:\n"Concreto, tubería EMT de una pulgada y riesgo eléctrico"'
                                    : 'No se detectaron coincidencias aún.\nToca el micrófono para hablar.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (matchResult!
                                      .matchedEstructuras
                                      .isNotEmpty) ...[
                                    const Text(
                                      'Estructuras:',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: matchResult!.matchedEstructuras
                                          .map(
                                            (e) => Chip(
                                              avatar: const Icon(
                                                Icons.foundation,
                                                size: 14,
                                                color: Color(0xFF38BDF8),
                                              ),
                                              label: Text(
                                                e,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: const Color(
                                                0xFF1E293B,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFF38BDF8),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (matchResult!
                                      .matchedMateriales
                                      .isNotEmpty) ...[
                                    const Text(
                                      'Materiales / Canalización:',
                                      style: TextStyle(
                                        color: Color(0xFF4ADE80),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: matchResult!.matchedMateriales
                                          .map(
                                            (m) => Chip(
                                              avatar: const Icon(
                                                Icons.hardware,
                                                size: 14,
                                                color: Color(0xFF4ADE80),
                                              ),
                                              label: Text(
                                                m,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: const Color(
                                                0xFF14532D,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFF4ADE80),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (matchResult!
                                      .matchedPeligros
                                      .isNotEmpty) ...[
                                    const Text(
                                      'Peligros Identificados:',
                                      style: TextStyle(
                                        color: Color(0xFFFBBF24),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: matchResult!.matchedPeligros
                                          .map(
                                            (p) => Chip(
                                              avatar: const Icon(
                                                Icons.warning_amber_rounded,
                                                size: 14,
                                                color: Color(0xFFFBBF24),
                                              ),
                                              label: Text(
                                                p,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: const Color(
                                                0xFF7C2D12,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFFBBF24),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Barra de acciones inferiores
                    Row(
                      children: [
                        // Botón de reintentar / hablar
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: isMicListening
                                ? Colors.redAccent
                                : const Color(0xFF334155),
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: Icon(
                            isMicListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                          ),
                          tooltip: isMicListening
                              ? 'Detener escucha'
                              : 'Hablar de nuevo',
                          onPressed: () {
                            if (isMicListening) {
                              _voiceService.stopListening();
                              setModalState(() => isMicListening = false);
                            } else {
                              startListeningInternal();
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        // Botón de inserción
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: totalMatches == 0
                                ? null
                                : () {
                                    _voiceService.stopListening();
                                    Navigator.pop(modalCtx);
                                    _applyVoiceMatchResult(matchResult!);
                                  },
                            icon: const Icon(Icons.add_task),
                            label: Text(
                              'Insertar Pines Detectados ($totalMatches)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE3A51A),
                              foregroundColor: const Color(0xFF001F2F),
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white30,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  /// Inserta de golpe los elementos reconocidos por voz, distribuyéndolos organizadamente en la foto
  void _applyVoiceMatchResult(VoiceCatalogMatchResult result) {
    setState(() {
      int index = 0;

      // Estructuras
      for (final item in result.matchedEstructuras) {
        final sticker = StickerModel.fromCatalog(
          item,
          StickerCategory.estructuras,
        );
        final offset = Offset(
          80.0 + (index % 3) * 100.0,
          160.0 + (index ~/ 3) * 70.0,
        );
        _placedStickers.add(
          PlacedSticker(
            id: '${DateTime.now().millisecondsSinceEpoch}_$index',
            sticker: sticker,
            position: offset,
          ),
        );
        index++;
      }

      // Materiales
      for (final item in result.matchedMateriales) {
        final sticker = StickerModel.fromCatalog(
          item,
          StickerCategory.materiales,
        );
        final offset = Offset(
          80.0 + (index % 3) * 100.0,
          160.0 + (index ~/ 3) * 70.0,
        );
        _placedStickers.add(
          PlacedSticker(
            id: '${DateTime.now().millisecondsSinceEpoch}_$index',
            sticker: sticker,
            position: offset,
          ),
        );
        index++;
      }

      // Peligros
      for (final item in result.matchedPeligros) {
        final sticker = StickerModel.fromCatalog(
          item,
          StickerCategory.peligros,
        );
        final offset = Offset(
          80.0 + (index % 3) * 100.0,
          160.0 + (index ~/ 3) * 70.0,
        );
        _placedStickers.add(
          PlacedSticker(
            id: '${DateTime.now().millisecondsSinceEpoch}_$index',
            sticker: sticker,
            position: offset,
          ),
        );
        index++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ ${result.totalMatches} pines agregados correctamente por voz.',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  // ==========================================================================
  // AGENTE AUDITOR SSOMA CON IA (LEY N° 29783, NORMA G.050, CNE SUMINISTRO)
  // ==========================================================================

  void _openSsomaAiWizard() async {
    final estructurasTags = _placedStickers
        .where((s) => s.sticker.category == StickerCategory.estructuras)
        .map((s) => s.sticker.title)
        .toList();

    final materialesTags = _placedStickers
        .where((s) => s.sticker.category == StickerCategory.materiales)
        .map((s) => s.sticker.title)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        bool isLoading = true;
        List<SsomaHazardSuggestion> suggestions = [];
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setWizardState) {
            void loadAudit() async {
              try {
                final results = await SsomaAiService.auditScene(
                  imageBytes: _capturedImageBytes,
                  detectedMateriales: materialesTags,
                  detectedEstructuras: estructurasTags,
                  areaSector:
                      'Foto #$_sessionPhotoNumber - ${widget.project.proyecto}',
                );
                if (modalCtx.mounted) {
                  setWizardState(() {
                    isLoading = false;
                    suggestions = results;
                  });
                }
              } catch (e) {
                if (modalCtx.mounted) {
                  setWizardState(() {
                    isLoading = false;
                    errorMessage = 'Error al ejecutar auditoría SSOMA: $e';
                  });
                }
              }
            }

            if (isLoading && suggestions.isEmpty && errorMessage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadAudit();
              });
            }

            final approvedCount = suggestions.where((s) => s.isChecked).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF001F2F), // Azul institucional VIGILARTE
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3A51A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bolt,
                            color: Color(0xFF001F2F),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auditor SSOMA con IA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Ley 29783 • Norma G.050 • CNE Suministro',
                                style: TextStyle(
                                  color: Color(0xFFE3A51A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (isLoading)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFE3A51A),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Auditando peligros en la escena...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Evaluando riesgos de altura, contacto eléctrico y entorno laboral',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (errorMessage != null)
                      Expanded(
                        child: Center(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Peligros identificados para validación:',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    '$approvedCount / ${suggestions.length} seleccionados',
                                    style: const TextStyle(
                                      color: Color(0xFFE3A51A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: suggestions.length,
                                itemBuilder: (ctx, i) {
                                  final item = suggestions[i];
                                  final bool isVigilarte =
                                      item.costResponsible == 'VIGILARTE';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: item.isChecked
                                            ? const Color(0xFFE3A51A)
                                            : const Color(0xFF334155),
                                        width: item.isChecked ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      activeColor: const Color(0xFFE3A51A),
                                      checkColor: const Color(0xFF001F2F),
                                      value: item.isChecked,
                                      onChanged: (val) {
                                        setWizardState(() {
                                          item.isChecked = val ?? false;
                                        });
                                      },
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.hazardName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isVigilarte
                                                  ? const Color(0xFF0284C7)
                                                        .withValues(alpha: 0.3)
                                                  : const Color(0xFFD97706)
                                                        .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isVigilarte
                                                    ? const Color(0xFF38BDF8)
                                                    : const Color(0xFFFBBF24),
                                              ),
                                            ),
                                            child: Text(
                                              'Costo: ${item.costResponsible}',
                                              style: TextStyle(
                                                color: isVigilarte
                                                    ? const Color(0xFF38BDF8)
                                                    : const Color(0xFFFBBF24),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            item.riskDescription,
                                            style: const TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Jerarquía: ${item.hierarchyLevel}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF4ADE80),
                                                    fontSize: 9.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.technicalBasis,
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 9.5,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Medida: ${item.preventiveMeasure}',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: approvedCount == 0
                                  ? null
                                  : () {
                                      Navigator.pop(modalCtx);
                                      _applySsomaSuggestions(
                                        suggestions
                                            .where((s) => s.isChecked)
                                            .toList(),
                                      );
                                    },
                              icon: const Icon(Icons.security, size: 20),
                              label: Text(
                                'Aprobar y Colocar ($approvedCount) Pines SSOMA',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE3A51A),
                                foregroundColor: const Color(0xFF001F2F),
                                disabledBackgroundColor: Colors.white12,
                                disabledForegroundColor: Colors.white30,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
        );
      },
    );
  }

  /// Aplica los peligros SSOMA auditados y aprobados por el usuario
  void _applySsomaSuggestions(List<SsomaHazardSuggestion> approved) {
    setState(() {
      int index = 0;
      for (final sug in approved) {
        final sticker = StickerModel(
          title: sug.hazardName,
          icon: Icons.warning_amber_rounded,
          backgroundColor: const Color(0xFF7C2D12),
          accentColor: const Color(0xFFFBBF24),
          category: StickerCategory.peligros,
        );

        final offset = Offset(
          100.0 + (index % 3) * 90.0,
          180.0 + (index ~/ 3) * 70.0,
        );
        _placedStickers.add(
          PlacedSticker(
            id: 'ssoma_${DateTime.now().millisecondsSinceEpoch}_$index',
            sticker: sticker,
            position: offset,
          ),
        );
        index++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ ${approved.length} peligros SSOMA auditados y añadidos a la foto.',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
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
                  const Icon(
                    Icons.handyman,
                    color: Color(0xFF38BDF8),
                    size: 24,
                  ),
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
                      title:
                          '🔩 Accesorios requeridos por Material (${accessories.length})',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
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
    RenderRepaintBoundary? boundary =
        _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo encontrar el contexto visual para renderizar.',
          ),
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
    final double maxDimension = math.max(
      boundary.size.width,
      boundary.size.height,
    );
    final double targetRatio = (maxDimension > 0)
        ? (1280.0 / maxDimension).clamp(1.0, 2.0)
        : 1.5;

    Uint8List pngBytes;
    Uint8List clientPngBytes;
    Uint8List? measurementsPngBytes;
    final initialDisplayMode = _overlayMode;

    try {
      // 2.1 Asegurar que la imagen principal con PINES se capture en modo Pines
      if (_overlayMode != OverlayDisplayMode.pines) {
        setState(() => _overlayMode = OverlayDisplayMode.pines);
        await Future.delayed(const Duration(milliseconds: 40));
      }

      ui.Image image = await boundary.toImage(pixelRatio: targetRatio);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Error al codificar imagen combinada en PNG.');
      }
      pngBytes = byteData.buffer.asUint8List();
      clientPngBytes = pngBytes; // Por defecto
      debugPrint(
        'Imagen con pines capturada: ${image.width} x ${image.height} (${(pngBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
      );

      // 2.2 Si hay cotas/medidas trazadas, capturar la imagen exclusiva de MEDIDAS (con pines ocultos)
      if (_linearMeasurements.isNotEmpty) {
        setState(() => _overlayMode = OverlayDisplayMode.medidas);
        await Future.delayed(const Duration(milliseconds: 40));
        ui.Image measImg = await boundary.toImage(pixelRatio: targetRatio);
        ByteData? measBd = await measImg.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (measBd != null) {
          measurementsPngBytes = measBd.buffer.asUint8List();
          debugPrint(
            'Imagen exclusiva de medidas/cotas capturada: ${measImg.width} x ${measImg.height} (${(measurementsPngBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
          );
        }
      }

      // 2.3 Imagen exclusiva para Cliente (SOLO marcadores de seguridad SST)
      setState(() => _overlayMode = OverlayDisplayMode.pines);
      final allStickersBackup = List<PlacedSticker>.from(_placedStickers);
      final hasNonSafety = _placedStickers.any(
        (s) => s.sticker.category != StickerCategory.peligros,
      );
      if (hasNonSafety) {
        setState(() {
          _placedStickers.removeWhere(
            (s) => s.sticker.category != StickerCategory.peligros,
          );
        });
        await Future.delayed(const Duration(milliseconds: 30));
        ui.Image clientImg = await boundary.toImage(pixelRatio: targetRatio);
        ByteData? clientBd = await clientImg.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (clientBd != null) {
          clientPngBytes = clientBd.buffer.asUint8List();
          debugPrint(
            'Imagen exclusiva de cliente SST capturada: ${clientImg.width} x ${clientImg.height}',
          );
        }
        setState(() {
          _placedStickers.clear();
          _placedStickers.addAll(allStickersBackup);
          _overlayMode = initialDisplayMode;
        });
      } else {
        setState(() => _overlayMode = initialDisplayMode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al renderizar imagen: $e'),
          backgroundColor: Colors.red,
        ),
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
            const Icon(
              Icons.add_photo_alternate,
              color: Color(0xFF38BDF8),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Guardar Foto #$_sessionPhotoNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proyecto: ${widget.project.proyecto}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
                hintText:
                    'Ej. Fachada Principal (Defecto: Foto #$_sessionPhotoNumber)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '🛠️ Herramientas deducidas: ${TechnicalCatalogMatrix.deduceHerramientas(estructuras: _placedStickers.where((s) => s.sticker.category == StickerCategory.estructuras).map((s) => s.sticker.title), materiales: _placedStickers.where((s) => s.sticker.category == StickerCategory.materiales).map((s) => s.sticker.title)).length}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
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
      final Directory designatedFolder = Directory(
        '${appDir.path}/${Constants.localFolderName}',
      );
      if (!await designatedFolder.exists()) {
        await designatedFolder.create(recursive: true);
      }

      final String cleanContact = widget.project.contacto
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final String cleanArea = finalAreaSector
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .trim();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final String localFileName =
          'VISTE_${cleanContact}_Foto${_sessionPhotoNumber}_${cleanArea}_$timestamp.png';
      final File localFile = File('${designatedFolder.path}/$localFileName');
      await localFile.writeAsBytes(pngBytes);
      final String localFilePath = localFile.path;
      debugPrint('Imagen guardada localmente en: $localFilePath');

      // Guardar también la imagen exclusiva con cotas/medidas si existe
      if (measurementsPngBytes != null) {
        final String medidasFileName =
            localFileName.replaceAll('.png', '_medidas.png');
        final File medidasFile =
            File('${designatedFolder.path}/$medidasFileName');
        await medidasFile.writeAsBytes(measurementsPngBytes);
        debugPrint('Imagen de cotas/medidas guardada en: ${medidasFile.path}');
      }

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
      final List<String> deducedHerramientas =
          TechnicalCatalogMatrix.deduceHerramientas(
            estructuras: estructurasTags,
            materiales: materialesTags,
          );

      final List<String> deducedAccesorios =
          TechnicalCatalogMatrix.deduceAccesorios(materiales: materialesTags);

      // Registrar evidencia en la sesión consolidada (VISTEC V3)
      _sessionModel.addPhoto(
        SessionEvidenceRecord(
          photoNumber: _sessionPhotoNumber,
          areaSector: finalAreaSector,
          localImagePath: localFilePath,
          pngBytes: pngBytes,
          clientPngBytes: clientPngBytes,
          measurementsPngBytes: measurementsPngBytes,
          linearMeasurements: List<LinearMeasurement>.from(_linearMeasurements),
          estructuras: estructurasTags,
          materiales: materialesTags,
          peligros: peligrosTags,
          herramientas: deducedHerramientas,
          accesorios: deducedAccesorios,
          timestamp: DateTime.now(),
        ),
      );

      // Persistir inmediatamente la sesión completa en almacenamiento local del dispositivo
      await ProjectStorageService.saveSession(_sessionModel);

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
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
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
                    value:
                        'Foto #$_sessionPhotoNumber • Accesorios: ${deducedAccesorios.length} • Herramientas: ${deducedHerramientas.length}',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('🏁 Finalizar Proyecto'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProjectSummaryReportScreen(session: _sessionModel),
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(
                      context,
                      true,
                    ); // Retorna a form_screen indicando fin de proyecto
                  }
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                    _linearMeasurements.clear();
                    _overlayMode = OverlayDisplayMode.pines;
                    _resetZoom();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Listo para capturar Foto #$_sessionPhotoNumber',
                      ),
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
            content: Text(
              'Error al sincronizar con Excel: ${syncResult.message}',
            ),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
              icon: const Icon(
                Icons.assessment_outlined,
                color: Color(0xFF38BDF8),
              ),
              tooltip: 'Ver Resumen y Reportes PDF',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProjectSummaryReportScreen(session: _sessionModel),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(
                Icons.flag_circle,
                color: Color(0xFF10B981),
                size: 18,
              ),
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
              icon: const Icon(Icons.bolt, color: Color(0xFFE3A51A), size: 22),
              tooltip: 'Auditor SSOMA con IA (⚡)',
              onPressed: _openSsomaAiWizard,
            ),
            IconButton(
              icon: const Icon(Icons.handyman_outlined, color: Color(0xFF4ADE80), size: 20),
              tooltip: 'Kit Técnico (Herramientas / Accesorios)',
              onPressed: _showKitTecnicoSheet,
            ),
            IconButton(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.rotate_90_degrees_cw_outlined,
                    color: Color(0xFF38BDF8),
                    size: 22,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001F2F),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                      ),
                      child: const Text(
                        '90°',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Girar foto 90°',
              onPressed: _isProcessing ? null : _rotateCapturedImage,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.amberAccent, size: 22),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
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
        // 1. Selector Segmentado Excluyente: [ 📍 Modo Pines ] vs [ 📏 Modo Medidas ]
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _overlayMode = OverlayDisplayMode.pines),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _overlayMode == OverlayDisplayMode.pines
                          ? const Color(0xFF001F2F)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: _overlayMode == OverlayDisplayMode.pines
                          ? Border.all(color: const Color(0xFF38BDF8), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 15,
                          color: _overlayMode == OverlayDisplayMode.pines
                              ? const Color(0xFF38BDF8)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '📍 Pines (${_placedStickers.length})',
                          style: TextStyle(
                            color: _overlayMode == OverlayDisplayMode.pines
                                ? Colors.white
                                : Colors.white60,
                            fontWeight: _overlayMode == OverlayDisplayMode.pines
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _overlayMode = OverlayDisplayMode.medidas),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _overlayMode == OverlayDisplayMode.medidas
                          ? const Color(0xFF001F2F)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: _overlayMode == OverlayDisplayMode.medidas
                          ? Border.all(color: const Color(0xFFE3A51A), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 15,
                          color: _overlayMode == OverlayDisplayMode.medidas
                              ? const Color(0xFFE3A51A)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '📏 Medidas (${_linearMeasurements.length})',
                          style: TextStyle(
                            color: _overlayMode == OverlayDisplayMode.medidas
                                ? Colors.white
                                : Colors.white60,
                            fontWeight: _overlayMode == OverlayDisplayMode.medidas
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Instrucción rápida contextual
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
          color: const Color(0xFF1E293B),
          child: Text(
            _overlayMode == OverlayDisplayMode.pines
                ? '💡 Modo Pines: Toca la foto para colocar pines o usa la barra inferior.'
                : (_selectedMeasurementId != null
                    ? '🎯 Cota seleccionada: Arrastra manija A (Origen) o B (Destino) con la lupa para centrar los bordes.'
                    : '📏 Modo Medidas: Arrastra para trazar cota (<--->). Toca una cota para centrarla, editarla o borrarla.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _overlayMode == OverlayDisplayMode.pines
                  ? const Color(0xFF38BDF8)
                  : (_selectedMeasurementId != null ? const Color(0xFF00E676) : const Color(0xFFE3A51A)),
              fontSize: 11,
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
                    panEnabled: _overlayMode == OverlayDisplayMode.pines,
                    scaleEnabled: true,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _imageAspectRatio,
                        child: RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              if (_overlayMode == OverlayDisplayMode.pines) {
                                // Centrar el pin en el punto exacto del toque
                                final Offset tapPosition = Offset(
                                  details.localPosition.dx,
                                  details.localPosition.dy,
                                );
                                _openStickerSelector(
                                  title: 'Añadir Pin #${_placedStickers.length + 1}',
                                  initialPosition: tapPosition,
                                );
                              } else if (_overlayMode == OverlayDisplayMode.medidas) {
                                // Verificar si tocó una cota para seleccionarla o editarla
                                final hitIndex = _findHitMeasurementIndex(details.localPosition);
                                if (hitIndex != null) {
                                  final hitM = _linearMeasurements[hitIndex];
                                  if (_selectedMeasurementId == hitM.id) {
                                    // Segundo tap sobre la cota seleccionada: abrir edición
                                    _openEditMeasurementModal(hitM);
                                  } else {
                                    // Primer tap: seleccionar y mostrar manijas A y B para centrado
                                    setState(() {
                                      _selectedMeasurementId = hitM.id;
                                      _guidedOriginA = null;
                                    });
                                  }
                                } else {
                                  // Tap afuera: deseleccionar
                                  if (_selectedMeasurementId != null) {
                                    setState(() => _selectedMeasurementId = null);
                                  }
                                }
                              }
                            },
                            onPanStart: _overlayMode == OverlayDisplayMode.medidas
                                ? (details) {
                                    final tap = details.localPosition;

                                    // 1. Si hay una cota seleccionada, verificar si toca Manija A (Origen) o Manija B (Destino)
                                    if (_selectedMeasurement != null) {
                                      final sel = _selectedMeasurement!;
                                      if ((tap - sel.startOffset).distance <= 36.0) {
                                        setState(() {
                                          _isDraggingHandleA = true;
                                          _showLoupe = true;
                                          _loupeFocalPoint = sel.startOffset;
                                          _loupeLabel = 'AJUSTE A';
                                          _loupeAccentColor = const Color(0xFF00E676);
                                        });
                                        return;
                                      }
                                      if ((tap - sel.endOffset).distance <= 36.0) {
                                        setState(() {
                                          _isDraggingHandleB = true;
                                          _showLoupe = true;
                                          _loupeFocalPoint = sel.endOffset;
                                          _loupeLabel = 'AJUSTE B';
                                          _loupeAccentColor = const Color(0xFF00E676);
                                        });
                                        return;
                                      }
                                    }

                                    // 2. Verificar si toca alguna otra cota existente
                                    final hitIdx = _findHitMeasurementIndex(tap);
                                    if (hitIdx != null) {
                                      final hitM = _linearMeasurements[hitIdx];
                                      final distA = (tap - hitM.startOffset).distance;
                                      final distB = (tap - hitM.endOffset).distance;
                                      if (distA <= 36.0) {
                                        setState(() {
                                          _selectedMeasurementId = hitM.id;
                                          _isDraggingHandleA = true;
                                          _showLoupe = true;
                                          _loupeFocalPoint = hitM.startOffset;
                                          _loupeLabel = 'AJUSTE A';
                                          _loupeAccentColor = const Color(0xFF00E676);
                                        });
                                        return;
                                      } else if (distB <= 36.0) {
                                        setState(() {
                                          _selectedMeasurementId = hitM.id;
                                          _isDraggingHandleB = true;
                                          _showLoupe = true;
                                          _loupeFocalPoint = hitM.endOffset;
                                          _loupeLabel = 'AJUSTE B';
                                          _loupeAccentColor = const Color(0xFF00E676);
                                        });
                                        return;
                                      } else {
                                        setState(() {
                                          _selectedMeasurementId = hitM.id;
                                          _guidedOriginA = null;
                                        });
                                        return;
                                      }
                                    }

                                    // 3. Flujo guiado con Lupa y Retícula:
                                    if (_guidedOriginA == null) {
                                      // PASO 1: Iniciar guiado del Origen (A)
                                      setState(() {
                                        _selectedMeasurementId = null;
                                        _isGuidingOriginA = true;
                                        _showLoupe = true;
                                        _loupeFocalPoint = tap;
                                        _loupeLabel = 'ORIGEN (A)';
                                        _loupeAccentColor = const Color(0xFF00E676);
                                      });
                                    } else {
                                      // PASO 2: Iniciar guiado del Destino (B) con cota elástica desde A
                                      setState(() {
                                        _selectedMeasurementId = null;
                                        _isGuidingDestinationB = true;
                                        _showLoupe = true;
                                        _loupeFocalPoint = tap;
                                        _guidedTargetB = tap;
                                        _loupeLabel = 'DESTINO (B)';
                                        _loupeAccentColor = const Color(0xFF38BDF8);
                                      });
                                    }
                                  }
                                : null,
                            onPanUpdate: _overlayMode == OverlayDisplayMode.medidas
                                ? (details) {
                                    final pos = details.localPosition;
                                    if (_isDraggingHandleA && _selectedMeasurementId != null) {
                                      final idx = _linearMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                      if (idx != -1) {
                                        setState(() {
                                          _linearMeasurements[idx] = _linearMeasurements[idx].copyWith(startOffset: pos);
                                          _loupeFocalPoint = pos;
                                        });
                                      }
                                    } else if (_isDraggingHandleB && _selectedMeasurementId != null) {
                                      final idx = _linearMeasurements.indexWhere((m) => m.id == _selectedMeasurementId);
                                      if (idx != -1) {
                                        setState(() {
                                          _linearMeasurements[idx] = _linearMeasurements[idx].copyWith(endOffset: pos);
                                          _loupeFocalPoint = pos;
                                        });
                                      }
                                    } else if (_isGuidingOriginA) {
                                      setState(() {
                                        _loupeFocalPoint = pos;
                                      });
                                    } else if (_isGuidingDestinationB) {
                                      setState(() {
                                        _loupeFocalPoint = pos;
                                        _guidedTargetB = pos;
                                      });
                                    }
                                  }
                                : null,
                            onPanEnd: _overlayMode == OverlayDisplayMode.medidas
                                ? (details) async {
                                    if (_isDraggingHandleA || _isDraggingHandleB) {
                                      setState(() {
                                        _isDraggingHandleA = false;
                                        _isDraggingHandleB = false;
                                        _showLoupe = false;
                                        _loupeFocalPoint = null;
                                      });
                                      HapticFeedback.lightImpact();
                                      return;
                                    }

                                    if (_isGuidingOriginA) {
                                      // Fijar el Punto A (Origen)
                                      final fixedA = _loupeFocalPoint;
                                      setState(() {
                                        _isGuidingOriginA = false;
                                        _showLoupe = false;
                                        _loupeFocalPoint = null;
                                        _guidedOriginA = fixedA;
                                      });
                                      HapticFeedback.mediumImpact();
                                      return;
                                    }

                                    if (_isGuidingDestinationB && _guidedOriginA != null) {
                                      final start = _guidedOriginA!;
                                      final end = _guidedTargetB ?? _loupeFocalPoint;
                                      setState(() {
                                        _isGuidingDestinationB = false;
                                        _showLoupe = false;
                                        _loupeFocalPoint = null;
                                        _guidedOriginA = null;
                                        _guidedTargetB = null;
                                      });
                                      HapticFeedback.mediumImpact();

                                      if (end != null) {
                                        final dx = end.dx - start.dx;
                                        final dy = end.dy - start.dy;
                                        final distance = math.sqrt(dx * dx + dy * dy);
                                        if (distance > 15) {
                                          final result = await showDialog<MeasurementModalResult>(
                                            context: context,
                                            builder: (ctx) => MeasurementCaptureModal(
                                              start: start,
                                              end: end,
                                              contextualConduits: _getContextualConduitMaterials(),
                                              voiceService: _voiceService,
                                            ),
                                          );
                                          if (result != null && result.action == MeasurementModalAction.saved && result.measurement != null) {
                                            setState(() {
                                              _linearMeasurements.add(result.measurement!);
                                              _selectedMeasurementId = result.measurement!.id; // Manijas A y B listas para micro-ajuste!
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '✓ Cota registrada. Arrastra las manijas A o B con la lupa si deseas reajustar los bordes.',
                                                  ),
                                                  backgroundColor: Color(0xFF10B981),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  _capturedImageBytes!,
                                  fit: BoxFit.fill,
                                ),

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
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8)
                                            .withValues(alpha: 0.7),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (widget.project.mapa.isNotEmpty &&
                                            widget.project.mapa !=
                                                '0.0, 0.0') ...[
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

                                // 1. MODO PINES (Visibles únicamente en modo Pines)
                                if (_overlayMode == OverlayDisplayMode.pines) ...[
                                  for (int i = 0; i < _placedStickers.length; i++)
                                    _buildNumberedPin(_placedStickers[i], i),

                                  if (_placedStickers.isNotEmpty)
                                    Positioned(
                                      bottom: 5,
                                      left: 5,
                                      right: 5,
                                      child: _buildInPhotoTranslucentLegend(),
                                    ),
                                ],

                                // 2. MODO MEDIDAS (Cotas con flechas de 2 puntas y Lupa de precisión, pines ocultos para no saturar)
                                if (_overlayMode == OverlayDisplayMode.medidas) ...[
                                  CustomPaint(
                                    painter: MeasurementLinesPainter(
                                      measurements: _linearMeasurements,
                                      selectedMeasurementId: _selectedMeasurementId,
                                      currentStart: _cotaDragStart,
                                      currentEnd: _cotaDragCurrent ?? _guidedTargetB,
                                      guidedOriginA: _guidedOriginA,
                                      activeMaterial:
                                          _getContextualConduitMaterials()
                                                  .isNotEmpty
                                              ? _getContextualConduitMaterials()
                                                  .first
                                              : null,
                                    ),
                                  ),
                                  if (_showLoupe && _loupeFocalPoint != null)
                                    LoupeMagnifierWidget(
                                      touchPosition: _loupeFocalPoint!,
                                      canvasSize: MediaQuery.of(context).size,
                                      label: _loupeLabel,
                                      accentColor: _loupeAccentColor,
                                    ),
                                  // Cápsula flotante de asistencia técnica sobre la fotografía
                                  Positioned(
                                    bottom: 8,
                                    left: 12,
                                    right: 12,
                                    child: _buildMeasurementStepGuidanceBanner(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Barra inferior de controles (Diseño en 2 niveles: 4 Botones + Botón Guardar Fijo)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nivel 1: Alterna según el modo activo (Pines vs Medidas)
                if (_overlayMode == OverlayDisplayMode.pines)
                  Row(
                    children: [
                      // 1. Estructuras (Ícono de estructura, Azul)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openStickerSelector(
                            title: 'Estructuras',
                            initialTabIndex: 0,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F2744),
                            foregroundColor: const Color(0xFF00B0FF),
                            side: const BorderSide(color: Color(0xFF00B0FF), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.domain, size: 18, color: Color(0xFF00B0FF)),
                              SizedBox(height: 2),
                              Text(
                                'Estructuras',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // 2. Materiales (Ícono de martillo y destornillador, Verde)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openStickerSelector(
                            title: 'Materiales',
                            initialTabIndex: 1,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C381E),
                            foregroundColor: const Color(0xFF00E676),
                            side: const BorderSide(color: Color(0xFF00E676), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.construction, size: 18, color: Color(0xFF00E676)),
                              SizedBox(height: 2),
                              Text(
                                'Materiales',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // 3. SSOMA (Ícono de triángulo con signo de advertencia, Amarillo)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openStickerSelector(
                            title: 'Peligros SSOMA',
                            initialTabIndex: 2,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF382D05),
                            foregroundColor: const Color(0xFFFFD600),
                            side: const BorderSide(color: Color(0xFFFFD600), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFFFD600)),
                              SizedBox(height: 2),
                              Text(
                                'SSOMA',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // 4. Agente IA (Micrófono + Rayo, Vigilarte #001F2F / #E3A51A)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startVoiceRecognitionModal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001F2F),
                            foregroundColor: const Color(0xFFE3A51A),
                            side: const BorderSide(color: Color(0xFFE3A51A), width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic, size: 16, color: Color(0xFFE3A51A)),
                                  Icon(Icons.bolt, size: 16, color: Color(0xFFE3A51A)),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Agente IA',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFE3A51A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_selectedMeasurement != null)
                  // Barra de herramientas cuando hay una cota seleccionada (manijas activas)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2744),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, color: Color(0xFF00E676), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'COTA SELECCIONADA (#${_linearMeasurements.indexOf(_selectedMeasurement!) + 1})',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_selectedMeasurement!.longitudMetros.toStringAsFixed(2)} m • ${_selectedMeasurement!.material}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Botón Editar
                        ElevatedButton.icon(
                          onPressed: () => _openEditMeasurementModal(_selectedMeasurement!),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Editar', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE3A51A),
                            foregroundColor: const Color(0xFF001F2F),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Botón Eliminar individual
                        IconButton(
                          onPressed: () {
                            final deletedLabel = _selectedMeasurement!.labelFormatted;
                            setState(() {
                              _linearMeasurements.removeWhere((m) => m.id == _selectedMeasurementId);
                              _selectedMeasurementId = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Cota eliminada: $deletedLabel'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          tooltip: 'Eliminar esta cota',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF7F1D1D).withValues(alpha: 0.7),
                            padding: const EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Botón Deseleccionar
                        IconButton(
                          onPressed: () => setState(() => _selectedMeasurementId = null),
                          icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                          tooltip: 'Deseleccionar',
                        ),
                      ],
                    ),
                  )
                else
                  // Barra de herramientas general del Modo Medidas
                  Row(
                    children: [
                      // Indicador de Total de Metros Acumulados
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE3A51A), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '📏 METRADO TOTAL',
                                style: TextStyle(
                                  color: Color(0xFFE3A51A),
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_linearMeasurements.fold<double>(0.0, (acc, m) => acc + m.longitudMetros).toStringAsFixed(2)} m (${_linearMeasurements.length} tramos)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botón Lista de Cotas (para ver, centrar, editar y borrar individualmente)
                      ElevatedButton.icon(
                        onPressed: _linearMeasurements.isEmpty ? null : _showMeasurementsListSheet,
                        icon: const Icon(Icons.format_list_bulleted, size: 16),
                        label: Text('Cotas (${_linearMeasurements.length})', style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          disabledForegroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botón Deshacer última cota
                      ElevatedButton.icon(
                        onPressed: _linearMeasurements.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _linearMeasurements.removeLast();
                                  _selectedMeasurementId = null;
                                });
                              },
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Deshacer', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          disabledForegroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Nivel 2: Fila Principal de Guardado y Avance (FIJA, SIEMPRE VISIBLE EN PANTALLA)
                Row(
                  children: [
                    // Botón Guardar Foto Actual y Avanzar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
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
                              : const Icon(Icons.cloud_upload, size: 20),
                          label: Text(
                            _isProcessing
                                ? 'Guardando...'
                                : 'Guardar Foto #$_sessionPhotoNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),

                    // Si ya hay fotos guardadas en la sesión, botón directo para Finalizar / Ver Reportes
                    if (_sessionModel.totalPhotos > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _confirmEndSession,
                            icon: const Icon(Icons.flag_circle, size: 18, color: Colors.white),
                            label: Text(
                              'Reportes (${_sessionModel.totalPhotos})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
        return const Color(
          0xFFFFD600,
        ); // Amarillo seguridad eléctrico y vibrante
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
              fillColor: const Color(
                0x35FFD600,
              ), // ~20% de opacidad: se ve completamente la estructura detrás
              borderColor: const Color(
                0xFFFFD600,
              ), // Borde amarillo eléctrico de máxima visibilidad
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
            color: const Color(
              0x3000B0FF,
            ), // ~19% de opacidad: cristalino sin fondo opaco
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: const Color(
                0xFF00B0FF,
              ), // Borde azul eléctrico de alto impacto
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
            color: const Color(
              0x3000E676,
            ), // ~19% de opacidad: cristalino sin fondo opaco
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
          color:
              Colors.transparent, // Zona táctil de comodidad sin bordes rígidos
          child: _buildPinBadge(placed.sticker.category, index + 1),
        ),
      ),
    );
  }

  void _showPinOptionsModal(PlacedSticker placed, int index) {
    final Color categoryColor = _getCategoryColor(placed.sticker.category);
    final String categoryName =
        placed.sticker.category == StickerCategory.estructuras
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
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 22,
                ),
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
        color: Colors.black.withValues(
          alpha: 0.48,
        ), // Fondo translúcido para visibilidad
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
              const Icon(
                Icons.format_list_bulleted,
                color: Color(0xFF38BDF8),
                size: 9,
              ),
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
            if (sstPins.isNotEmpty || matPins.isNotEmpty)
              const SizedBox(height: 1.2),
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
            border: Border.all(color: Colors.white, width: 0.6),
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
            border: Border.all(color: Colors.white, width: 0.6),
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
