import 'dart:math' as math;
import 'dart:ui';

/// Representa una cota o medida lineal trazada entre dos puntos en una fotografía técnica
class LinearMeasurement {
  final String id;
  final Offset startOffset; // Coordenadas normalizadas o en píxeles del punto inicial
  final Offset endOffset;   // Coordenadas normalizadas o en píxeles del punto final
  final double longitudMetros; // Longitud ingresada por el técnico en metros (ej. 12.50)
  final String material; // Material o canalización (ej. Tubo EMT 3/4", Canaleta 40x25)
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
    return '$cleanMetros m • $material';
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
      material: json['material'] as String? ?? 'Canalización',
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
