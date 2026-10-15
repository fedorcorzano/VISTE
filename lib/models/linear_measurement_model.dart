import 'dart:math' as math;
import 'dart:ui';

/// Representa una cota o medida lineal trazada entre dos puntos en una fotografía técnica
class LinearMeasurement {
  final String id;
  final Offset startOffset; // Coordenadas normalizadas o en píxeles del punto inicial
  final Offset endOffset;   // Coordenadas normalizadas o en píxeles del punto final
  final double longitudMetros; // Longitud ingresada por el técnico en metros (ej. 12.50)
  final String material; // Material o canalización (ej. Tubo EMT 3/4", Canaleta 40x25)
  final bool esMetradoMaterial; // Si es true, computa en metrado de materiales; si es false, es solo medida de referencia
  final String? origenEstructura; // Opcional: Estructura de partida
  final String? destinoEstructura; // Opcional: Estructura de llegada
  final DateTime timestamp;

  LinearMeasurement({
    required this.id,
    Offset? startOffset,
    Offset? endOffset,
    Offset? startNormalized,
    Offset? endNormalized,
    double? longitudMetros,
    double? meters,
    required this.material,
    this.esMetradoMaterial = false,
    String? origenEstructura,
    String? startStructure,
    String? destinoEstructura,
    String? endStructure,
    DateTime? timestamp,
  })  : startOffset = startOffset ?? startNormalized ?? Offset.zero,
        endOffset = endOffset ?? endNormalized ?? Offset.zero,
        longitudMetros = longitudMetros ?? meters ?? 0.0,
        origenEstructura = origenEstructura ?? startStructure,
        destinoEstructura = destinoEstructura ?? endStructure,
        timestamp = timestamp ?? DateTime.now();

  // Alias y getters de ergonomía
  double get meters => longitudMetros;
  String? get startStructure => origenEstructura;
  String? get endStructure => destinoEstructura;
  Offset get startNormalized => startOffset;
  Offset get endNormalized => endOffset;
  String get formattedLabel => labelFormatted;

  /// Etiqueta formateada para mostrar en la cota de la imagen (ej: "12.50 m • Tubo EMT 3/4\"")
  String get labelFormatted {
    final String cleanMetros = longitudMetros % 1 == 0
        ? longitudMetros.toInt().toString()
        : longitudMetros.toStringAsFixed(2);
    if (material.isEmpty || material == 'Por definir' || material == 'Sin especificar') {
      return '$cleanMetros m';
    }
    return '$cleanMetros m • $material';
  }

  /// Etiqueta con sólo la distancia en metros (ej: "12.50 m") para el trazo sobre la foto
  String get labelDistanceOnly {
    final String cleanMetros = longitudMetros % 1 == 0
        ? longitudMetros.toInt().toString()
        : longitudMetros.toStringAsFixed(2);
    return '$cleanMetros m';
  }

  /// Tramo descriptivo (ej: "Bandeja a Caja de Paso" o "Tramo #1")
  String get tramoDescription {
    if (origenEstructura != null && destinoEstructura != null) {
      return '$origenEstructura -> $destinoEstructura';
    }
    return 'Tramo lineal ($labelFormatted)';
  }

  /// Distancia euclidiana en píxeles sobre un canvas de tamaño dado
  double distancePx(Size size) {
    final dx = (endOffset.dx - startOffset.dx) * size.width;
    final dy = (endOffset.dy - startOffset.dy) * size.height;
    return math.sqrt(dx * dx + dy * dy);
  }

  LinearMeasurement copyWith({
    String? id,
    Offset? startOffset,
    Offset? endOffset,
    double? longitudMetros,
    String? material,
    bool? esMetradoMaterial,
    String? origenEstructura,
    String? destinoEstructura,
    DateTime? timestamp,
  }) {
    return LinearMeasurement(
      id: id ?? this.id,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      longitudMetros: longitudMetros ?? this.longitudMetros,
      material: material ?? this.material,
      esMetradoMaterial: esMetradoMaterial ?? this.esMetradoMaterial,
      origenEstructura: origenEstructura ?? this.origenEstructura,
      destinoEstructura: destinoEstructura ?? this.destinoEstructura,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startX': startOffset.dx,
      'startY': startOffset.dy,
      'endX': endOffset.dx,
      'endY': endOffset.dy,
      'longitudMetros': longitudMetros,
      'material': material,
      'esMetradoMaterial': esMetradoMaterial,
      'origenEstructura': origenEstructura,
      'destinoEstructura': destinoEstructura,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LinearMeasurement.fromMap(Map<String, dynamic> map) => LinearMeasurement.fromJson(map);

  factory LinearMeasurement.fromJson(Map<String, dynamic> json) {
    return LinearMeasurement(
      id: json['id'] as String? ?? _generateId(),
      startOffset: Offset(
        (json['startX'] as num?)?.toDouble() ?? 0.0,
        (json['startY'] as num?)?.toDouble() ?? 0.0,
      ),
      endOffset: Offset(
        (json['endX'] as num?)?.toDouble() ?? 0.0,
        (json['endY'] as num?)?.toDouble() ?? 0.0,
      ),
      longitudMetros: (json['longitudMetros'] as num?)?.toDouble() ?? 0.0,
      material: json['material'] as String? ?? 'Solo Medida',
      esMetradoMaterial: json['esMetradoMaterial'] as bool? ?? false,
      origenEstructura: json['origenEstructura'] as String?,
      destinoEstructura: json['destinoEstructura'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static int _counter = 0;
  static String _generateId() => 'cota_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}
