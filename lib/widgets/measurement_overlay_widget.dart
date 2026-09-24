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
    // Micro-indicador técnico de manija de ajuste (cápsula compacta, sin círculos grandes ni halos de lupa)
    final TextSpan span = TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFF001F2F),
        fontSize: 9.0,
        fontWeight: FontWeight.w900,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final Offset badgeCenter = Offset(center.dx, center.dy - 16);
    final Rect badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: tp.width + 8,
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
    const double loupeDiameter = 114.0;
    const double loupeRadius = loupeDiameter / 2;

    // Desplazar la lupa 110px por encima del dedo para despejar por completo el área visual
    double loupeX = touchPosition.dx - loupeRadius;
    double loupeY = touchPosition.dy - 110.0;

    // Control de bordes de pantalla
    loupeX = loupeX.clamp(10.0, math.max(10.0, canvasSize.width - loupeDiameter - 10.0));
    bool invertedBelow = false;
    if (loupeY < 32.0) {
      // Si el punto está pegado al borde superior, invertir la lupa debajo del dedo
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
              // 1. Lente amplificador circular 100% nítido (SIN recortes dobles ni sombras internas)
              Container(
                width: loupeDiameter,
                height: loupeDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RawMagnifier(
                      decoration: const MagnifierDecoration(
                        shape: CircleBorder(),
                      ),
                      size: const Size(loupeDiameter, loupeDiameter),
                      magnificationScale: 2.4,
                      focalPointOffset: focalOffset,
                    ),
                    // Retícula táctica de ultra-precisión (SIN línea ecuatorial ni oscurecimiento)
                    CustomPaint(
                      size: const Size(loupeDiameter, loupeDiameter),
                      painter: CrosshairReticlePainter(color: accentColor),
                    ),
                  ],
                ),
              ),

              // 2. Etiqueta flotante con el paso activo colocada COMPLETAMENTE FUERA del lente
              if (label != null)
                Positioned(
                  top: invertedBelow ? loupeDiameter + 6 : -22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001F2F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label!,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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

/// Dibuja la retícula técnica militar con puntero central ("la punta") lista para alinear al milímetro.
/// 100% Despejada: SIN línea ecuatorial divisoria ni zonas sombreadas en la parte superior.
class CrosshairReticlePainter extends CustomPainter {
  final Color color;

  const CrosshairReticlePainter({this.color = const Color(0xFF00E676)});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Círculo exterior táctico sutil y limpio
    final Paint circlePaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), 36.0, circlePaint);

    // 2. Guías exteriores de alineación en los 4 extremos (N, S, E, O)
    // Dejando un radio central de 18px COMPLETAMENTE ABIERTO Y DESPEJADO
    // para que el punto y borde a señalar sean 100% visibles sin ninguna línea horizontal divisoria.
    final Paint guideLinePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final Paint guideShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    const double innerClearRadius = 18.0;
    const double outerGuideRadius = 38.0;

    // Horizontales (Oeste y Este): Ticks guía exteriores únicamente en los extremos
    // (¡NUNCA una línea continua que cruce el ecuador cy!)
    canvas.drawLine(Offset(cx - outerGuideRadius, cy), Offset(cx - innerClearRadius, cy), guideShadowPaint);
    canvas.drawLine(Offset(cx - outerGuideRadius, cy), Offset(cx - innerClearRadius, cy), guideLinePaint);
    canvas.drawLine(Offset(cx + innerClearRadius, cy), Offset(cx + outerGuideRadius, cy), guideShadowPaint);
    canvas.drawLine(Offset(cx + innerClearRadius, cy), Offset(cx + outerGuideRadius, cy), guideLinePaint);

    // Verticales (Norte y Sur): Ticks guía exteriores
    canvas.drawLine(Offset(cx, cy - outerGuideRadius), Offset(cx, cy - innerClearRadius), guideShadowPaint);
    canvas.drawLine(Offset(cx, cy - outerGuideRadius), Offset(cx, cy - innerClearRadius), guideLinePaint);
    canvas.drawLine(Offset(cx, cy + innerClearRadius), Offset(cx, cy + outerGuideRadius), guideShadowPaint);
    canvas.drawLine(Offset(cx, cy + innerClearRadius), Offset(cx, cy + outerGuideRadius), guideLinePaint);

    // 3. Punteros micro-guía hacia el centro focal (longitud 3.5px, radio 4.5px a 8px)
    final Paint microTickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx, cy - 8.0), Offset(cx, cy - 4.5), microTickPaint);
    canvas.drawLine(Offset(cx, cy + 4.5), Offset(cx, cy + 8.0), microTickPaint);
    canvas.drawLine(Offset(cx - 8.0, cy), Offset(cx - 4.5, cy), microTickPaint);
    canvas.drawLine(Offset(cx + 4.5, cy), Offset(cx + 8.0, cy), microTickPaint);

    // 4. Punto central focal de alta visibilidad (Punto blanco puro con contorno negro)
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
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
