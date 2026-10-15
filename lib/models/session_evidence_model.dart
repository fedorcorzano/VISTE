import 'dart:io';
import 'dart:typed_data';
import 'linear_measurement_model.dart';
import 'project_model.dart';
import 'sticker_model.dart';

/// Representa la frecuencia y criticidad de un ítem (herramienta o material) en el proyecto
class ItemFrequency {
  final String name;
  final int count;
  final int totalPhotos;
  final List<String> areas;

  const ItemFrequency({
    required this.name,
    required this.count,
    required this.totalPhotos,
    required this.areas,
  });

  /// Porcentaje de presencia en las fotografías del proyecto (0.0 a 100.0)
  double get percentage => totalPhotos > 0 ? (count / totalPhotos) * 100 : 0.0;

  /// Si aparece en 2 o más fotos (o en el 50% o más de las fotos), es INDISPENSABLE
  bool get isIndispensable {
    if (totalPhotos <= 1) return true;
    return count >= 2 || percentage >= 50.0;
  }

  /// Nivel de prioridad textual
  String get priorityLabel {
    if (isIndispensable) return 'INDISPENSABLE / CRÍTICO';
    if (percentage >= 30.0) return 'PRIORITARIO';
    return 'COMPLEMENTARIO';
  }

  /// Texto explicativo de frecuencia (ej: "Aparece en 4 de 5 fotos (80%)")
  String get frequencyDescription {
    return 'En $count de $totalPhotos ${totalPhotos == 1 ? 'foto' : 'fotos'} (${percentage.toStringAsFixed(0)}%)';
  }
}

/// Registro individual de cada fotografía técnica tomada durante la sesión
class SessionEvidenceRecord {
  final int photoNumber;
  final String areaSector;
  final String localImagePath;
  final Uint8List pngBytes; // Versión completa con todos los pines para Gestor de Proyectos
  final Uint8List? cleanPngBytes; // Imagen limpia original sin marcas, pines ni cotas horneadas
  final Uint8List? clientPngBytes; // Versión exclusiva para el Cliente (SOLO marcadores de seguridad SST)
  final Uint8List? measurementsPngBytes; // Versión exclusiva con Cotas y Medidas (pines ocultos)
  final List<LinearMeasurement> linearMeasurements; // Cotas y medidas lineales estructuradas
  final List<PlacedSticker> placedPins; // Pines interactivos colocados en la foto
  final List<String> estructuras;
  final List<String> materiales;
  final List<String> peligros;
  final List<String> herramientas;
  final List<String> accesorios;
  final Map<String, String> photoHierarchyResponsibility;
  final Map<String, String> photoHierarchyControls;
  final String? technicalStatus; // 'apto' | 'condicionado' | 'no_apto' (o null para cálculo automático)
  final String? technicalObservation; // Observación personalizada para el reporte del cliente
  final DateTime timestamp;

  const SessionEvidenceRecord({
    required this.photoNumber,
    required this.areaSector,
    required this.localImagePath,
    required this.pngBytes,
    this.cleanPngBytes,
    this.clientPngBytes,
    this.measurementsPngBytes,
    this.linearMeasurements = const [],
    this.placedPins = const [],
    required this.estructuras,
    required this.materiales,
    required this.peligros,
    required this.herramientas,
    required this.accesorios,
    this.photoHierarchyResponsibility = const {},
    this.photoHierarchyControls = const {},
    this.technicalStatus,
    this.technicalObservation,
    required this.timestamp,
  });

  /// Retorna la imagen base limpia original para el lienzo interactivo del editor
  Uint8List get baseImageBytes {
    if (cleanPngBytes != null && cleanPngBytes!.isNotEmpty) {
      return cleanPngBytes!;
    }
    if (localImagePath.isNotEmpty) {
      final rawPath = localImagePath.replaceAll('.png', '_raw.jpg');
      final fRaw = File(rawPath);
      if (fRaw.existsSync()) {
        try {
          final b = fRaw.readAsBytesSync();
          if (b.isNotEmpty) return b;
        } catch (_) {}
      }
      final f = File(localImagePath);
      if (f.existsSync()) {
        try {
          final b = f.readAsBytesSync();
          if (b.isNotEmpty) return b;
        } catch (_) {}
      }
    }
    return pngBytes;
  }

  /// Retorna la imagen adecuada para el cliente (con solo marcadores SST) o fallback a la limpia/completa
  Uint8List get clientImageBytes {
    if (clientPngBytes != null && clientPngBytes!.isNotEmpty) {
      return clientPngBytes!;
    }
    if (peligros.isEmpty) {
      return baseImageBytes;
    }
    return pngBytes;
  }

  /// Retorna la imagen con cotas o null si no tiene medidas
  Uint8List? get measurementsImageBytes => measurementsPngBytes;

  /// Retorna el estado técnico del sector ('apto', 'condicionado' o 'no_apto')
  /// Resuelve la combinación entre la selección manual del usuario/gestor y el cálculo automático SST
  String get effectiveTechnicalStatus {
    if (technicalStatus != null && technicalStatus!.isNotEmpty) {
      return technicalStatus!;
    }
    final text = peligros.join(' ').toLowerCase();
    final bool hasCritical = text.contains('eléctric') ||
        text.contains('electric') ||
        text.contains('confinado') ||
        text.contains('colapso') ||
        text.contains('inestabl') ||
        text.contains('tensión') ||
        text.contains('tension') ||
        text.contains('gas') ||
        text.contains('químic');
    if (hasCritical) return 'no_apto';
    if (peligros.isNotEmpty) return 'condicionado';
    return 'apto';
  }

  /// Retorna la entidad responsable de un nivel de control ('VIGILARTE' o 'CLIENTE')
  String getResponsibility(String levelKey) {
    final lower = levelKey.toLowerCase().trim();
    if (photoHierarchyResponsibility.containsKey(lower)) {
      return photoHierarchyResponsibility[lower]!;
    }
    if (lower.contains('eliminac') || lower.contains('sustituc')) {
      return 'CLIENTE';
    }
    return 'VIGILARTE';
  }

  /// Retorna la descripción o acción específica para un nivel de control
  String getControlDescription(String levelKey) {
    final lower = levelKey.toLowerCase().trim();
    return photoHierarchyControls[lower] ?? '';
  }

  SessionEvidenceRecord copyWith({
    int? photoNumber,
    String? areaSector,
    String? localImagePath,
    Uint8List? pngBytes,
    Uint8List? cleanPngBytes,
    Uint8List? clientPngBytes,
    Uint8List? measurementsPngBytes,
    List<LinearMeasurement>? linearMeasurements,
    List<PlacedSticker>? placedPins,
    List<String>? estructuras,
    List<String>? materiales,
    List<String>? peligros,
    List<String>? herramientas,
    List<String>? accesorios,
    Map<String, String>? photoHierarchyResponsibility,
    Map<String, String>? photoHierarchyControls,
    String? technicalStatus,
    String? technicalObservation,
    DateTime? timestamp,
  }) {
    return SessionEvidenceRecord(
      photoNumber: photoNumber ?? this.photoNumber,
      areaSector: areaSector ?? this.areaSector,
      localImagePath: localImagePath ?? this.localImagePath,
      pngBytes: pngBytes ?? this.pngBytes,
      cleanPngBytes: cleanPngBytes ?? this.cleanPngBytes,
      clientPngBytes: clientPngBytes ?? this.clientPngBytes,
      measurementsPngBytes: measurementsPngBytes ?? this.measurementsPngBytes,
      linearMeasurements: linearMeasurements ?? this.linearMeasurements,
      placedPins: placedPins ?? this.placedPins,
      estructuras: estructuras ?? this.estructuras,
      materiales: materiales ?? this.materiales,
      peligros: peligros ?? this.peligros,
      herramientas: herramientas ?? this.herramientas,
      accesorios: accesorios ?? this.accesorios,
      photoHierarchyResponsibility:
          photoHierarchyResponsibility ?? this.photoHierarchyResponsibility,
      photoHierarchyControls:
          photoHierarchyControls ?? this.photoHierarchyControls,
      technicalStatus: technicalStatus ?? this.technicalStatus,
      technicalObservation: technicalObservation ?? this.technicalObservation,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'photoNumber': photoNumber,
      'areaSector': areaSector,
      'localImagePath': localImagePath,
      'estructuras': estructuras,
      'materiales': materiales,
      'peligros': peligros,
      'herramientas': herramientas,
      'accesorios': accesorios,
      'photoHierarchyResponsibility': photoHierarchyResponsibility,
      'photoHierarchyControls': photoHierarchyControls,
      'technicalStatus': technicalStatus,
      'technicalObservation': technicalObservation,
      'linearMeasurements': linearMeasurements.map((m) => m.toJson()).toList(),
      'placedPins': placedPins.map((p) => p.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SessionEvidenceRecord.fromJson(Map<String, dynamic> json) {
    final String imagePath = json['localImagePath'] as String? ?? '';
    Uint8List loadedBytes = Uint8List(0);
    Uint8List? loadedCleanBytes;
    Uint8List? loadedClientBytes;
    Uint8List? loadedMeasurementsBytes;

    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        try {
          loadedBytes = file.readAsBytesSync();
        } catch (_) {}
      }
      final rawPath = imagePath.replaceAll('.png', '_raw.jpg');
      final rawFile = File(rawPath);
      if (rawFile.existsSync()) {
        try {
          loadedCleanBytes = rawFile.readAsBytesSync();
        } catch (_) {}
      }
      final sstPath = imagePath.replaceAll('.png', '_sst.png');
      final sstFile = File(sstPath);
      if (sstFile.existsSync()) {
        try {
          loadedClientBytes = sstFile.readAsBytesSync();
        } catch (_) {}
      }
      final medidasPath = imagePath.replaceAll('.png', '_medidas.png');
      final medidasFile = File(medidasPath);
      if (medidasFile.existsSync()) {
        try {
          loadedMeasurementsBytes = medidasFile.readAsBytesSync();
        } catch (_) {}
      }
    }

    final rawMeasurements = json['linearMeasurements'] as List<dynamic>? ?? [];
    final parsedMeasurements = rawMeasurements
        .map((m) => LinearMeasurement.fromJson(m as Map<String, dynamic>))
        .toList();

    final rawPins = json['placedPins'] as List<dynamic>? ?? [];
    final parsedPins = rawPins
        .map((p) => PlacedSticker.fromJson(p as Map<String, dynamic>))
        .toList();

    final rawResp = json['photoHierarchyResponsibility'] as Map<String, dynamic>? ?? {};
    final Map<String, String> photoResp = rawResp.map((k, v) => MapEntry(k.toString(), v.toString()));

    final rawControls = json['photoHierarchyControls'] as Map<String, dynamic>? ?? {};
    final Map<String, String> photoControls = rawControls.map((k, v) => MapEntry(k.toString(), v.toString()));

    return SessionEvidenceRecord(
      photoNumber: json['photoNumber'] as int? ?? 1,
      areaSector: json['areaSector'] as String? ?? '',
      localImagePath: imagePath,
      pngBytes: loadedBytes,
      cleanPngBytes: loadedCleanBytes,
      clientPngBytes: loadedClientBytes,
      measurementsPngBytes: loadedMeasurementsBytes,
      linearMeasurements: parsedMeasurements,
      placedPins: parsedPins,
      estructuras: (json['estructuras'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      materiales: (json['materiales'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      peligros: (json['peligros'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      herramientas: (json['herramientas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      accesorios: (json['accesorios'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      photoHierarchyResponsibility: photoResp,
      photoHierarchyControls: photoControls,
      technicalStatus: json['technicalStatus'] as String?,
      technicalObservation: json['technicalObservation'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Contenedor integral de la sesión de trabajo con métodos de consolidación y métricas
class ProjectSessionModel {
  final ProjectModel project;
  final List<SessionEvidenceRecord> photos;

  /// Conjuntos de exclusión y personalización administrados por el Gestor de Proyectos
  final Set<String> excludedTools = {};
  final Set<String> excludedMaterials = {};
  final Set<String> excludedAccessories = {};

  /// Ítems adicionales ingresados manualmente por el Gestor
  final List<String> additionalTools = [];
  final List<String> additionalMaterials = [];
  final List<String> additionalAccessories = [];

  /// Responsables personalizados de la Jerarquía de Control de Riesgos (ISO 45001 / Ley 29783)
  /// Claves: 'eliminacion', 'sustitucion', 'ingenieria', 'administracion', 'epp'
  final Map<String, String> customHierarchyResponsibles = {};

  ProjectSessionModel({
    required this.project,
    List<SessionEvidenceRecord>? photos,
  }) : photos = photos ?? [];

  /// Agrega una evidencia fotográfica a la sesión
  void addPhoto(SessionEvidenceRecord record) {
    photos.add(record);
  }

  /// Actualiza o reemplaza una evidencia fotográfica en la sesión
  void updatePhoto(int index, SessionEvidenceRecord record) {
    if (index >= 0 && index < photos.length) {
      photos[index] = record;
    }
  }

  /// Actualiza la asignación de jerarquía SST de una fotografía específica
  void setPhotoHierarchy(int photoIndex, {
    required Map<String, String> responsibilities,
    required Map<String, String> controls,
  }) {
    if (photoIndex >= 0 && photoIndex < photos.length) {
      photos[photoIndex] = photos[photoIndex].copyWith(
        photoHierarchyResponsibility: Map<String, String>.from(responsibilities),
        photoHierarchyControls: Map<String, String>.from(controls),
      );
    }
  }

  /// Calcula el consolidado de canalizaciones con cálculo de tiras/tubos comerciales (3.00 m c/u)
  List<Map<String, dynamic>> getConduitCalculation() {
    final totals = getConsolidatedLinearMeters();
    return totals.entries.map((e) {
      final meters = e.value;
      const commercialLength = 3.0;
      final piecesNeeded = (meters / commercialLength).ceil();
      return {
        'material': e.key,
        'meters': meters,
        'standardLength': commercialLength,
        'pieces': piecesNeeded,
      };
    }).toList();
  }

  /// Obtiene el responsable de la jerarquía respetando la personalización del Gestor
  String getHierarchyResponsible(String levelKey, String defaultResponsible) {
    final custom = customHierarchyResponsibles[levelKey.toLowerCase().trim()];
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return defaultResponsible;
  }

  int get totalPhotos => photos.length;

  /// Obtiene la lista consolidada de materiales con su respectiva frecuencia y criticidad
  List<ItemFrequency> getMaterialsWithFrequency() {
    final Map<String, int> counts = {};
    final Map<String, List<String>> areaMap = {};

    for (final photo in photos) {
      for (final mat in photo.materiales) {
        counts[mat] = (counts[mat] ?? 0) + 1;
        areaMap.putIfAbsent(mat, () => []);
        if (!areaMap[mat]!.contains(photo.areaSector)) {
          areaMap[mat]!.add(photo.areaSector);
        }
      }
    }

    final List<ItemFrequency> items = counts.entries.map((e) {
      return ItemFrequency(
        name: e.key,
        count: e.value,
        totalPhotos: totalPhotos,
        areas: areaMap[e.key] ?? [],
      );
    }).toList();

    // Ordenar: primero los indispensables, luego por mayor frecuencia
    items.sort((a, b) {
      if (a.isIndispensable && !b.isIndispensable) return -1;
      if (!a.isIndispensable && b.isIndispensable) return 1;
      return b.count.compareTo(a.count);
    });

    return items;
  }

  /// Obtiene la lista consolidada de herramientas requeridas con su frecuencia y criticidad
  List<ItemFrequency> getToolsWithFrequency() {
    final Map<String, int> counts = {};
    final Map<String, List<String>> areaMap = {};

    for (final photo in photos) {
      for (final tool in photo.herramientas) {
        counts[tool] = (counts[tool] ?? 0) + 1;
        areaMap.putIfAbsent(tool, () => []);
        if (!areaMap[tool]!.contains(photo.areaSector)) {
          areaMap[tool]!.add(photo.areaSector);
        }
      }
    }

    final List<ItemFrequency> items = counts.entries.map((e) {
      return ItemFrequency(
        name: e.key,
        count: e.value,
        totalPhotos: totalPhotos,
        areas: areaMap[e.key] ?? [],
      );
    }).toList();

    // Ordenar: indispensables primero, luego por cantidad descendente
    items.sort((a, b) {
      if (a.isIndispensable && !b.isIndispensable) return -1;
      if (!a.isIndispensable && b.isIndispensable) return 1;
      return b.count.compareTo(a.count);
    });

    return items;
  }

  /// Obtiene lista consolidada y desduplicada de accesorios necesarios
  List<String> getConsolidatedAccessories() {
    final Set<String> acc = {};
    for (final photo in photos) {
      acc.addAll(photo.accesorios);
    }
    final list = acc.toList();
    list.sort();
    return list;
  }

  /// Obtiene los accesorios con su frecuencia y distribución en fotos
  List<ItemFrequency> getAccessoriesWithFrequency() {
    final Map<String, int> counts = {};
    final Map<String, List<String>> areaMap = {};

    for (final photo in photos) {
      for (final acc in photo.accesorios) {
        counts[acc] = (counts[acc] ?? 0) + 1;
        areaMap.putIfAbsent(acc, () => []);
        if (!areaMap[acc]!.contains(photo.areaSector)) {
          areaMap[acc]!.add(photo.areaSector);
        }
      }
    }

    final List<ItemFrequency> items = counts.entries.map((e) {
      return ItemFrequency(
        name: e.key,
        count: e.value,
        totalPhotos: totalPhotos,
        areas: areaMap[e.key] ?? [],
      );
    }).toList();

    items.sort((a, b) => b.count.compareTo(a.count));
    return items;
  }

  /// Obtiene peligros identificados agrupados por área o sector
  Map<String, List<String>> getHazardsByArea() {
    final Map<String, List<String>> result = {};
    for (final photo in photos) {
      if (photo.peligros.isNotEmpty) {
        result[photo.areaSector] = photo.peligros;
      }
    }
    return result;
  }

  /// Obtiene todos los peligros únicos identificados en la sesión
  List<String> getConsolidatedHazards() {
    final Set<String> hazards = {};
    for (final photo in photos) {
      hazards.addAll(photo.peligros);
    }
    return hazards.toList();
  }

  /// Herramientas validadas por el gestor (excluye las que provee el cliente o ya están en sitio)
  List<ItemFrequency> getValidatedToolsWithFrequency() {
    final raw = getToolsWithFrequency();
    final filtered = raw.where((t) => !excludedTools.contains(t.name)).toList();
    for (final add in additionalTools) {
      if (!filtered.any((f) => f.name == add) && !excludedTools.contains(add)) {
        filtered.add(
          ItemFrequency(
            name: add,
            count: totalPhotos > 0 ? totalPhotos : 1,
            totalPhotos: totalPhotos > 0 ? totalPhotos : 1,
            areas: const ['Agregado por Gestor'],
          ),
        );
      }
    }
    return filtered;
  }

  /// Materiales validados por el gestor (excluye los ya existentes en la instalación)
  List<ItemFrequency> getValidatedMaterialsWithFrequency() {
    final raw = getMaterialsWithFrequency();
    final filtered =
        raw.where((m) => !excludedMaterials.contains(m.name)).toList();
    for (final add in additionalMaterials) {
      if (!filtered.any((f) => f.name == add) &&
          !excludedMaterials.contains(add)) {
        filtered.add(
          ItemFrequency(
            name: add,
            count: totalPhotos > 0 ? totalPhotos : 1,
            totalPhotos: totalPhotos > 0 ? totalPhotos : 1,
            areas: const ['Agregado por Gestor'],
          ),
        );
      }
    }
    return filtered;
  }

  /// Accesorios validados por el gestor (excluye los ya existentes)
  List<String> getValidatedConsolidatedAccessories() {
    final raw = getConsolidatedAccessories();
    final filtered =
        raw.where((a) => !excludedAccessories.contains(a)).toList();
    for (final add in additionalAccessories) {
      if (!filtered.contains(add) && !excludedAccessories.contains(add)) {
        filtered.add(add);
      }
    }
    filtered.sort();
    return filtered;
  }

  /// Consolidado de metrados lineales totales por material (ej: {"Tubo EMT 3/4\"": 45.0, "Canaleta 40x25": 18.5})
  Map<String, double> getConsolidatedLinearMeters() {
    final Map<String, double> totals = {};
    for (final photo in photos) {
      for (final m in photo.linearMeasurements) {
        if (!m.esMetradoMaterial && (m.material == 'Solo Medida' || m.material == 'Por definir' || m.material.isEmpty)) {
          continue;
        }
        if (m.material != 'Solo Medida' && m.material != 'Por definir' && m.material.isNotEmpty) {
          totals[m.material] = (totals[m.material] ?? 0.0) + m.longitudMetros;
        }
      }
    }
    return totals;
  }

  /// Total general acumulado de metros lineales en el proyecto
  double get totalLinearMeters {
    double sum = 0.0;
    for (final photo in photos) {
      for (final m in photo.linearMeasurements) {
        sum += m.longitudMetros;
      }
    }
    return sum;
  }

  /// Todas las mediciones lineales de la sesión
  List<LinearMeasurement> getAllMeasurements() {
    final List<LinearMeasurement> list = [];
    for (final photo in photos) {
      list.addAll(photo.linearMeasurements);
    }
    return list;
  }

  /// Identificador único y seguro para nombre de archivo en almacenamiento local
  String get id {
    final raw = '${project.contacto}_${project.proyecto}_${project.fecha}';
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'proyecto_${DateTime.now().millisecondsSinceEpoch}' : sanitized;
  }

  /// Fecha legible formateada para el listado de proyectos
  String get displayDate => project.fecha.isNotEmpty ? project.fecha : 'Sin fecha';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project': project.toStorageMap(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'excludedTools': excludedTools.toList(),
      'excludedMaterials': excludedMaterials.toList(),
      'excludedAccessories': excludedAccessories.toList(),
      'additionalTools': additionalTools,
      'additionalMaterials': additionalMaterials,
      'additionalAccessories': additionalAccessories,
      'customHierarchyResponsibles': customHierarchyResponsibles,
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  factory ProjectSessionModel.fromJson(Map<String, dynamic> json) {
    final project = ProjectModel.fromStorageMap(json['project'] as Map<String, dynamic>? ?? {});
    final photosList = (json['photos'] as List<dynamic>?)
        ?.map((p) => SessionEvidenceRecord.fromJson(p as Map<String, dynamic>))
        .toList() ?? [];

    final session = ProjectSessionModel(
      project: project,
      photos: photosList,
    );

    if (json['excludedTools'] != null) {
      session.excludedTools.addAll((json['excludedTools'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['excludedMaterials'] != null) {
      session.excludedMaterials.addAll((json['excludedMaterials'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['excludedAccessories'] != null) {
      session.excludedAccessories.addAll((json['excludedAccessories'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['additionalTools'] != null) {
      session.additionalTools.addAll((json['additionalTools'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['additionalMaterials'] != null) {
      session.additionalMaterials.addAll((json['additionalMaterials'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['additionalAccessories'] != null) {
      session.additionalAccessories.addAll((json['additionalAccessories'] as List<dynamic>).map((e) => e.toString()));
    }
    if (json['customHierarchyResponsibles'] != null) {
      final map = json['customHierarchyResponsibles'] as Map<String, dynamic>;
      map.forEach((k, v) {
        session.customHierarchyResponsibles[k] = v.toString();
      });
    }

    return session;
  }
}
