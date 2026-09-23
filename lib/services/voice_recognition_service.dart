import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Resultado de la coincidencia semántica y difusa entre la voz y los catálogos técnicos
class VoiceCatalogMatchResult {
  final List<String> matchedMateriales;
  final List<String> matchedEstructuras;
  final List<String> matchedPeligros;
  final String rawText;

  const VoiceCatalogMatchResult({
    required this.matchedMateriales,
    required this.matchedEstructuras,
    required this.matchedPeligros,
    required this.rawText,
  });

  bool get hasMatches =>
      matchedMateriales.isNotEmpty ||
      matchedEstructuras.isNotEmpty ||
      matchedPeligros.isNotEmpty;

  int get totalMatches =>
      matchedMateriales.length +
      matchedEstructuras.length +
      matchedPeligros.length;
}

/// Servicio de reconocimiento y búsqueda por voz para selección de ítems en terreno.
/// Compatible con el micrófono integrado del celular y manos libres / audífonos Bluetooth.
class VoiceRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  /// Inicializa el motor de reconocimiento de voz del sistema
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (err) => debugPrint('Error SpeechToText: ${err.errorMsg}'),
        onStatus: (status) => debugPrint('Estado SpeechToText: $status'),
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('Fallo al inicializar SpeechToText: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// Inicia la escucha activa por micrófono (celular o Bluetooth manos libres)
  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevelChange,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: 'es_PE',
        ),
      );
    } catch (e) {
      debugPrint('Error al iniciar escucha: $e');
    }
  }

  /// Detiene la escucha
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancela la escucha
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// Normaliza texto removiendo tildes y diacríticos para matching infalible en español
  static String normalizeText(String input) {
    String text = input.toLowerCase().trim();
    const withDia = 'áéíóúüñÁÉÍÓÚÜÑ';
    const withoutDia = 'aeiouunAEIOUUN';
    for (int i = 0; i < withDia.length; i++) {
      text = text.replaceAll(withDia[i], withoutDia[i]);
    }
    return text;
  }

  /// Realiza una coincidencia inteligente y difusa del texto hablado contra los catálogos técnicos
  static VoiceCatalogMatchResult matchVoiceToCatalog(
    String spokenText, {
    required List<String> availableMateriales,
    required List<String> availableEstructuras,
    required List<String> availablePeligros,
  }) {
    final String clean = normalizeText(spokenText);
    if (clean.isEmpty) {
      return VoiceCatalogMatchResult(
        matchedMateriales: const [],
        matchedEstructuras: const [],
        matchedPeligros: const [],
        rawText: spokenText,
      );
    }

    final Set<String> matchedMats = {};
    final Set<String> matchedEsts = {};
    final Set<String> matchedPels = {};

    // 1. Coincidencia de Materiales (incluye sinónimos comunes en obra)
    final Map<String, List<String>> materialKeywords = {
      'Canaletas': ['canaleta', 'canaletas', 'canal', 'moldura', 'canaleta plastica', 'canaleta legrand'],
      'Tubo PVC SEL': ['pvc sel', 'tubo sel', 'tubo liviano', 'sel'],
      'Corrugado PVC': ['corrugado pvc', 'corrugado blanco', 'manguera corrugada', 'tubo corrugado', 'corrugado'],
      'Tubo PVC SAP': ['pvc sap', 'tubo sap', 'tubo pesado', 'sap'],
      'Tubo EMT': ['tubo emt', 'emt', 'metalico emt', 'tubo galvanizado', 'conduit emt', 'conduit'],
      'Tubo IMC': ['tubo imc', 'imc', 'tuberia pesada imc'],
      'Corrugado EMT': ['corrugado emt', 'tubo flexible emt', 'metalico flexible'],
      'Corrugado Liquid Tight': ['liquid tight', 'liquid', 'hermetico flexible', 'tubo hermetico'],
      'Cables y Conductores': ['cables', 'cable', 'conductor', 'alambre', 'cordon', 'thw'],
      'Bandeja Portacables': ['bandeja', 'escalerilla', 'canastilla'],
    };

    // Primero revisar nombres directos disponibles
    for (final mat in availableMateriales) {
      final key = normalizeText(mat);
      if (clean.contains(key)) {
        matchedMats.add(mat);
      }
    }

    // Luego sinónimos de obra
    materialKeywords.forEach((matName, keywords) {
      for (final kw in keywords) {
        if (_containsWord(clean, normalizeText(kw))) {
          final found = availableMateriales.firstWhere(
            (m) => normalizeText(m).contains(normalizeText(matName)) || normalizeText(matName).contains(normalizeText(m)),
            orElse: () => matName,
          );
          matchedMats.add(found);
          break;
        }
      }
    });

    // 2. Coincidencia de Estructuras (incluye sinónimos comunes)
    final Map<String, List<String>> estructuraKeywords = {
      'Concreto': ['concreto', 'cemento', 'muro de concreto', 'columna', 'techo', 'pared de concreto', 'placa', 'pared'],
      'Ladrillo Hueco': ['ladrillo hueco', 'pandereta', 'pared de ladrillo', 'ladrillo'],
      'Ladrillo Macizo': ['ladrillo macizo', 'bloqueta', 'bloque'],
      'Drywall': ['drywall', 'durlock', 'yeso', 'tablaroca', 'planchas', 'tabique'],
      'Mayólica': ['mayolica', 'ceramica', 'porcelanato', 'azulejo', 'baldosa'],
      'Vidrio': ['vidrio', 'cristal', 'mampara', 'ventana'],
      'Fierro': ['fierro', 'hierro', 'viga de fierro', 'columna metalica', 'tijeral', 'metal', 'techo metalico'],
      'Acero Inoxidable': ['acero inoxidable', 'acero inox', 'inoxidable', 'inox'],
      'Policarbonato': ['policarbonato', 'cobertura plastica'],
      'Teja': ['teja', 'techo de tejas', 'techado teja'],
    };

    for (final est in availableEstructuras) {
      final key = normalizeText(est);
      if (clean.contains(key)) {
        matchedEsts.add(est);
      }
    }

    estructuraKeywords.forEach((estName, keywords) {
      for (final kw in keywords) {
        if (_containsWord(clean, normalizeText(kw))) {
          final found = availableEstructuras.firstWhere(
            (e) => normalizeText(e).contains(normalizeText(estName)) || normalizeText(estName).contains(normalizeText(e)),
            orElse: () => estName,
          );
          matchedEsts.add(found);
          break;
        }
      }
    });

    // 3. Coincidencia de Peligros / Riesgos SSOMA
    final Map<String, List<String>> peligroKeywords = {
      'Riesgo Eléctrico': [
        'electrico', 'electricidad', 'electrocucion', 'cables expuestos',
        'cables', 'cable', 'alta tension', 'corriente', 'tablero', 'energizado', 'shock', 'chispa',
      ],
      'Trabajo en Altura': ['altura', 'escalera', 'andamio', 'caida', 'techo alto', 'desnivel alto'],
      'Piso irregular / Objeto en el suelo': ['piso irregular', 'objeto en el suelo', 'desnivel', 'tropezon', 'piso resbaloso', 'resbaloso'],
      'Falta de Señalización': ['falta de senalizacion', 'sin senalizar', 'no hay senal', 'senales', 'senaletica'],
      'Falta de Orden y Limpieza': ['falta de orden', 'orden y limpieza', 'desorden', 'basura', 'escombros'],
    };

    for (final pel in availablePeligros) {
      final key = normalizeText(pel);
      if (clean.contains(key)) {
        matchedPels.add(pel);
      }
    }

    peligroKeywords.forEach((pelName, keywords) {
      for (final kw in keywords) {
        if (_containsWord(clean, normalizeText(kw))) {
          final found = availablePeligros.firstWhere(
            (p) => normalizeText(p).contains(normalizeText(pelName)) || normalizeText(pelName).contains(normalizeText(p)),
            orElse: () => pelName,
          );
          matchedPels.add(found);
          break;
        }
      }
    });

    return VoiceCatalogMatchResult(
      matchedMateriales: matchedMats.toList(),
      matchedEstructuras: matchedEsts.toList(),
      matchedPeligros: matchedPels.toList(),
      rawText: spokenText,
    );
  }

  /// Verifica si la frase contiene la palabra o subfrase como token
  static bool _containsWord(String text, String search) {
    if (text == search) return true;
    if (text.contains(search)) return true;
    final words = text.split(RegExp(r'\s+'));
    return words.contains(search);
  }
}
