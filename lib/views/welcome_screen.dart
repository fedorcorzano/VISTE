import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'form_screen.dart';
import 'project_history_screen.dart';

/// Pantalla de Bienvenida VISTEC con Tarjeta Digital de Presentación
/// Proporciones nativas sin distorsión vertical y distribución de controles:
/// [ Mis proyectos ] [ Clave debajo del QR ] [ Buscar proyectos ]
/// [             Registrar proyecto (debajo de los 3)           ]
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const String _authorizedKey = 'VGL';

  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isKeyValid = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validateKeyOnChange);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validateKeyOnChange);
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateKeyOnChange() {
    final text = _passwordController.text.trim().toUpperCase();
    final isValid = text == _authorizedKey;
    if (isValid != _isKeyValid) {
      setState(() {
        _isKeyValid = isValid;
      });
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al abrir enlace $urlString: $e');
    }
  }

  void _onRegisterProject() {
    FocusScope.of(context).unfocus();
    final input = _passwordController.text.trim().toUpperCase();

    if (input == _authorizedKey) {
      setState(() {
        _isKeyValid = true;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FormScreen()),
      );
    } else {
      _passwordFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acceso restringido. Ingrese la clave autorizada (VGL) para registrar proyectos.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onOpenHistory({bool autoFocusSearch = false}) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectHistoryScreen(autoFocusSearch: autoFocusSearch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            // Relación de aspecto nativa del diseño original (576 x 1024 = 0.5625)
            // Esto asegura que NUNCA se estire verticalmente en pantallas 20:9 o 21:9
            const double originalAspect = 576.0 / 1024.0;
            final double naturalContentHeight = screenWidth / originalAspect;

            // Si la pantalla es más alta que la proporción 9:16 (ej. pantallas 20:9 de celulares modernos),
            // centramos el lienzo verticalmente sobre fondo blanco puro
            final double totalContainerHeight = math.max(constraints.maxHeight, naturalContentHeight);
            final double verticalOffset = (totalContainerHeight > naturalContentHeight)
                ? (totalContainerHeight - naturalContentHeight) / 2
                : 0.0;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Container(
                width: screenWidth,
                height: totalContainerHeight,
                color: Colors.white,
                child: Stack(
                  children: [
                    // 1. Imagen de fondo renderizada en su proporción exacta (cero estiramiento)
                    Positioned(
                      top: verticalOffset,
                      left: 0,
                      width: screenWidth,
                      height: naturalContentHeight,
                      child: Image.asset(
                        'assets/images/welcome_bg.png',
                        width: screenWidth,
                        height: naturalContentHeight,
                        fit: BoxFit.fill, // Proporción garantizada por el contenedor
                      ),
                    ),

                    // 2. Zona interactiva sobre el código QR de WhatsApp
                    Positioned(
                      top: verticalOffset + (naturalContentHeight * 0.14),
                      left: screenWidth * 0.22,
                      width: screenWidth * 0.56,
                      height: naturalContentHeight * 0.21,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: const Color(0xFF25D366).withValues(alpha: 0.25),
                          onTap: () => _launchExternalUrl(
                            'https://wa.me/51955281424?text=Hola%20Fedor,%20te%20contacto%20desde%20la%20app%20VISTEC',
                          ),
                        ),
                      ),
                    ),

                    // 3. Distribución de controles en la zona blanca intermedia
                    // a) Mis proyectos (Izquierda) | b) Clave debajo del QR (Centro) | c) Buscar proyectos (Derecha)
                    // d) Registrar proyecto (Debajo de los 3 anteriores)
                    Positioned(
                      top: verticalOffset + (naturalContentHeight * 0.366),
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Fila superior: Mis proyectos | Clave | Buscar proyectos (misma altura: 46dp)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // a) Botón "Mis proyectos" a la izquierda
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A), // Slate 900
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                      elevation: 2,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _onOpenHistory(autoFocusSearch: false),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.folder_shared_outlined, size: 16, color: Color(0xFF38BDF8)),
                                        SizedBox(height: 2),
                                        Text(
                                          'Mis proyectos',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // b) Campo de Clave en el centro (directamente debajo del QR)
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  height: 46,
                                  child: TextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    obscureText: _obscurePassword,
                                    textCapitalization: TextCapitalization.characters,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: '••••••••',
                                      hintStyle: const TextStyle(
                                        color: Colors.black26,
                                        fontSize: 13,
                                        letterSpacing: 2.0,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                      prefixIcon: Icon(
                                        _isKeyValid ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                        color: _isKeyValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        size: 17,
                                      ),
                                      suffixIcon: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(maxWidth: 26),
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: Colors.black38,
                                          size: 15,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: _isKeyValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          width: 1.8,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: _isKeyValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          width: 2.2,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) => _onRegisterProject(),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // c) Botón "Buscar proyectos" a la derecha
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      foregroundColor: const Color(0xFF1E293B),
                                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _onOpenHistory(autoFocusSearch: true),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_rounded, size: 16, color: Color(0xFF475569)),
                                        SizedBox(height: 2),
                                        Text(
                                          'Buscar proyectos',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // d) Botón "Registrar proyecto" debajo de los primeros 3
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7), // Blue Vigilarte
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                              label: const Text(
                                'Registrar proyecto',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              onPressed: _onRegisterProject,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. Zonas interactivas táctiles sobre la tarjeta de presentación de Fedor Corzano
                    // 4.1 Correo: fedor.corzano@vigilarte.pe
                    Positioned(
                      top: verticalOffset + (naturalContentHeight * 0.81),
                      left: 16,
                      width: screenWidth * 0.58,
                      height: 38,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          splashColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          onTap: () => _launchExternalUrl('mailto:fedor.corzano@vigilarte.pe'),
                        ),
                      ),
                    ),

                    // 4.2 Celular: 955281424
                    Positioned(
                      top: verticalOffset + (naturalContentHeight * 0.875),
                      left: 16,
                      width: screenWidth * 0.58,
                      height: 38,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          splashColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          onTap: () => _launchExternalUrl('tel:+51955281424'),
                        ),
                      ),
                    ),

                    // 4.3 Web: www.vigilarte.pe
                    Positioned(
                      top: verticalOffset + (naturalContentHeight * 0.94),
                      left: 16,
                      width: screenWidth * 0.58,
                      height: 38,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          splashColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          onTap: () => _launchExternalUrl('https://www.vigilarte.pe'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
