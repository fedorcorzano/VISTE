import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../config/constants.dart';

/// Representa una sugerencia de peligro auditada por el agente SSOMA con IA
class SsomaHazardSuggestion {
  final String hazardName;
  final String riskDescription;
  final String hierarchyLevel; // Eliminación, Sustitución, Control de Ingeniería, Control Administrativo, EPP
  final String preventiveMeasure;
  final String costResponsible; // 'VIGILARTE' o 'CLIENTE'
  final String technicalBasis;
  bool isChecked;

  SsomaHazardSuggestion({
    required this.hazardName,
    required this.riskDescription,
    required this.hierarchyLevel,
    required this.preventiveMeasure,
    required this.costResponsible,
    required this.technicalBasis,
    this.isChecked = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'hazardName': hazardName,
      'riskDescription': riskDescription,
      'hierarchyLevel': hierarchyLevel,
      'preventiveMeasure': preventiveMeasure,
      'costResponsible': costResponsible,
      'technicalBasis': technicalBasis,
      'isChecked': isChecked,
    };
  }

  factory SsomaHazardSuggestion.fromJson(Map<String, dynamic> json) {
    return SsomaHazardSuggestion(
      hazardName: json['hazardName'] as String? ?? 'Peligro No Identificado',
      riskDescription: json['riskDescription'] as String? ?? '',
      hierarchyLevel: json['hierarchyLevel'] as String? ?? 'Control de Ingeniería',
      preventiveMeasure: json['preventiveMeasure'] as String? ?? '',
      costResponsible: json['costResponsible'] as String? ?? 'VIGILARTE',
      technicalBasis: json['technicalBasis'] as String? ?? '',
      isChecked: json['isChecked'] as bool? ?? true,
    );
  }
}

/// Servicio del Agente Auditor SSOMA con IA (Google Gemini 2.5 Flash)
/// Especializado en seguridad y salud en el trabajo para obras e instalaciones eléctricas (Ley 29783 / G.050)
class SsomaAiService {
  static const String _modelName = 'gemini-2.5-flash';

  /// Realiza la auditoría de la foto y escena técnica.
  /// Si hay conectividad y clave de API, utiliza visión artificial de Gemini.
  /// Si no hay conexión o no hay API key, utiliza el motor de reglas heurísticas locales (offline-first).
  static Future<List<SsomaHazardSuggestion>> auditScene({
    Uint8List? imageBytes,
    List<String> detectedMateriales = const [],
    List<String> detectedEstructuras = const [],
    String areaSector = '',
  }) async {
    final String apiKey = Constants.geminiApiKey.trim();

    // Si contamos con clave de API e imagen, ejecutamos el agente en la nube
    if (apiKey.isNotEmpty && imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final suggestions = await _callGeminiVision(
          apiKey: apiKey,
          imageBytes: imageBytes,
          detectedMateriales: detectedMateriales,
          detectedEstructuras: detectedEstructuras,
          areaSector: areaSector,
        );
        if (suggestions.isNotEmpty) return suggestions;
      } catch (e) {
        debugPrint('Fallo en auditoría remota Gemini: $e. Aplicando motor heurístico local...');
      }
    }

    // Fallback inteligente offline con matriz técnica de seguridad
    return _generateLocalHeuristicSuggestions(
      materiales: detectedMateriales,
      estructuras: detectedEstructuras,
      areaSector: areaSector,
    );
  }

  /// Llama a la API REST de Gemini 2.5 Flash enviando la imagen comprimida y solicitando JSON estructurado
  static Future<List<SsomaHazardSuggestion>> _callGeminiVision({
    required String apiKey,
    required Uint8List imageBytes,
    required List<String> detectedMateriales,
    required List<String> detectedEstructuras,
    required String areaSector,
  }) async {
    // Reescalar imagen a ~720px para reducir latencia y costo de tokens
    Uint8List compressedJpeg = imageBytes;
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        img.Image resized = decoded;
        if (decoded.width > 900 || decoded.height > 900) {
          resized = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 900 : null,
            height: decoded.height >= decoded.width ? 900 : null,
          );
        }
        compressedJpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 78));
      }
    } catch (_) {}

    final String base64Data = base64Encode(compressedJpeg);

    final String prompt = '''
Eres el Ingeniero Auditor SSOMA de VIGILARTE INGENIERÍA SAC en Perú.
Analiza esta fotografía técnica de un relevamiento en el sector: "$areaSector".
Estructuras reportadas: ${detectedEstructuras.join(', ')}.
Materiales reportados: ${detectedMateriales.join(', ')}.

Según la Ley N° 29783 (Ley de Seguridad y Salud en el Trabajo) y la Norma Técnica G.050 (Seguridad durante la construcción):
1. Identifica entre 2 y 4 peligros críticos visibles o inherentes a esta instalación (ej. Riesgo Eléctrico, Trabajo en Altura > 1.80m, Espacio Confinado, Falta de Orden y Limpieza, Proyección de partículas al perforar, etc.).
2. Para cada peligro, asigna la Jerarquía de Control ('Eliminación', 'Sustitución', 'Control de Ingeniería', 'Control Administrativo', 'EPP').
3. Especifica la medida preventiva concreta.
4. Determina si el costo de implementar la medida corresponde comercialmente a 'VIGILARTE' (ej. herramientas aisladas, arnés, delimitación, EPP de cuadrilla) o al 'CLIENTE' (ej. despejar área, desenergizar tablero general, suministrar andamiaje de obra civil o puntos de anclaje certificados).

Responde EXCLUSIVAMENTE un arreglo JSON con el siguiente formato exacto:
[
  {
    "hazardName": "Nombre del Peligro",
    "riskDescription": "Descripción concisa del riesgo",
    "hierarchyLevel": "Control de Ingeniería / EPP / Control Administrativo",
    "preventiveMeasure": "Medida preventiva obligatoria",
    "costResponsible": "VIGILARTE o CLIENTE",
    "technicalBasis": "Artículo o fundamento de Ley 29783 / G.050"
  }
]
''';

    final Uri url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Data,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
      }
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final String rawJsonText = parts.first['text'] as String;
          final List<dynamic> parsedList = jsonDecode(rawJsonText);
          return parsedList
              .map((item) => SsomaHazardSuggestion.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } else {
      debugPrint('Gemini API Error ${response.statusCode}: ${response.body}');
    }

    return [];
  }

  /// Motor de reglas técnicas locales (100% offline) para garantizar respuesta instantánea
  static List<SsomaHazardSuggestion> _generateLocalHeuristicSuggestions({
    required List<String> materiales,
    required List<String> estructuras,
    required String areaSector,
  }) {
    final List<SsomaHazardSuggestion> list = [];
    final lowerMats = materiales.map((m) => m.toLowerCase()).toList();
    final lowerEsts = estructuras.map((e) => e.toLowerCase()).toList();
    final lowerArea = areaSector.toLowerCase();

    // 1. Detección de Riesgo Eléctrico
    final hasPiping = lowerMats.any((m) => m.contains('emt') || m.contains('imc') || m.contains('sel') || m.contains('sap') || m.contains('canaleta'));
    if (hasPiping || lowerArea.contains('tablero') || lowerArea.contains('subestaci') || lowerArea.contains('cuarto')) {
      list.add(
        SsomaHazardSuggestion(
          hazardName: 'Riesgo Eléctrico',
          riskDescription: 'Posible inducción, contacto accidental con conductores o arcos eléctricos en bandejas y tableros.',
          hierarchyLevel: 'Control de Ingeniería',
          preventiveMeasure: 'Verificación de ausencia de tensión con multímetro CAT III/IV y uso de herramientas dieléctricas 1000V.',
          costResponsible: 'VIGILARTE',
          technicalBasis: 'CNE Suministro / Ley 29783 Art. 21',
          isChecked: true,
        ),
      );
    }

    // 2. Detección de Trabajo en Altura
    final isElevated = lowerEsts.any((e) => e.contains('fierro') || e.contains('techo') || e.contains('teja') || e.contains('policarbonato')) ||
        lowerArea.contains('altura') ||
        lowerArea.contains('techo') ||
        lowerArea.contains('fachada');
    if (isElevated || list.isEmpty) {
      list.add(
        SsomaHazardSuggestion(
          hazardName: 'Trabajo en Altura',
          riskDescription: 'Labores sobre escaleras o andamios a desnivel mayor a 1.80m con riesgo de caída de personas y objetos.',
          hierarchyLevel: 'Control de Ingeniería / EPP',
          preventiveMeasure: 'Uso de arnés con línea de vida doble y absorbedor de impacto; inspección diaria de escaleras (tarjeta verde).',
          costResponsible: 'VIGILARTE',
          technicalBasis: 'Norma G.050 Art. 20 / D.S. 005-2012-TR',
          isChecked: true,
        ),
      );
    }

    // 3. Detección de Polvo / Proyección de Partículas al perforar estructuras duras
    final hasHardStructure = lowerEsts.any((e) => e.contains('concreto') || e.contains('ladrillo') || e.contains('mayolica'));
    if (hasHardStructure) {
      list.add(
        SsomaHazardSuggestion(
          hazardName: 'Proyección de Partículas y Polvo de Sílice',
          riskDescription: 'Perforación con rotomartillo genera astillas, virutas y polvo mineral en suspensión.',
          hierarchyLevel: 'EPP',
          preventiveMeasure: 'Lentes de seguridad con protección lateral anti-impacto (ANSI Z87.1) y respirador para partículas N95/P100.',
          costResponsible: 'VIGILARTE',
          technicalBasis: 'Norma G.050 Art. 12 (Protección Respiratoria y Visual)',
          isChecked: true,
        ),
      );
    }

    // 4. Falta de Orden y Limpieza / Tránsito de personas
    list.add(
      SsomaHazardSuggestion(
        hazardName: 'Falta de Orden y Limpieza / Vías de Tránsito',
        riskDescription: 'Presencia de cajas, cables temporales y herramientas en el piso que originan tropiezos o caídas al mismo nivel.',
        hierarchyLevel: 'Control Administrativo',
        preventiveMeasure: 'Delimitación del área de trabajo con conos reflectivos, cinta de seguridad y retiro inmediato de retazos.',
        costResponsible: 'VIGILARTE',
        technicalBasis: 'Ley 29783 Art. 50 / G.050 Orden y Limpieza',
        isChecked: true,
      ),
    );

    // 5. Si el sector es exterior o fachada, considerar condición civil del cliente
    if (lowerArea.contains('exterior') || lowerArea.contains('patio') || lowerArea.contains('fachada')) {
      list.add(
        SsomaHazardSuggestion(
          hazardName: 'Interferencia con Tránsito Vehicular / Peatonal',
          riskDescription: 'Tránsito de montacargas, camiones o personal ajeno a la instalación.',
          hierarchyLevel: 'Control Administrativo',
          preventiveMeasure: 'Coordinación con el Cliente para vigía de seguridad y bloqueo temporal del acceso de vehículos.',
          costResponsible: 'CLIENTE',
          technicalBasis: 'Ley 29783 Art. 68 (Seguridad en contratistas y terceros)',
          isChecked: false, // Desmarcado por defecto para que el usuario decida si aplica
        ),
      );
    }

    return list;
  }
}
