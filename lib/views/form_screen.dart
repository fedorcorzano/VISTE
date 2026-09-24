import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/project_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import 'camera_overlay_screen.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();

  // Controladores de texto
  final TextEditingController _contactoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _celularController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _responsableController =
      TextEditingController(text: 'Fedor Corzano');
  final TextEditingController _mapaController =
      TextEditingController(text: 'Obteniendo GPS...');

  String? _selectedProyecto = TechnicalCatalogMatrix.defaultProyectos.first;
  List<String> _proyectosList =
      List<String>.from(TechnicalCatalogMatrix.defaultProyectos);
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
    _obtenerUbicacionGPS();
  }

  @override
  void dispose() {
    _contactoController.dispose();
    _direccionController.dispose();
    _celularController.dispose();
    _correoController.dispose();
    _responsableController.dispose();
    _mapaController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _mapaController.text = 'GPS desactivado';
        if (mounted) setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _mapaController.text = 'Permiso GPS denegado';
          if (mounted) setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _mapaController.text = 'Permiso GPS bloqueado';
        if (mounted) setState(() => _isGettingLocation = false);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final String coords =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      _mapaController.text = coords;
    } catch (e) {
      debugPrint('Error al capturar GPS: $e');
      if (_mapaController.text == 'Obteniendo GPS...' ||
          _mapaController.text.isEmpty) {
        _mapaController.text = '0.0, 0.0';
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _loadCatalogs() async {
    try {
      final catalogs = await _sheetsService.fetchCatalogs();
      if (mounted) {
        final incoming = catalogs['proyectos'] ?? [];
        if (incoming.isNotEmpty) {
          setState(() {
            _proyectosList = incoming;
            if (_selectedProyecto == null ||
                !_proyectosList.contains(_selectedProyecto)) {
              _selectedProyecto = _proyectosList.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos en form_screen: $e');
    }
  }

  Future<void> _avanzarACamara() async {
    if (_formKey.currentState!.validate()) {
      final String mapaGps = _mapaController.text.trim();
      final proyectoData = ProjectModel(
        contacto: _contactoController.text.trim(),
        direccion: _direccionController.text.trim().isEmpty
            ? 'Sin dirección'
            : _direccionController.text.trim(),
        celular: _celularController.text.trim().isEmpty
            ? 'N/A'
            : _celularController.text.trim(),
        correo: _correoController.text.trim().isEmpty
            ? 'N/A'
            : _correoController.text.trim(),
        proyecto: _selectedProyecto ?? 'General',
        fecha: DateTime.now().toString().split('.')[0],
        mapa: (mapaGps.isEmpty ||
                mapaGps.contains('Obteniendo') ||
                mapaGps.contains('Permiso') ||
                mapaGps.contains('desactivado'))
            ? '0.0, 0.0'
            : mapaGps,
        responsable: _responsableController.text.trim(),
        peligros: [],
        estructuras: [],
        materiales: [],
        fotoBase64: '',
      );

      // Avanzar a la siguiente pantalla (Cámara y Stickers)
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraOverlayScreen(project: proyectoData),
        ),
      );

      if (!mounted) return;

      if (resultado == true) {
        _contactoController.clear();
        _direccionController.clear();
        _celularController.clear();
        _correoController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro finalizado exitosamente.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'VISTE • Relevamiento de Información',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar catálogos de Excel',
            onPressed: _loadCatalogs,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 48.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner superior informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFF38BDF8),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paso 1: Relevamiento de Información',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Ingresa los datos del proyecto para iniciar el relevamiento fotográfico de campo.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Campo Contacto / Cliente
                _buildTextField(
                  controller: _contactoController,
                  label: 'Contacto / Cliente / Empresa',
                  hint: 'Ej. Juan Pérez o ABC SAC',
                  icon: Icons.person_outline,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'El nombre o contacto es obligatorio'
                          : null,
                ),
                const SizedBox(height: 14),

                // Campo Dirección
                _buildTextField(
                  controller: _direccionController,
                  label: 'Dirección o Ubicación de Obra',
                  hint: 'Ej. Av. Javier Prado Este 1234',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),

                // Campo Mapa (Coordenadas GPS para Excel)
                _buildTextField(
                  controller: _mapaController,
                  label: 'Coordenadas GPS (Campo Mapa en Excel)',
                  hint: 'Obteniendo GPS...',
                  icon: Icons.location_searching,
                  suffixIcon: IconButton(
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF38BDF8),
                            ),
                          )
                        : const Icon(Icons.my_location, color: Color(0xFF38BDF8)),
                    tooltip: 'Recapturar GPS',
                    onPressed: _isGettingLocation ? null : _obtenerUbicacionGPS,
                  ),
                ),
                const SizedBox(height: 14),

                // Campo Celular
                _buildTextField(
                  controller: _celularController,
                  label: 'Número de Celular',
                  hint: 'Ej. 987654321',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                // Campo Correo
                _buildTextField(
                  controller: _correoController,
                  label: 'Correo Electrónico',
                  hint: 'ejemplo@correo.com',
                  icon: Icons.alternate_email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // Campo Responsable
                _buildTextField(
                  controller: _responsableController,
                  label: 'Responsable Técnico',
                  hint: 'Nombre del inspector',
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'El responsable es obligatorio'
                          : null,
                ),
                const SizedBox(height: 14),

                // Dropdown Proyecto desde Excel
                Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF475569),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_selectedProyecto),
                          initialValue: _selectedProyecto,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Proyecto (desde Excel)',
                            labelStyle: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.work_outline,
                              color: Color(0xFF38BDF8),
                            ),
                            border: InputBorder.none,
                          ),
                          items: _proyectosList.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                p,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProyecto = val),
                        ),
                      ),
                const SizedBox(height: 30),

                // Botón Siguiente: Avanzar a Sesión de Fotos
                ElevatedButton.icon(
                  onPressed: _avanzarACamara,
                  icon: const Icon(Icons.photo_camera, size: 22, color: Color(0xFF001F2F)),
                  label: const Text(
                    'Iniciar Sesión de Fotos (Proyecto) 📸',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F2F),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE3A51A), // COLOR 02 AMARILLO VIGILARTE
                    foregroundColor: const Color(0xFF001F2F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: const Color(0xFFE3A51A).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
