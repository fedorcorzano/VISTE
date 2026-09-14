import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/project_model.dart';

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

  // 2. Obtener catálogos (Proyectos, Estructuras, Materiales, Peligros)
  Future<Map<String, List<String>>> fetchCatalogs() async {
    try {
      final response = await http.get(Uri.parse(_webAppUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'proyectos': List<String>.from(
            data['Proyectos'] ?? data['proyectos'] ?? [],
          ),
          'estructuras': List<String>.from(
            data['Estructuras'] ?? data['estructuras'] ?? [],
          ),
          'materiales': List<String>.from(
            data['Materiales'] ?? data['materiales'] ?? [],
          ),
          'peligros': List<String>.from(
            data['Peligros'] ??
                data['peligros'] ??
                data['Riesgos'] ??
                data['riesgos'] ??
                [],
          ),
        };
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos: $e');
    }

    // Listas por defecto en caso de que no haya internet o falle la conexión
    return {
      'proyectos': ['Proyecto por Defecto'],
      'estructuras': ['Ladrillo', 'Concreto', 'Madera', 'Metal'],
      'materiales': ['tubo PVC', 'Cable UTP'],
      'peligros': ['Riesgo Eléctrico'],
    };
  }
}
