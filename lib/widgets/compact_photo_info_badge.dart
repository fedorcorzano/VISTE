import 'package:flutter/material.dart';

/// Cuadro de texto ultra-compacto que aparece impreso en las fotografías técnicas (Ficha Técnica).
/// 
/// Campos mostrados (Req. 1):
/// 1. Tipo de sistema (servicio)
/// 2. Nombre del contacto del cliente
/// 3. Nombre del ambiente (cada foto corresponde a un ambiente)
/// 4. Fecha y hora
/// 5. Desarrollado por: Fedor Corzano
/// * El GPS ha sido retirado explícitamente porque se gestiona en Excel.
/// * Altura y espacios optimizados al mínimo para no obstaculizar la fotografía.
class CompactPhotoInfoBadge extends StatelessWidget {
  final String proyecto;
  final String contacto;
  final String ambiente;
  final String? fecha;
  final int? photoNumber;

  const CompactPhotoInfoBadge({
    super.key,
    required this.proyecto,
    required this.contacto,
    required this.ambiente,
    this.fecha,
    this.photoNumber,
  });

  String _formatDateTime() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final currentTime = '$h:$min';

    if (fecha != null && fecha!.trim().isNotEmpty) {
      final f = fecha!.trim();
      return f.contains(':') ? f : '$f $currentTime';
    }
    return '$d/$m/$y $currentTime';
  }

  @override
  Widget build(BuildContext context) {
    final String cleanProyecto = proyecto.trim().isEmpty ? 'SISTEMA' : proyecto.trim().toUpperCase();
    final String cleanContacto = contacto.trim().isEmpty ? 'CLIENTE' : contacto.trim();
    final String cleanAmbiente = ambiente.trim().isEmpty
        ? (photoNumber != null ? 'Ambiente #$photoNumber' : 'General')
        : ambiente.trim();
    final String dateTimeStr = _formatDateTime();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: Sistema y Ambiente
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified,
                color: Color(0xFF38BDF8),
                size: 8.5,
              ),
              const SizedBox(width: 3),
              Text(
                'Sistema: $cleanProyecto',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 7.2,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              const Text(
                ' • ',
                style: TextStyle(color: Colors.white38, fontSize: 7.0, height: 1.1),
              ),
              Flexible(
                child: Text(
                  'Ambiente: $cleanAmbiente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.2,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (photoNumber != null) ...[
                const Text(
                  ' • ',
                  style: TextStyle(color: Colors.white38, fontSize: 7.0, height: 1.1),
                ),
                Text(
                  'Foto #$photoNumber',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 7.0,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 1.5),

          // Fila 2: Contacto Cliente, Fecha/Hora y Desarrollador
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cliente: $cleanContacto',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 6.8,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                ' | ',
                style: TextStyle(color: Colors.white38, fontSize: 6.5, height: 1.1),
              ),
              Text(
                '📅 $dateTimeStr',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 6.8,
                  height: 1.1,
                ),
              ),
              const Text(
                ' | ',
                style: TextStyle(color: Colors.white38, fontSize: 6.5, height: 1.1),
              ),
              const Text(
                'Desarrollado por: Fedor Corzano',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 6.8,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
