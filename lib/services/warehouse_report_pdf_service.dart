import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';
import 'catalog_visual_service.dart';

class WarehouseReportPdfService {
  /// Genera el reporte especializado exclusivo para el Almacén y Pañol técnico
  /// con imágenes destacadas ("vitales") de cada herramienta requerida para la obra.
  static Future<Uint8List> generatePdf(ProjectSessionModel session) async {
    final pdf = pw.Document();

    final tools = session.getToolsWithFrequency();

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0284C7); // Sky 600
    const redBadge = PdfColor.fromInt(0xFFDC2626); // Red 600
    const yellowBadge = PdfColor.fromInt(0xFFD97706); // Amber 600
    const lightBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const borderGray = PdfColor.fromInt(0xFFCBD5E1); // Slate 300

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2.2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VIGILARTE - REPORTE DE ALMACEN Y PAÑOL DE HERRAMIENTAS',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Ficha Técnica Visual para Despacho, Control Físico y Retorno de Equipos',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8.5),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF59E0B),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'USO ALMACÉN',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderGray, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VIGILARTE Sistema de Almacén - Elaborado por Fedor Corzano',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // Tarjeta Informativa del Proyecto
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderGray),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildInfoRow('Proyecto:', session.project.proyecto),
                    ),
                    pw.Expanded(
                      child: _buildInfoRow('Responsable de Obra:', session.project.responsable.isNotEmpty ? session.project.responsable : session.project.contacto),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildInfoRow('Fecha de Salida:', session.project.fecha),
                    ),
                    pw.Expanded(
                      child: _buildInfoRow('Total Herramientas:', '${tools.length} requeridas'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Instrucciones de Almacén
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFEFF6FF),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE)),
            ),
            child: pw.Text(
              'Nota para el Pañolero: Verificar estado operativo y accesorios de cada herramienta antes del despacho. Marcar casillas al entregar y al recibir de vuelta.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF1E40AF)),
            ),
          ),
          pw.SizedBox(height: 14),

          // Título de Sección
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'HERRAMIENTAS Y EQUIPOS REQUERIDOS (CON FOTOS VITALES DE IDENTIFICACIÓN)',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${tools.length} ÍTEMS',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF38BDF8),
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Lista de Herramientas con Imágenes Vitales (Grandes y Claras)
          if (tools.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'No se registraron herramientas técnicas específicas para esta sesión.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            )
          else
            ...tools.map((entry) {
              final toolName = entry.name;
              final count = entry.count;
              final isIndispensable = entry.isIndispensable;
              final visualInfo = CatalogVisualService.getItemInfo(toolName);

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: lightBg,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // FOTO VITAL DE ALTA VISIBILIDAD (82 x 82 pt)
                    pw.Container(
                      width: 82,
                      height: 82,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(6),
                          bottomLeft: pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '[ FOTO DE\nHERRAMIENTA ]',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),

                    // DETALLE TÉCNICO Y COMERCIAL
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Nombre y Badges
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    visualInfo.commercialName.isNotEmpty
                                        ? visualInfo.commercialName
                                        : toolName,
                                    style: pw.TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: isIndispensable ? redBadge : yellowBadge,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    isIndispensable ? 'INDISPENSABLE' : 'PRIORITARIO',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),

                            // Nombre técnico de origen
                            pw.Text(
                              'Ítem Técnico: $toolName',
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                            ),
                            pw.SizedBox(height: 3),

                            // Especificación técnica de almacén
                            pw.Text(
                              'Especificación: ${visualInfo.specification}',
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                            ),
                            pw.SizedBox(height: 4),

                            // Cantidad de sectores donde se usará
                            pw.Row(
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFFE0F2FE),
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    'Requerido en $count sector(es) de la obra',
                                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF0369A1)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // CASILLAS DE CONTROL DE ALMACÉN
                    pw.Container(
                      width: 100,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(color: borderGray, width: 0.8)),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Control de Salida:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGray))),
                              pw.SizedBox(width: 4),
                              pw.Text('Entregado', style: const pw.TextStyle(fontSize: 7)),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Control de Retorno:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGray))),
                              pw.SizedBox(width: 4),
                              pw.Text('Devuelto OK', style: const pw.TextStyle(fontSize: 7)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          pw.SizedBox(height: 18),

          // FIRMAS DE CONTROL DE PAÑOL
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Entrega: Responsable de Pañol / Almacén', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Recibe: Técnico Líder de Cuadrilla', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}
