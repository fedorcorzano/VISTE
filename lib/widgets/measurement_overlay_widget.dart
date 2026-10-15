import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/linear_measurement_model.dart';
import '../models/sticker_model.dart';
import '../services/voice_recognition_service.dart';

/// Painter de ingeniería técnica que dibuja cotas con flechas de dos puntas (<------>),
/// puntos de anclaje de alta precisión y manijas interactivas de ajuste milimétrico A (Origen) y B (Destino).
class MeasurementLinesPainter extends CustomPainter {
  final List<LinearMeasurement> measurements;
  final String? selectedMeasurementId;
  final Offset? currentStart;
  final Offset? currentEnd;
  final Offset? guidedOriginA;
  final String? activeMaterial;

  MeasurementLinesPainter({
    required this.measurements,
    this.selectedMeasurementId,
    this.currentStart,
    this.currentEnd,
    this.guidedOriginA,
    this.activeMaterial,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar todas las cotas finalizadas
    for (int i = 0; i < measurements.length; i++) {
      final m = measurements[i];
      final bool isSelected = m.id == selectedMeasurementId;

      _drawDimensionArrow(
        canvas: canvas,
        start: m.startOffset,
        end: m.endOffset,
        label: m.labelDistanceOnly,
        isTemp: false,
        isSelected: isSelected,
      );
    }

    // 2. Si hay un Origen A fijado en el flujo guiado, dibujarlo como baliza destacada
    if (guidedOriginA != null) {
      _drawGuidedOriginBeacon(canvas, guidedOriginA!);
    }

    // 3. Dibujar la cota que se está trazando en vivo (bien desde currentStart o desde guidedOriginA hasta currentEnd)
    final Offset? liveStart = guidedOriginA ?? currentStart;
    if (liveStart != null && currentEnd != null) {
      final double dx = currentEnd!.dx - liveStart.dx;
      final double dy = currentEnd!.dy - liveStart.dy;
      final double pixelDistance = math.sqrt(dx * dx + dy * dy);

      if (pixelDistance > 5) {
        _drawDimensionArrow(
          canvas: canvas,
          start: liveStart,
          end: currentEnd!,
          label: activeMaterial != null ? 'Trazando • $activeMaterial' : 'Guiando Destino (B)...',
          isTemp: true,
          isSelected: true,
        );
      }
    }
  }

  void _drawGuidedOriginBeacon(Canvas canvas, Offset origin) {
    // Halo pulsante exterior
    final Paint pulsePaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(origin, 18, pulsePaint);

    final Paint ringPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(origin, 10, ringPaint);

    // Punto central de contacto
    final Paint centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint centerBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(origin, 3.5, centerPaint);
    canvas.drawCircle(origin, 3.5, centerBorder);

    // Etiqueta flotante "ORIGEN A"
    final TextSpan span = const TextSpan(
      text: 'ORIGEN A',
      style: TextStyle(
        color: Color(0xFF001F2F),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout();

    final Offset badgeOffset = Offset(origin.dx - tp.width / 2, origin.dy - 26);
    final Rect badgeRect = Rect.fromLTWH(badgeOffset.dx - 5, badgeOffset.dy - 2, tp.width + 10, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF00E676),
    );
    tp.paint(canvas, badgeOffset);
  }

  void _drawDimensionArrow({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required String label,
    required bool isTemp,
    required bool isSelected,
  }) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final double uX = dx / len;
    final double uY = dy / len;
    final double perpX = -uY;
    final double perpY = uX;

    final Color strokeColor = isTemp
        ? const Color(0xFF38BDF8)
        : (isSelected ? const Color(0xFF00E676) : const Color(0xFFE3A51A)); // Verde esmeralda si seleccionada, dorado vigilarte por defecto
    final Color bgColor = const Color(0xFF001F2F).withValues(alpha: 0.92);

    // 1. Sombra posterior oscura para máximo contraste sobre fotos claras o reflectivas
    final Paint shadowLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..strokeWidth = isSelected ? 2.6 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, shadowLine);

    // 2. Línea principal de cota (esbelta y delgada para máxima precisión técnica)
    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = isSelected ? 1.8 : 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, linePaint);

    // 3. Flechas de dos puntas de ingeniería (<--------->)
    const double arrowLen = 9.5;
    const double arrowHalfWidth = 3.6;

    final Paint arrowPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    final Paint arrowBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Flecha Punta A (Origen: apunta exactamente al contacto del punto start)
    final Path startArrow = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(
        start.dx + uX * arrowLen + perpX * arrowHalfWidth,
        start.dy + uY * arrowLen + perpY * arrowHalfWidth,
      )
      ..lineTo(
        start.dx + uX * (arrowLen * 0.75),
        start.dy + uY * (arrowLen * 0.75),
      )
      ..lineTo(
        start.dx + uX * arrowLen - perpX * arrowHalfWidth,
        start.dy + uY * arrowLen - perpY * arrowHalfWidth,
      )
      ..close();
    canvas.drawPath(startArrow, arrowPaint);
    canvas.drawPath(startArrow, arrowBorder);

    // Flecha Punta B (Destino: apunta exactamente al contacto del punto end)
    final Path endArrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - uX * arrowLen + perpX * arrowHalfWidth,
        end.dy - uY * arrowLen + perpY * arrowHalfWidth,
      )
      ..lineTo(
        end.dx - uX * (arrowLen * 0.75),
        end.dy - uY * (arrowLen * 0.75),
      )
      ..lineTo(
        end.dx - uX * arrowLen - perpX * arrowHalfWidth,
        end.dy - uY * arrowLen - perpY * arrowHalfWidth,
      )
      ..close();
    canvas.drawPath(endArrow, arrowPaint);
    canvas.drawPath(endArrow, arrowBorder);

    // 4. Puntos de contacto milimétricos (centro de coordenadas)
    final Paint centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint centerDotBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(start, 1.8, centerDotPaint);
    canvas.drawCircle(start, 1.8, centerDotBorder);
    canvas.drawCircle(end, 1.8, centerDotPaint);
    canvas.drawCircle(end, 1.8, centerDotBorder);

    // 5. Manijas táctiles de ajuste si la cota está seleccionada para centrado
    if (isSelected && !isTemp) {
      _drawHandle(canvas: canvas, center: start, label: 'A', color: strokeColor);
      _drawHandle(canvas: canvas, center: end, label: 'B', color: strokeColor);
    }

    // 6. Etiqueta central con texto de metrado y material
    final Offset mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final TextSpan span = TextSpan(
      text: label,
      style: TextStyle(
        color: isSelected ? const Color(0xFF001F2F) : Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.1,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final double padH = 5.0;
    final double padV = 2.5;
    final Rect bgRect = Rect.fromCenter(
      center: mid,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    final RRect rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));
    final Paint badgeBgPaint = Paint()
      ..color = isSelected ? strokeColor : bgColor;
    final Paint badgeBorderPaint = Paint()
      ..color = isSelected ? const Color(0xFF001F2F) : strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.1;

    canvas.drawRRect(rrect, badgeBgPaint);
    canvas.drawRRect(rrect, badgeBorderPaint);

    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  void _drawHandle({
    required Canvas canvas,
    required Offset center,
    required String label,
    required Color color,
  }) {
    // 1. Halo y anillo táctil interactivo para agarre y ajuste de posición milimétrico
    final Paint touchHalo = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 13, touchHalo);

    final Paint borderRing = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 13, borderRing);

    final Paint centerDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, centerDot);

    // 2. Micro-indicador técnico de manija con etiqueta ('A' Origen, 'B' Destino)
    final TextSpan span = TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFF001F2F),
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final Offset badgeCenter = Offset(center.dx, center.dy - 19);
    final Rect badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: tp.width + 10,
      height: tp.height + 4,
    );
    final RRect rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(4));

    final Paint badgeBg = Paint()..color = color;
    final Paint badgeBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawRRect(rrect, badgeBg);
    canvas.drawRRect(rrect, badgeBorder);
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MeasurementLinesPainter oldDelegate) {
    return true;
  }
}

/// Lupa de magnificación flotante pura: sólo lente amplificador cristalino sin elementos adicionales ni opacidad
class LoupeMagnifierWidget extends StatelessWidget {
  final Offset touchPosition;
  final Size canvasSize;
  final String? label;
  final Color accentColor;

  const LoupeMagnifierWidget({
    super.key,
    required this.touchPosition,
    required this.canvasSize,
    this.label,
    this.accentColor = const Color(0xFF00E676),
  });

  @override
  Widget build(BuildContext context) {
    const double loupeDiameter = 114.0;
    const double loupeRadius = loupeDiameter / 2;

    // Desplazar la lupa 110px por encima del dedo para despejar por completo el área visual
    double loupeX = touchPosition.dx - loupeRadius;
    double loupeY = touchPosition.dy - 110.0;

    // Control de bordes de pantalla
    loupeX = loupeX.clamp(10.0, math.max(10.0, canvasSize.width - loupeDiameter - 10.0));
    bool invertedBelow = false;
    if (loupeY < 32.0) {
      loupeY = touchPosition.dy + 45.0;
      invertedBelow = true;
    }

    final double centerX = loupeX + loupeRadius;
    final double centerY = loupeY + loupeRadius;

    // CÁLCULO EXACTO: Vector desde el centro geométrico de la lupa hasta el punto de contacto real
    final Offset focalOffset = Offset(touchPosition.dx - centerX, touchPosition.dy - centerY);

    return Positioned(
      left: loupeX,
      top: loupeY,
      child: IgnorePointer(
        child: SizedBox(
          width: loupeDiameter,
          height: loupeDiameter,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Lente de aumento 100% puro: cristal limpio sin líneas interiores, sin opacidad ni sombras
              RawMagnifier(
                decoration: MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: accentColor, width: 2.4),
                  ),
                  shadows: const [],
                ),
                size: const Size(loupeDiameter, loupeDiameter),
                magnificationScale: 2.2,
                focalPointOffset: focalOffset,
              ),

              // Etiqueta flotante externa opcional
              if (label != null)
                Positioned(
                  top: invertedBelow ? loupeDiameter + 6 : -22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001F2F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor, width: 1.2),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado de la acción del modal de captura / edición
enum MeasurementModalAction { saved, deleted, cancelled }

class MeasurementModalResult {
  final MeasurementModalAction action;
  final LinearMeasurement? measurement;

  const MeasurementModalResult({required this.action, this.measurement});
}

/// Diálogo de captura rápida y edición de longitud en metros y material contextual
class MeasurementCaptureModal extends StatefulWidget {
  final Offset start;
  final Offset end;
  final List<String> contextualConduits;
  final VoiceRecognitionService voiceService;
  final LinearMeasurement? existingMeasurement; // Para editar cota existente
  final String clasificacion;
  final List<String>? allAvailableMaterials;
  final bool onlyDistance; // Si es true (en campo), solo pide distancia sin material

  const MeasurementCaptureModal({
    super.key,
    required this.start,
    required this.end,
    required this.contextualConduits,
    required this.voiceService,
    this.existingMeasurement,
    this.clasificacion = 'Comercial',
    this.allAvailableMaterials,
    this.onlyDistance = false,
  });

  @override
  State<MeasurementCaptureModal> createState() => _MeasurementCaptureModalState();
}

class _MeasurementCaptureModalState extends State<MeasurementCaptureModal> {
  final TextEditingController _distanceController = TextEditingController();
  late String _selectedMaterial;
  late String _selectedFamily;
  late bool _esMetrado;
  bool _isListening = false;
  String _recognizedVoice = '';

  @override
  void initState() {
    super.initState();
    if (widget.existingMeasurement != null) {
      final m = widget.existingMeasurement!;
      _distanceController.text = m.longitudMetros % 1 == 0
          ? m.longitudMetros.toInt().toString()
          : m.longitudMetros.toStringAsFixed(2);
      _selectedMaterial = m.material.isNotEmpty ? m.material : 'Solo Medida';
      _esMetrado = m.esMetradoMaterial;
    } else {
      _esMetrado = false;
      if (widget.contextualConduits.isNotEmpty) {
        _selectedMaterial = widget.contextualConduits.first;
      } else {
        // Sugerir según clasificación de proyecto
        final priority = TechnicalCatalogMatrix.materialesPorClasificacion[widget.clasificacion];
        if (priority != null && priority.isNotEmpty) {
          final fam = TechnicalCatalogMatrix.deduceFamilia(priority.first);
          final variants = TechnicalCatalogMatrix.familiasYVariantesCanalizacion[fam];
          _selectedMaterial = (variants != null && variants.isNotEmpty) ? variants[1] : 'Tubo EMT 3/4"';
        } else {
          _selectedMaterial = 'Tubo EMT 3/4"';
        }
      }
    }

    _selectedFamily = (_selectedMaterial == 'Por definir' || _selectedMaterial == 'Solo Medida')
        ? 'EMT'
        : TechnicalCatalogMatrix.deduceFamilia(_selectedMaterial);
  }

  @override
  void dispose() {
    _distanceController.dispose();
    if (_isListening) {
      widget.voiceService.stopListening();
    }
    super.dispose();
  }

  Future<void> _listenVoiceDistance() async {
    if (_isListening) {
      await widget.voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await widget.voiceService.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Micrófono no disponible'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedVoice = 'Escuchando...';
    });

    await widget.voiceService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _recognizedVoice = text;
        });

        final number = _extractMetersFromVoice(text);
        if (number != null && number > 0) {
          _distanceController.text = number.toStringAsFixed(2);
        }
      },
    );
  }

  double? _extractMetersFromVoice(String spoken) {
    String clean = spoken.toLowerCase()
        .replaceAll('metros', '')
        .replaceAll('metro', '')
        .replaceAll('mts', '')
        .replaceAll('m', '')
        .trim();

    clean = clean.replaceAll('coma', '.').replaceAll('punto', '.');
    final match = RegExp(r'(\d+[\.,]?\d*)').firstMatch(clean);
    if (match != null) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(numStr);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingMeasurement != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3A51A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.straighten,
                      color: const Color(0xFF001F2F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.onlyDistance
                          ? (isEditing ? 'Editar Distancia' : 'Registrar Distancia')
                          : (isEditing ? 'Configurar Cota de Medida' : 'Registrar Cota de Medida'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Campo de metros con botón de micrófono
              const Text(
                'Longitud del tramo (Metros):',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _distanceController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ej. 12.50',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                        suffixText: 'metros',
                        suffixStyle: const TextStyle(color: Color(0xFFE3A51A), fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE3A51A), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening ? Colors.redAccent : const Color(0xFF334155),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    tooltip: 'Dictar medida por voz',
                    onPressed: _listenVoiceDistance,
                  ),
                ],
              ),
              if (_isListening || _recognizedVoice.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '🎙️ "$_recognizedVoice"',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],

              // Si es gestión de escritorio, configurar si es Solo Medida o Metrado de Material
              if (!widget.onlyDistance) ...[
                const SizedBox(height: 16),
                const Text(
                  'Función de la Cota:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.straighten, size: 13),
                        label: const Text('Solo Medida', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        selected: !_esMetrado,
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (val) => setState(() => _esMetrado = false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.inventory_2_outlined, size: 13),
                        label: const Text('Metrado Material', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        selected: _esMetrado,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (val) => setState(() => _esMetrado = true),
                      ),
                    ),
                  ],
                ),
              ],

              // Solo si está activado Metrado de Material en Gabinete
              if (!widget.onlyDistance && _esMetrado) ...[
                const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Tipo de Canalización (Base):',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (widget.clasificacion.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                      ),
                      child: Text(
                        'Proyecto ${widget.clasificacion}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila de pines flotantes de familias base (prioritarias primero)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...(() {
                    final sortedFamilies = List<String>.from(TechnicalCatalogMatrix.familiasCanalizacion)
                      ..sort((a, b) {
                        final aPri = _isFamilyPriority(a);
                        final bPri = _isFamilyPriority(b);
                        if (aPri && !bPri) return -1;
                        if (!aPri && bPri) return 1;
                        return a.compareTo(b);
                      });
                    return sortedFamilies;
                  })().map((fam) {
                    final bool isFamilyActive = _selectedFamily == fam;
                    final bool isPriorityForClasif = _isFamilyPriority(fam);

                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFamilyIcon(fam),
                            size: 14,
                            color: isFamilyActive ? const Color(0xFF001F2F) : (isPriorityForClasif ? const Color(0xFFE3A51A) : Colors.white70),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPriorityForClasif ? '$fam ★' : fam,
                            style: TextStyle(
                              color: isFamilyActive ? const Color(0xFF001F2F) : Colors.white,
                              fontSize: 12,
                              fontWeight: isFamilyActive ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      selected: isFamilyActive,
                      selectedColor: const Color(0xFFE3A51A),
                      backgroundColor: const Color(0xFF0F172A),
                      side: BorderSide(
                        color: isFamilyActive
                            ? const Color(0xFFE3A51A)
                            : (isPriorityForClasif ? const Color(0xFFE3A51A) : const Color(0xFF334155)),
                        width: isFamilyActive || isPriorityForClasif ? 1.5 : 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      onSelected: (selected) {
                        if (selected) {
                          _onFamilySelected(fam);
                        }
                      },
                    );
                  }),
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, size: 14, color: Colors.amberAccent),
                        SizedBox(width: 4),
                        Text('⚡ Por definir', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    selected: _selectedFamily == 'Por definir',
                    selectedColor: const Color(0xFFE3A51A),
                    backgroundColor: const Color(0xFF0F172A),
                    side: BorderSide(
                      color: _selectedFamily == 'Por definir' ? const Color(0xFFE3A51A) : const Color(0xFF334155),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFamily = 'Por definir';
                          _selectedMaterial = 'Por definir';
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. NIVEL 2: MEDIDAS Y VARIANTES DISPONIBLES INMEDIATAMENTE DEBAJO
              if (_selectedFamily != 'Por definir') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 14, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Medidas disponibles para $_selectedFamily:',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _buildSizedVariantChips(),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cota rápida sin material asignado. Podrás definir el material específico en la pantalla de gabinete.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

              const SizedBox(height: 20),

              // Botones de acción (Eliminar si está editando, Cancelar, Guardar)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isEditing)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          const MeasurementModalResult(action: MeasurementModalAction.deleted),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _submitMeasurement,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(isEditing ? 'Guardar Cambios' : 'Guardar Cota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3A51A),
                      foregroundColor: const Color(0xFF001F2F),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isFamilyPriority(String fam) {
    final list = TechnicalCatalogMatrix.materialesPorClasificacion[widget.clasificacion] ?? [];
    return list.any((item) => TechnicalCatalogMatrix.deduceFamilia(item) == fam);
  }

  IconData _getFamilyIcon(String fam) {
    switch (fam) {
      case 'EMT':
        return Icons.straighten;
      case 'IMC':
        return Icons.hardware;
      case 'PVC':
        return Icons.water_drop_outlined;
      case 'Canaleta':
        return Icons.view_week_outlined;
      case 'Liquid Tight':
        return Icons.cable;
      case 'Bandeja':
        return Icons.table_rows_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  void _onFamilySelected(String fam) {
    setState(() {
      _selectedFamily = fam;
      final variants = TechnicalCatalogMatrix.familiasYVariantesCanalizacion[fam] ?? [];
      if (!variants.contains(_selectedMaterial)) {
        // Seleccionar por defecto la medida estándar de la familia (ej. 3/4" o 40x25)
        if (variants.length >= 2) {
          _selectedMaterial = variants[1]; // Habitualmente 3/4" o tamaño estándar
        } else if (variants.isNotEmpty) {
          _selectedMaterial = variants.first;
        }
      }
    });
  }

  List<Widget> _buildSizedVariantChips() {
    final variants = TechnicalCatalogMatrix.familiasYVariantesCanalizacion[_selectedFamily] ?? [];

    return variants.map((variant) {
      final bool isSelected = _selectedMaterial == variant;

      return ChoiceChip(
        label: Text(
          variant,
          style: TextStyle(
            color: isSelected ? const Color(0xFF001F2F) : Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFE3A51A),
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(
          color: isSelected ? const Color(0xFFE3A51A) : const Color(0xFF475569),
          width: isSelected ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedMaterial = variant);
          }
        },
      );
    }).toList();
  }

  void _submitMeasurement() {
    final double? meters = double.tryParse(_distanceController.text.trim());
    if (meters == null || meters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una longitud válida en metros (ej. 12.50)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String finalMaterial = (widget.onlyDistance || !_esMetrado) ? 'Solo Medida' : _selectedMaterial;
    final bool finalEsMetrado = !widget.onlyDistance && _esMetrado;

    final result = (widget.existingMeasurement != null)
        ? widget.existingMeasurement!.copyWith(
            longitudMetros: meters,
            material: finalMaterial,
            esMetradoMaterial: finalEsMetrado,
          )
        : LinearMeasurement(
            id: 'cota_${DateTime.now().millisecondsSinceEpoch}',
            startOffset: widget.start,
            endOffset: widget.end,
            longitudMetros: meters,
            material: finalMaterial,
            esMetradoMaterial: finalEsMetrado,
          );

    Navigator.pop(
      context,
      MeasurementModalResult(
        action: MeasurementModalAction.saved,
        measurement: result,
      ),
    );
  }
}
