import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/linear_measurement_model.dart';
import '../services/voice_recognition_service.dart';

/// Painter de alta fidelidad para dibujar cotas de ingeniería técnica sobre la fotografía
class MeasurementLinesPainter extends CustomPainter {
  final List<LinearMeasurement> measurements;
  final Offset? currentStart;
  final Offset? currentEnd;
  final String? activeMaterial;

  MeasurementLinesPainter({
    required this.measurements,
    this.currentStart,
    this.currentEnd,
    this.activeMaterial,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar todas las cotas finalizadas
    for (final m in measurements) {
      _drawDimensionLine(
        canvas: canvas,
        start: m.startOffset,
        end: m.endOffset,
        label: m.labelFormatted,
        isTemp: false,
      );
    }

    // 2. Dibujar la cota que se está trazando en vivo
    if (currentStart != null && currentEnd != null) {
      final double dx = currentEnd!.dx - currentStart!.dx;
      final double dy = currentEnd!.dy - currentStart!.dy;
      final double pixelDistance = math.sqrt(dx * dx + dy * dy);

      if (pixelDistance > 10) {
        _drawDimensionLine(
          canvas: canvas,
          start: currentStart!,
          end: currentEnd!,
          label: activeMaterial != null ? 'Trazando • $activeMaterial' : 'Ajustando cota...',
          isTemp: true,
        );
      }
    }
  }

  void _drawDimensionLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required String label,
    required bool isTemp,
  }) {
    final Color strokeColor = isTemp ? const Color(0xFF38BDF8) : const Color(0xFFE3A51A); // Azul en temp, Amarillo en fija
    final Color bgColor = const Color(0xFF001F2F).withValues(alpha: 0.90);

    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = isTemp ? 2.5 : 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Línea principal
    canvas.drawLine(start, end, linePaint);

    // Calcular vector unitario y perpendicular
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final double uX = dx / len;
    final double uY = dy / len;
    final double perpX = -uY;
    final double perpY = uX;

    // Dibujar topes perpendiculares (ticks) en los extremos
    const double tickLen = 9.0;
    final Paint tickPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Tick en Inicio
    canvas.drawLine(
      Offset(start.dx + perpX * tickLen, start.dy + perpY * tickLen),
      Offset(start.dx - perpX * tickLen, start.dy - perpY * tickLen),
      tickPaint,
    );
    // Tick en Fin
    canvas.drawLine(
      Offset(end.dx + perpX * tickLen, end.dy + perpY * tickLen),
      Offset(end.dx - perpX * tickLen, end.dy - perpY * tickLen),
      tickPaint,
    );

    // Puntos de anclaje (círculos) en los extremos
    final Paint pointPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 3.5, pointPaint);
    canvas.drawCircle(end, 3.5, pointPaint);

    // Etiqueta central con texto de metrado y material
    final Offset mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final TextSpan span = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
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

    final double padH = 6.0;
    final double padV = 3.5;
    final Rect bgRect = Rect.fromCenter(
      center: mid,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    final RRect rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(5));
    final Paint bgPaint = Paint()..color = bgColor;
    final Paint borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MeasurementLinesPainter oldDelegate) {
    return true;
  }
}

/// Lupa de magnificación flotante con retícula en cruz para aproximar al milímetro los bordes de estructuras
class LoupeMagnifierWidget extends StatelessWidget {
  final Offset touchPosition;
  final Size canvasSize;

  const LoupeMagnifierWidget({
    super.key,
    required this.touchPosition,
    required this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    // Desplazar la lupa 80px por encima del dedo para que el dedo no tape la vista
    double loupeX = touchPosition.dx - 45;
    double loupeY = touchPosition.dy - 100;

    // Asegurar que no se salga de los límites de la pantalla
    loupeX = loupeX.clamp(10.0, math.max(10.0, canvasSize.width - 100.0));
    if (loupeY < 10) {
      // Si está muy cerca del borde superior, mostrar la lupa debajo del dedo
      loupeY = touchPosition.dy + 35;
    }

    return Positioned(
      left: loupeX,
      top: loupeY,
      child: IgnorePointer(
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: const Color(0xFFE3A51A), width: 2.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
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
                  size: const Size(90, 90),
                  magnificationScale: 2.0,
                  focalPointOffset: Offset.zero,
                ),
                // Retícula de precisión (Cruz +)
                CustomPaint(
                  size: const Size(90, 90),
                  painter: CrosshairReticlePainter(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la cruz de precisión en el centro de la lupa
class CrosshairReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFF3366) // Rojo brillante de alta visibilidad
      ..strokeWidth = 1.2;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    const double len = 12.0;
    const double gap = 3.0;

    // Líneas horizontales
    canvas.drawLine(Offset(cx - len, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + len, cy), paint);

    // Líneas verticales
    canvas.drawLine(Offset(cx, cy - len), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + len), paint);

    // Punto central
    final Paint dotPaint = Paint()..color = const Color(0xFFFF3366);
    canvas.drawCircle(Offset(cx, cy), 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Diálogo compacto de captura rápida de longitud en metros y selección de material contextual
class MeasurementCaptureModal extends StatefulWidget {
  final Offset start;
  final Offset end;
  final List<String> contextualConduits; // Materiales de canalización detectados en los pines de la foto
  final VoiceRecognitionService voiceService;

  const MeasurementCaptureModal({
    super.key,
    required this.start,
    required this.end,
    required this.contextualConduits,
    required this.voiceService,
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
    // Seleccionar por defecto el primer material contextual si existe
    _selectedMaterial = widget.contextualConduits.isNotEmpty
        ? widget.contextualConduits.first
        : 'Tubo EMT 3/4"';
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

        // Intentar extraer número decimal de la voz (ej: "12 punto 5", "quince metros", "3.80")
        final number = _extractMetersFromVoice(text);
        if (number != null && number > 0) {
          _distanceController.text = number.toStringAsFixed(2);
        }
      },
    );
  }

  double? _extractMetersFromVoice(String spoken) {
    // Normalizar texto
    String clean = spoken.toLowerCase()
        .replaceAll('metros', '')
        .replaceAll('metro', '')
        .replaceAll('mts', '')
        .replaceAll('m', '')
        .trim();

    // Reemplazar palabras numéricas comunes o comas por puntos
    clean = clean.replaceAll('coma', '.').replaceAll('punto', '.');
    
    // Buscar regex numérico (ej. "12.5" o "12")
    final match = RegExp(r'(\d+[\.,]?\d*)').firstMatch(clean);
    if (match != null) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(numStr);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(
                    Icons.straighten,
                    color: Color(0xFF001F2F),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registrar Cota de Medida',
                    style: TextStyle(
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

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _submitMeasurement,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Guardar Cota'),
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
    // Combinar los contextuales con los estándares
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

    final newMeasurement = LinearMeasurement(
      id: 'cota_${DateTime.now().millisecondsSinceEpoch}',
      startOffset: widget.start,
      endOffset: widget.end,
      longitudMetros: meters,
      material: _selectedMaterial,
    );

    Navigator.pop(context, newMeasurement);
  }
}
