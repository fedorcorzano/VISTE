import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';
import 'catalog_visual_service.dart';

class PurchasingReportPdfService {
  /// Genera el reporte especializado exclusivo para Compras y Cotizaciones de Materiales y Accesorios
  /// con tabla ejecutiva, fotos comerciales, especificaciones técnicas y cantidades a cotizar.
  static Future<Uint8List> generatePdf(ProjectSessionModel session) async {
    final pdf = pw.Document();

    final materials = session.getValidatedMaterialsWithFrequency();
    final accessories = session.getValidatedConsolidatedAccessories();

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0284C7); // Sky 600
    const emeraldColor = PdfColor.fromInt(0xFF10B981); // Emerald 500
    const lightBg = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
    const borderGray = PdfColor.fromInt(0xFFCBD5E1); // Slate 300

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
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
                      'VIGILARTE - REPORTE DE COMPRAS Y COTIZACIÓN DE MATERIALES',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Lista Ejecutiva de Materiales y Accesorios de Canalización para Cotización en Obra',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8.5),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF0284C7),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'COMPRAS Y LOGÍSTICA',
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
                  'VIGILARTE Sistema de Compras - Desarrollado por Fedor Corzano',
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
          // 1. Tarjeta Informativa del Proyecto y Cotización
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
                      child: _buildInfoRow('Cliente / Destino:', session.project.contacto),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildInfoRow('Fecha de Solicitud:', session.project.fecha),
                    ),
                    pw.Expanded(
                      child: _buildInfoRow('Dirección de Entrega:', session.project.direccion.isNotEmpty ? session.project.direccion : 'Según coordinación de almacén'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Banner de Cotización Digital con Proveedores
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF0FDF4),
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBBF7D0)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: emeraldColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'PORTAL DIGITAL',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    'Solicitud de Precios Multiproveedor: Este listado puede ser cotizado directamente vía web por los proveedores autorizados para comparar mejores precios y tiempos de entrega.',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF166534)),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // TÍTULO DE LA TABLA
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TABLA DE MATERIALES Y ACCESORIOS PARA COMPRA / COTIZACIÓN',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${materials.length + accessories.length} ÍTEMS TOTALES',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF38BDF8),
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // TABLA EJECUTIVA CON FOTOS, CANTIDADES Y ESPECIFICACIONES
          pw.Table(
            border: pw.TableBorder.all(color: borderGray, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(48), // Foto
              1: pw.FlexColumnWidth(3.2), // Descripción & Especificación
              2: pw.FixedColumnWidth(42), // Unidad
              3: pw.FixedColumnWidth(44), // Cantidad
              4: pw.FixedColumnWidth(55), // P. Unitario
              5: pw.FixedColumnWidth(55), // Subtotal
            },
            children: [
              // Encabezado
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightBg),
                children: [
                  _buildHeaderCell('Foto', align: pw.TextAlign.center),
                  _buildHeaderCell('Material / Especificación Técnica'),
                  _buildHeaderCell('Unidad', align: pw.TextAlign.center),
                  _buildHeaderCell('Cantidad', align: pw.TextAlign.center),
                  _buildHeaderCell('P. Unit. (S/)', align: pw.TextAlign.right),
                  _buildHeaderCell('Subtotal (S/)', align: pw.TextAlign.right),
                ],
              ),

              // Filas de Materiales Principales
              ...materials.map((entry) {
                final matName = entry.name;
                final count = entry.count;
                final visualInfo = CatalogVisualService.getItemInfo(matName, isMaterial: true);
                final unit = _deduceUnit(matName);
                final qty = _calculateEstimatedQty(matName, count);

                return pw.TableRow(
                  children: [
                    // Foto
                    pw.Container(
                      height: 38,
                      margin: const pw.EdgeInsets.all(2),
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '[Foto]',
                          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                        ),
                      ),
                    ),
                    // Descripción
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            visualInfo.commercialName.isNotEmpty ? visualInfo.commercialName : matName,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            visualInfo.specification,
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    // Unidad
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(unit, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    // Cantidad
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text('$qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    // P. Unitario (casilla para cotizar)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    // Subtotal
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                  ],
                );
              }),

              // Filas de Accesorios Consolidados
              ...accessories.map((accName) {
                final visualInfo = CatalogVisualService.getItemInfo(accName, isMaterial: true);
                final unit = 'Und';
                final qty = session.photos.length * 4; // Estimación estándar de accesorios por sector

                return pw.TableRow(
                  children: [
                    // Foto
                    pw.Container(
                      height: 38,
                      margin: const pw.EdgeInsets.all(2),
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '[Foto]',
                          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                        ),
                      ),
                    ),
                    // Descripción
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            visualInfo.commercialName.isNotEmpty ? visualInfo.commercialName : accName,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            visualInfo.specification,
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    // Unidad
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(unit, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    // Cantidad
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text('$qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    // P. Unitario (casilla para cotizar)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    // Subtotal
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text('', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),

          // CUADRO DE RESUMEN DE TOTALES Y CONDICIONES COMERCIALES
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: borderGray),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Condiciones de Cotización:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('- Indicar precios unitarios en Soles (S/.) con IGV incluido o desglosado.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text('- Especificar plazo de entrega en almacén de obra y marca del fabricante.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text('- Validez mínima de cotización requerida: 15 días calendario.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: accentColor),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: const PdfColor.fromInt(0xFFF0F9FF),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal Materiales:', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          pw.Text('S/. _________', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('IGV (18%):', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          pw.Text('S/. _________', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                      pw.Divider(color: accentColor, thickness: 0.5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL COMPRAS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('S/. _________', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // FIRMAS DE COMPRAS Y APROBACIÓN
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Elaborado por: Compras & Cotizaciones', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Aprobación: Gerencia de Operaciones', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String _deduceUnit(String matName) {
    final lower = matName.toLowerCase();
    if (lower.contains('tubo') || lower.contains('emt') || lower.contains('canaleta')) {
      return 'Tiras (3m)';
    }
    if (lower.contains('cable') || lower.contains('utp')) {
      return 'Caja (305m)';
    }
    if (lower.contains('riel') || lower.contains('strut')) {
      return 'Tiras';
    }
    return 'Und';
  }

  static int _calculateEstimatedQty(String matName, int sectorCount) {
    final lower = matName.toLowerCase();
    if (lower.contains('tubo') || lower.contains('canaleta')) {
      return sectorCount * 5; // Estimado estándar de tiras por sector
    }
    if (lower.contains('cable')) {
      return (sectorCount / 2).ceil();
    }
    return sectorCount * 2;
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
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
