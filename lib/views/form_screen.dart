import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/project_model.dart';
import '../models/sticker_model.dart';
import '../services/google_sheets_service.dart';
import '../services/technical_catalog_icons.dart';
import '../widgets/voice_input_button.dart';
import 'field_photo_capture_screen.dart';

enum _HudFieldId {
  contacto,
  direccion,
  celular,
  correo,
  responsable,
  clasificacion,
  sistema,
}

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  static const Color _vigilarteYellow = Color(0xFFE3A51A);
  static const Color _hudDarkBg = Color(0xFF0F172A);
  static const Color _hudSurface = Color(0xFF1E293B);
  static const Color _hudCyan = Color(0xFF38BDF8);
  static const Color _hudGreen = Color(0xFF10B981);

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

  // FocusNodes para activar automáticamente el teclado al desplegar un botón HUD
  final Map<_HudFieldId, FocusNode> _focusNodes = {
    _HudFieldId.contacto: FocusNode(),
    _HudFieldId.direccion: FocusNode(),
    _HudFieldId.celular: FocusNode(),
    _HudFieldId.correo: FocusNode(),
    _HudFieldId.responsable: FocusNode(),
  };

  _HudFieldId? _activeField;
  String? _contactoError;
  String? _responsableError;

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

    for (final c in [
      _contactoController,
      _direccionController,
      _celularController,
      _correoController,
      _responsableController,
    ]) {
      c.addListener(_onFieldTextChanged);
    }
  }

  void _onFieldTextChanged() {
    if (!mounted) return;
    if (_contactoError != null && _contactoController.text.trim().isNotEmpty) {
      _contactoError = null;
    }
    if (_responsableError != null &&
        _responsableController.text.trim().isNotEmpty) {
      _responsableError = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _contactoController,
      _direccionController,
      _celularController,
      _correoController,
      _responsableController,
    ]) {
      c.removeListener(_onFieldTextChanged);
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _contactoController.dispose();
    _direccionController.dispose();
    _celularController.dispose();
    _correoController.dispose();
    _responsableController.dispose();
    _mapaController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _toggleHudField(_HudFieldId fieldId) {
    HapticFeedback.selectionClick();
    if (_activeField == fieldId) {
      FocusScope.of(context).unfocus();
      setState(() => _activeField = null);
    } else {
      setState(() => _activeField = fieldId);
      final focusNode = _focusNodes[fieldId];
      if (focusNode != null) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _activeField == fieldId) {
            focusNode.requestFocus();
          }
        });
      } else {
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _collapseActiveHudField() {
    if (_activeField != null) {
      FocusScope.of(context).unfocus();
      setState(() => _activeField = null);
    }
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
          _mapController.move(
              LatLng(position.latitude, position.longitude), 16.5);
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

  bool _validateFormAndExpandErrors() {
    _contactoError = _contactoController.text.trim().isEmpty
        ? 'El nombre o contacto es obligatorio'
        : null;
    _responsableError = _responsableController.text.trim().isEmpty
        ? 'El responsable es obligatorio'
        : null;

    if (_contactoError != null) {
      setState(() => _activeField = _HudFieldId.contacto);
      _focusNodes[_HudFieldId.contacto]?.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_contactoError!),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (_responsableError != null) {
      setState(() => _activeField = _HudFieldId.responsable);
      _focusNodes[_HudFieldId.responsable]?.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_responsableError!),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _avanzarACamara() async {
    if (!_validateFormAndExpandErrors()) return;

    FocusScope.of(context).unfocus();
    setState(() => _activeField = null);

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
          backgroundColor: _hudGreen,
        ),
      );
    }
  }

  IconData _getClasificacionIcon(String clasif) {
    switch (clasif) {
      case 'Residencial':
        return Icons.home_outlined;
      case 'Corporativo':
        return Icons.business_outlined;
      case 'Industrial':
        return Icons.factory_outlined;
      case 'Comercial':
      default:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double expandedHudWidth =
        (screenWidth - 88).clamp(240.0, 380.0);

    return Scaffold(
      // 1. Fondo amarillo oficial #E3A51A en la segunda pantalla
      backgroundColor: _vigilarteYellow,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(6.0),
          color: _vigilarteYellow,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Form(
              key: _formKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 2. El mapa ocupa todo el tamaño de la pantalla
                  _buildFullScreenInteractiveMap(),

                  // 3. Columna izquierda de botones HUD animados (izquierda a derecha)
                  Positioned(
                    top: 12,
                    left: 12,
                    bottom: 72,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAnimatedHudTextField(
                            fieldId: _HudFieldId.contacto,
                            controller: _contactoController,
                            label: 'Contacto / Cliente / Empresa',
                            hint: 'Ej. Juan Pérez o ABC SAC',
                            icon: Icons.person_outline,
                            expandedWidth: expandedHudWidth,
                            errorText: _contactoError,
                            isRequired: true,
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedHudTextField(
                            fieldId: _HudFieldId.direccion,
                            controller: _direccionController,
                            label: 'Dirección o Ubicación de Obra',
                            hint: 'Ej. Av. Javier Prado Este 1234',
                            icon: Icons.location_on_outlined,
                            expandedWidth: expandedHudWidth,
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedHudTextField(
                            fieldId: _HudFieldId.celular,
                            controller: _celularController,
                            label: 'Celular',
                            hint: 'Ej. 987654321',
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            expandedWidth: expandedHudWidth,
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedHudTextField(
                            fieldId: _HudFieldId.correo,
                            controller: _correoController,
                            label: 'Correo Electrónico',
                            hint: 'Ej. cliente@empresa.com.pe',
                            icon: Icons.alternate_email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            expandedWidth: expandedHudWidth,
                          ),
                          const SizedBox(height: 10),
                          _buildAnimatedHudTextField(
                            fieldId: _HudFieldId.responsable,
                            controller: _responsableController,
                            label: 'Responsable Técnico',
                            hint: 'Nombre del inspector',
                            icon: Icons.badge_outlined,
                            expandedWidth: expandedHudWidth,
                            errorText: _responsableError,
                            isRequired: true,
                          ),
                          const SizedBox(height: 10),
                          // 6. Clasificación del Proyecto estilo HUD
                          _buildAnimatedHudClasificacion(expandedHudWidth),
                          const SizedBox(height: 10),
                          // 7. Tipo de Sistema a Instalar con ícono representativo estilo HUD
                          _buildAnimatedHudSistemaDropdown(expandedHudWidth),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botón HUD animado para campos de texto:
  /// Normalmente muestra solo su ícono identificativo; al seleccionarlo se despliega
  /// animadamente de izquierda a derecha permitiendo escritura o dictado por voz.
  Widget _buildAnimatedHudTextField({
    required _HudFieldId fieldId,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required double expandedWidth,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    bool isRequired = false,
  }) {
    final bool isExpanded = _activeField == fieldId;
    final bool hasValue = controller.text.trim().isNotEmpty;
    final bool hasError = errorText != null;

    final Color borderColor = hasError
        ? Colors.redAccent
        : isExpanded
            ? _vigilarteYellow
            : hasValue
                ? _hudGreen.withValues(alpha: 0.85)
                : _hudCyan.withValues(alpha: 0.55);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: isExpanded ? expandedWidth : 48.0,
      height: isExpanded ? 54.0 : 48.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _hudDarkBg.withValues(alpha: isExpanded ? 0.95 : 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: isExpanded ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpanded ? _vigilarteYellow : Colors.black)
                .withValues(alpha: isExpanded ? 0.35 : 0.45),
            blurRadius: isExpanded ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isExpanded
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: expandedWidth - 4,
                height: 50,
                child: Row(
                  children: [
                    // Botón de ícono izquierdo (permite plegar el HUD)
                    InkWell(
                      onTap: () => _toggleHudField(fieldId),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          color: _vigilarteYellow,
                          size: 20,
                        ),
                      ),
                    ),
                    // Campo de escritura animado
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        focusNode: _focusNodes[fieldId],
                        keyboardType: keyboardType,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _collapseActiveHudField(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: label,
                          labelStyle: TextStyle(
                            color: hasError ? Colors.redAccent : _vigilarteYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: hint,
                          hintStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    // Botón de dictado por voz integrado en el HUD desplegado
                    VoiceInputButton(
                      controller: controller,
                      iconSize: 19,
                      inactiveColor: _hudCyan,
                      activeColor: const Color(0xFFEF4444),
                    ),
                    // Botón para confirmar/cerrar el HUD
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Confirmar',
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: _hudGreen,
                        size: 19,
                      ),
                      onPressed: _collapseActiveHudField,
                    ),
                  ],
                ),
              ),
            )
          : Tooltip(
              message: hasValue ? '$label: ${controller.text}' : label,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleHudField(fieldId),
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        icon,
                        color: hasValue ? _vigilarteYellow : Colors.white,
                        size: 21,
                      ),
                      // Indicador de estado (punto verde si ya tiene dato, ámbar si es obligatorio vacío)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasError
                                ? Colors.redAccent
                                : hasValue
                                    ? _hudGreen
                                    : isRequired
                                        ? _vigilarteYellow
                                        : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Botón HUD animado para Clasificación del Proyecto (Residencial, Comercial, Corporativo, Industrial)
  Widget _buildAnimatedHudClasificacion(double expandedWidth) {
    final bool isExpanded = _activeField == _HudFieldId.clasificacion;
    final IconData activeIcon = _getClasificacionIcon(_selectedClasificacion);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: isExpanded ? expandedWidth : 48.0,
      height: isExpanded ? 54.0 : 48.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _hudDarkBg.withValues(alpha: isExpanded ? 0.95 : 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpanded ? _vigilarteYellow : _hudGreen.withValues(alpha: 0.85),
          width: isExpanded ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpanded ? _vigilarteYellow : Colors.black)
                .withValues(alpha: isExpanded ? 0.35 : 0.45),
            blurRadius: isExpanded ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isExpanded
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: expandedWidth - 4,
                height: 50,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleHudField(_HudFieldId.clasificacion),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          activeIcon,
                          color: _vigilarteYellow,
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: TechnicalCatalogMatrix.clasificacionesProyectos
                            .map((clasif) {
                          final bool isSelected =
                              _selectedClasificacion == clasif;
                          final IconData itemIcon =
                              _getClasificacionIcon(clasif);

                          return Tooltip(
                            message: clasif,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedClasificacion = clasif;
                                  _activeField = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _vigilarteYellow
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      itemIcon,
                                      size: 17,
                                      color: isSelected
                                          ? const Color(0xFF001F2F)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        clasif,
                                        style: const TextStyle(
                                          color: Color(0xFF001F2F),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Tooltip(
              message: 'Clasificación: $_selectedClasificacion',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleHudField(_HudFieldId.clasificacion),
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        activeIcon,
                        color: _vigilarteYellow,
                        size: 21,
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _hudGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// 4. Botón HUD animado para el Tipo de Sistema a Instalar con ícono representativo para cada sistema
  Widget _buildAnimatedHudSistemaDropdown(double expandedWidth) {
    final bool isExpanded = _activeField == _HudFieldId.sistema;
    final IconData systemIcon =
        TechnicalCatalogIcons.getProjectSystemIcon(_selectedProyecto);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: isExpanded ? expandedWidth : 48.0,
      height: isExpanded ? 54.0 : 48.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _hudDarkBg.withValues(alpha: isExpanded ? 0.95 : 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpanded ? _vigilarteYellow : _hudGreen.withValues(alpha: 0.85),
          width: isExpanded ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpanded ? _vigilarteYellow : Colors.black)
                .withValues(alpha: isExpanded ? 0.35 : 0.45),
            blurRadius: isExpanded ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isExpanded
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: expandedWidth - 4,
                height: 50,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleHudField(_HudFieldId.sistema),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          systemIcon,
                          color: _vigilarteYellow,
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: ValueKey(_selectedProyecto),
                          value: _selectedProyecto,
                          isExpanded: true,
                          isDense: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: _vigilarteYellow,
                            size: 22,
                          ),
                          dropdownColor: _hudSurface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _proyectosList.map((sistema) {
                            final itemIcon =
                                TechnicalCatalogIcons.getProjectSystemIcon(
                                    sistema);
                            return DropdownMenuItem<String>(
                              value: sistema,
                              child: Row(
                                children: [
                                  Icon(
                                    itemIcon,
                                    color: _vigilarteYellow,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sistema,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedProyecto = val;
                              _activeField = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            )
          : Tooltip(
              message: 'Sistema: ${_selectedProyecto ?? "Seleccionar"}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleHudField(_HudFieldId.sistema),
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        systemIcon,
                        color: _vigilarteYellow,
                        size: 21,
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _hudGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFullScreenInteractiveMap() {
    final LatLng centerLatLng = LatLng(
      _latitude ?? _deviceGpsLat ?? -12.046374,
      _longitude ?? _deviceGpsLng ?? -77.042793,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        // Mapa Interactivo 2D a pantalla completa
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
            onTap: (_, _) => _collapseActiveHudField(),
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
              urlTemplate:
                  'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=es',
              userAgentPackageName: 'com.vigilarte.vistec_app',
              maxZoom: 20,
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
                        color: _hudCyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: _hudCyan.withValues(alpha: 0.6),
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

        // Badge inferior izquierdo con coordenadas seleccionadas y botón volver
        Positioned(
          left: 12,
          bottom: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón compacto para regresar a la pantalla de inicio
              Material(
                color: _hudDarkBg.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: _vigilarteYellow,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _hudDarkBg.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _vigilarteYellow.withValues(alpha: 0.55),
                    width: 1.0,
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
                      color: _vigilarteYellow,
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
            ],
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
                color: _hudDarkBg.withValues(alpha: 0.88),
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
                              color: _vigilarteYellow,
                            ),
                          )
                        : const Icon(
                            Icons.my_location,
                            size: 20,
                            color: _vigilarteYellow,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Botones de Zoom +/-
              Material(
                color: _hudDarkBg.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
                elevation: 4,
                shadowColor: Colors.black54,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(
                            _mapController.camera.center, currentZoom + 1);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.add, size: 18, color: Colors.white),
                      ),
                    ),
                    Container(
                        height: 1, width: 22, color: const Color(0xFF334155)),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(
                            _mapController.camera.center, currentZoom - 1);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child:
                            Icon(Icons.remove, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Botón Iniciar sesión de fotos: ícono de cámara fotográfica en esquina inferior derecha
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
                  color: _vigilarteYellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _vigilarteYellow.withValues(alpha: 0.5),
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
    );
  }
}
