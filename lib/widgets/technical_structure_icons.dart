import 'package:flutter/material.dart';
import '../models/sticker_model.dart';

/// Renderizador de iconos técnicos altamente representativos y realistas
/// (Fierro = Viga H / Metallic Beam, Concreto = Pared con piedras, Teja = Teja colonial curva, etc.)
class TechnicalStructureIconWidget extends StatelessWidget {
  final String name;
  final StickerCategory category;
  final double size;
  final Color? color;

  const TechnicalStructureIconWidget({
    super.key,
    required this.name,
    this.category = StickerCategory.estructuras,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase().trim();

    if (category == StickerCategory.estructuras) {
      if (lower.contains('fierro') || lower.contains('acero') || lower.contains('metal')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _HBeamPainter(color ?? const Color(0xFF38BDF8)),
        );
      }
      if (lower.contains('concreto')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _ConcreteWallPainter(color ?? const Color(0xFF94A3B8)),
        );
      }
      if (lower.contains('teja')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _RoofTilePainter(color ?? const Color(0xFFF97316)),
        );
      }
      if (lower.contains('ladrillo')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _BrickWallPainter(color ?? const Color(0xFFEA580C)),
        );
      }
      if (lower.contains('madera')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _WoodPlankPainter(color ?? const Color(0xFFD97706)),
        );
      }
      if (lower.contains('vidrio')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _GlassPanePainter(color ?? const Color(0xFF67E8F9)),
        );
      }
      if (lower.contains('drywall')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _DrywallPainter(color ?? const Color(0xFFCBD5E1)),
        );
      }
      if (lower.contains('mayolica') || lower.contains('mayólica') || lower.contains('ceramica')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _CeramicTilePainter(color ?? const Color(0xFF2DD4BF)),
        );
      }
      if (lower.contains('policarbonato')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _PolycarbonatePainter(color ?? const Color(0xFF38BDF8)),
        );
      }
    } else if (category == StickerCategory.materiales) {
      if (lower.contains('canaleta')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _CanaletaPainter(color ?? const Color(0xFF10B981)),
        );
      }
      if (lower.contains('emt') || lower.contains('imc') || lower.contains('pvc') || lower.contains('tubo')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _ConduitPipePainter(color ?? const Color(0xFF10B981)),
        );
      }
      if (lower.contains('bandeja')) {
        return CustomPaint(
          size: Size(size, size),
          painter: _CableTrayPainter(color ?? const Color(0xFF10B981)),
        );
      }
    }

    // Fallback estándar con icono Material
    final IconData icon = _getFallbackIcon(lower, category);
    return Icon(icon, size: size, color: color ?? Colors.white);
  }

  static IconData _getFallbackIcon(String lower, StickerCategory category) {
    if (category == StickerCategory.peligros) {
      if (lower.contains('electric') || lower.contains('eléctric')) return Icons.electric_bolt;
      if (lower.contains('altura') || lower.contains('caida')) return Icons.stairs;
      if (lower.contains('piso') || lower.contains('suelo')) return Icons.do_not_step;
      return Icons.warning_amber_rounded;
    }
    return Icons.category_rounded;
  }
}

/// 1. Viga H / Perfil Metálico (H-Beam / I-Beam) para Fierro y Acero
class _HBeamPainter extends CustomPainter {
  final Color color;
  _HBeamPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final flangeThick = h * 0.22;
    final webThick = w * 0.22;

    final paintFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      // Ala superior
      ..moveTo(w * 0.1, h * 0.08)
      ..lineTo(w * 0.9, h * 0.08)
      ..lineTo(w * 0.9, h * 0.08 + flangeThick)
      // Unión al alma derecha
      ..lineTo(w * 0.5 + webThick / 2, h * 0.08 + flangeThick)
      ..lineTo(w * 0.5 + webThick / 2, h * 0.92 - flangeThick)
      // Ala inferior derecha
      ..lineTo(w * 0.9, h * 0.92 - flangeThick)
      ..lineTo(w * 0.9, h * 0.92)
      ..lineTo(w * 0.1, h * 0.92)
      ..lineTo(w * 0.1, h * 0.92 - flangeThick)
      // Unión al alma izquierda
      ..lineTo(w * 0.5 - webThick / 2, h * 0.92 - flangeThick)
      ..lineTo(w * 0.5 - webThick / 2, h * 0.08 + flangeThick)
      ..lineTo(w * 0.1, h * 0.08 + flangeThick)
      ..close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintBorder);

    // Brillo metálico en el centro
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.5, h * 0.32), Offset(w * 0.5, h * 0.68), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _HBeamPainter oldDelegate) => oldDelegate.color != color;
}

/// 2. Concreto: Pared / Muro con pequeños elementos de piedra (áridos)
class _ConcreteWallPainter extends CustomPainter {
  final Color color;
  _ConcreteWallPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bloque de muro de concreto
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.76),
      const Radius.circular(3),
    );

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(rect, borderPaint);

    // Piedras / gravilla / agregados incrustados en el concreto
    final stoneDark = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;
    final stoneLight = Paint()..color = const Color(0xFFF1F5F9)..style = PaintingStyle.fill;
    final stoneMid = Paint()..color = const Color(0xFF475569)..style = PaintingStyle.fill;

    // Piedras poligonales y redondas distribuidas
    canvas.drawCircle(Offset(w * 0.28, h * 0.34), 2.2, stoneDark);
    canvas.drawCircle(Offset(w * 0.68, h * 0.32), 2.6, stoneMid);
    canvas.drawCircle(Offset(w * 0.46, h * 0.52), 1.8, stoneLight);
    canvas.drawCircle(Offset(w * 0.25, h * 0.68), 2.4, stoneMid);
    canvas.drawCircle(Offset(w * 0.72, h * 0.66), 2.0, stoneDark);
    canvas.drawCircle(Offset(w * 0.52, h * 0.74), 1.5, stoneLight);

    // Pequeño triángulo de piedra
    final pPath = Path()
      ..moveTo(w * 0.38, h * 0.26)
      ..lineTo(w * 0.45, h * 0.24)
      ..lineTo(w * 0.42, h * 0.32)
      ..close();
    canvas.drawPath(pPath, stoneDark);
  }

  @override
  bool shouldRepaint(covariant _ConcreteWallPainter oldDelegate) => oldDelegate.color != color;
}

/// 3. Teja: Forma tradicional colonial ondulada / curvada
class _RoofTilePainter extends CustomPainter {
  final Color color;
  _RoofTilePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final tilePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFF7C2D12)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Fila 1 (inferior): 3 arcos de teja curva
    for (int i = 0; i < 3; i++) {
      final startX = w * (0.1 + i * 0.27);
      final tileW = w * 0.26;
      final y = h * 0.55;

      final path = Path()
        ..moveTo(startX, y + h * 0.25)
        ..quadraticBezierTo(startX + tileW / 2, y, startX + tileW, y + h * 0.25)
        ..lineTo(startX + tileW * 0.85, y + h * 0.32)
        ..quadraticBezierTo(startX + tileW / 2, y + h * 0.1, startX + tileW * 0.15, y + h * 0.32)
        ..close();

      canvas.drawPath(path, tilePaint);
      canvas.drawPath(path, borderPaint);
    }

    // Fila 2 (superior intercalada): 2 tejas
    for (int i = 0; i < 2; i++) {
      final startX = w * (0.24 + i * 0.27);
      final tileW = w * 0.26;
      final y = h * 0.22;

      final path = Path()
        ..moveTo(startX, y + h * 0.25)
        ..quadraticBezierTo(startX + tileW / 2, y, startX + tileW, y + h * 0.25)
        ..lineTo(startX + tileW * 0.85, y + h * 0.32)
        ..quadraticBezierTo(startX + tileW / 2, y + h * 0.1, startX + tileW * 0.15, y + h * 0.32)
        ..close();

      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, tilePaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoofTilePainter oldDelegate) => oldDelegate.color != color;
}

/// 4. Muro de Ladrillos con juntas trabadas
class _BrickWallPainter extends CustomPainter {
  final Color color;
  _BrickWallPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..color = const Color(0xFF64748B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.76), const Radius.circular(2)), bg);

    final brick = Paint()..color = color;
    final border = Paint()..color = Colors.black.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 0.8;

    // Fila 1
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.38, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.38, h * 0.2), border);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.15, w * 0.38, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.15, w * 0.38, h * 0.2), border);

    // Fila 2 (trabada)
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.40, w * 0.16, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.40, w * 0.16, h * 0.2), border);
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.40, w * 0.40, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.40, w * 0.40, h * 0.2), border);
    canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.40, w * 0.16, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.40, w * 0.16, h * 0.2), border);

    // Fila 3
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.65, w * 0.38, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.65, w * 0.38, h * 0.2), border);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.65, w * 0.38, h * 0.2), brick);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.65, w * 0.38, h * 0.2), border);
  }

  @override
  bool shouldRepaint(covariant _BrickWallPainter oldDelegate) => oldDelegate.color != color;
}

/// 5. Madera: Listón con vetas
class _WoodPlankPainter extends CustomPainter {
  final Color color;
  _WoodPlankPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.76), const Radius.circular(3));
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Vetas de madera
    final grain = Paint()..color = const Color(0xFF78350F)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final path1 = Path()..moveTo(w * 0.15, h * 0.3)..quadraticBezierTo(w * 0.5, h * 0.45, w * 0.85, h * 0.25);
    final path2 = Path()..moveTo(w * 0.15, h * 0.55)..quadraticBezierTo(w * 0.6, h * 0.7, w * 0.85, h * 0.5);
    final path3 = Path()..moveTo(w * 0.15, h * 0.75)..quadraticBezierTo(w * 0.4, h * 0.85, w * 0.85, h * 0.75);

    canvas.drawPath(path1, grain);
    canvas.drawPath(path2, grain);
    canvas.drawPath(path3, grain);
  }

  @override
  bool shouldRepaint(covariant _WoodPlankPainter oldDelegate) => oldDelegate.color != color;
}

/// 6. Vidrio: Cristal con reflejo diagonal
class _GlassPanePainter extends CustomPainter {
  final Color color;
  _GlassPanePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76), const Radius.circular(3));
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawRRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Destellos de reflejo diagonal
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.3, h * 0.65), Offset(w * 0.65, h * 0.3), shine);
    canvas.drawLine(Offset(w * 0.45, h * 0.75), Offset(w * 0.75, h * 0.45), shine..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant _GlassPanePainter oldDelegate) => oldDelegate.color != color;
}

/// 7. Drywall: Plancha de yeso con tornillos
class _DrywallPainter extends CustomPainter {
  final Color color;
  _DrywallPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.76), const Radius.circular(2));
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Puntos de tornillos en esquinas
    final screw = Paint()..color = const Color(0xFF334155)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.22, h * 0.25), 1.6, screw);
    canvas.drawCircle(Offset(w * 0.78, h * 0.25), 1.6, screw);
    canvas.drawCircle(Offset(w * 0.22, h * 0.75), 1.6, screw);
    canvas.drawCircle(Offset(w * 0.78, h * 0.75), 1.6, screw);
  }

  @override
  bool shouldRepaint(covariant _DrywallPainter oldDelegate) => oldDelegate.color != color;
}

/// 8. Cerámica / Mayólica: Malla 2x2 de azulejos
class _CeramicTilePainter extends CustomPainter {
  final Color color;
  _CeramicTilePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.76), bg);

    final tile = Paint()..color = color;
    const pad = 2.0;
    final tw = (w * 0.8 - pad) / 2;
    final th = (h * 0.76 - pad) / 2;

    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.12, tw, th), tile);
    canvas.drawRect(Rect.fromLTWH(w * 0.1 + tw + pad, h * 0.12, tw, th), tile);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.12 + th + pad, tw, th), tile);
    canvas.drawRect(Rect.fromLTWH(w * 0.1 + tw + pad, h * 0.12 + th + pad, tw, th), tile);
  }

  @override
  bool shouldRepaint(covariant _CeramicTilePainter oldDelegate) => oldDelegate.color != color;
}

/// 9. Policarbonato: Plancha alveolar transparente
class _PolycarbonatePainter extends CustomPainter {
  final Color color;
  _PolycarbonatePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.7);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);

    final line = Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 1.0;
    for (int i = 1; i <= 4; i++) {
      final x = w * (0.1 + i * 0.16);
      canvas.drawLine(Offset(x, h * 0.15), Offset(x, h * 0.85), line);
    }
  }

  @override
  bool shouldRepaint(covariant _PolycarbonatePainter oldDelegate) => oldDelegate.color != color;
}

/// 10. Tubería Conduit (EMT, IMC, PVC)
class _ConduitPipePainter extends CustomPainter {
  final Color color;
  _ConduitPipePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final pipeRect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.32, w * 0.84, h * 0.36), const Radius.circular(4));
    canvas.drawRRect(pipeRect, Paint()..color = color);
    canvas.drawRRect(pipeRect, Paint()..color = Colors.black.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Conectores en extremos
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.26, w * 0.14, h * 0.48), const Radius.circular(2)), Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.81, h * 0.26, w * 0.14, h * 0.48), const Radius.circular(2)), Paint()..color = const Color(0xFFE2E8F0));
  }

  @override
  bool shouldRepaint(covariant _ConduitPipePainter oldDelegate) => oldDelegate.color != color;
}

/// 11. Canaleta
class _CanaletaPainter extends CustomPainter {
  final Color color;
  _CanaletaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = Rect.fromLTWH(w * 0.1, h * 0.25, w * 0.8, h * 0.5);
    canvas.drawRect(body, Paint()..color = color);
    canvas.drawRect(body, Paint()..color = Colors.black.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Tapa frontal ranurada
    final line = Paint()..color = Colors.white.withValues(alpha: 0.8)..strokeWidth = 1.2;
    canvas.drawLine(Offset(w * 0.15, h * 0.5), Offset(w * 0.85, h * 0.5), line);
  }

  @override
  bool shouldRepaint(covariant _CanaletaPainter oldDelegate) => oldDelegate.color != color;
}

/// 12. Bandeja Portacables
class _CableTrayPainter extends CustomPainter {
  final Color color;
  _CableTrayPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rails = Paint()..color = color..strokeWidth = 2.2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.1, h * 0.25), Offset(w * 0.9, h * 0.25), rails);
    canvas.drawLine(Offset(w * 0.1, h * 0.75), Offset(w * 0.9, h * 0.75), rails);

    final rungs = Paint()..color = color..strokeWidth = 1.4;
    for (int i = 0; i < 5; i++) {
      final x = w * (0.18 + i * 0.16);
      canvas.drawLine(Offset(x, h * 0.25), Offset(x, h * 0.75), rungs);
    }
  }

  @override
  bool shouldRepaint(covariant _CableTrayPainter oldDelegate) => oldDelegate.color != color;
}
