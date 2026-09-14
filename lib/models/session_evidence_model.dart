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
}

/// Contenedor integral de la sesión de trabajo con métodos de consolidación y métricas
class ProjectSessionModel {
  final ProjectModel project;
  final List<SessionEvidenceRecord> photos;

  ProjectSessionModel({
    required this.project,
    List<SessionEvidenceRecord>? photos,
  }) : photos = photos ?? [];

  /// Agrega una evidencia fotográfica a la sesión
  void addPhoto(SessionEvidenceRecord record) {
    photos.add(record);
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
}
