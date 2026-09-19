import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/project_model.dart';
import '../models/sticker_model.dart';
import 'catalog_visual_service.dart';

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
          if (data['catalogoVisual'] is List) {
            final List rawList = data['catalogoVisual'];
            final List<Map<String, dynamic>> items = [];
            for (final elem in rawList) {
              if (elem is Map) {
                items.add(Map<String, dynamic>.from(elem));
              }
            }
            if (items.isNotEmpty) {
              CatalogVisualService.updateFromSheets(items);
            }
          }
        }

        final List<String> serverEstructuras = List<String>.from(
          data['Estructuras'] ?? data['estructuras'] ?? [],
        ).where((s) => s.trim().isNotEmpty).toList();
        final List<String> serverMateriales = List<String>.from(
          data['Materiales'] ?? data['materiales'] ?? [],
        ).where((m) => m.trim().isNotEmpty).toList();

        final List<String> serverProyectos = List<String>.from(
          data['Proyectos'] ?? data['proyectos'] ?? [],
        ).where((p) => p.trim().isNotEmpty).toList();

        return {
          'proyectos': serverProyectos.isNotEmpty
              ? serverProyectos
              : TechnicalCatalogMatrix.defaultProyectos,
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
      'proyectos': TechnicalCatalogMatrix.defaultProyectos,
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

  // 3. Subir foto de herramienta/material al catálogo en Google Drive y Sheets (Método 1)
  Future<SheetsResponse> uploadCatalogImage({
    required String itemName,
    required String category,
    required Uint8List imageBytes,
    String? commercialName,
    String? specification,
  }) async {
    try {
      final base64Data = base64Encode(imageBytes);
      final payload = {
        'action': 'upload_catalog_image',
        'itemName': itemName,
        'category': category,
        'commercialName': commercialName ?? itemName,
        'specification': specification ?? '',
        'base64Data': base64Data,
      };

      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'error') {
          return SheetsResponse(
            isSuccess: false,
            message: data['message'] ?? 'Error reportado por el servidor',
          );
        }

        final url = (data is Map && data['url'] != null) ? data['url'].toString() : '';
        if (url.isNotEmpty) {
          final isMat = category.toLowerCase().contains('mat');
          CatalogVisualService.setSingleItem(
            VisualCatalogItem(
              title: itemName,
              category: category,
              commercialName: commercialName ?? itemName,
              specification: (specification != null && specification.isNotEmpty)
                  ? specification
                  : 'Especificación estándar según catálogo de obra.',
              imageUrl: url,
              fallbackIcon: isMat ? Icons.inventory_2 : Icons.handyman,
              badgeColor: isMat ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
            ),
          );
        }

        return SheetsResponse(
          isSuccess: true,
          message: '¡Foto registrada con éxito en Drive y actualizada en Excel!',
        );
      } else {
        return SheetsResponse(
          isSuccess: false,
          message: 'Error en el servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SheetsResponse(isSuccess: false, message: 'Error al subir foto: $e');
    }
  }

  // 4. Sincronizar masivamente las fotos desde la carpeta de Google Drive (Método 2)
  Future<SheetsResponse> syncDriveCatalog() async {
    try {
      final response = await http.post(
        Uri.parse(_webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'sync_drive_catalog'}),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        final msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Sincronización de Drive completada.';

        // Re-cargar catálogos para actualizar catálogo visual en memoria
        await fetchCatalogs();

        return SheetsResponse(isSuccess: true, message: msg);
      } else {
        return SheetsResponse(
          isSuccess: false,
          message: 'Error en el servidor al sincronizar: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SheetsResponse(isSuccess: false, message: 'Error de red: $e');
    }
  }

  /// 5. Genera la URL pública para enviar a múltiples proveedores (3 o más) para cotizar
  String getSupplierQuoteUrl(String projectName, {List<String>? items}) {
    final base =
        '$_webAppUrl?action=cotizar&project=${Uri.encodeComponent(projectName)}';
    if (items != null && items.isNotEmpty) {
      final sanitizedItems = items
          .map((item) => item.replaceAll(',', ';').trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      return '$base&items=${Uri.encodeComponent(sanitizedItems.join(","))}';
    }
    return base;
  }

  /// 6. Consulta las cotizaciones enviadas por los distintos proveedores para el proyecto
  Future<Map<String, dynamic>> fetchSupplierQuotes(String projectName) async {
    try {
      final url = '$_webAppUrl?action=get_supplier_quotes&project=${Uri.encodeComponent(projectName)}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return {'quotes': [], 'minPrices': {}};
    } catch (e) {
      debugPrint('Error al consultar cotizaciones de proveedores: $e');
      return {'quotes': [], 'minPrices': {}};
    }
  }
}
