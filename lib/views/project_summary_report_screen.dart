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
    try {
      final warehouse = await WarehouseReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() => _warehousePdfBytes = warehouse);
      }
    } catch (e) {
      debugPrint('Error generando PDF de Almacén: $e');
    }

    try {
      final purchasing = await PurchasingReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() => _purchasingPdfBytes = purchasing);
      }
    } catch (e) {
      debugPrint('Error generando PDF de Compras: $e');
    }

    try {
      final manager = await ProjectManagerReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() => _managerPdfBytes = manager);
      }
    } catch (e) {
      debugPrint('Error generando PDF de Gestor: $e');
    }

    try {
      final client = await ClientReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() => _clientPdfBytes = client);
      }
    } catch (e) {
      debugPrint('Error generando PDF de Cliente SST: $e');
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

  void _openManagerValidationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManagerValidationSheet(
        session: widget.session,
        onSaved: () {
          _generatePdfsInBackground();
          setState(() {});
        },
      ),
    );
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
            tooltip: 'Validación del Gestor (Excluir/Editar SST)',
            icon: const Icon(Icons.fact_check_outlined, color: Colors.amberAccent),
            onPressed: _openManagerValidationSheet,
          ),
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
    final tools = widget.session.getValidatedToolsWithFrequency();
    final materials = widget.session.getValidatedMaterialsWithFrequency();
    final accessories = widget.session.getValidatedConsolidatedAccessories();
    final int excludedCount = widget.session.excludedTools.length +
        widget.session.excludedMaterials.length +
        widget.session.excludedAccessories.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Métricas clave
        Row(
          children: [
            _buildKpiCard(
              title: 'Herramientas Críticas',
              count: '${tools.where((t) => t.isIndispensable).length}',
              subtitle: 'Validadas para almacén',
              color: const Color(0xFFEF4444),
              icon: Icons.handyman,
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Materiales Clave',
              count: '${materials.where((m) => m.isIndispensable).length}',
              subtitle: 'Validados para compras',
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
        const SizedBox(height: 16),

        // Banner de Validación del Gestor de Proyectos
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: excludedCount > 0 ? Colors.amber : const Color(0xFF38BDF8).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fact_check_outlined,
                  color: excludedCount > 0 ? Colors.amberAccent : const Color(0xFF38BDF8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      excludedCount > 0
                          ? 'Validación Activa ($excludedCount ítems excluidos)'
                          : 'Validación del Gestor de Proyectos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      excludedCount > 0
                          ? 'Herramientas/materiales excluidos no figuran en compras ni almacén. Toca para editar.'
                          : 'Excluye herramientas provistas por el cliente, materiales en obra o edita responsables SST.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: excludedCount > 0 ? Colors.amber[700] : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openManagerValidationSheet,
                child: Text(
                  excludedCount > 0 ? 'Modificar' : 'Validar',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
    if (pdfBytes == null) {
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
            try {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: filename,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al compartir archivo PDF: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
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

  String get _projectIdentifier {
    final proj = widget.session.project.proyecto.trim();
    final cont = widget.session.project.contacto.trim();
    if (cont.isNotEmpty && cont != 'N/A' && cont != 'General') {
      return '$proj ($cont)';
    }
    return proj.isNotEmpty ? proj : 'Proyecto General';
  }

  void _shareSupplierQuoteLink() {
    final sheetsService = GoogleSheetsService();
    final materials = widget.session.getValidatedMaterialsWithFrequency();
    final accessories = widget.session.getValidatedConsolidatedAccessories();
    final allItems = [
      ...materials.map((m) => m.name),
      ...accessories,
    ];

    final quoteUrl = sheetsService.getSupplierQuoteUrl(
      _projectIdentifier,
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
    final data = await sheetsService.fetchSupplierQuotes(_projectIdentifier);

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

// ============================================================================
// MODAL DE VALIDACIÓN Y CONTROL PARA EL GESTOR DE PROYECTOS (VIGILARTE V3.6)
// ============================================================================

class _ManagerValidationSheet extends StatefulWidget {
  final ProjectSessionModel session;
  final VoidCallback onSaved;

  const _ManagerValidationSheet({
    required this.session,
    required this.onSaved,
  });

  @override
  State<_ManagerValidationSheet> createState() => _ManagerValidationSheetState();
}

class _ManagerValidationSheetState extends State<_ManagerValidationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  late Set<String> _tempExcludedTools;
  late Set<String> _tempExcludedMaterials;
  late Set<String> _tempExcludedAccessories;

  late TextEditingController _elimCtrl;
  late TextEditingController _sustCtrl;
  late TextEditingController _ingCtrl;
  late TextEditingController _admCtrl;
  late TextEditingController _eppCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tempExcludedTools = Set<String>.from(widget.session.excludedTools);
    _tempExcludedMaterials = Set<String>.from(widget.session.excludedMaterials);
    _tempExcludedAccessories = Set<String>.from(widget.session.excludedAccessories);

    _elimCtrl = TextEditingController(
      text: widget.session.getHierarchyResponsible('eliminacion', 'Cliente / Mantenimiento'),
    );
    _sustCtrl = TextEditingController(
      text: widget.session.getHierarchyResponsible('sustitucion', 'VIGILARTE / Contratista'),
    );
    _ingCtrl = TextEditingController(
      text: widget.session.getHierarchyResponsible('ingenieria', 'Cliente / VIGILARTE'),
    );
    _admCtrl = TextEditingController(
      text: widget.session.getHierarchyResponsible('administracion', 'Supervisor SST VIGILARTE'),
    );
    _eppCtrl = TextEditingController(
      text: widget.session.getHierarchyResponsible('epp', 'Personal Tecnico Instalador'),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _elimCtrl.dispose();
    _sustCtrl.dispose();
    _ingCtrl.dispose();
    _admCtrl.dispose();
    _eppCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() {
    widget.session.excludedTools.clear();
    widget.session.excludedTools.addAll(_tempExcludedTools);

    widget.session.excludedMaterials.clear();
    widget.session.excludedMaterials.addAll(_tempExcludedMaterials);

    widget.session.excludedAccessories.clear();
    widget.session.excludedAccessories.addAll(_tempExcludedAccessories);

    widget.session.customHierarchyResponsibles['eliminacion'] = _elimCtrl.text.trim();
    widget.session.customHierarchyResponsibles['sustitucion'] = _sustCtrl.text.trim();
    widget.session.customHierarchyResponsibles['ingenieria'] = _ingCtrl.text.trim();
    widget.session.customHierarchyResponsibles['administracion'] = _admCtrl.text.trim();
    widget.session.customHierarchyResponsibles['epp'] = _eppCtrl.text.trim();

    Navigator.pop(context);
    widget.onSaved();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Validación aplicada. Reportes de Almacén, Compras y Cliente regenerados.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTools = widget.session.getToolsWithFrequency();
    final allMaterials = widget.session.getMaterialsWithFrequency();
    final allAccessories = widget.session.getConsolidatedAccessories();

    final activeToolsCount = allTools.where((t) => !_tempExcludedTools.contains(t.name)).length;
    final activeMatsCount = allMaterials.where((m) => !_tempExcludedMaterials.contains(m.name)).length;
    final activeAccCount = allAccessories.where((a) => !_tempExcludedAccessories.contains(a)).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Asa superior
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Encabezado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined, color: Color(0xFF38BDF8), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validación del Gestor de Proyectos',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Valida herramientas y materiales antes de pasar a almacén y compras',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // TabBar
            TabBar(
              controller: _tabCtrl,
              indicatorColor: const Color(0xFF38BDF8),
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Herramientas ($activeToolsCount/${allTools.length})'),
                Tab(text: 'Materiales (${activeMatsCount + activeAccCount})'),
                Tab(text: 'Responsables SST'),
              ],
            ),

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildToolsTab(allTools),
                  _buildMaterialsTab(allMaterials, allAccessories),
                  _buildSstTab(),
                ],
              ),
            ),

            // Botón de Guardado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: const Text(
                    'Guardar Validación y Regenerar Reportes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saveChanges,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsTab(List<ItemFrequency> tools) {
    if (tools.isEmpty) {
      return const Center(
        child: Text('No hay herramientas deducidas en el proyecto.', style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desmarca las herramientas que el cliente proporcione o que ya se encuentren en obra para no solicitarlas a Almacén.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...tools.map((t) {
          final isIncluded = !_tempExcludedTools.contains(t.name);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isIncluded ? const Color(0xFF0F172A) : const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isIncluded ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : Colors.white12,
              ),
            ),
            child: SwitchListTile(
              title: Text(
                t.name,
                style: TextStyle(
                  color: isIncluded ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  decoration: isIncluded ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                isIncluded
                    ? '✓ Incluida para Almacén (${t.count} foto/s)'
                    : '✗ Excluida (En obra / Provista por cliente)',
                style: TextStyle(
                  color: isIncluded ? const Color(0xFF4ADE80) : Colors.amberAccent,
                  fontSize: 11,
                ),
              ),
              value: isIncluded,
              activeThumbColor: const Color(0xFF38BDF8),
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _tempExcludedTools.remove(t.name);
                  } else {
                    _tempExcludedTools.add(t.name);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMaterialsTab(List<ItemFrequency> materials, List<String> accessories) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desmarca los materiales o accesorios que el cliente suministre o que existan en stock para no incluirlos en Compras.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sección Materiales
        if (materials.isNotEmpty) ...[
          const Text(
            'CANALIZACIONES Y TUBERÍAS',
            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...materials.map((m) {
            final isIncluded = !_tempExcludedMaterials.contains(m.name);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isIncluded ? const Color(0xFF0F172A) : const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isIncluded ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white12,
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  m.name,
                  style: TextStyle(
                    color: isIncluded ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: isIncluded ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  isIncluded
                      ? '✓ Incluido para Compras (${m.count} foto/s)'
                      : '✗ Excluido (Suministro de cliente / Existente)',
                  style: TextStyle(
                    color: isIncluded ? const Color(0xFF4ADE80) : Colors.amberAccent,
                    fontSize: 11,
                  ),
                ),
                value: isIncluded,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() {
                    if (val) {
                      _tempExcludedMaterials.remove(m.name);
                    } else {
                      _tempExcludedMaterials.add(m.name);
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // Sección Accesorios
        if (accessories.isNotEmpty) ...[
          const Text(
            'ACCESORIOS DEDUCIDOS',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...accessories.map((a) {
            final isIncluded = !_tempExcludedAccessories.contains(a);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isIncluded ? const Color(0xFF0F172A) : const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isIncluded ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white12,
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  a,
                  style: TextStyle(
                    color: isIncluded ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    decoration: isIncluded ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  isIncluded
                      ? '✓ Requerido para cotización/compra'
                      : '✗ Excluido (En stock / Provisto)',
                  style: TextStyle(
                    color: isIncluded ? const Color(0xFF4ADE80) : Colors.amberAccent,
                    fontSize: 11,
                  ),
                ),
                value: isIncluded,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() {
                    if (val) {
                      _tempExcludedAccessories.remove(a);
                    } else {
                      _tempExcludedAccessories.add(a);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSstTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personaliza los responsables en la Matriz de Jerarquía de Control de Riesgos. Útil cuando el cliente solicita incluir trabajos como parte del servicio de VIGILARTE.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildSstLevelCard(
          level: '1. Eliminación',
          color: const Color(0xFF16A34A),
          controller: _elimCtrl,
          suggestions: [
            'Cliente / Mantenimiento',
            'VIGILARTE como parte del servicio',
            'Supervisor SST / VIGILARTE',
          ],
        ),
        const SizedBox(height: 12),

        _buildSstLevelCard(
          level: '2. Sustitución',
          color: const Color(0xFF0D9488),
          controller: _sustCtrl,
          suggestions: [
            'VIGILARTE / Contratista',
            'Cliente / Mantenimiento',
            'VIGILARTE como parte del servicio',
          ],
        ),
        const SizedBox(height: 12),

        _buildSstLevelCard(
          level: '3. Controles de Ingeniería',
          color: const Color(0xFFD97706),
          controller: _ingCtrl,
          suggestions: [
            'Cliente / VIGILARTE',
            'VIGILARTE como parte del servicio',
            'Cliente / Mantenimiento',
          ],
        ),
        const SizedBox(height: 12),

        _buildSstLevelCard(
          level: '4. Controles Administrativos',
          color: const Color(0xFFEA580C),
          controller: _admCtrl,
          suggestions: [
            'Supervisor SST VIGILARTE',
            'Cliente / Supervisor SST',
            'Supervisor SST / VIGILARTE',
          ],
        ),
        const SizedBox(height: 12),

        _buildSstLevelCard(
          level: '5. Equipos de Protección Personal (EPP)',
          color: const Color(0xFFDC2626),
          controller: _eppCtrl,
          suggestions: [
            'Personal Tecnico Instalador',
            'VIGILARTE / Contratista',
          ],
        ),
      ],
    );
  }

  Widget _buildSstLevelCard({
    required String level,
    required Color color,
    required TextEditingController controller,
    required List<String> suggestions,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                level,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Responsable',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: suggestions.map((s) {
              return InkWell(
                onTap: () {
                  setState(() {
                    controller.text = s;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

