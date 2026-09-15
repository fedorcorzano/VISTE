import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../models/session_evidence_model.dart';
import '../services/warehouse_report_pdf_service.dart';
import '../services/purchasing_report_pdf_service.dart';
import '../services/project_manager_report_pdf_service.dart';
import '../services/client_report_pdf_service.dart';
import '../services/catalog_visual_service.dart';
import '../services/google_sheets_service.dart';
import 'catalog_manager_screen.dart';

class ProjectSummaryReportScreen extends StatefulWidget {
  final ProjectSessionModel session;

  const ProjectSummaryReportScreen({
    super.key,
    required this.session,
  });

  @override
  State<ProjectSummaryReportScreen> createState() =>
      _ProjectSummaryReportScreenState();
}

class _ProjectSummaryReportScreenState extends State<ProjectSummaryReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Uint8List? _warehousePdfBytes;
  Uint8List? _purchasingPdfBytes;
  Uint8List? _managerPdfBytes;
  Uint8List? _clientPdfBytes;
  bool _isLoadingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _generatePdfsInBackground();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePdfsInBackground() async {
    setState(() => _isLoadingPdf = true);
    try {
      final warehouse =
          await WarehouseReportPdfService.generatePdf(widget.session);
      final purchasing =
          await PurchasingReportPdfService.generatePdf(widget.session);
      final manager =
          await ProjectManagerReportPdfService.generatePdf(widget.session);
      final client =
          await ClientReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() {
          _warehousePdfBytes = warehouse;
          _purchasingPdfBytes = purchasing;
          _managerPdfBytes = manager;
          _clientPdfBytes = client;
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar PDFs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Acción para enviar por correo al cliente el reporte técnico y de SST
  Future<void> _sendEmailToClient() async {
    if (_clientPdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando PDF del cliente, por favor espere...'),
        ),
      );
      return;
    }

    final TextEditingController emailCtrl = TextEditingController();
    // Si el contacto pareciera ser un email, usarlo como valor por defecto
    if (widget.session.project.contacto.contains('@')) {
      emailCtrl.text = widget.session.project.contacto;
    }

    final bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined,
                color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Text('Enviar Reporte al Cliente',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proyecto: ${widget.session.project.proyecto}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Correo del Cliente / Destinatario:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ejemplo@cliente.com',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se adjuntará el PDF con las evidencias fotográficas de alta resolución, la propuesta de canalización/equipos y la matriz de seguridad SST.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Abrir Correo'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldSend == true && mounted) {
      final safeProject = widget.session.project.proyecto
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filename = 'VIGILARTE_Reporte_Cliente_SST_$safeProject.pdf';
      final subject =
          'VIGILARTE: Condiciones de Seguridad SST y Equipos - Proyecto: ${widget.session.project.proyecto}';

      await Printing.sharePdf(
        bytes: _clientPdfBytes!,
        filename: filename,
        subject: subject,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Proyecto',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.session.project.proyecto} • ${widget.session.totalPhotos} fotos registradas',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Catálogo Visual & Fotos',
            icon: const Icon(Icons.photo_camera_back, color: Color(0xFF10B981)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const CatalogManagerScreen(),
                ),
              );
              if (mounted) {
                _generatePdfsInBackground();
                setState(() {});
              }
            },
          ),
          IconButton(
            tooltip: 'Enviar Correo al Cliente',
            icon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
            onPressed: _sendEmailToClient,
          ),
          IconButton(
            tooltip: 'Cerrar y volver',
            icon: const Icon(Icons.check, color: Color(0xFF4ADE80)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.handyman_outlined, size: 18), text: 'Almacén'),
            Tab(icon: Icon(Icons.shopping_cart_outlined, size: 18), text: 'Compras'),
            Tab(icon: Icon(Icons.engineering_outlined, size: 18), text: 'Gestor'),
            Tab(icon: Icon(Icons.security_outlined, size: 18), text: 'Cliente SST'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildPdfPreviewTab(_warehousePdfBytes, 'VIGILARTE_Reporte_Almacen.pdf'),
          _buildPurchasingTab(),
          _buildPdfPreviewTab(_managerPdfBytes, 'VIGILARTE_Reporte_Gestor.pdf'),
          _buildPdfPreviewTab(_clientPdfBytes, 'VIGILARTE_Reporte_Cliente_SST.pdf'),
        ],
      ),
    );
  }

  /// Pestaña 1: Dashboard Visual interactivo con fotos reales de herramientas y materiales
  Widget _buildDashboardTab() {
    final tools = widget.session.getToolsWithFrequency();
    final materials = widget.session.getMaterialsWithFrequency();
    final accessories = widget.session.getConsolidatedAccessories();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Métricas clave
        Row(
          children: [
            _buildKpiCard(
              title: 'Herramientas Críticas',
              count: '${tools.where((t) => t.isIndispensable).length}',
              subtitle: 'Indispensables para avanzar',
              color: const Color(0xFFEF4444),
              icon: Icons.handyman,
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Materiales Clave',
              count: '${materials.where((m) => m.isIndispensable).length}',
              subtitle: 'En múltiples fotos',
              color: const Color(0xFF38BDF8),
              icon: Icons.inventory_2,
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Accesorios',
              count: '${accessories.length}',
              subtitle: 'Deducidos automáticamente',
              color: const Color(0xFF4ADE80),
              icon: Icons.category,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Banner de envío rápido al cliente
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0369A1), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0284C7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mark_email_read, color: Color(0xFF38BDF8), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reporte para el Cliente Listo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Incluye propuesta de canalizaciones y matriz de seguridad SST de ${widget.session.totalPhotos} fotografías.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Enviar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _sendEmailToClient,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Banner de Acceso al Catálogo Visual y Sincronización Drive (Métodos 1 y 2)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_a_photo, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Visual de Herramientas & Materiales',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Toma fotos reales en campo o sincroniza fotos desde Google Drive.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.manage_search, size: 15),
                label: const Text('Catálogo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const CatalogManagerScreen(),
                    ),
                  );
                  if (mounted) {
                    _generatePdfsInBackground();
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Herramientas con Fotos Reales y Frecuencia
        _buildSectionHeader(
          icon: Icons.handyman,
          title: 'HERRAMIENTAS PRIORIZADAS EN LA OBRA',
          subtitle: 'Herramientas deducidas según las estructuras y materiales de cada foto',
        ),
        const SizedBox(height: 12),

        ...tools.map((tool) {
          final visual = CatalogVisualService.getItemInfo(tool.name, isMaterial: false);
          return _buildVisualCard(
            item: visual,
            frequency: tool,
            isTool: true,
          );
        }),

        const SizedBox(height: 24),

        // 4. Materiales con Fotos Reales y Frecuencia
        _buildSectionHeader(
          icon: Icons.inventory_2,
          title: 'MATERIALES REQUERIDOS PARA INSTALACIÓN',
          subtitle: 'Tuberías y canalizaciones identificadas en el proyecto',
        ),
        const SizedBox(height: 12),

        ...materials.map((mat) {
          final visual = CatalogVisualService.getItemInfo(mat.name, isMaterial: true);
          return _buildVisualCard(
            item: visual,
            frequency: mat,
            isTool: false,
          );
        }),

        const SizedBox(height: 24),

        // 5. Accesorios y consumibles deducidos
        _buildSectionHeader(
          icon: Icons.category,
          title: 'ACCESORIOS Y CONSUMIBLES DEDUCIDOS',
          subtitle: 'Conectores, uniones, abrazaderas y cajas de paso requeridas',
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accessories.map((acc) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      acc,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  /// Tarjeta visual del objeto con imagen real, frecuencia de aparición y especificaciones
  Widget _buildVisualCard({
    required VisualCatalogItem item,
    required ItemFrequency frequency,
    required bool isTool,
  }) {
    final bool isCrit = frequency.isIndispensable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCrit ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFF334155),
          width: isCrit ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen real o ícono fallback con indicador táctil
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CatalogManagerScreen(initialSearch: item.title),
                      ),
                    );
                    if (mounted) {
                      _generatePdfsInBackground();
                      setState(() {});
                    }
                  },
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFF0F172A),
                          child: item.imageUrl.isNotEmpty
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Icon(
                                    item.fallbackIcon,
                                    color: item.badgeColor,
                                    size: 36,
                                  ),
                                )
                              : Icon(
                                  item.fallbackIcon,
                                  color: item.badgeColor,
                                  size: 36,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xE60F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            item.imageUrl.isNotEmpty ? Icons.camera_alt : Icons.add_a_photo,
                            color: item.imageUrl.isNotEmpty ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Criticidad / Frecuencia
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCrit
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCrit ? 'INDISPENSABLE' : 'PRIORITARIO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              frequency.frequencyDescription,
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nombre en tienda: ${item.commercialName}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: item.imageUrl.isNotEmpty ? 'Cambiar Foto' : 'Tomar Foto para Catálogo',
                  icon: Icon(
                    item.imageUrl.isNotEmpty ? Icons.edit_outlined : Icons.add_a_photo,
                    color: item.imageUrl.isNotEmpty ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                    size: 20,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => CatalogManagerScreen(initialSearch: item.title),
                      ),
                    );
                    if (mounted) {
                      _generatePdfsInBackground();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          // Barra inferior con especificación técnica para compras
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.specification,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Visor PDF integrado con zoom, descarga, impresión y compartir
  Widget _buildPdfPreviewTab(Uint8List? pdfBytes, String filename) {
    if (_isLoadingPdf || pdfBytes == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 14),
            Text(
              'Generando documento PDF en alta resolución...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return PdfPreview(
      build: (format) => pdfBytes,
      pdfFileName: filename,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      actions: [
        PdfPreviewAction(
          icon: const Icon(Icons.share),
          onPressed: (context, build, pageFormat) async {
            await Printing.sharePdf(
              bytes: pdfBytes,
              filename: filename,
            );
          },
        ),
      ],
    );
  }

  /// Pestaña de Compras con barra de cotización de proveedores
  Widget _buildPurchasingTab() {
    return Column(
      children: [
        // Action banner para cotización digital de proveedores
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cotización con Proveedores',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enviar enlace a 3 o más proveedores para comparar',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Enviar Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _shareSupplierQuoteLink,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.payments_outlined, size: 14),
                label: const Text('Precios', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _viewSupplierQuotesDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildPdfPreviewTab(_purchasingPdfBytes, 'VIGILARTE_Reporte_Compras.pdf'),
        ),
      ],
    );
  }

  void _shareSupplierQuoteLink() {
    final sheetsService = GoogleSheetsService();
    final materials = widget.session.getMaterialsWithFrequency();
    final accessories = widget.session.getConsolidatedAccessories();
    final allItems = [
      ...materials.map((m) => m.name),
      ...accessories,
    ];

    final quoteUrl = sheetsService.getSupplierQuoteUrl(
      widget.session.project.proyecto,
      items: allItems,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Text('Enlace para Proveedores', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puedes enviar este enlace a 3 o más ferreterías/distribuidores. Cada proveedor ingresará sus precios unitarios y tiempos de entrega:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SelectableText(
                quoteUrl,
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar Enlace'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: quoteUrl));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Enlace copiado al portapapeles. Listo para enviar por WhatsApp o Correo.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _viewSupplierQuotesDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
    );

    final sheetsService = GoogleSheetsService();
    final data = await sheetsService.fetchSupplierQuotes(widget.session.project.proyecto);

    if (!mounted) return;
    Navigator.pop(context); // cerrar spinner

    final List quotes = (data['quotes'] as List?) ?? [];
    final Map minPrices = (data['minPrices'] as Map?) ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.compare_arrows, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Text(
              'Cotizaciones (${quotes.length})',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: quotes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Aún no se han recibido cotizaciones de proveedores para este proyecto.\nEnvía el enlace a tus proveedores para recibir precios.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: quotes.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF334155)),
                  itemBuilder: (ctx, i) {
                    final q = quotes[i] as Map;
                    final item = q['item'] ?? '';
                    final price = q['price'] ?? 0;
                    final supplier = q['supplier'] ?? 'Proveedor';
                    final isBest = minPrices[item] != null && minPrices[item]['supplier'] == supplier;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$item (${q['unit'] ?? "Und"})',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Text(
                            'S/. $price',
                            style: TextStyle(
                              color: isBest ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text('De: $supplier', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (isBest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF065F46),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('MEJOR PRECIO', style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }
}

