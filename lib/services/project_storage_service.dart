import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_evidence_model.dart';

/// Servicio de persistencia local para sesiones de proyectos técnicos
/// Garantiza que ninguna evidencia o progreso se pierda y permite
/// regenerar reportes en cualquier momento desde el historial.
class ProjectStorageService {
  static const String _folderName = 'saved_projects';

  /// Obtiene el directorio donde se almacenan las sesiones
  static Future<Directory> _getProjectsDirectory() async {
    Directory dir;
    try {
      final appDir = await getApplicationDocumentsDirectory().timeout(const Duration(milliseconds: 500));
      dir = Directory('${appDir.path}/$_folderName');
    } catch (_) {
      dir = Directory('.$_folderName');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Guarda o actualiza una sesión de proyecto en disco en formato JSON
  static Future<void> saveSession(ProjectSessionModel session) async {
    try {
      final dir = await _getProjectsDirectory();
      final file = File('${dir.path}/${session.id}.json');

      // Guardar imágenes de cliente (SST), cotas y fotos base en disco si existen en memoria
      for (final photo in session.photos) {
        if (photo.localImagePath.isNotEmpty) {
          // 1. Imagen principal con pines
          if (photo.pngBytes.isNotEmpty) {
            try {
              final mainFile = File(photo.localImagePath);
              await mainFile.writeAsBytes(photo.pngBytes);
            } catch (e) {
              debugPrint('Error guardando imagen principal: $e');
            }
          }

          // 2. Imagen exclusiva para cliente SST (solo riesgos SST)
          if (photo.clientPngBytes != null && photo.clientPngBytes!.isNotEmpty) {
            try {
              final sstPath = photo.localImagePath.replaceAll('.png', '_sst.png');
              final sstFile = File(sstPath);
              await sstFile.writeAsBytes(photo.clientPngBytes!);
            } catch (e) {
              debugPrint('Error guardando imagen SST: $e');
            }
          }

          // 3. Imagen exclusiva de cotas/medidas
          if (photo.measurementsPngBytes != null && photo.measurementsPngBytes!.isNotEmpty) {
            try {
              final medidasPath = photo.localImagePath.replaceAll('.png', '_medidas.png');
              final medidasFile = File(medidasPath);
              await medidasFile.writeAsBytes(photo.measurementsPngBytes!);
            } catch (e) {
              debugPrint('Error guardando imagen cotas: $e');
            }
          }

          // 4. Imagen base limpia (raw)
          if (photo.cleanPngBytes != null && photo.cleanPngBytes!.isNotEmpty) {
            try {
              final rawPath = photo.localImagePath.replaceAll('.png', '_raw.jpg');
              final rawFile = File(rawPath);
              if (!rawFile.existsSync()) {
                await rawFile.writeAsBytes(photo.cleanPngBytes!);
              }
            } catch (e) {
              debugPrint('Error guardando imagen raw: $e');
            }
          }
        }
      }

      final jsonStr = jsonEncode(session.toJson());
      await file.writeAsString(jsonStr);
      debugPrint('Proyecto guardado exitosamente en: ${file.path} (${session.photos.length} fotos)');
    } catch (e, stack) {
      debugPrint('Error al guardar sesión de proyecto: $e\n$stack');
    }
  }

  /// Carga todas las sesiones almacenadas localmente, ordenadas por fecha más reciente
  static Future<List<ProjectSessionModel>> getAllSessions() async {
    final List<ProjectSessionModel> list = [];
    try {
      final dir = await _getProjectsDirectory();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final Map<String, dynamic> jsonMap = jsonDecode(content);
          final session = ProjectSessionModel.fromJson(jsonMap);
          list.add(session);
        } catch (e) {
          debugPrint('Error al leer sesión del archivo ${file.path}: $e');
        }
      }

      // Ordenar por cantidad de fotos / fecha más reciente
      list.sort((a, b) {
        final dateA = a.photos.isNotEmpty ? a.photos.last.timestamp : DateTime(2000);
        final dateB = b.photos.isNotEmpty ? b.photos.last.timestamp : DateTime(2000);
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint('Error al listar proyectos guardados: $e');
    }
    return list;
  }

  /// Busca sesiones que coincidan con la consulta en cliente, proyecto o fecha
  static Future<List<ProjectSessionModel>> searchSessions(String query) async {
    final all = await getAllSessions();
    if (query.trim().isEmpty) return all;

    final q = query.trim().toLowerCase();
    return all.where((s) {
      final contacto = s.project.contacto.toLowerCase();
      final proyecto = s.project.proyecto.toLowerCase();
      final fecha = s.project.fecha.toLowerCase();
      final responsable = s.project.responsable.toLowerCase();
      return contacto.contains(q) ||
          proyecto.contains(q) ||
          fecha.contains(q) ||
          responsable.contains(q);
    }).toList();
  }

  /// Elimina una sesión del almacenamiento local
  static Future<bool> deleteSession(String id) async {
    try {
      final dir = await _getProjectsDirectory();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) {
        await file.delete();
        debugPrint('Sesión $id eliminada de almacenamiento.');
        return true;
      }
    } catch (e) {
      debugPrint('Error al eliminar sesión $id: $e');
    }
    return false;
  }
}
