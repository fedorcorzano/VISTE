import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Helper corporativo para inserción de identidad visual VIGILARTE en reportes PDF
class PdfBrandHelper {
  /// Genera el Logo corporativo de VIGILARTE en alta fidelidad vectorial
  static pw.Widget buildLogo({
    double size = 32,
    PdfColor primaryTextColor = const PdfColor.fromInt(0xFF0F172A),
    PdfColor secondaryTextColor = const PdfColor.fromInt(0xFF0284C7),
    bool showSubtitle = true,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Emblema con lente de seguridad
        pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF0F172A), // Slate 900
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
                    color: PdfColor.fromInt(0xFF10B981), // Emerald 500
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

  /// Construye un encabezado de reporte estandarizado con el logo de VIGILARTE
  static pw.Widget buildHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required PdfColor badgeColor,
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
              buildLogo(size: 28, showSubtitle: false),
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
}
