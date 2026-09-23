import 'dart:io';
import 'dart:typed_data';
import 'project_model.dart';

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
  final Uint8List? clientPngBytes; // Versión exclusiva para el Cliente (SOLO marcadores de seguridad SST)
  final List<String> estructuras;
  final List<String> materiales;
  final List<String> peligros;
  final List<String> herramientas;
  final List<String> accesorios;
  final DateTime timestamp;

  const SessionEvidenceRecord({
    required this.photoNumber,
    required this.areaSector,
    required this.localImagePath,
    required this.pngBytes,
    this.clientPngBytes,
    required this.estructuras,
    required this.materiales,
    required this.peligros,
    required this.herramientas,
    required this.accesorios,
    required this.timestamp,
  });

  /// Retorna la imagen adecuada para el cliente (con solo marcadores SST) o fallback a la completa
  Uint8List get clientImageBytes => clientPngBytes ?? pngBytes;

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
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SessionEvidenceRecord.fromJson(Map<String, dynamic> json) {
    final String imagePath = json['localImagePath'] as String? ?? '';
    Uint8List loadedBytes = Uint8List(0);
    Uint8List? loadedClientBytes;

    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        try {
          loadedBytes = file.readAsBytesSync();
        } catch (_) {}
      }
      final sstPath = imagePath.replaceAll('.png', '_sst.png');
      final sstFile = File(sstPath);
      if (sstFile.existsSync()) {
        try {
          loadedClientBytes = sstFile.readAsBytesSync();
        } catch (_) {}
      }
    }

    return SessionEvidenceRecord(
      photoNumber: json['photoNumber'] as int? ?? 1,
      areaSector: json['areaSector'] as String? ?? '',
      localImagePath: imagePath,
      pngBytes: loadedBytes,
      clientPngBytes: loadedClientBytes,
      estructuras: (json['estructuras'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      materiales: (json['materiales'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      peligros: (json['peligros'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      herramientas: (json['herramientas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      accesorios: (json['accesorios'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
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
