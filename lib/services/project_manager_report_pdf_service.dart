import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';

class ProjectManagerReportPdfService {
  /// Genera el reporte técnico integral para el Gestor de Proyectos de VIGILARTE
  static Future<Uint8List> generatePdf(ProjectSessionModel session) async {
    final pdf = pw.Document();

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0284C7); // Sky 600
    const warningColor = PdfColor.fromInt(0xFFB45309); // Amber 700
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderGray = PdfColor.fromInt(0xFFE2E8F0);

    final hazardsByArea = session.getHazardsByArea();
    final allHazards = session.getConsolidatedHazards();

    // 1. PÁGINA DE RESUMEN EJECUTIVO Y METADATA DEL PROYECTO
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
                      'VIGILARTE - REPORTE DE GESTOR DE PROYECTOS (METADATA)',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Informe Tecnico Integral de Obra, Canalizaciones y Validacion de Campo',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8.5),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF0284C7),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'GESTOR PROYECTO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
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
                  'VIGILARTE - Gestor de Proyectos - Desarrollado por Fedor Corzano',
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
          // Tarjeta de Datos del Proyecto y Cliente
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
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
                      child: _buildInfoRow('Cliente / Contacto:', session.project.contacto),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildInfoRow('Fecha:', session.project.fecha),
                    ),
                    pw.Expanded(
                      child: _buildInfoRow('Ubicacion GPS:', session.project.mapa.isNotEmpty ? session.project.mapa : 'Registrada en app'),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildInfoRow('Responsable de Campo:', session.project.responsable),
                    ),
                    pw.Expanded(
                      child: _buildInfoRow('Total Fotos Relevadas:', '${session.totalPhotos} fotos tecnicas'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // SECCIÓN 1: CONDICIONES DE SEGURIDAD SST IDENTIFICADAS
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '1. CONDICIONES DE SEGURIDAD Y PREVENCION (SST)',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          if (allHazards.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFECFDF5),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFA7F3D0)),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    '[OK] No se identificaron peligros criticos en los sectores relevados.',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF065F46)),
                  ),
                ],
              ),
            )
          else ...[
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.8),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(3.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildHeaderCell('Sector / Area'),
                    _buildHeaderCell('Peligros Identificados'),
                    _buildHeaderCell('Medida Preventiva Recomendada'),
                  ],
                ),
                ...hazardsByArea.entries.map((entry) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.key,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: entry.value.map((h) {
                            return pw.Container(
                              margin: const pw.EdgeInsets.only(bottom: 2),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFFEF3C7),
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                '[!] $h',
                                style: const pw.TextStyle(fontSize: 7.5, color: warningColor),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _getSSTRecommendation(entry.value),
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
          pw.SizedBox(height: 18),

          // SECCIÓN 2: METADATA ESTRUCTURAL Y CANALIZACIONES POR SECTOR
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '2. METADATA ESTRUCTURAL Y PROPUESTA DE CANALIZACIONES',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9.5,
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
              0: pw.FlexColumnWidth(1.6), // Area
              1: pw.FlexColumnWidth(2.0), // Estructuras
              2: pw.FlexColumnWidth(2.2), // Materiales / Canalizaciones
              3: pw.FlexColumnWidth(2.2), // Herramientas Deducidas
              4: pw.FlexColumnWidth(1.6), // Viabilidad
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightBg),
                children: [
                  _buildHeaderCell('Sector'),
                  _buildHeaderCell('Estructuras'),
                  _buildHeaderCell('Materiales'),
                  _buildHeaderCell('Herramientas Requeridas'),
                  _buildHeaderCell('Viabilidad'),
                ],
              ),
              ...session.photos.map((p) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        p.areaSector,
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        p.estructuras.isEmpty ? 'Estandar' : p.estructuras.join(', '),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        p.materiales.isEmpty ? 'Por definir' : p.materiales.join(', '),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        p.herramientas.isEmpty ? 'Estandar' : p.herramientas.take(3).join(', '),
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFDCFCE7),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'Conforme',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF15803D)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // FIRMAS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Gestor de Proyectos VIGILARTE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Responsable Tecnico de Obra', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // 2. PÁGINAS DE FOTOGRAFÍAS TÉCNICAS COMPLETAS (CON TODOS LOS PINES DE METADATA)
    for (int i = 0; i < session.photos.length; i++) {
      final photo = session.photos[i];
      final imageProvider = pw.MemoryImage(photo.pngBytes); // Versión completa con todos los pines

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'EVIDENCIA #${photo.photoNumber} (METADATA COMPLETA) - ${photo.areaSector.toUpperCase()}',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Proyecto: ${session.project.proyecto}',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Container(height: 1.5, color: accentColor),
                pw.SizedBox(height: 8),

                // Imagen en Alta Resolución
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderGray, width: 1),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Image(
                        imageProvider,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Ficha Técnica al Pie de la Foto
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
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
                            _buildInfoRow('Estructuras:', photo.estructuras.join(', ')),
                            pw.SizedBox(height: 2),
                            _buildInfoRow('Materiales:', photo.materiales.join(', ')),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Peligros SST:', photo.peligros.isEmpty ? 'Ninguno reportado' : photo.peligros.join(', ')),
                            pw.SizedBox(height: 2),
                            _buildInfoRow('Herramientas:', photo.herramientas.take(3).join(', ')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static String _getSSTRecommendation(List<String> hazards) {
    final List<String> recs = [];
    final text = hazards.join(' ').toLowerCase();

    if (text.contains('altura') || text.contains('caida')) {
      recs.add('Uso obligatorio de arnes con linea de vida y punto de anclaje certificado.');
    }
    if (text.contains('electr') || text.contains('cable') || text.contains('tension')) {
      recs.add('Desenergizacion previa, bloqueo y etiquetado (LOTO) con guantes dielectricos.');
    }
    if (text.contains('corte') || text.contains('vidrio') || text.contains('filo')) {
      recs.add('Uso de guantes anticorte nivel 5 y proteccion ocular.');
    }
    if (text.contains('ruido') || text.contains('rotomartillo')) {
      recs.add('Proteccion auditiva tipo copa y mascarilla para particulas.');
    }

    if (recs.isEmpty) {
      return 'Cumplir con EPP basico reglamentario (casco, lentes, calzado dielectrico con punta reforzada).';
    }
    return recs.join(' ');
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
            value.isEmpty ? 'Sin registro' : value,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
          ),
        ),
      ],
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
