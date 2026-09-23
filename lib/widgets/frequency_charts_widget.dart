import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/session_evidence_model.dart';

/// Paleta cromática corporativa y de alto contraste para los gráficos
const List<Color> kChartPalette = [
  Color(0xFFE3A51A), // Amarillo Vigilarte
  Color(0xFF38BDF8), // Azul Eléctrico
  Color(0xFF10B981), // Verde Esmeralda
  Color(0xFFF97316), // Naranja
  Color(0xFFA855F7), // Violeta
  Color(0xFFEC4899), // Fucsia
  Color(0xFF06B6D4), // Cyan
  Color(0xFFF43F5E), // Rojo Coral
  Color(0xFF6366F1), // Índigo
  Color(0xFF84CC16), // Lima
];

/// Gráfico Circular / Donut de distribución porcentual
class DonutChartWidget extends StatelessWidget {
  final List<ItemFrequency> items;
  final String title;
  final String centerSubtitle;

  const DonutChartWidget({
    super.key,
    required this.items,
    this.title = 'Distribución Porcentual',
    this.centerSubtitle = 'Ítems Totales',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          'No hay datos suficientes para generar el gráfico circular.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final int totalCount = items.fold(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: Color(0xFFE3A51A), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(170, 170),
                    painter: _DonutChartPainter(
                      items: items,
                      totalCount: totalCount,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        centerSubtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Leyenda interactiva de colores y porcentajes
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final color = kChartPalette[index % kChartPalette.length];
              final double itemPercent =
                  totalCount > 0 ? (item.count / totalCount) * 100 : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${itemPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<ItemFrequency> items;
  final int totalCount;

  _DonutChartPainter({required this.items, required this.totalCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalCount <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < items.length; i++) {
      final sweepAngle = (items[i].count / totalCount) * 2 * math.pi;
      paint.color = kChartPalette[i % kChartPalette.length];

      // Reducir levemente para dejar separación estética entre arcos
      final actualSweep = math.max(0.02, sweepAngle - 0.04);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        actualSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.totalCount != totalCount || oldDelegate.items != items;
  }
}

/// Gráfico de Barras Horizontales con frecuencia de repetición y porcentaje
class FrequencyBarChartWidget extends StatelessWidget {
  final List<ItemFrequency> items;
  final String title;
  final Color accentColor;
  final IconData icon;

  const FrequencyBarChartWidget({
    super.key,
    required this.items,
    required this.title,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          'No hay registros para mostrar en el gráfico de barras.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final int maxCount = items.fold(1, (max, i) => i.count > max ? i.count : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${items.length} variantes',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...items.map((item) {
            final double ratio = maxCount > 0 ? (item.count / maxCount) : 0.0;
            final bool isCrit = item.isIndispensable;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isCrit) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFE3A51A),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Conteo de repetición y porcentaje
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.count}x',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.percentage.toStringAsFixed(0)}% fotos',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Barra horizontal con gradiente
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.04, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.6),
                                  accentColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (item.areas.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'En: ${item.areas.join(", ")}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
