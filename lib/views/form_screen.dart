import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/project_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import '../widgets/voice_input_button.dart';
import 'field_photo_capture_screen.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final MapController _mapController = MapController();

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
  String _selectedClasificacion = 'Comercial';
  List<String> _proyectosList =
      List<String>.from(TechnicalCatalogMatrix.defaultProyectos);
  bool _isGettingLocation = false;
  double? _latitude;
  double? _longitude;
  double? _deviceGpsLat;
  double? _deviceGpsLng;

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
    _mapController.dispose();
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
      _latitude = position.latitude;
      _longitude = position.longitude;
      _deviceGpsLat = position.latitude;
      _deviceGpsLng = position.longitude;

      if (mounted) {
        setState(() {});
        try {
          _mapController.move(LatLng(position.latitude, position.longitude), 16.5);
        } catch (_) {}
      }
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
        clasificacion: _selectedClasificacion,
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

      // Avanzar a Pantalla 3: Captura Rápida en Campo
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FieldPhotoCaptureScreen(project: proyectoData),
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
      // Sin AppBar para máxima amplitud visual
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Gesto: Volver a la pantalla anterior deslizando de derecha a izquierda
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                (details.primaryVelocity! < -250 || details.primaryVelocity! > 250)) {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            }
          },
          child: RefreshIndicator(
            color: const Color(0xFF38BDF8),
            backgroundColor: const Color(0xFF1E293B),
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await Future.wait([
                _loadCatalogs(),
                _obtenerUbicacionGPS(),
              ]);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Catálogos y GPS recargados'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Campo Contacto / Cliente
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
                    const SizedBox(height: 10),

                    // 2. Campo Dirección
                    _buildTextField(
                      controller: _direccionController,
                      label: 'Dirección o Ubicación de Obra',
                      hint: 'Ej. Av. Javier Prado Este 1234',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 10),

                    // 3. Campo Celular (en fila independiente)
                    _buildTextField(
                      controller: _celularController,
                      label: 'Celular',
                      hint: 'Ej. 987654321',
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),

                    // 4. Campo Correo (en fila independiente para correos largos)
                    _buildTextField(
                      controller: _correoController,
                      label: 'Correo Electrónico',
                      hint: 'Ej. contacto.cliente@empresa-peru.com.pe',
                      icon: Icons.alternate_email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    // 5. Responsable Técnico
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
                    const SizedBox(height: 10),

                    // 6. Clasificación del Proyecto (Iconos en fila bien espaciada)
                    _buildClasificacionSelector(),
                    const SizedBox(height: 10),

                    // 7. Dropdown Proyecto desde Excel
                    _buildProjectDropdown(),
                    const SizedBox(height: 14),

                    // 8. Mapa 2D Interactivo: Del mismo ancho que los cuadros de texto y altura compacta
                    _buildInteractive2DMap(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClasificacionSelector() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: TechnicalCatalogMatrix.clasificacionesProyectos.map((clasif) {
          final bool isSelected = _selectedClasificacion == clasif;
          IconData iconData;
          switch (clasif) {
            case 'Residencial':
              iconData = Icons.home_outlined;
              break;
            case 'Corporativo':
              iconData = Icons.business_outlined;
              break;
            case 'Industrial':
              iconData = Icons.factory_outlined;
              break;
            case 'Comercial':
            default:
              iconData = Icons.storefront_outlined;
              break;
          }

          return Tooltip(
            message: clasif,
            child: InkWell(
              onTap: () => setState(() => _selectedClasificacion = clasif),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: isSelected ? const Color(0xFF001F2F) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey(_selectedProyecto),
          value: _selectedProyecto,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8), size: 22),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          hint: const Row(
            children: [
              Icon(Icons.work_outline, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 8),
              Text(
                'Seleccionar Proyecto',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
          items: _proyectosList.map((p) {
            return DropdownMenuItem<String>(
              value: p,
              child: Row(
                children: [
                  const Icon(Icons.work_outline, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedProyecto = val),
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
    bool enableVoice = true,
  }) {
    Widget? effectiveSuffixIcon = suffixIcon;
    if (enableVoice && !readOnly) {
      final voiceBtn = VoiceInputButton(controller: controller);
      if (suffixIcon != null) {
        effectiveSuffixIcon = Row(
          mainAxisSize: MainAxisSize.min,
          children: [suffixIcon, voiceBtn],
        );
      } else {
        effectiveSuffixIcon = voiceBtn;
      }
    }

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 12.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        suffixIcon: effectiveSuffixIcon,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildInteractive2DMap() {
    final LatLng centerLatLng = LatLng(
      _latitude ?? _deviceGpsLat ?? -12.046374,
      _longitude ?? _deviceGpsLng ?? -77.042793,
    );

    return Container(
      height: 220,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mapa Interactivo 2D con flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerLatLng,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _latitude = camera.center.latitude;
                  _longitude = camera.center.longitude;
                  _mapaController.text =
                      '${camera.center.latitude.toStringAsFixed(6)}, ${camera.center.longitude.toStringAsFixed(6)}';
                  setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vigilarte.vistec_app',
                maxZoom: 19,
              ),
              // Marcador de la posición GPS del dispositivo (Punto azul con halo)
              if (_deviceGpsLat != null && _deviceGpsLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_deviceGpsLat!, _deviceGpsLng!),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Pin centrado estilo GPS para ubicar y referenciar el proyecto
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFEF4444),
                        size: 38,
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Badge inferior izquierdo con coordenadas seleccionadas
          Positioned(
            left: 12,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore,
                    size: 14,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    (_latitude != null && _longitude != null)
                        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                        : _mapaController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controles de Mapa en la esquina superior derecha: Centrar GPS y Zoom +/-
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Centrar Mapa
                Material(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: Colors.black54,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (_deviceGpsLat != null && _deviceGpsLng != null) {
                        _mapController.move(
                          LatLng(_deviceGpsLat!, _deviceGpsLng!),
                          16.5,
                        );
                        setState(() {
                          _latitude = _deviceGpsLat;
                          _longitude = _deviceGpsLng;
                          _mapaController.text =
                              '${_deviceGpsLat!.toStringAsFixed(6)}, ${_deviceGpsLng!.toStringAsFixed(6)}';
                        });
                      } else {
                        _obtenerUbicacionGPS();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: _isGettingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF38BDF8),
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                              size: 20,
                              color: Color(0xFF38BDF8),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botones de Zoom +/-
                Material(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  elevation: 4,
                  shadowColor: Colors.black54,
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        onTap: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom + 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.add, size: 18, color: Colors.white),
                        ),
                      ),
                      Container(height: 1, width: 22, color: const Color(0xFF334155)),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                        onTap: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom - 1);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.remove, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón Iniciar sesión de fotos: ícono de cámara fotográfica simplemente
          Positioned(
            bottom: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _avanzarACamara,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3A51A), // COLOR 02 AMARILLO VIGILARTE
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE3A51A).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.photo_camera,
                      size: 28,
                      color: Color(0xFF001F2F),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

