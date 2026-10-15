import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/session_evidence_model.dart';
import 'pdf_brand_helper.dart';

class ClientReportPdfService {
  /// Genera el reporte formal exclusivo para el cliente con:
  /// 1. Carátula ejecutiva con Logo VIGILARTE, Nombre del proyecto, Fecha,
  ///    Persona a cargo de la visita y Mapa 2D georreferenciado con pin.
  /// 2. Resumen ejecutivo de condiciones de seguridad SST y Equipamiento cotizado.
  /// 3. Evidencias fotográficas con SOLO marcadores de Seguridad / SST (sin pines ni cotas).
  static Future<Uint8List> generatePdf(
    ProjectSessionModel session, {
    Uint8List? preloadedSatelliteMap,
  }) async {
    final pdf = pw.Document();

    const primaryColor = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const accentColor = PdfColor.fromInt(0xFF0284C7); // Sky 600
    const warningColor = PdfColor.fromInt(0xFFB45309); // Amber 700
    const lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderGray = PdfColor.fromInt(0xFFE2E8F0);

    // 0. Cargar logo corporativo oficial y mapa 2D para la carátula
    final logoBytes = await PdfBrandHelper.loadLogoBytes();
    final coords = _parseCoordinates(session.project.mapa);
    Uint8List? satelliteMapBytes = preloadedSatelliteMap;
    if (satelliteMapBytes == null && coords != null) {
      satelliteMapBytes = await _fetchSatelliteMap(coords.$1, coords.$2);
    }

    final hazardsByArea = session.getHazardsByArea();
    final allHazards = session.getConsolidatedHazards();

    // =========================================================================
    // 0. PÁGINA DE CARÁTULA EJECUTIVA FORMAL PARA EL CLIENTE
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 1.2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Top Header: Logo VIGILARTE & Badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    PdfBrandHelper.buildCoverLogo(logoBytes: logoBytes, height: 42),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF0284C7),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'ENTREGABLE CLIENTE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Accent dividing line (Navy + Sky Blue + Emerald)
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(height: 3, color: const PdfColor.fromInt(0xFF0F172A)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(height: 3, color: const PdfColor.fromInt(0xFF0284C7)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(height: 3, color: const PdfColor.fromInt(0xFF10B981)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Document Title
                pw.Text(
                  'INFORME TECNICO DE INSPECCION',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'CONDICIONES DE SEGURIDAD SST Y PROPUESTA DE EQUIPAMIENTO',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF0284C7),
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 14),

                // Executive Metadata Card
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                  ),
                  child: pw.Column(
                    children: [
                      _buildCoverMetaRow('Proyecto:', session.project.proyecto, isBold: true),
                      pw.SizedBox(height: 5),
                      _buildCoverMetaRow('Fecha de Visita:', session.project.fecha),
                      pw.SizedBox(height: 5),
                      _buildCoverMetaRow(
                        'A Cargo de la Visita:',
                        session.project.responsable.isNotEmpty
                            ? session.project.responsable
                            : (session.project.contacto.isNotEmpty ? session.project.contacto : 'Fedor Corzano'),
                        isAccent: true,
                      ),
                      pw.SizedBox(height: 5),
                      _buildCoverMetaRow('Cliente / Contacto:', session.project.contacto),
                      if (session.project.direccion.isNotEmpty) ...[
                        pw.SizedBox(height: 5),
                        _buildCoverMetaRow('Direccion:', session.project.direccion),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Map Section Title
                pw.Text(
                  'UBICACION GEORREFERENCIADA DEL PROYECTO (MAPA 2D)',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF0F172A),
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Square Satellite Map with Centered Position Marker
                _buildSatelliteMapWidget(
                  satelliteBytes: satelliteMapBytes,
                  lat: coords?.$1,
                  lng: coords?.$2,
                ),

                pw.Spacer(),

                // Bottom Footer
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'VIGILARTE - Seguridad Electronica & Infraestructura',
                        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7.5),
                      ),
                      pw.Text(
                        'Desarrollado por Fedor Corzano',
                        style: pw.TextStyle(
                          color: const PdfColor.fromInt(0xFF0F172A),
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Documento Confidencial',
                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // =========================================================================
    // 1. PÁGINA DE RESUMEN EJECUTIVO DE SEGURIDAD SST Y EQUIPOS
    // =========================================================================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return PdfBrandHelper.buildHeader(
            title: 'CONDICIONES DE SEGURIDAD SST Y EQUIPOS',
            subtitle: 'Informe de Condiciones de Seguridad en Campo y Propuesta de Equipamiento',
            badgeText: 'REPORTE CLIENTE',
            badgeColor: const PdfColor.fromInt(0xFF10B981),
            logoBytes: logoBytes,
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
                  'VIGILARTE - Entregable al Cliente - Desarrollado por Fedor Corzano',
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
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // SECCIÓN 1: PROPUESTA DE EQUIPAMIENTO Y SISTEMAS COTIZADOS
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '1. PROPUESTA DE EQUIPAMIENTO Y SISTEMAS COTIZADOS',
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

          pw.Text(
            'Detalle de la solucion tecnica de equipamiento propuesta para cada sector relevado en el proyecto:',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),

          pw.Table(
            border: pw.TableBorder.all(color: borderGray, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightBg),
                children: [
                  _buildHeaderCell('Sector / Area'),
                  _buildHeaderCell('Sistema / Equipamiento Propuesto'),
                  _buildHeaderCell('Estado Tecnico'),
                ],
              ),
              ...session.photos.map((p) {
                final status = p.effectiveTechnicalStatus;
                final PdfColor badgeBg;
                final PdfColor badgeText;
                final String badgeLabel;
                final String defaultDesc;

                if (status == 'no_apto') {
                  badgeBg = const PdfColor.fromInt(0xFFFEE2E2);
                  badgeText = const PdfColor.fromInt(0xFFDC2626);
                  badgeLabel = 'No Apto para Instalación';
                  defaultDesc = 'Sector con riesgos críticos no aptos para el montaje hasta subsanar condiciones de seguridad.';
                } else if (status == 'condicionado') {
                  badgeBg = const PdfColor.fromInt(0xFFFEF3C7);
                  badgeText = const PdfColor.fromInt(0xFFD97706);
                  badgeLabel = 'Apto Condicionado a SST';
                  defaultDesc = 'Punto apto sujeto a cumplimiento de medidas preventivas y controles de SST requeridos.';
                } else {
                  badgeBg = const PdfColor.fromInt(0xFFDCFCE7);
                  badgeText = const PdfColor.fromInt(0xFF15803D);
                  badgeLabel = 'Apto para Instalación';
                  defaultDesc = 'Punto de instalación preparado y apto para montaje de equipos cotizados.';
                }

                final desc = (p.technicalObservation != null && p.technicalObservation!.trim().isNotEmpty)
                    ? p.technicalObservation!.trim()
                    : defaultDesc;

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        p.areaSector.isNotEmpty ? p.areaSector : 'Sector sin definir',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        desc,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: badgeBg,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          badgeLabel,
                          style: pw.TextStyle(fontSize: 7.5, color: badgeText, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 18),

          // SECCIÓN 2: CONDICIONES DE SEGURIDAD Y PREVENCION DE RIESGOS (SST)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Text(
                  '2. CONDICIONES DE SEGURIDAD Y PREVENCION DE RIESGOS (SST)',
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
                    '[OK] No se identificaron condiciones de riesgo criticas en las areas evaluadas.',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF065F46)),
                  ),
                ],
              ),
            )
          else ...[
            pw.Text(
              'A continuacion se presentan las condiciones de seguridad observadas en cada sector inspeccionado y las medidas preventivas recomendadas para el desarrollo seguro de los trabajos:',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.0), // Sector
                1: pw.FlexColumnWidth(2.5), // Condicion de Seguridad / Peligro
                2: pw.FlexColumnWidth(3.5), // Medida de Prevencion SST
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildHeaderCell('Sector / Area'),
                    _buildHeaderCell('Condicion de Seguridad Identificada'),
                    _buildHeaderCell('Medida de Control / Prevencion (SST)'),
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
          pw.SizedBox(height: 24),

          // FIRMAS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Especialista de Seguridad SST VIGILARTE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 1, color: borderGray),
                  pw.SizedBox(height: 4),
                  pw.Text('Conformidad del Cliente / Supervisor', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // 3. PÁGINAS DE FOTOGRAFÍAS EXCLUSIVAS PARA CLIENTE CON JERARQUÍA DE CONTROL DE RIESGOS
    // Solo deben mostrarse las fotos con los peligros (Req. 5)
    final sstPhotos = session.photos.where((p) => p.peligros.isNotEmpty).toList();
    final photosToDisplay = sstPhotos.isNotEmpty ? sstPhotos : session.photos;

    for (int i = 0; i < photosToDisplay.length; i++) {
      final photo = photosToDisplay[i];
      // USAR EXCLUSIVAMENTE clientImageBytes (con solo marcadores SST, sin herramientas ni materiales ni cotas)
      final imageProvider = pw.MemoryImage(photo.clientImageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado de Sección 3 con Logo VIGILARTE
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        PdfBrandHelper.buildLogo(logoBytes: logoBytes, height: 22, showSubtitle: false),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '3. JERARQUÍA DE CONTROL DE RIESGOS Y EVIDENCIA #${photo.photoNumber}',
                          style: pw.TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'SECTOR: ${photo.areaSector.toUpperCase()}',
                      style: pw.TextStyle(
                        color: accentColor,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(height: 1.5, color: const PdfColor.fromInt(0xFF10B981)),
                pw.SizedBox(height: 8),

                // Imagen Fotográfica centrada horizontalmente, manteniendo gran detalle
                pw.Center(
                  child: pw.Container(
                    height: 245,
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
                pw.SizedBox(height: 7),

                // Recuadro de Peligros identificados (antes de la tabla de jerarquía)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: borderGray, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Peligros identificados: ',
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              pw.TextSpan(
                                text: photo.peligros.isEmpty
                                    ? 'Area conforme / Sin riesgos criticos'
                                    : photo.peligros.join(', '),
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Text(
                        'VIGILARTE SST',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 7),

                // Título de la Tabla de Jerarquía
                pw.Text(
                  'Matriz de Jerarquia de Control de Riesgos Operacionales (ISO 45001 / Ley 29783):',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 4),

                // Tabla con los campos solicitados: Jerarquía | Medida de Control Preventivo | Responsable
                _buildHierarchyControlsTable(photo.peligros, primaryColor, borderGray, lightBg, session),
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

  /// Construye la tabla de 5 niveles de Jerarquía de Control de Riesgos (ISO 45001 / Ley 29783)
  static pw.Widget _buildHierarchyControlsTable(
    List<String> hazards,
    PdfColor primaryColor,
    PdfColor borderGray,
    PdfColor lightBg,
    ProjectSessionModel session,
  ) {
    final text = hazards.join(' ').toLowerCase();

    // 1. Eliminación
    String elim = 'Eliminar elementos cortantes, desorden y cables en desuso en el area inmediata de trabajo.';
    String elimResp = 'Cliente / Mantenimiento';
    if (text.contains('electr') || text.contains('tension') || text.contains('cable')) {
      elim = 'Desenergizar y aplicar bloqueo / etiquetado (LOTO) en tableros o circuitos cercanos antes de intervenir.';
      elimResp = 'Cliente / Mantenimiento';
    } else if (text.contains('altura') || text.contains('caida')) {
      elim = 'Planificar pre-armado y ensambles a nivel de piso para minimizar el tiempo de exposicion en altura.';
      elimResp = 'Supervisor SST / VIGILARTE';
    }
    elimResp = session.getHierarchyResponsible('eliminacion', elimResp);

    // 2. Sustitución
    String sust = 'Sustituir herramientas manuales convencionales por herramientas con aislamiento certificado.';
    String sustResp = 'VIGILARTE / Contratista';
    if (text.contains('altura') || text.contains('caida')) {
      sust = 'Sustituir escaleras portatiles de mano por andamios modulares normados o plataforma elevadora tipo tijera.';
      sustResp = 'VIGILARTE / Contratista';
    }
    sustResp = session.getHierarchyResponsible('sustitucion', sustResp);

    // 3. Ingeniería
    String ing = 'Instalacion de delimitacion fisica rigida y protecciones en puntos de paso o trabajo.';
    String ingResp = 'Cliente / VIGILARTE';
    if (text.contains('altura') || text.contains('caida')) {
      ing = 'Instalar puntos de anclaje certificados (5,000 lbf), lineas de vida y barandas perimetrales de proteccion.';
      ingResp = 'Cliente / VIGILARTE';
    } else if (text.contains('electr')) {
      ing = 'Colocacion de mantas dielectricas y aislamiento fisico en canalizaciones o tableros adyacentes.';
      ingResp = 'Cliente / VIGILARTE';
    }
    ingResp = session.getHierarchyResponsible('ingenieria', ingResp);

    // 4. Administración
    String adm = 'Difusion de IPERC Continuo, AST diario, charla de seguridad de 5 minutos y senalizacion perimetral.';
    String admResp = 'Supervisor SST VIGILARTE';
    if (text.contains('altura')) {
      adm = 'Emision obligatoria de PETAR para Trabajos en Altura, check-list de arnes e inspeccion previa del area.';
      admResp = 'Supervisor SST VIGILARTE';
    }
    admResp = session.getHierarchyResponsible('administracion', admResp);

    // 5. EPP
    String epp = 'Casco de seguridad con barbiquejo, lentes con proteccion lateral, guantes anticorte y calzado dielectrico.';
    String eppResp = 'Personal Tecnico Instalador';
    if (text.contains('altura')) {
      epp = 'Arnes de cuerpo entero normado ANSI Z359 con doble linea de vida y absorbedor de impacto, casco dielectrico.';
      eppResp = 'Personal Tecnico Instalador';
    } else if (text.contains('electr')) {
      epp = 'Guantes dielectricos normados clase 00/0, careta facial contra arco electrico y calzado de seguridad dielectrico.';
      eppResp = 'Personal Tecnico Instalador';
    }
    eppResp = session.getHierarchyResponsible('epp', eppResp);

    final rows = [
      ('Eliminacion', elim, elimResp, const PdfColor.fromInt(0xFF16A34A)),
      ('Sustitucion', sust, sustResp, const PdfColor.fromInt(0xFF0D9488)),
      ('Ingenieria', ing, ingResp, const PdfColor.fromInt(0xFFD97706)),
      ('Administracion', adm, admResp, const PdfColor.fromInt(0xFFEA580C)),
      ('EPP', epp, eppResp, const PdfColor.fromInt(0xFFDC2626)),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: borderGray, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8), // Jerarquía
        1: pw.FlexColumnWidth(5.4), // Medida de Control
        2: pw.FlexColumnWidth(2.8), // Responsable
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: lightBg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Text('Jerarquia', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Text('Medida de Control Preventivo', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Text('Responsable', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ),
          ],
        ),
        ...rows.map((r) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Row(
                  children: [
                    pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: r.$4)),
                    pw.SizedBox(width: 4),
                    pw.Text(r.$1, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: r.$4)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Text(r.$3, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0369A1))),
              ),
            ],
          );
        }),
      ],
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
          color: const PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER METHODS PARA CARÁTULA Y MAPA SATELITAL
  // =========================================================================

  /// Parsea coordenadas en formato "lat, lng" o URL
  static (double, double)? _parseCoordinates(String mapa) {
    if (mapa.isEmpty || mapa == '0.0, 0.0') return null;
    final match = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)').firstMatch(mapa);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        return (lat, lng);
      }
    }
    return null;
  }

  /// Descarga imagen 2D ArcGIS World Street Map centrada en el proyecto en formato ancho panorámico
  static Future<Uint8List?> _fetchSatelliteMap(double lat, double lng) async {
    try {
      const deltaLon = 0.0060; // Zoom horizontal amplio
      const deltaLat = 0.0028; // Zoom vertical proporcional
      final minLon = lng - deltaLon;
      final maxLon = lng + deltaLon;
      final minLat = lat - deltaLat;
      final maxLat = lat + deltaLat;

      final url =
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/export'
          '?bbox=$minLon,$minLat,$maxLon,$maxLat&bboxSR=4326&imageSR=4326&size=800,380&format=jpg&f=image';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Fallback a gráfico vectorial 2D si se encuentra sin conexión o timeout
    }
    return null;
  }


  /// Fila de metadata para la carátula
  static pw.Widget _buildCoverMetaRow(
    String label,
    String value, {
    bool isBold = false,
    bool isAccent = false,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 135,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF475569),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? 'Sin registro' : value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold || isAccent ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isAccent
                  ? const PdfColor.fromInt(0xFF0284C7)
                  : const PdfColor.fromInt(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  /// Mapa panorámico satelital con marcador de posición (pin) centrado y ancho completo A4
  static pw.Widget _buildSatelliteMapWidget({
    required Uint8List? satelliteBytes,
    required double? lat,
    required double? lng,
  }) {
    const double mapWidth = 475.0;
    const double mapHeight = 240.0;
    const markerColor = PdfColor.fromInt(0xFFEF4444); // Red 500

    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Container(
        width: mapWidth,
        height: mapHeight,
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFF0F172A),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFF0284C7), width: 1.5),
        ),
        child: pw.Stack(
          alignment: pw.Alignment.center,
          children: [
          // Imagen Satelital o Representación de Respaldo
          if (satelliteBytes != null)
            pw.Image(
              pw.MemoryImage(satelliteBytes),
              fit: pw.BoxFit.cover,
              width: mapWidth,
              height: mapHeight,
            )
          else
            _buildVectorMapPlaceholder(lat, lng),

          // Insignia Superior Izquierda: MODO SATELITAL
          pw.Positioned(
            top: 7,
            left: 7,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xE60F172A),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFF38BDF8), width: 0.5),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    width: 5,
                    height: 5,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF10B981),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    'MAPA 2D',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Indicador de Norte Superior Derecho
          pw.Positioned(
            top: 7,
            right: 7,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xE60F172A),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'N ^',
                style: pw.TextStyle(
                  color: const PdfColor.fromInt(0xFF38BDF8),
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),

          // Marcador de Posición Centrado (PIN ROJO)
          pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 18,
                  height: 18,
                  decoration: pw.BoxDecoration(
                    color: markerColor,
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.white, width: 2),
                  ),
                  child: pw.Center(
                    child: pw.Container(
                      width: 5,
                      height: 5,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                pw.CustomPaint(
                  size: const PdfPoint(7, 5),
                  painter: (canvas, size) {
                    canvas.moveTo(0, 0);
                    canvas.lineTo(size.x, 0);
                    canvas.lineTo(size.x / 2, size.y);
                    canvas.closePath();
                    canvas.setFillColor(markerColor);
                    canvas.fillPath();
                  },
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xE60F172A),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'PROYECTO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 5.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra Inferior de Coordenadas GPS
          pw.Positioned(
            bottom: 7,
            left: 7,
            right: 7,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xE60F172A),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    lat != null && lng != null
                        ? 'GPS: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                        : 'GPS: Registrado en sistema',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'ARCGIS STREETS 2D',
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF38BDF8),
                      fontSize: 5.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  /// Gráfico de respaldo para mapa satelital cuando no hay conexión
  static pw.Widget _buildVectorMapPlaceholder(double? lat, double? lng) {
    return pw.Container(
      color: const PdfColor.fromInt(0xFF1E293B),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              '[ MAPA 2D ]',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF38BDF8),
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              lat != null && lng != null
                  ? 'Lat: ${lat.toStringAsFixed(5)}, Lon: ${lng.toStringAsFixed(5)}'
                  : 'Coordenadas del Proyecto Registradas',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }
}
