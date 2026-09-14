import 'package:flutter/material.dart';

/// Información visual y comercial de una herramienta o material para facilitar su compra e identificación
class VisualCatalogItem {
  final String title;
  final String category; // 'Herramienta' o 'Material'
  final String commercialName; // Nombre común en ferretería o tienda
  final String specification; // Especificación técnica sugerida para cotizar
  final String imageUrl; // Foto real representativa
  final IconData fallbackIcon;
  final Color badgeColor;

  const VisualCatalogItem({
    required this.title,
    required this.category,
    required this.commercialName,
    required this.specification,
    required this.imageUrl,
    required this.fallbackIcon,
    this.badgeColor = const Color(0xFF38BDF8),
  });
}

class CatalogVisualService {
  /// Catálogo visual enriquecido con imágenes reales y descripciones de compra
  static final Map<String, VisualCatalogItem> _catalog = {
    // ================= HERRAMIENTAS =================
    'ROTOMARTILLO SDS PLUS / MAX': const VisualCatalogItem(
      title: 'Rotomartillo SDS Plus / Max',
      category: 'Herramienta Eléctrica',
      commercialName: 'Rotomartillo percutor profesional SDS Plus',
      specification: 'Potencia 800W-1000W, encastre SDS Plus, con selector de cincelado y percusión.',
      imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.handyman,
      badgeColor: Color(0xFFEF4444),
    ),
    'DOBLADOR DE TUBO EMT (HICKEY / CURVADORA)': const VisualCatalogItem(
      title: 'Doblador de tubo EMT (Hickey / Curvadora)',
      category: 'Herramienta de Montaje',
      commercialName: 'Curvadora manual para tubo EMT / Conduit',
      specification: 'Curvador de aluminio o hierro dúctil con marcas de grados (30°, 45°, 90°) para tubo de 3/4" o 1/2".',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.architecture,
      badgeColor: Color(0xFFF59E0B),
    ),
    'BROCAS SDS DE PERCUSION PARA CONCRETO': const VisualCatalogItem(
      title: 'Brocas SDS de percusión para concreto',
      category: 'Consumible / Accesorio',
      commercialName: 'Juego de brocas SDS Plus para pared y concreto',
      specification: 'Brocas con punta de carburo de tungsteno (Widia) en medidas 1/4", 5/16", 3/8" y 1/2".',
      imageUrl: 'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.hardware,
      badgeColor: Color(0xFF10B981),
    ),
    'AMOLADORA ANGULAR CON DISCO DE CORTE Y DESBASTE': const VisualCatalogItem(
      title: 'Amoladora angular con disco de corte y desbaste',
      category: 'Herramienta Eléctrica',
      commercialName: 'Esmeril angular / Amoladora 4-1/2"',
      specification: 'Amoladora 4-1/2" 850W con guarda protectora y discos de corte extrafino para metal/inox.',
      imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.construction,
      badgeColor: Color(0xFFEF4444),
    ),
    'TALADRO PERCUTOR / ATORNILLADOR': const VisualCatalogItem(
      title: 'Taladro percutor / Atornillador',
      category: 'Herramienta Eléctrica',
      commercialName: 'Taladro inalámbrico 18V / 20V con percusión',
      specification: 'Batería Litio 20V, mandril de 1/2" metálico, control de torque y 2 velocidades mecánicas.',
      imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.build,
      badgeColor: Color(0xFF38BDF8),
    ),
    'NIVEL DE MANO / NIVEL LASER': const VisualCatalogItem(
      title: 'Nivel de mano / Nivel láser',
      category: 'Herramienta de Medición',
      commercialName: 'Nivel torpedo magnético de 9" o Nivel Láser verde',
      specification: 'Cuerpo de aluminio con base imantada para tubería metálica y 3 burbujas (0°, 45°, 90°).',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.straighten,
      badgeColor: Color(0xFF06B6D4),
    ),
    'FLEXOMETRO / CINTA METRICA': const VisualCatalogItem(
      title: 'Flexómetro / Cinta métrica',
      category: 'Herramienta de Medición',
      commercialName: 'Wincha / Cinta métrica 5m o 8m de alta resistencia',
      specification: 'Cinta de 5m con cinta ancha antigolpes y gancho magnético.',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.square_foot,
      badgeColor: Color(0xFF64748B),
    ),
    'TIJERA CORTACANALETAS / INGLETADORA': const VisualCatalogItem(
      title: 'Tijera cortacanaletas / Ingletadora',
      category: 'Herramienta de Corte',
      commercialName: 'Tijera multi-ángulo para canaletas y molduras PVC',
      specification: 'Cuchilla de acero con base graduada de 45° a 135° para cortes limpios sin rebarba.',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.content_cut,
      badgeColor: Color(0xFF8B5CF6),
    ),
    'GUIA PASACABLES DE NYLON / ACERO': const VisualCatalogItem(
      title: 'Guía pasacables de nylon / acero',
      category: 'Herramienta de Cableado',
      commercialName: 'Guía pasacables / Laza cables 15m o 30m',
      specification: 'Alma de acero recubierta de nylon flexible de 4mm con puntera de bronce y ojal de tracción.',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.cable,
      badgeColor: Color(0xFFEC4899),
    ),
    'TERRAJA MANUAL O ELECTRICA PARA ROSCAR IMC': const VisualCatalogItem(
      title: 'Terraja manual o eléctrica para roscar IMC',
      category: 'Herramienta de Taller',
      commercialName: 'Terraja de trinquete para tubería Conduit / NPT',
      specification: 'Juego de cabezales intercambiables de 1/2", 3/4" y 1" NPT con peines de aleación templada.',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.settings,
      badgeColor: Color(0xFFF97316),
    ),

    // ================= MATERIALES =================
    'TUBO EMT': const VisualCatalogItem(
      title: 'Tubo EMT',
      category: 'Tubería Eléctrica',
      commercialName: 'Tubería metálica rígida liviana Conduit EMT',
      specification: 'Tiras de 3 metros, acero galvanizado, diámetros estándar 1/2", 3/4" o 1", norma ANSI C80.3.',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.view_column,
      badgeColor: Color(0xFF4ADE80),
    ),
    'CANALETAS': const VisualCatalogItem(
      title: 'Canaletas',
      category: 'Canalización PVC',
      commercialName: 'Canaleta decorativa de superficie con división',
      specification: 'Tramos de 2m, PVC autoextinguible con adhesivo doble contacto o perforaciones para fijación (ej. 20x10, 40x25).',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.line_weight,
      badgeColor: Color(0xFF4ADE80),
    ),
    'TUBO PVC SAP': const VisualCatalogItem(
      title: 'Tubo PVC SAP',
      category: 'Tubería Eléctrica',
      commercialName: 'Tubo eléctrico PVC Standard Americano Pesado (SAP)',
      specification: 'Tiras de 3m con campana en un extremo, resistente a impactos, para empotrado en piso o concreto.',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.lens_blur,
      badgeColor: Color(0xFF4ADE80),
    ),
    'TUBO PVC SEL': const VisualCatalogItem(
      title: 'Tubo PVC SEL',
      category: 'Tubería Eléctrica',
      commercialName: 'Tubo eléctrico PVC Standard Europeo Liviano (SEL)',
      specification: 'Tiras de 3m para canalización liviana en cielos rasos y tabiques.',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.lens_blur,
      badgeColor: Color(0xFF4ADE80),
    ),
    'CORRUGADO PVC': const VisualCatalogItem(
      title: 'Corrugado PVC',
      category: 'Canalización Flexible',
      commercialName: 'Manguera corrugada plástica flexible para cables',
      specification: 'Rollos de 50m o 100m, libre de halógenos / no propagador de llama, 1/2" y 3/4".',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.gesture,
      badgeColor: Color(0xFF4ADE80),
    ),
    'CORRUGADO LIQUID TIGHT': const VisualCatalogItem(
      title: 'Corrugado Liquid Tight',
      category: 'Canalización Hermética',
      commercialName: 'Tubería metálica flexible hermética a líquidos (Liquid Tight)',
      specification: 'Núcleo de acero galvanizado con recubrimiento de PVC para intemperie, motores o bombas (IP66).',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.water_drop,
      badgeColor: Color(0xFF4ADE80),
    ),
    'TUBO IMC': const VisualCatalogItem(
      title: 'Tubo IMC',
      category: 'Tubería Pesada',
      commercialName: 'Tubería Conduit metálica intermedia (IMC) roscada',
      specification: 'Acero galvanizado por inmersión en caliente con rosca NPT en ambos extremos, apto zonas industriales.',
      imageUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186f5f7?w=600&auto=format&fit=crop&q=80',
      fallbackIcon: Icons.view_column,
      badgeColor: Color(0xFF4ADE80),
    ),
  };

  /// Normaliza una clave para búsqueda insensible a mayúsculas y tildes
  static String _normalize(String key) {
    return key
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .trim();
  }

  /// Convierte enlaces de Google Drive comunes a enlaces de imagen directos
  static String normalizeImageUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';

    // Manejo de URLs de Google Drive tipo:
    // https://drive.google.com/file/d/FILE_ID/view...
    // https://drive.google.com/open?id=FILE_ID
    if (clean.contains('drive.google.com')) {
      final matchId = RegExp(r'(?:/d/|id=)([a-zA-Z0-9_-]+)').firstMatch(clean);
      if (matchId != null) {
        final fileId = matchId.group(1);
        return 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }
    return clean;
  }

  /// Actualiza o amplía el catálogo visual dinámicamente con los datos provenientes de Google Sheets
  static void updateFromSheets(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final name = (item['item'] ?? item['Item'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final category = (item['categoria'] ?? item['Categoria'] ?? 'Herramienta').toString().trim();
      final commercial = (item['nombreComercial'] ?? item['Nombre Comercial'] ?? name).toString().trim();
      final spec = (item['especificacion'] ?? item['Especificacion'] ?? '').toString().trim();
      final rawUrl = (item['urlImagen'] ?? item['URL Imagen'] ?? '').toString().trim();
      final imageUrl = normalizeImageUrl(rawUrl);

      final key = _normalize(name);
      _catalog[key] = VisualCatalogItem(
        title: name,
        category: category,
        commercialName: commercial,
        specification: spec.isNotEmpty ? spec : 'Especificación estándar según catálogo de obra.',
        imageUrl: imageUrl,
        fallbackIcon: category.toLowerCase().contains('mat') ? Icons.inventory_2 : Icons.handyman,
        badgeColor: category.toLowerCase().contains('mat') ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
      );
    }
  }

  /// Devuelve la tarjeta visual detallada o un objeto genérico estilizado
  static VisualCatalogItem getItemInfo(String name, {bool isMaterial = false}) {
    final clean = _normalize(name);

    // Búsqueda directa
    if (_catalog.containsKey(clean)) {
      return _catalog[clean]!;
    }

    // Búsqueda por coincidencia parcial de palabras clave
    for (final entry in _catalog.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }

    // Fallback genérico elegante
    return VisualCatalogItem(
      title: name,
      category: isMaterial ? 'Material de Obra' : 'Herramienta Técnica',
      commercialName: name,
      specification: 'Solicitar según catálogo técnico del proyecto y dimensiones del sector.',
      imageUrl: '',
      fallbackIcon: isMaterial ? Icons.inventory_2 : Icons.construction,
      badgeColor: isMaterial ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
    );
  }
}

