import 'package:flutter/material.dart';

enum StickerCategory { estructuras, materiales, peligros }

class StickerModel {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
  final StickerCategory category;

  const StickerModel({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
    required this.category,
  });

  /// Crea un sticker a partir de una cadena y una categoría, asignando colores e íconos adecuados
  factory StickerModel.fromCatalog(String title, StickerCategory category) {
    switch (category) {
      case StickerCategory.estructuras:
        return StickerModel(
          title: title,
          icon: Icons.foundation,
          backgroundColor: const Color(0xFF1E293B),
          accentColor: const Color(0xFF38BDF8),
          category: category,
        );
      case StickerCategory.materiales:
        return StickerModel(
          title: title,
          icon: Icons.hardware,
          backgroundColor: const Color(0xFF14532D),
          accentColor: const Color(0xFF4ADE80),
          category: category,
        );
      case StickerCategory.peligros:
        return StickerModel(
          title: title,
          icon: Icons.warning_amber_rounded,
          backgroundColor: const Color(0xFF7C2D12),
          accentColor: const Color(0xFFFBBF24),
          category: category,
        );
    }
  }
}

class PlacedSticker {
  final String id;
  StickerModel sticker;
  Offset position;
  double scale;
  double rotation;

  PlacedSticker({
    required this.id,
    required this.sticker,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}
