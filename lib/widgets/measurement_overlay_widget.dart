import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/linear_measurement_model.dart';
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
        label: '#${i + 1} • ${m.labelFormatted}',
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
      ..strokeWidth = (isSelected ? 3.4 : 2.6) + 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, shadowLine);

    // 2. Línea principal de cota
    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = isSelected ? 3.0 : 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, linePaint);

    // 3. Flechas de dos puntas de ingeniería (<--------->)
    const double arrowLen = 13.5;
    const double arrowHalfWidth = 5.2;

    final Paint arrowPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    final Paint arrowBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

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
      ..strokeWidth = 1.2;

    canvas.drawCircle(start, 2.5, centerDotPaint);
    canvas.drawCircle(start, 2.5, centerDotBorder);
    canvas.drawCircle(end, 2.5, centerDotPaint);
    canvas.drawCircle(end, 2.5, centerDotBorder);

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
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final double padH = 7.0;
    final double padV = 4.0;
    final Rect bgRect = Rect.fromCenter(
      center: mid,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    final RRect rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(6));
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
    // Halo translúcido exterior
    final Paint haloPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16.0, haloPaint);

    // Anillo exterior
    final Paint ringPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 13.0, ringPaint);

    // Centro circular sólido
    final Paint centerBg = Paint()
      ..color = const Color(0xFF001F2F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10.0, centerBg);

    // Letra A / B
    final TextSpan span = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MeasurementLinesPainter oldDelegate) {
    return true;
  }
}

/// Lupa de magnificación flotante de alta precisión con puntero táctico y compensación exacta de focalPointOffset
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
    const double loupeDiameter = 110.0;
    const double loupeRadius = loupeDiameter / 2;

    // Desplazar la lupa 110px por encima del dedo para despejar por completo el área visual
    double loupeX = touchPosition.dx - loupeRadius;
    double loupeY = touchPosition.dy - 110.0;

    // Control de bordes de pantalla
    loupeX = loupeX.clamp(10.0, math.max(10.0, canvasSize.width - loupeDiameter - 10.0));
    if (loupeY < 15.0) {
      // Si el punto está pegado al borde superior, invertir la lupa debajo del dedo
      loupeY = touchPosition.dy + 40.0;
    }

    final double centerX = loupeX + loupeRadius;
    final double centerY = loupeY + loupeRadius;

    // CÁLCULO EXACTO: Vector desde el centro geométrico de la lupa hasta el punto de contacto real
    // Esto garantiza que el centro de la lupa y la punta del visor coincidan milimétricamente con el contacto
    final Offset focalOffset = Offset(touchPosition.dx - centerX, touchPosition.dy - centerY);

    return Positioned(
      left: loupeX,
      top: loupeY,
      child: IgnorePointer(
        child: Container(
          width: loupeDiameter,
          height: loupeDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: accentColor, width: 2.8),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.40),
                blurRadius: 14,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                RawMagnifier(
                  decoration: const MagnifierDecoration(
                    shape: CircleBorder(),
                  ),
                  size: const Size(loupeDiameter, loupeDiameter),
                  magnificationScale: 2.5,
                  focalPointOffset: focalOffset,
                ),
                // Retícula táctica y puntero de máxima precisión en el centro
                CustomPaint(
                  size: const Size(loupeDiameter, loupeDiameter),
                  painter: CrosshairReticlePainter(color: accentColor),
                ),
                // Etiqueta superior con el paso activo (ORIGEN A / DESTINO B)
                if (label != null)
                  Positioned(
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withValues(alpha: 0.9), width: 1.0),
                      ),
                      child: Text(
                        label!,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la retícula técnica militar con puntero central ("la punta") lista para alinear al milímetro
class CrosshairReticlePainter extends CustomPainter {
  final Color color;

  const CrosshairReticlePainter({this.color = const Color(0xFF00E676)});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Círculo exterior táctico con líneas guía
    final Paint circlePaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), 24.0, circlePaint);

    final Paint circleShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(Offset(cx, cy), 24.0, circleShadow);

    // 2. Líneas de cruz de precisión (con apertura central de 12px)
    final Paint lineShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..strokeWidth = 2.4;
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.3;

    const double innerGap = 6.0;
    const double outerLen = 34.0;

    // Horizontales
    canvas.drawLine(Offset(cx - outerLen, cy), Offset(cx - innerGap, cy), lineShadow);
    canvas.drawLine(Offset(cx + innerGap, cy), Offset(cx + outerLen, cy), lineShadow);
    canvas.drawLine(Offset(cx - outerLen, cy), Offset(cx - innerGap, cy), linePaint);
    canvas.drawLine(Offset(cx + innerGap, cy), Offset(cx + outerLen, cy), linePaint);

    // Verticales
    canvas.drawLine(Offset(cx, cy - outerLen), Offset(cx, cy - innerGap), lineShadow);
    canvas.drawLine(Offset(cx, cy + innerGap), Offset(cx, cy + outerLen), lineShadow);
    canvas.drawLine(Offset(cx, cy - outerLen), Offset(cx, cy - innerGap), linePaint);
    canvas.drawLine(Offset(cx, cy + innerGap), Offset(cx, cy + outerLen), linePaint);

    // 3. "La Punta": Cuatro flechas guía convergentes hacia el centro focal exacto
    final Paint arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint arrowBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Punta Norte (apunta hacia abajo al centro)
    final Path northArrow = Path()
      ..moveTo(cx, cy - 2.0)
      ..lineTo(cx - 3.5, cy - 7.0)
      ..lineTo(cx + 3.5, cy - 7.0)
      ..close();
    canvas.drawPath(northArrow, arrowPaint);
    canvas.drawPath(northArrow, arrowBorder);

    // Punta Sur (apunta hacia arriba al centro)
    final Path southArrow = Path()
      ..moveTo(cx, cy + 2.0)
      ..lineTo(cx - 3.5, cy + 7.0)
      ..lineTo(cx + 3.5, cy + 7.0)
      ..close();
    canvas.drawPath(southArrow, arrowPaint);
    canvas.drawPath(southArrow, arrowBorder);

    // Punta Oeste (apunta hacia la derecha al centro)
    final Path westArrow = Path()
      ..moveTo(cx - 2.0, cy)
      ..lineTo(cx - 7.0, cy - 3.5)
      ..lineTo(cx - 7.0, cy + 3.5)
      ..close();
    canvas.drawPath(westArrow, arrowPaint);
    canvas.drawPath(westArrow, arrowBorder);

    // Punta Este (apunta hacia la izquierda al centro)
    final Path eastArrow = Path()
      ..moveTo(cx + 2.0, cy)
      ..lineTo(cx + 7.0, cy - 3.5)
      ..lineTo(cx + 7.0, cy + 3.5)
      ..close();
    canvas.drawPath(eastArrow, arrowPaint);
    canvas.drawPath(eastArrow, arrowBorder);

    // 4. Punto central focal de alta visibilidad (Punto blanco con contorno negro)
    final Paint centerDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint centerBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), 1.6, centerDot);
    canvas.drawCircle(Offset(cx, cy), 1.6, centerBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  const MeasurementCaptureModal({
    super.key,
    required this.start,
    required this.end,
    required this.contextualConduits,
    required this.voiceService,
    this.existingMeasurement,
  });

  @override
  State<MeasurementCaptureModal> createState() => _MeasurementCaptureModalState();
}

class _MeasurementCaptureModalState extends State<MeasurementCaptureModal> {
  final TextEditingController _distanceController = TextEditingController();
  late String _selectedMaterial;
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
      _selectedMaterial = m.material;
    } else {
      _selectedMaterial = widget.contextualConduits.isNotEmpty
          ? widget.contextualConduits.first
          : 'Tubo EMT 3/4"';
    }
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
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    isEditing ? 'Editar Cota de Medida' : 'Registrar Cota de Medida',
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
            const SizedBox(height: 16),

            // Selector contextual de Canalización / Tubería
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Canalización / Material:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                if (widget.contextualConduits.isNotEmpty)
                  const Text(
                    '📍 Sugerido de pines',
                    style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Chips de canalización
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _buildMaterialChips(),
            ),

            const SizedBox(height: 20),

            // Botones de acción (Eliminar si está editando, Cancelar, Guardar)
            Row(
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
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _submitMeasurement,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEditing ? 'Guardar Cambios' : 'Guardar Cota'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE3A51A),
                    foregroundColor: const Color(0xFF001F2F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMaterialChips() {
    final Set<String> allOptions = {};
    allOptions.addAll(widget.contextualConduits);
    allOptions.addAll([
      'Tubo EMT 3/4"',
      'Tubo EMT 1"',
      'Canaleta 40x25',
      'Canaleta 25x14',
      'Tubo PVC SAP 3/4"',
      'Bandeja Portacables',
      'Cable UTP Cat6',
    ]);

    return allOptions.take(8).map((mat) {
      final bool isSelected = _selectedMaterial == mat;
      final bool isFromPin = widget.contextualConduits.contains(mat);

      return ChoiceChip(
        label: Text(
          isFromPin ? '★ $mat' : mat,
          style: TextStyle(
            color: isSelected ? const Color(0xFF001F2F) : Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFE3A51A),
        backgroundColor: const Color(0xFF0F172A),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFE3A51A)
              : (isFromPin ? const Color(0xFF4ADE80) : const Color(0xFF334155)),
          width: isFromPin ? 1.4 : 1.0,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedMaterial = mat);
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

    final result = (widget.existingMeasurement != null)
        ? widget.existingMeasurement!.copyWith(
            longitudMetros: meters,
            material: _selectedMaterial,
          )
        : LinearMeasurement(
            id: 'cota_${DateTime.now().millisecondsSinceEpoch}',
            startOffset: widget.start,
            endOffset: widget.end,
            longitudMetros: meters,
            material: _selectedMaterial,
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
