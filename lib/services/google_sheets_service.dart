import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/project_model.dart';
import '../models/sticker_model.dart';

class GoogleSheetsService {
  String get _webAppUrl => Constants.googleScriptUrl;

  // 1. Enviar / Sincronizar el reporte a Google Sheets y Drive
  Future<SheetsResponse> syncProject(ProjectModel project) async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(project.toJson()),
      );

      debugPrint('Código HTTP recibido: ${response.statusCode}');
      debugPrint('Respuesta Apps Script: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 302) {
        String msg = '¡Reporte y foto registrados con éxito en Excel y Drive!';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['status'] == 'error') {
            return SheetsResponse(
              isSuccess: false,
              message: data['message'] ?? 'Error reportado por el servidor',
            );
          }
          if (data is Map && data['data'] != null && data['data']['fotoUrl'] != null) {
            final url = data['data']['fotoUrl'];
            msg = '¡Éxito! Evidencia guardada en Drive y registrada en Excel.\nURL: $url';
          }
        } catch (_) {}

        return SheetsResponse(
          isSuccess: true,
          message: msg,
        );
      } else {
        return SheetsResponse(
          isSuccess: false,
          message: 'Error en el servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SheetsResponse(isSuccess: false, message: 'Excepción de red: $e');
    }
  }

  // 2. Obtener catálogos (Proyectos, Estructuras, Materiales, Peligros, Herramientas, Accesorios)
  Future<Map<String, List<String>>> fetchCatalogs() async {
    try {
      final response = await http.get(Uri.parse(_webAppUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Actualizar matrices personalizadas si vienen del servidor
        if (data is Map) {
          if (data['accesoriosMaterial'] is Map) {
            final Map<String, dynamic> raw = data['accesoriosMaterial'];
            TechnicalCatalogMatrix.accesoriosMaterialOverride = raw.map(
              (k, v) => MapEntry(k, List<String>.from(v ?? [])),
            );
          }
          if (data['herramientasMaterial'] is Map) {
            final Map<String, dynamic> raw = data['herramientasMaterial'];
            TechnicalCatalogMatrix.herramientasMaterialOverride = raw.map(
              (k, v) => MapEntry(k, List<String>.from(v ?? [])),
            );
          }
          if (data['herramientasEstructura'] is Map) {
            final Map<String, dynamic> raw = data['herramientasEstructura'];
            TechnicalCatalogMatrix.herramientasEstructuraOverride = raw.map(
              (k, v) => MapEntry(k, List<String>.from(v ?? [])),
            );
          }
        }

        final List<String> serverEstructuras = List<String>.from(
          data['Estructuras'] ?? data['estructuras'] ?? [],
        );
        final List<String> serverMateriales = List<String>.from(
          data['Materiales'] ?? data['materiales'] ?? [],
        );

        return {
          'proyectos': List<String>.from(
            data['Proyectos'] ?? data['proyectos'] ?? [],
          ),
          'estructuras': serverEstructuras.isNotEmpty
              ? serverEstructuras
              : TechnicalCatalogMatrix.defaultEstructuras,
          'materiales': serverMateriales.isNotEmpty
              ? serverMateriales
              : TechnicalCatalogMatrix.defaultMateriales,
          'peligros': List<String>.from(
            data['Peligros'] ??
                data['peligros'] ??
                data['Riesgos'] ??
                data['riesgos'] ??
                [
                  'Riesgo Eléctrico',
                  'Caída a distinto nivel',
                  'Espacio Confinado',
                  'Corte / Atrapamiento',
                  'Piso Resbaladizo',
                ],
          ),
        };
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos desde Apps Script: $e');
    }

    // Listas por defecto con los materiales y estructuras oficiales de VISTEC
    return {
      'proyectos': ['Cámaras de videovigilancia', 'Canalizaciones y Redes', 'General'],
      'estructuras': TechnicalCatalogMatrix.defaultEstructuras,
      'materiales': TechnicalCatalogMatrix.defaultMateriales,
      'peligros': [
        'Riesgo Eléctrico',
        'Caída a distinto nivel',
        'Espacio Confinado',
        'Corte / Atrapamiento',
        'Piso Resbaladizo',
      ],
    };
  }
}
