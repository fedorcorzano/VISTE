import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';

/// Servicio de generación del informe IPERC formal en PDF (Fase 2 - Proyecto Aceptado / Ejecución de Obra)
/// Estructurado según Ley N° 29783, D.S. 005-2012-TR y Norma Técnica G.050
class IpercReportPdfService {
  static Future<Uint8List> generatePdf(ProjectSessionModel session) async {
    final pdf = pw.Document();

    const navyColor = PdfColor.fromInt(0xFF001F2F);
    const yellowColor = PdfColor.fromInt(0xFFE3A51A);
    const grayBorder = PdfColor.fromInt(0xFFCBD5E1);
    const lightHeader = PdfColor.fromInt(0xFFF1F5F9);

    final hazards = session.getConsolidatedHazards();
    final hazardsByArea = session.getHazardsByArea();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: navyColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VIGILARTE INGENIERÍA SAC - MATRIZ IPERC CONTINUO',
                      style: pw.TextStyle(
                        color: navyColor,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Identificación de Peligros, Evaluación de Riesgos y Medidas de Control (Ley 29783 / G.050)',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: yellowColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'DOCUMENTO SST OBLIGATORIO',
                    style: pw.TextStyle(
                      color: navyColor,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // Ficha de metadatos del proyecto
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: lightHeader,
                border: pw.Border.all(color: grayBorder),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Cliente / Empresa:', session.project.contacto),
                        _buildMetaRow('Proyecto:', session.project.proyecto),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Dirección / Ubicación:', session.project.direccion),
                        _buildMetaRow('Fecha de Elaboración:', session.displayDate),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Gestor Responsable:', session.project.responsable),
                        _buildMetaRow('Total Evidencias:', '${session.totalPhotos} fotos técnicas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabla IPERC
            pw.Table(
              border: pw.TableBorder.all(color: grayBorder, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.8), // N°
                1: pw.FlexColumnWidth(2.5), // Área / Sector
                2: pw.FlexColumnWidth(3.0), // Peligro
                3: pw.FlexColumnWidth(3.5), // Riesgo / Consecuencia
                4: pw.FlexColumnWidth(1.2), // Riesgo Inicial
                5: pw.FlexColumnWidth(2.5), // Jerarquía
                6: pw.FlexColumnWidth(4.5), // Medida de Control
                7: pw.FlexColumnWidth(2.0), // Responsable (Costo)
                8: pw.FlexColumnWidth(1.2), // Riesgo Residual
              },
              children: [
                // Cabecera
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navyColor),
                  children: [
                    _buildTh('Item'),
                    _buildTh('Área / Sector'),
                    _buildTh('Peligro Identificado'),
                    _buildTh('Riesgo / Evento'),
                    _buildTh('Riesgo Inicial'),
                    _buildTh('Jerarquía Control'),
                    _buildTh('Medida Preventiva Obligatoria'),
                    _buildTh('Responsable'),
                    _buildTh('Riesgo Residual'),
                  ],
                ),
                // Filas por cada peligro en cada área
                ..._buildIpercRows(session, hazardsByArea, hazards),
              ],
            ),

            pw.SizedBox(height: 20),

            // Cuadro de firmas y responsabilidades
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSignatureBox('Elaborado por:', session.project.responsable, 'Gestor de Proyectos - VIGILARTE'),
                _buildSignatureBox('Revisado por:', 'Ing. SSOMA Residente', 'VIGILARTE INGENIERÍA SAC'),
                _buildSignatureBox('Aprobado por Cliente:', session.project.contacto, 'Supervisor SST Cliente'),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetaRow(String label, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              val.isEmpty ? 'N/A' : val,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTh(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static List<pw.TableRow> _buildIpercRows(
    ProjectSessionModel session,
    Map<String, List<String>> hazardsByArea,
    List<String> allHazards,
  ) {
    final List<pw.TableRow> rows = [];
    int itemCounter = 1;

    if (hazardsByArea.isEmpty) {
      for (final pel in allHazards) {
        rows.add(_createRow(itemCounter++, 'General / Obra', pel, session));
      }
    } else {
      hazardsByArea.forEach((area, pList) {
        for (final pel in pList) {
          rows.add(_createRow(itemCounter++, area, pel, session));
        }
      });
    }

    if (rows.isEmpty) {
      rows.add(
        _createRow(1, 'Zona de Relevamiento', 'Condiciones estándar de obra', session),
      );
    }

    return rows;
  }

  static pw.TableRow _createRow(int index, String area, String peligro, ProjectSessionModel session) {
    final bool isElec = peligro.toLowerCase().contains('eléctrico') || peligro.toLowerCase().contains('electrico');
    final bool isAlt = peligro.toLowerCase().contains('altura') || peligro.toLowerCase().contains('escalera');

    String riesgoDesc = 'Exposición a condición subestándar durante maniobra';
    String jerarquia = 'Control de Ingeniería';
    String medida = 'Inspección de herramientas y delimitación del área con conos.';
    String responsable = session.getHierarchyResponsible('ingenieria', 'VIGILARTE INGENIERÍA');
    String riesgoInicial = 'MEDIO';
    PdfColor badgeColor = PdfColors.amber700;

    if (isElec) {
      riesgoDesc = 'Contacto con partes vivas, electrocución o arco eléctrico';
      jerarquia = 'Ingeniería / EPP';
      medida = 'Verificación con multímetro, bloqueo LOTO y guantes dieléctricos 1000V.';
      responsable = session.getHierarchyResponsible('ingenieria', 'VIGILARTE INGENIERÍA');
      riesgoInicial = 'ALTO';
      badgeColor = PdfColors.red700;
    } else if (isAlt) {
      riesgoDesc = 'Caída a distinto nivel (>1.80m), politraumatismo';
      jerarquia = 'Control de Ingeniería / EPP';
      medida = 'Uso de arnés con absorbedor de impacto, inspección de escalera con tarjeta verde.';
      responsable = session.getHierarchyResponsible('epp', 'VIGILARTE INGENIERÍA');
      riesgoInicial = 'ALTO';
      badgeColor = PdfColors.red700;
    }

    return pw.TableRow(
      children: [
        _buildTd(index.toString(), align: pw.TextAlign.center),
        _buildTd(area),
        _buildTd(peligro, bold: true),
        _buildTd(riesgoDesc),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
            child: pw.Text(
              riesgoInicial,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: badgeColor),
            ),
          ),
        ),
        _buildTd(jerarquia),
        _buildTd(medida),
        _buildTd(responsable, bold: true),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
            child: pw.Text(
              'BAJO',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTd(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSignatureBox(String role, String name, String cargo) {
    return pw.Container(
      width: 180,
      padding: const pw.EdgeInsets.only(top: 25),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 1)),
      ),
      child: pw.Column(
        children: [
          pw.Text(role, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Text(cargo, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
