import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_recognition_service.dart';

/// Botón interactivo de dictado y búsqueda por voz para cualquier campo de texto.
/// Permite ingresar datos hablando al micrófono del celular o audífonos bluetooth.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final VoiceRecognitionService? voiceService;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onFinalResult;
  final Color? activeColor;
  final Color? inactiveColor;
  final double iconSize;
  final String tooltip;
  final bool appendMode;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.voiceService,
    this.onChanged,
    this.onFinalResult,
    this.activeColor = const Color(0xFFEF4444), // Rojo pulsante al escuchar
    this.inactiveColor = const Color(0xFF38BDF8), // Cian VISTE
    this.iconSize = 20.0,
    this.tooltip = 'Dictar o buscar por voz',
    this.appendMode = false,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final VoiceRecognitionService _service;
  bool _isListening = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    if (widget.voiceService != null) {
      _service = widget.voiceService!;
    } else {
      _service = VoiceRecognitionService();
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    if (_isListening) {
      _service.stopListening();
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _service.stopListening();
      if (mounted) {
        setState(() => _isListening = false);
        _animController.stop();
        _animController.reset();
      }
      return;
    }

    HapticFeedback.selectionClick();
    final ok = await _service.initialize();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo acceder al micrófono o reconocimiento de voz.'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    _animController.repeat(reverse: true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.mic, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('🎤 Escuchando... Di el texto ahora'),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final String initialText = widget.appendMode ? widget.controller.text : '';

    await _service.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        final String newText = initialText.isNotEmpty
            ? '$initialText ${words.trim()}'
            : words.trim();

        widget.controller.text = newText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
        widget.onChanged?.call();

        if (isFinal) {
          setState(() => _isListening = false);
          _animController.stop();
          _animController.reset();
          widget.onFinalResult?.call(newText);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final scale = _isListening ? 1.0 + (_animController.value * 0.25) : 1.0;
        final color = _isListening
            ? (widget.activeColor ?? const Color(0xFFEF4444))
            : (widget.inactiveColor ?? const Color(0xFF38BDF8));

        return Transform.scale(
          scale: scale,
          child: IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: color,
              size: widget.iconSize,
            ),
            tooltip: _isListening ? 'Detener escucha' : widget.tooltip,
            onPressed: _toggleListening,
          ),
        );
      },
    );
  }
}
