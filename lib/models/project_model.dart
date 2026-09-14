//import 'dart:convert';

class ProjectModel {
  final String contacto;
  final String direccion;
  final String celular;
  final String correo;
  final String proyecto;
  final String fecha;
  final String mapa;
  final String responsable;
  final String areaSector;
  final int numFoto;
  final List<String> peligros;
  final List<String> estructuras;
  final List<String> materiales;
  final List<String> herramientas;
  final List<String> accesorios;
  final String fotoBase64;
  final String? localImagePath;

  ProjectModel({
    required this.contacto,
    required this.direccion,
    required this.celular,
    required this.correo,
    required this.proyecto,
    required this.fecha,
    required this.mapa,
    required this.responsable,
    this.areaSector = '',
    this.numFoto = 1,
    this.peligros = const [],
    this.estructuras = const [],
    this.materiales = const [],
    this.herramientas = const [],
    this.accesorios = const [],
    this.fotoBase64 = '',
    this.localImagePath,
  });

  ProjectModel copyWith({
    String? contacto,
    String? direccion,
    String? celular,
    String? correo,
    String? proyecto,
    String? fecha,
    String? mapa,
    String? responsable,
    String? areaSector,
    int? numFoto,
    List<String>? peligros,
    List<String>? estructuras,
    List<String>? materiales,
    List<String>? herramientas,
    List<String>? accesorios,
    String? fotoBase64,
    String? localImagePath,
  }) {
    return ProjectModel(
      contacto: contacto ?? this.contacto,
      direccion: direccion ?? this.direccion,
      celular: celular ?? this.celular,
      correo: correo ?? this.correo,
      proyecto: proyecto ?? this.proyecto,
      fecha: fecha ?? this.fecha,
      mapa: mapa ?? this.mapa,
      responsable: responsable ?? this.responsable,
      areaSector: areaSector ?? this.areaSector,
      numFoto: numFoto ?? this.numFoto,
      peligros: peligros ?? this.peligros,
      estructuras: estructuras ?? this.estructuras,
      materiales: materiales ?? this.materiales,
      herramientas: herramientas ?? this.herramientas,
      accesorios: accesorios ?? this.accesorios,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  Map<String, dynamic> toJson() {
    final String peligrosStr = peligros.isEmpty ? 'Ninguno' : peligros.join(', ');
    final String estructurasStr = estructuras.isEmpty ? 'N/A' : estructuras.join(', ');
    final String materialesStr = materiales.isEmpty ? 'N/A' : materiales.join(', ');
    final String herramientasStr = herramientas.isEmpty ? 'N/A' : herramientas.join(', ');
    final String accesoriosStr = accesorios.isEmpty ? 'N/A' : accesorios.join(', ');
    final String areaFinal = areaSector.trim().isEmpty ? 'Foto #$numFoto' : areaSector.trim();

    return {
      'contacto': contacto,
      'nombre': contacto,
      'direccion': direccion,
      'celular': celular,
      'correo': correo,
      'proyecto': proyecto,
      'areaSector': areaFinal,
      'area': areaFinal,
      'numFoto': numFoto,
      'fecha': fecha,
      'mapa': mapa,
      'responsable': responsable,
      'peligros': peligrosStr,
      'riesgos': peligrosStr,
      'ssoma': peligrosStr, // Compatibilidad con hojas anteriores
      'estructuras': estructurasStr,
      'materiales': materialesStr,
      'herramientas': herramientasStr,
      'accesorios': accesoriosStr,
      'fotoBase64': fotoBase64,
      'localImagePath': localImagePath ?? '',
    };
  }
}

class SheetsResponse {
  final bool isSuccess;
  final String message;

  SheetsResponse({required this.isSuccess, required this.message});
}
