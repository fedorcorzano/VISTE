import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Helper corporativo para inserción de identidad visual VIGILARTE en reportes PDF
class PdfBrandHelper {
  static Uint8List? _cachedLogoBytes;

  /// Carga los bytes del logo oficial de VIGILARTE desde los assets o el sistema de archivos
  static Future<Uint8List?> loadLogoBytes() async {
    if (_cachedLogoBytes != null) return _cachedLogoBytes;
    try {
      final byteData = await rootBundle.load('assets/images/vigilarte_logo.png');
      if (byteData.lengthInBytes > 0) {
        _cachedLogoBytes = byteData.buffer.asUint8List();
        return _cachedLogoBytes;
      }
    } catch (_) {}

    try {
      final f = File('assets/images/vigilarte_logo.png');
      if (f.existsSync()) {
        _cachedLogoBytes = f.readAsBytesSync();
        return _cachedLogoBytes;
      }
    } catch (_) {}

    return null;
  }

  /// Retorna los bytes del logo si ya fueron cargados o están en disco
  static Uint8List? get cachedLogoBytes {
    if (_cachedLogoBytes != null) return _cachedLogoBytes;
    try {
      final f = File('assets/images/vigilarte_logo.png');
      if (f.existsSync()) {
        _cachedLogoBytes = f.readAsBytesSync();
        return _cachedLogoBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Genera el Logo corporativo oficial de VIGILARTE (con imagen oficial o fallback vectorial)
  static pw.Widget buildLogo({
    Uint8List? logoBytes,
    double? size,
    double height = 28,
    double? width,
    PdfColor primaryTextColor = const PdfColor.fromInt(0xFF0F172A),
    PdfColor secondaryTextColor = const PdfColor.fromInt(0xFF0284C7),
    bool showSubtitle = true,
  }) {
    final effectiveHeight = size ?? height;
    final bytes = logoBytes ?? cachedLogoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(
            pw.MemoryImage(bytes),
            height: effectiveHeight,
            width: width,
            fit: pw.BoxFit.contain,
          ),
          if (showSubtitle) ...[
            pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'SEGURIDAD ELECTRONICA & INFRAESTRUCTURA',
                  style: pw.TextStyle(
                    color: secondaryTextColor,
                    fontSize: (height * 0.22).clamp(5.0, 7.5),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Fallback vectorial de respaldo si la imagen PNG no está disponible
    return _buildVectorFallback(
      size: effectiveHeight,
      primaryTextColor: primaryTextColor,
      secondaryTextColor: secondaryTextColor,
      showSubtitle: showSubtitle,
    );
  }

  /// Logo oficial para carátulas ejecutivas a gran escala
  static pw.Widget buildCoverLogo({
    Uint8List? logoBytes,
    double height = 46,
  }) {
    final bytes = logoBytes ?? cachedLogoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(
            pw.MemoryImage(bytes),
            height: height,
            fit: pw.BoxFit.contain,
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'SEGURIDAD ELECTRONICA & INFRAESTRUCTURA',
                style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFF0284C7),
                  fontSize: 7.0,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'INGENIERIA | RELEVAMIENTO | GESTION DE RIESGOS',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 5.5,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _buildVectorFallback(size: height, showSubtitle: true);
  }

  /// Construye un encabezado de reporte estandarizado con el logo oficial de VIGILARTE
  static pw.Widget buildHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required PdfColor badgeColor,
    Uint8List? logoBytes,
    PdfColor accentBorderColor = const PdfColor.fromInt(0xFF0284C7),
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: accentBorderColor, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              buildLogo(logoBytes: logoBytes, height: 28, showSubtitle: false),
              pw.SizedBox(width: 10),
              pw.Container(
                height: 26,
                width: 1.5,
                color: const PdfColor.fromInt(0xFFCBD5E1),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xFF0F172A),
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      color: PdfColors.grey700,
                      fontSize: 7.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: badgeColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              badgeText,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildVectorFallback({
    double size = 32,
    PdfColor primaryTextColor = const PdfColor.fromInt(0xFF0F172A),
    PdfColor secondaryTextColor = const PdfColor.fromInt(0xFF0284C7),
    bool showSubtitle = true,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF0F172A),
            borderRadius: pw.BorderRadius.circular(size * 0.22),
            border: pw.Border.all(
              color: const PdfColor.fromInt(0xFF0284C7),
              width: 1.2,
            ),
          ),
          child: pw.Center(
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Container(
                  width: size * 0.58,
                  height: size * 0.58,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFF38BDF8),
                      width: 1.2,
                    ),
                  ),
                ),
                pw.Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF10B981),
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'V I G I L A R T E',
              style: pw.TextStyle(
                color: primaryTextColor,
                fontSize: size * 0.42,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (showSubtitle) ...[
              pw.SizedBox(height: 1),
              pw.Text(
                'SEGURIDAD ELECTRONICA & INFRAESTRUCTURA',
                style: pw.TextStyle(
                  color: secondaryTextColor,
                  fontSize: size * 0.17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
