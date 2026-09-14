import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';
import 'catalog_visual_service.dart';

class InternalReportPdfService {
  /// Genera el documento PDF para uso interno (Cotizaciones, Compras y Almacén)
  static Future<Uint8List> generatePdf(ProjectSessionModel session) async {
    final pdf = pw.Document();

    final materials = session.getMaterialsWithFrequency();
    final tools = session.getToolsWithFrequency();
    final accessories = session.getConsolidatedAccessories();

    // Paleta de colores PDF corporativa
    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0284C7); // Sky 600
    const redBadge = PdfColor.fromInt(0xFFDC2626); // Red 600
    const yellowBadge = PdfColor.fromInt(0xFFD97706); // Amber 600
    const greenBadge = PdfColor.fromInt(0xFF16A34A); // Green 600
    const lightBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const borderGray = PdfColor.fromInt(0xFFE2E8F0); // Slate 200

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VIGILARTE - REPORTE INTERNO DE COMPRAS Y LOGISTICA',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Lista de Materiales y Herramientas Priorizadas para Cotizacion en Obra',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFEF4444),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'USO INTERNO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
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
                  'VIGILARTE Sistema de Gestion de Evidencias - Elaborado por Fedor Corzano',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                ),
                pw.Text(
                  'Pagina ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // 1. Tarjeta de Datos del Proyecto
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderGray),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Proyecto:', session.project.proyecto),
                      pw.SizedBox(height: 4),
                      _buildInfoRow('Cliente / Contacto:', session.project.contacto),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Fecha de relevamiento:', session.project.fecha),
                      pw.SizedBox(height: 4),
                      _buildInfoRow('Total Fotos en Sesión:', '${session.totalPhotos} fotografías'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 2. Resumen Métrico de Criticidad
          pw.Row(
            children: [
              _buildMetricCard(
                'Herramientas Críticas',
                '${tools.where((t) => t.isIndispensable).length}',
                'Indispensables en varias fotos',
                redBadge,
              ),
              pw.SizedBox(width: 10),
              _buildMetricCard(
                'Materiales Críticos',
                '${materials.where((m) => m.isIndispensable).length}',
                'Materiales de alta frecuencia',
                accentColor,
              ),
              pw.SizedBox(width: 10),
              _buildMetricCard(
                'Accesorios Deducidos',
                '${accessories.length}',
                'Uniones, cajas y abrazaderas',
                greenBadge,
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // 3. Sección de Herramientas
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '1. HERRAMIENTAS Y EQUIPOS PRIORIZADOS PARA LA OBRA',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: borderGray, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2), // Herramienta
              1: pw.FlexColumnWidth(1.2), // Criticidad / Frecuencia
              2: pw.FlexColumnWidth(1.6), // Sectores
              3: pw.FlexColumnWidth(3.0), // Especificación comercial para compra
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightBg),
                children: [
                  _buildHeaderCell('Herramienta Requerida'),
                  _buildHeaderCell('Frecuencia / Prioridad'),
                  _buildHeaderCell('Sectores / Áreas'),
                  _buildHeaderCell('Especificación Comercial para Compra / Pañol'),
                ],
              ),
              ...tools.map((t) {
                final visual = CatalogVisualService.getItemInfo(t.name, isMaterial: false);
                final isCrit = t.isIndispensable;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            t.name,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            'Comercial: ${visual.commercialName}',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: isCrit ? redBadge : yellowBadge,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              isCrit ? 'INDISPENSABLE' : 'PRIORITARIO',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            t.frequencyDescription,
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        t.areas.isEmpty ? 'General' : t.areas.join(', '),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        visual.specification,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // 4. Sección de Materiales
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '2. MATERIALES DE CANALIZACIÓN Y ESTRUCTURA',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: borderGray, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightBg),
                children: [
                  _buildHeaderCell('Material'),
                  _buildHeaderCell('Frecuencia / Prioridad'),
                  _buildHeaderCell('Sectores Detectados'),
                  _buildHeaderCell('Especificación de Compra Sugerida'),
                ],
              ),
              ...materials.map((m) {
                final visual = CatalogVisualService.getItemInfo(m.name, isMaterial: true);
                final isCrit = m.isIndispensable;
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            m.name,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            visual.category,
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: isCrit ? accentColor : greenBadge,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              isCrit ? 'INDISPENSABLE' : 'PRIORITARIO',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            m.frequencyDescription,
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        m.areas.isEmpty ? 'General' : m.areas.join(', '),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        visual.specification,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // 5. Sección de Accesorios y Consumibles Deducidos
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '3. ACCESORIOS Y CONSUMIBLES DEDUCIDOS PARA MONTAJE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: accessories.map((acc) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderGray),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 5,
                      decoration: const pw.BoxDecoration(
                        color: greenBadge,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      acc,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                    ),
                  ],
                ),
              );
            }).toList(),
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
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCard(String label, String value, String subtitle, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
  }
}
