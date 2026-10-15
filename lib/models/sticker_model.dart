import 'package:flutter/material.dart';
import '../services/technical_catalog_icons.dart';

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

  /// Crea un sticker a partir de una cadena y una categoría, asignando colores e íconos especializados
  factory StickerModel.fromCatalog(String title, StickerCategory category) {
    switch (category) {
      case StickerCategory.estructuras:
        return StickerModel(
          title: title,
          icon: TechnicalCatalogIcons.getStructureIcon(title),
          backgroundColor: const Color(0xFF1E293B),
          accentColor: const Color(0xFF00B0FF),
          category: category,
        );
      case StickerCategory.materiales:
        return StickerModel(
          title: title,
          icon: TechnicalCatalogIcons.getMaterialIcon(title),
          backgroundColor: const Color(0xFF14532D),
          accentColor: const Color(0xFF00E676),
          category: category,
        );
      case StickerCategory.peligros:
        return StickerModel(
          title: title,
          icon: TechnicalCatalogIcons.getHazardIcon(title),
          backgroundColor: const Color(0xFF7C2D12),
          accentColor: const Color(0xFFFFD600),
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

  PlacedSticker copyWith({
    String? id,
    StickerModel? sticker,
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return PlacedSticker(
      id: id ?? this.id,
      sticker: sticker ?? this.sticker,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': sticker.title,
      'category': sticker.category.name,
      'dx': position.dx,
      'dy': position.dy,
      'scale': scale,
      'rotation': rotation,
    };
  }

  factory PlacedSticker.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'estructuras';
    final category = StickerCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => StickerCategory.estructuras,
    );
    final title = json['title'] as String? ?? '';
    final sticker = StickerModel.fromCatalog(title, category);
    final dx = (json['dx'] as num?)?.toDouble() ?? 0.0;
    final dy = (json['dy'] as num?)?.toDouble() ?? 0.0;
    final scale = (json['scale'] as num?)?.toDouble() ?? 1.0;
    final rotation = (json['rotation'] as num?)?.toDouble() ?? 0.0;

    return PlacedSticker(
      id: json['id'] as String? ?? 'pin_${DateTime.now().millisecondsSinceEpoch}',
      sticker: sticker,
      position: Offset(dx, dy),
      scale: scale,
      rotation: rotation,
    );
  }
}

/// ============================================================================
/// MATRIZ TÉCNICA MAESTRA: VINCULACIÓN DE HERRAMIENTAS Y ACCESORIOS (VISTEC V2)
/// ============================================================================
class TechnicalCatalogMatrix {
  // Clasificaciones oficiales de proyectos de VIGILARTE
  static const List<String> clasificacionesProyectos = [
    'Residencial',
    'Comercial',
    'Corporativo',
    'Industrial',
  ];

  // Materiales prioritarios según el tipo/clasificación de proyecto
  static const Map<String, List<String>> materialesPorClasificacion = {
    'Residencial': [
      'Canaletas',
      'Tubo PVC SEL',
      'Corrugado PVC',
      'Tubo PVC SAP',
    ],
    'Comercial': [
      'Tubo EMT',
      'Canaletas',
      'Corrugado EMT',
      'Tubo PVC SAP',
    ],
    'Corporativo': [
      'Tubo EMT',
      'Bandeja Portacables',
      'Canaletas',
      'Corrugado EMT',
    ],
    'Industrial': [
      'Tubo IMC',
      'Tubo EMT',
      'Liquid Tight',
      'Tubo PVC SAP',
      'Bandeja Portacables',
    ],
  };

  /// Devuelve la lista completa de materiales colocando los prioritarios del tipo de proyecto
  /// en los primeros lugares, a la espera de su rápida selección, sin ocultar ninguno.
  static List<String> getPrioritizedMaterials(String? clasificacion, List<String> allMaterials) {
    final key = clasificacion?.trim();
    final priority = (key != null && materialesPorClasificacion.containsKey(key))
        ? materialesPorClasificacion[key]!
        : const <String>[];

    final Set<String> prioritizedSet = {};
    final List<String> result = [];

    bool matchesPriority(String material, String priorityItem) {
      final m = material.toLowerCase().trim();
      final p = priorityItem.toLowerCase().trim();
      if (m == p || m.contains(p) || p.contains(m)) return true;
      final mStem = m.endsWith('s') ? m.substring(0, m.length - 1) : m;
      final pStem = p.endsWith('s') ? p.substring(0, p.length - 1) : p;
      return mStem.contains(pStem) || pStem.contains(mStem);
    }

    // 1. Primero los prioritarios que existan dentro de allMaterials
    for (final p in priority) {
      final matches = allMaterials.where((m) => matchesPriority(m, p));
      for (final match in matches) {
        if (prioritizedSet.add(match)) {
          result.add(match);
        }
      }
    }

    // 2. Luego todo el resto de materiales disponibles
    for (final m in allMaterials) {
      if (prioritizedSet.add(m)) {
        result.add(m);
      }
    }

    return result;
  }

  // Familias principales de canalización (pines flotantes de selección base)
  static const List<String> familiasCanalizacion = [
    'EMT',
    'IMC',
    'PVC',
    'Canaleta',
    'Liquid Tight',
    'Bandeja',
  ];

  // Variantes comerciales y medidas disponibles por cada familia
  static const Map<String, List<String>> familiasYVariantesCanalizacion = {
    'EMT': [
      'Tubo EMT 1/2"',
      'Tubo EMT 3/4"',
      'Tubo EMT 1"',
      'Tubo EMT 1 1/4"',
      'Tubo EMT 1 1/2"',
      'Tubo EMT 2"',
      'Corrugado EMT 3/4"',
    ],
    'IMC': [
      'Tubo IMC 1/2"',
      'Tubo IMC 3/4"',
      'Tubo IMC 1"',
      'Tubo IMC 1 1/4"',
      'Tubo IMC 1 1/2"',
      'Tubo IMC 2"',
    ],
    'PVC': [
      'Tubo PVC SEL 1/2"',
      'Tubo PVC SEL 3/4"',
      'Tubo PVC SEL 1"',
      'Tubo PVC SAP 1/2"',
      'Tubo PVC SAP 3/4"',
      'Tubo PVC SAP 1"',
      'Corrugado PVC 3/4"',
    ],
    'Canaleta': [
      'Canaleta 20x10 mm',
      'Canaleta 40x25 mm',
      'Canaleta 60x40 mm',
      'Canaleta 100x50 mm',
    ],
    'Liquid Tight': [
      'Liquid Tight 1/2"',
      'Liquid Tight 3/4"',
      'Liquid Tight 1"',
    ],
    'Bandeja': [
      'Bandeja Portacables 100x50',
      'Bandeja Portacables 150x50',
      'Bandeja Portacables 200x50',
    ],
  };

  /// Deducir la familia base a partir de un material o texto de cota
  static String deduceFamilia(String material) {
    final m = material.toUpperCase();
    if (m.contains('EMT')) return 'EMT';
    if (m.contains('IMC')) return 'IMC';
    if (m.contains('PVC') || m.contains('SEL') || m.contains('SAP')) return 'PVC';
    if (m.contains('CANALETA')) return 'Canaleta';
    if (m.contains('LIQUID') || m.contains('TIGHT')) return 'Liquid Tight';
    if (m.contains('BANDEJA')) return 'Bandeja';
    return 'EMT'; // Default común
  }

  // Lista oficial de materiales de canalización / tubería
  static const List<String> defaultMateriales = [
    'Canaletas',
    'Tubo PVC SEL',
    'Corrugado PVC',
    'Tubo PVC SAP',
    'Tubo EMT',
    'Tubo IMC',
    'Corrugado EMT',
    'Corrugado Liquid Tight',
  ];

  // Lista oficial de estructuras más comunes en campo
  static const List<String> defaultEstructuras = [
    'Concreto',
    'Ladrillo Hueco',
    'Ladrillo Macizo',
    'Drywall',
    'Mayólica',
    'Vidrio',
    'Fierro',
    'Acero Inoxidable',
    'Policarbonato',
    'Teja',
    'Madera',
  ];

  // Lista oficial de servicios y tipos de proyectos de VIGILARTE
  static const List<String> defaultProyectos = [
    'Cámaras de videovigilancia (CCTV)',
    'Control de Accesos y Asistencia',
    'Alarmas Contra Incendio (Detección)',
    'Alarmas Contra Intrusión',
    'Cableado Estructurado y Redes',
    'Fibra Óptica y Enlaces Inalámbricos',
    'Canalizaciones Eléctricas y Tableros',
    'Mantenimiento Preventivo / Correctivo',
    'Inspección de Seguridad SST',
    'General',
  ];

  /// Formatea cadenas a formato tipo título preservando siglas técnicas (PVC, EMT, IMC, etc.)
  static String formatTitleCase(String text) {
    if (text.trim().isEmpty) return '';
    const acronyms = {
      'PVC',
      'SEL',
      'SAP',
      'EMT',
      'IMC',
      'SDS',
      'IP65',
      'IP66',
      'F°G°',
      'LED',
      'HDPE',
      'UTP',
      'CCTV',
    };

    final words = text.trim().split(RegExp(r'\s+'));
    return words.map((w) {
      final upper = w.toUpperCase();
      if (acronyms.contains(upper)) {
        return upper;
      }
      if (w.isEmpty) return '';
      final lower = w.toLowerCase();
      if (lower == 'de' || lower == 'para' || lower == 'con' || lower == 'en' || lower == 'y') {
        return lower;
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  // Accesorios prioritarios por material (orden descendente de prioridad)
  static const Map<String, List<String>> accesoriosMaterial = {
    'CANALETAS': [
      'Codos planos para canaleta',
      'Uniones para canaleta',
      'Codos interiores (Ángulos internos)',
      'Codos exteriores (Ángulos externos)',
      'Tees de derivación para canaleta',
      'Tapas terminales para canaleta',
      'Cinta doble contacto de alta adherencia',
      'Tarugos y tornillos de fijación',
    ],
    'TUBO PVC SEL': [
      'Conectores PVC SEL (a caja)',
      'Uniones PVC SEL',
      'Curvas PVC SEL 90°',
      'Cajas de paso octogonales/rectangulares PVC',
      'Pegamento para PVC',
      'Abrazaderas PVC tipo omega',
    ],
    'CORRUGADO PVC': [
      'Conectores para corrugado PVC',
      'Cajas de paso PVC',
      'Uniones para tubo corrugado',
      'Cinta aislante / vulcanizada',
      'Abrazaderas plásticas',
    ],
    'TUBO PVC SAP': [
      'Conectores PVC SAP',
      'Uniones PVC SAP',
      'Curvas PVC SAP 90°',
      'Cajas de paso pesadas SAP',
      'Pegamento PVC alta presión',
      'Abrazaderas metálicas tipo U',
    ],
    'TUBO EMT': [
      'Conectores EMT rectos',
      'Uniones EMT',
      'Abrazaderas Conduit / Unistrut',
      'Curvas EMT 90° preformadas',
      'Cajas de paso de fierro galvanizado (F°G°)',
      'Boquillas terminales de protección',
      'Riel Unistrut',
    ],
    'TUBO IMC': [
      'Conectores IMC roscados',
      'Uniones IMC roscadas',
      'Abrazaderas Unistrut pesadas',
      'Cajas de paso Conduit pesadas (Condulet)',
      'Boquillas y contratuercas galvanizadas',
      'Sellador de roscas',
    ],
    'CORRUGADO EMT': [
      'Conectores rectos para flexible metálico',
      'Conectores curvos 90° para flexible metálico',
      'Abrazaderas metálicas',
      'Uniones flexible a rígido EMT',
    ],
    'CORRUGADO LIQUID TIGHT': [
      'Conectores herméticos Liquid Tight rectos',
      'Conectores herméticos Liquid Tight a 90°',
      'Empaquetaduras de goma herméticas',
      'Cajas de paso herméticas IP65/IP66',
      'Abrazaderas recubiertas para intemperie',
    ],
  };

  // Herramientas prioritarias por material (orden descendente de prioridad)
  static const Map<String, List<String>> herramientasMaterial = {
    'CANALETAS': [
      'Tijera cortacanaletas / Ingletadora',
      'Nivel de mano / Nivel láser',
      'Taladro percutor / Atornillador',
      'Cinta métrica / Flexómetro',
      'Lima para desbaste',
    ],
    'TUBO PVC SEL': [
      'Sierra de mano / Cortador de tubos PVC',
      'Soplete a gas / Decapador térmico para doblado',
      'Taladro / Atornillador',
      'Escariador / Lima',
      'Flexómetro',
    ],
    'CORRUGADO PVC': [
      'Cúter / Cuchilla para corte',
      'Guía pasacables de nylon / acero',
      'Cinta métrica',
      'Alicate universal',
    ],
    'TUBO PVC SAP': [
      'Cortatubos para PVC / Sierra de arco',
      'Soplete / Pistola de calor',
      'Taladro percutor',
      'Escariador',
      'Nivel de gota',
    ],
    'TUBO EMT': [
      'Doblador de tubo EMT (Hickey / Curvadora)',
      'Sierra para metales / Cortatubos',
      'Escariador de tubo EMT (desbarbador)',
      'Taladro percutor con brocas',
      'Atornillador de impacto',
      'Nivel torpedo magnético',
      'Flexómetro',
    ],
    'TUBO IMC': [
      'Terraja manual o eléctrica para roscar IMC',
      'Prensa de cadena / Tornillo de banco',
      'Cortatubos para metal pesado',
      'Curvadora hidráulica / manual IMC',
      'Llave Stilson / Llave para tubos',
      'Aceite para roscar',
      'Taladro percutor',
    ],
    'CORRUGADO EMT': [
      'Sierra de metal de diente fino',
      'Alicate pelacables / corte',
      'Destornillador plano / cruz',
      'Guía pasacables',
    ],
    'CORRUGADO LIQUID TIGHT': [
      'Cúter / Sierra fina para cubierta plástica',
      'Llave inglesa / Llave francesa para ajuste hermético',
      'Guía pasacables de acero',
      'Destornillador',
    ],
  };

  // Herramientas prioritarias por estructura (orden descendente de prioridad)
  static const Map<String, List<String>> herramientasEstructura = {
    'CONCRETO': [
      'Rotomartillo SDS Plus / Max',
      'Brocas SDS de percusión para concreto',
      'Cincel plano / Punta demoledora',
      'Llave de impacto / Llaves de dado',
      'Martillo / Comba pequeña',
      'Extensión eléctrica industrial',
    ],
    'LADRILLO HUECO': [
      'Taladro con percusión suave / sin percusión',
      'Brocas para ladrillo hueco',
      'Atornillador de torque regulable',
      'Nivel de mano',
    ],
    'LADRILLO MACIZO': [
      'Rotomartillo / Taladro percutor',
      'Brocas para mampostería maciza',
      'Cincel de desbaste',
      'Martillo',
    ],
    'DRYWALL': [
      'Atornillador inalámbrico para drywall',
      'Cúter profesional / Serrucho de punta para yeso',
      'Puntas Phillips PH2 con tope',
      'Nivel magnético',
      'Detector de montantes / perfiles metálicos',
    ],
    'MAYOLICA': [
      'Broca diamantada / punta de carburo de tungsteno',
      'Taladro velocidad variable (sin percusión)',
      'Rociador / pulverizador de agua (refrigeración)',
      'Cinta masking tape (anti-deslizamiento)',
      'Nivel de gota',
    ],
    'VIDRIO': [
      'Ventosas dobles de sujeción para vidrio',
      'Pistola de calafateo para silicona estructural',
      'Rascador / Cúter de precisión',
      'Paño de microfibra y limpiador',
    ],
    'FIERRO': [
      'Taladro con brocas para metal HSS / Cobalto',
      'Amoladora angular con disco de corte y desbaste',
      'Remachadora manual o neumática',
      'Llaves de corona / fijas',
      'Punzón de centro / Granete',
      'Cepillo de alambre',
    ],
    'ACERO INOXIDABLE': [
      'Brocas especiales de Cobalto (HSS-Co)',
      'Amoladora con discos para inox (libres de hierro)',
      'Pasta decapante / limpiador de acero inoxidable',
      'Taladro de baja velocidad con lubricante de corte',
      'Llaves con protección para acero inoxidable',
    ],
    'POLICARBONATO': [
      'Sierra caladora con hoja de diente fino para plástico',
      'Taladro con broca afilada para acrílico/plástico (sin percusión)',
      'Cúter resistente',
      'Pistola de silicona neutra',
    ],
    'TEJA': [
      'Amoladora con disco diamantado continuo',
      'Taladro con brocas para cerámica / teja',
      'Cincel fino manual',
      'Pistola de calafateo para sellador poliuretano',
    ],
    'MADERA': [
      'Taladro con brocas para madera / Brocas paleta',
      'Atornillador inalámbrico con puntas Phillips/Torx',
      'Sierra de calar / Serrucho de mano',
      'Escuadra y cinta métrica',
      'Cincel de madera / Formón',
    ],
  };

  // Overrides dinámicos recibidos desde Google Sheets en tiempo de ejecución
  static Map<String, List<String>>? accesoriosMaterialOverride;
  static Map<String, List<String>>? herramientasMaterialOverride;
  static Map<String, List<String>>? herramientasEstructuraOverride;

  /// Normaliza una cadena para comparaciones seguras
  static String _cleanKey(String key) {
    return key
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .trim();
  }

  /// Obtiene los accesorios para un material dado
  static List<String> getAccesoriosForMaterial(String material) {
    final clean = _cleanKey(material);
    final map = accesoriosMaterialOverride ?? accesoriosMaterial;
    for (final entry in map.entries) {
      if (_cleanKey(entry.key) == clean || clean.contains(_cleanKey(entry.key))) {
        return entry.value;
      }
    }
    return [];
  }

  /// Obtiene las herramientas para un material dado
  static List<String> getHerramientasForMaterial(String material) {
    final clean = _cleanKey(material);
    final map = herramientasMaterialOverride ?? herramientasMaterial;
    for (final entry in map.entries) {
      if (_cleanKey(entry.key) == clean || clean.contains(_cleanKey(entry.key))) {
        return entry.value;
      }
    }
    return [];
  }

  /// Obtiene las herramientas para una estructura dada
  static List<String> getHerramientasForEstructura(String estructura) {
    final clean = _cleanKey(estructura);
    final map = herramientasEstructuraOverride ?? herramientasEstructura;
    for (final entry in map.entries) {
      if (_cleanKey(entry.key) == clean || clean.contains(_cleanKey(entry.key))) {
        return entry.value;
      }
    }
    return [];
  }

  /// Deduce y consolida todas las herramientas requeridas para un conjunto de estructuras y materiales
  static List<String> deduceHerramientas({
    required Iterable<String> estructuras,
    required Iterable<String> materiales,
    Map<String, List<String>>? customHerramientasEstructura,
    Map<String, List<String>>? customHerramientasMaterial,
  }) {
    final Set<String> tools = {};

    for (final e in estructuras) {
      final list = customHerramientasEstructura?[e] ?? getHerramientasForEstructura(e);
      tools.addAll(list);
    }

    for (final m in materiales) {
      final list = customHerramientasMaterial?[m] ?? getHerramientasForMaterial(m);
      tools.addAll(list);
    }

    return tools.toList();
  }

  /// Deduce y consolida todos los accesorios requeridos para un conjunto de materiales
  static List<String> deduceAccesorios({
    required Iterable<String> materiales,
    Map<String, List<String>>? customAccesoriosMaterial,
  }) {
    final Set<String> accessories = {};

    for (final m in materiales) {
      final list = customAccesoriosMaterial?[m] ?? getAccesoriosForMaterial(m);
      accessories.addAll(list);
    }

    return accessories.toList();
  }
}
