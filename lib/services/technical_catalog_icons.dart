import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import '../widgets/technical_structure_icons.dart';

/// Catálogo visual de iconos especializados para cada estructura y material de VISTEC
class TechnicalCatalogIcons {
  /// Retorna un widget visual realista (Fierro = Viga H, Concreto = Pared con piedras, Teja = Teja tradicional, etc.)
  static Widget buildIcon(
    String name,
    StickerCategory category, {
    double size = 20.0,
    Color? color,
  }) {
    return TechnicalStructureIconWidget(
      name: name,
      category: category,
      size: size,
      color: color,
    );
  }

  /// Retorna el icono representativo exacto para cada tipo de estructura
  static IconData getStructureIcon(String structureName) {
    final lower = structureName.toLowerCase().trim();

    if (lower.contains('madera')) {
      return Icons.forest_outlined;
    }
    if (lower.contains('fierro') || lower.contains('acero') || lower.contains('metal')) {
      return Icons.hardware;
    }
    if (lower.contains('ladrillo')) {
      return Icons.grid_view_rounded;
    }
    if (lower.contains('vidrio')) {
      return Icons.window_outlined;
    }
    if (lower.contains('concreto')) {
      return Icons.foundation;
    }
    if (lower.contains('drywall')) {
      return Icons.layers_outlined;
    }
    if (lower.contains('mayolica') || lower.contains('mayólica') || lower.contains('ceramica')) {
      return Icons.grid_on;
    }
    if (lower.contains('policarbonato')) {
      return Icons.solar_power_outlined;
    }
    if (lower.contains('teja')) {
      return Icons.roofing;
    }

    return Icons.domain;
  }

  /// Retorna el icono representativo exacto para cada tipo de material de canalización
  static IconData getMaterialIcon(String materialName) {
    final lower = materialName.toLowerCase().trim();

    if (lower.contains('emt')) {
      return Icons.linear_scale;
    }
    if (lower.contains('imc')) {
      return Icons.line_weight;
    }
    if (lower.contains('canaleta')) {
      return Icons.view_column_rounded;
    }
    if (lower.contains('pvc')) {
      return Icons.water_drop_outlined;
    }
    if (lower.contains('liquid') || lower.contains('tight')) {
      return Icons.waves;
    }
    if (lower.contains('bandeja')) {
      return Icons.table_rows_outlined;
    }
    if (lower.contains('caja')) {
      return Icons.check_box_outline_blank;
    }
    if (lower.contains('corrugado')) {
      return Icons.all_inclusive;
    }
    if (lower.contains('cable') || lower.contains('utp') || lower.contains('fibra')) {
      return Icons.cable;
    }

    return Icons.inventory_2_outlined;
  }

  /// Retorna el icono para peligros SST
  static IconData getHazardIcon(String hazardName) {
    final lower = hazardName.toLowerCase().trim();

    if (lower.contains('electric') || lower.contains('eléctric')) {
      return Icons.electric_bolt;
    }
    if (lower.contains('altura') || lower.contains('caida') || lower.contains('caída')) {
      return Icons.stairs;
    }
    if (lower.contains('piso') || lower.contains('suelo') || lower.contains('resbal')) {
      return Icons.do_not_step;
    }
    if (lower.contains('confinado')) {
      return Icons.compress;
    }
    if (lower.contains('corte') || lower.contains('atrapam')) {
      return Icons.content_cut;
    }
    if (lower.contains('caliente') || lower.contains('fuego')) {
      return Icons.local_fire_department;
    }

    return Icons.warning_amber_rounded;
  }

  /// Retorna el icono representativo para el tipo de sistema o servicio a instalar
  static IconData getProjectSystemIcon(String? projectType) {
    if (projectType == null || projectType.trim().isEmpty) {
      return Icons.work_outline;
    }
    final lower = projectType.toLowerCase().trim();

    if (lower.contains('camara') ||
        lower.contains('cámara') ||
        lower.contains('cctv') ||
        lower.contains('video')) {
      return Icons.videocam_rounded;
    }
    if (lower.contains('acceso') ||
        lower.contains('asistencia') ||
        lower.contains('biometr')) {
      return Icons.fingerprint_rounded;
    }
    if (lower.contains('incendio') ||
        lower.contains('humo') ||
        lower.contains('fuego') ||
        lower.contains('deteccion') ||
        lower.contains('detección')) {
      return Icons.local_fire_department_rounded;
    }
    if (lower.contains('intrusion') ||
        lower.contains('intrusión') ||
        lower.contains('alarma') ||
        lower.contains('cerco')) {
      return Icons.security_rounded;
    }
    if (lower.contains('cableado') ||
        lower.contains('red') ||
        lower.contains('datos') ||
        lower.contains('estructurado')) {
      return Icons.lan_rounded;
    }
    if (lower.contains('fibra') ||
        lower.contains('inalambric') ||
        lower.contains('inalámbric') ||
        lower.contains('enlace') ||
        lower.contains('antena')) {
      return Icons.settings_input_antenna_rounded;
    }
    if (lower.contains('electric') ||
        lower.contains('eléctric') ||
        lower.contains('canalizacion') ||
        lower.contains('canalización') ||
        lower.contains('tablero') ||
        lower.contains('pozo')) {
      return Icons.electrical_services_rounded;
    }
    if (lower.contains('mantenimiento') ||
        lower.contains('preventivo') ||
        lower.contains('correctivo')) {
      return Icons.build_circle_outlined;
    }
    if (lower.contains('sst') ||
        lower.contains('seguridad') ||
        lower.contains('inspeccion') ||
        lower.contains('inspección')) {
      return Icons.health_and_safety_rounded;
    }

    return Icons.engineering_rounded;
  }
}
