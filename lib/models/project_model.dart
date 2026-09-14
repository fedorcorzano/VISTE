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
  final List<String> peligros;
  final List<String> estructuras;
  final List<String> materiales;
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
    this.peligros = const [],
    this.estructuras = const [],
    this.materiales = const [],
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
    List<String>? peligros,
    List<String>? estructuras,
    List<String>? materiales,
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
      peligros: peligros ?? this.peligros,
      estructuras: estructuras ?? this.estructuras,
      materiales: materiales ?? this.materiales,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  Map<String, dynamic> toJson() {
    final String peligrosStr = peligros.isEmpty ? 'Ninguno' : peligros.join(', ');
    final String estructurasStr = estructuras.isEmpty ? 'N/A' : estructuras.join(', ');
    final String materialesStr = materiales.isEmpty ? 'N/A' : materiales.join(', ');

    return {
      'contacto': contacto,
      'nombre': contacto,
      'direccion': direccion,
      'celular': celular,
      'correo': correo,
      'proyecto': proyecto,
      'fecha': fecha,
      'mapa': mapa,
      'responsable': responsable,
      'peligros': peligrosStr,
      'riesgos': peligrosStr,
      'ssoma': peligrosStr, // Compatibilidad con hojas anteriores
      'estructuras': estructurasStr,
      'materiales': materialesStr,
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
