import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/session_evidence_model.dart';
import '../services/google_sheets_service.dart';
import '../services/project_storage_service.dart';
import '../services/purchasing_report_pdf_service.dart';
import 'welcome_screen.dart';

/// ============================================================================
/// PANTALLA 6: COTIZACIÓN A PROVEEDORES Y FIN DE PROYECTO (VISTEC V3)
/// Etapa final del flujo de trabajo:
/// - Listado ejecutivo de materiales, canalizaciones (metros y tiras) y herramientas
/// - Módulo de envío directo de solicitud de cotización por WhatsApp y enlace
/// - Portal web interactivo donde 3 a 5 proveedores colocan sus precios
/// - Comparativa de cotizaciones en tiempo real con mejor precio destacado
/// - Descarga / Compartición de PDF de compras
/// - Botón definitivo para finalizar y cerrar el proyecto
/// ============================================================================
class SupplierQuotationScreen extends StatefulWidget {
  final ProjectSessionModel session;

  const SupplierQuotationScreen({
    super.key,
    required this.session,
  });

  @override
  State<SupplierQuotationScreen> createState() => _SupplierQuotationScreenState();
}

class _SupplierQuotationScreenState extends State<SupplierQuotationScreen> {
  Uint8List? _purchasingPdfBytes;
  bool _isLoadingPdf = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPurchasingPdf();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchasingPdf() async {
    setState(() => _isLoadingPdf = true);
    try {
      final bytes = await PurchasingReportPdfService.generatePdf(widget.session);
      if (mounted) {
        setState(() {
          _purchasingPdfBytes = bytes;
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      debugPrint('Error generando PDF de compras: $e');
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  String get _projectIdentifier {
    final proj = widget.session.project.proyecto.trim();
    final cont = widget.session.project.contacto.trim();
    if (cont.isNotEmpty && cont != 'N/A' && cont != 'General') {
      return '$proj ($cont)';
    }
    return proj.isNotEmpty ? proj : 'Proyecto General';
  }

  List<String> _getAllQuotationItems() {
    final conduits = widget.session.getConduitCalculation();
    final materials = widget.session.getValidatedMaterialsWithFrequency();
    final accessories = widget.session.getValidatedConsolidatedAccessories();

    final allItems = <String>[];
    for (final c in conduits) {
      final mat = c['material'];
      final pieces = c['pieces'];
      allItems.add('$mat ($pieces tiras de 3m)');
    }
    for (final m in materials) {
      allItems.add(m.name);
    }
    for (final a in accessories) {
      allItems.add(a);
    }

    // Controles SST que cotiza VIGILARTE
    for (final photo in widget.session.photos) {
      for (final entry in photo.photoHierarchyResponsibility.entries) {
        if (entry.value.toUpperCase() == 'VIGILARTE') {
          final desc = photo.getControlDescription(entry.key);
          if (desc.isNotEmpty && !allItems.contains(desc)) {
            allItems.add(desc);
          }
        }
      }
    }
    return allItems;
  }

  /// Genera y comparte el enlace público del portal web para 3 a 5 proveedores
  void _shareSupplierQuoteLink() {
    final sheetsService = GoogleSheetsService();
    final allItems = _getAllQuotationItems();
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
            Expanded(
              child: Text(
                'Enlace para Proveedores',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puedes enviar este enlace a 3, 4 o 5 ferreterías o distribuidores. Cada proveedor abrirá el enlace en su navegador, verá la lista de insumos requeridos y colocará en los cuadros de texto sus costos unitarios y plazos de entrega:',
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
            const SizedBox(height: 8),
            Text(
              '(${allItems.length} ítems incluidos en la cotización web)',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
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

  /// Consulta las cotizaciones enviadas por los diferentes proveedores y muestra la comparativa
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

    // Agrupar por proveedor y calcular sumatoria
    final Map<String, double> supplierTotals = {};
    for (final q in quotes) {
      if (q is Map) {
        final supp = q['supplier']?.toString() ?? 'Proveedor';
        final price = (q['price'] is num) ? (q['price'] as num).toDouble() : 0.0;
        supplierTotals[supp] = (supplierTotals[supp] ?? 0.0) + price;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.compare_arrows, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comparativa (${quotes.length} cotizaciones)',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: quotes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.amber, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Aún no se han recibido cotizaciones de proveedores para este proyecto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Envía el enlace web a 3 o 5 proveedores para que ingresen sus costos en los cuadros de texto y puedas compararlos aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Resumen comparativo de proveedores participantes
                    if (supplierTotals.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📊 Resumen de Proveedores Evaluados:',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ...supplierTotals.entries.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('• ${entry.key}:', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  Text(
                                    'S/. ${entry.value.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                    Flexible(
                      child: ListView.separated(
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
                                    child: const Text(
                                      'MEJOR PRECIO',
                                      style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          if (quotes.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copiar Reporte Comparativo', style: TextStyle(fontSize: 11)),
              onPressed: () {
                final buf = StringBuffer();
                buf.writeln('📊 *REPORTE COMPARATIVO DE PRECIOS - ${widget.session.project.proyecto}*');
                for (final q in quotes) {
                  final item = q['item'] ?? '';
                  final price = q['price'] ?? 0;
                  final supp = q['supplier'] ?? 'Proveedor';
                  final isBest = minPrices[item] != null && minPrices[item]['supplier'] == supp;
                  buf.writeln('• $item: S/. $price ($supp) ${isBest ? "★ MEJOR PRECIO" : ""}');
                }
                Clipboard.setData(ClipboardData(text: buf.toString()));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Reporte comparativo copiado al portapapeles.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  /// Construye el mensaje estructurado de cotización para WhatsApp o correo
  String _buildQuotationMessage() {
    final buffer = StringBuffer();
    final p = widget.session.project;
    final conduits = widget.session.getConduitCalculation();
    final materials = widget.session.getValidatedMaterialsWithFrequency();
    final accessories = widget.session.getValidatedConsolidatedAccessories();

    buffer.writeln('📋 *SOLICITUD DE COTIZACIÓN DE MATERIALES*');
    buffer.writeln('🏢 *Empresa:* VIGILARTE SEGURIDAD ELECTRÓNICA');
    buffer.writeln('📁 *Proyecto:* ${p.proyecto} (${p.clasificacion})');
    buffer.writeln('📍 *Ubicación:* ${p.direccion}');
    buffer.writeln('👤 *Gestor:* ${p.responsable}');
    buffer.writeln('📅 *Fecha:* ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('');

    if (conduits.isNotEmpty) {
      buffer.writeln('🔹 *1. TUBERÍAS Y CANALIZACIONES (METRADO REAL):*');
      for (final c in conduits) {
        final mat = c['material'];
        final meters = (c['meters'] as double).toStringAsFixed(2);
        final pieces = c['pieces'];
        buffer.writeln('• $mat: $meters metros ➔ *$pieces tiras/tubos* (tramos de 3m)');
      }
      buffer.writeln('');
    }

    if (materials.isNotEmpty) {
      buffer.writeln('🔹 *2. MATERIALES PRINCIPALES:*');
      for (final m in materials) {
        final star = m.isIndispensable ? ' ★' : '';
        buffer.writeln('• ${m.name}$star (${m.frequencyDescription})');
      }
      buffer.writeln('');
    }

    if (accessories.isNotEmpty) {
      buffer.writeln('🔹 *3. ACCESORIOS DE INSTALACIÓN:*');
      for (final a in accessories) {
        buffer.writeln('• $a');
      }
      buffer.writeln('');
    }

    // Controles SST que cotiza VIGILARTE
    final vigilarteControls = <String>[];
    for (final photo in widget.session.photos) {
      for (final entry in photo.photoHierarchyResponsibility.entries) {
        if (entry.value.toUpperCase() == 'VIGILARTE') {
          final desc = photo.getControlDescription(entry.key);
          if (desc.isNotEmpty && !vigilarteControls.contains(desc)) {
            vigilarteControls.add(desc);
          }
        }
      }
    }

    if (vigilarteControls.isNotEmpty) {
      buffer.writeln('🔹 *4. IMPLEMENTOS DE SEGURIDAD SST REQUERIDOS (VIGILARTE):*');
      for (final sst in vigilarteControls) {
        buffer.writeln('• $sst');
      }
      buffer.writeln('');
    }

    if (_notesController.text.trim().isNotEmpty) {
      buffer.writeln('📝 *Notas adicionales:* ${_notesController.text.trim()}');
      buffer.writeln('');
    }

    // Enlace Web para que los proveedores completen sus precios directamente
    final quoteUrl = GoogleSheetsService().getSupplierQuoteUrl(
      _projectIdentifier,
      items: _getAllQuotationItems(),
    );
    buffer.writeln('🌐 *Portal Web para Registrar Precios:*');
    buffer.writeln(quoteUrl);
    buffer.writeln('');

    buffer.writeln('Favor remitir cotización con tiempos de entrega y disponibilidad. Gracias.');
    return buffer.toString();
  }

  /// Envía la solicitud de cotización directamente por WhatsApp
  Future<void> _sendQuotationViaWhatsApp() async {
    final message = _buildQuotationMessage();
    final encoded = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('whatsapp://send?text=$encoded');
    final webWhatsappUrl = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else if (await canLaunchUrl(webWhatsappUrl)) {
        await launchUrl(webWhatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp no disponible. Mensaje copiado al portapapeles.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copiado al portapapeles: $e'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  /// Copia el texto completo de cotización al portapapeles
  Future<void> _copyQuotationToClipboard() async {
    final text = _buildQuotationMessage();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Solicitud de cotización copiada al portapapeles.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Comparte o imprime el PDF oficial de compras para proveedores
  Future<void> _sharePurchasingPdf() async {
    if (_purchasingPdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generando PDF... por favor espere')),
      );
      return;
    }
    await Printing.sharePdf(
      bytes: _purchasingPdfBytes!,
      filename: 'Cotizacion_Proveedores_${widget.session.id}.pdf',
    );
  }

  /// Finaliza y cierra el proyecto, regresando a la pantalla principal
  Future<void> _finalizeAndCloseProject() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text(
              'Cerrar Proyecto',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '¿Deseas finalizar el relevamiento y cotización del proyecto "${widget.session.project.proyecto}"?\n\nToda la información ha sido guardada.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Sí, Finalizar Proyecto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Guardar estado final del proyecto en almacenamiento
    await ProjectStorageService.saveSession(widget.session);

    if (!mounted) return;

    // Diálogo de éxito
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Proyecto Finalizado con Éxito!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'El flujo de 6 etapas para "${widget.session.project.proyecto}" ha concluido correctamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Regresa a la pantalla de Generación de Reportes
              },
              icon: const Icon(Icons.assessment_outlined, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              label: const Text(
                'Volver a Generación de Reportes',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('Cerrar y volver al inicio', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conduits = widget.session.getConduitCalculation();
    final materials = widget.session.getValidatedMaterialsWithFrequency();
    final tools = widget.session.getValidatedToolsWithFrequency();
    final p = widget.session.project;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.request_quote, color: Color(0xFF10B981), size: 18),
                SizedBox(width: 6),
                Text(
                  'Fase 6: Cotización a Proveedores',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '${p.proyecto} • ${p.clasificacion}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner superior ejecutivo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront, color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumen Ejecutivo para Compras',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cálculo de tiras comerciales de tubería (${widget.session.totalLinearMeters.toStringAsFixed(1)} m lineales) y requerimientos de insumos.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD: PORTAL WEB PARA PROVEEDORES (COMPARADOR DE 3 A 5 PROVEEDORES)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2B48), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.public, color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Portal Web de Cotizaciones a Proveedores',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Envía el enlace a 3 a 5 ferreterías para comparar costos unitarios',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareSupplierQuoteLink,
                            icon: const Icon(Icons.link, color: Colors.white, size: 16),
                            label: const Text(
                              'Generar Enlace Web',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _viewSupplierQuotesDialog,
                            icon: const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 16),
                            label: const Text(
                              'Comparar Precios',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botones de acción rápida: WhatsApp / Copiar / PDF
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sendQuotationViaWhatsApp,
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyQuotationToClipboard,
                      icon: const Icon(Icons.copy, color: Color(0xFF38BDF8), size: 18),
                      label: const Text(
                        'Copiar Texto',
                        style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sharePurchasingPdf,
                    icon: _isLoadingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.all(12),
                    ),
                    tooltip: 'Compartir PDF de Compras',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECCIÓN 1: CANALIZACIONES Y TUBERÍAS (Cálculo en Tiras)
              _buildSectionCard(
                title: 'Canalizaciones y Tuberías (Metrado Real)',
                icon: Icons.straighten,
                accentColor: const Color(0xFFE3A51A),
                content: conduits.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No se trazaron cotas lineales con canalizaciones.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : Column(
                        children: conduits.map((c) {
                          final mat = c['material'] as String;
                          final meters = (c['meters'] as double).toStringAsFixed(2);
                          final pieces = c['pieces'] as int;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3A51A).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.cable, color: Color(0xFFE3A51A), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mat,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Metrado total: $meters m',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE3A51A), width: 1),
                                  ),
                                  child: Text(
                                    '$pieces ${pieces == 1 ? 'tira' : 'tiras'} (3m)',
                                    style: const TextStyle(
                                      color: Color(0xFFE3A51A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 2: MATERIALES PRINCIPALES
              _buildSectionCard(
                title: 'Materiales & Canalizaciones Consolidados',
                icon: Icons.hardware,
                accentColor: const Color(0xFF00E676),
                content: materials.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No hay materiales registrados.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : Column(
                        children: materials.map((m) {
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: m.isIndispensable ? const Color(0xFF00E676) : Colors.white38,
                              size: 18,
                            ),
                            title: Text(
                              m.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              m.frequencyDescription,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            trailing: m.isIndispensable
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'INDISPENSABLE',
                                      style: TextStyle(
                                        color: Color(0xFF00E676),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 3: HERRAMIENTAS VITALES
              _buildSectionCard(
                title: 'Herramientas Necesarias para Instalación',
                icon: Icons.handyman,
                accentColor: const Color(0xFF38BDF8),
                content: tools.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No se dedujeron herramientas.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tools.map((t) {
                          return Chip(
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(
                              color: t.isIndispensable ? const Color(0xFF38BDF8) : Colors.white12,
                            ),
                            label: Text(
                              t.name,
                              style: TextStyle(
                                color: t.isIndispensable ? const Color(0xFF38BDF8) : Colors.white70,
                                fontSize: 11,
                                fontWeight: t.isIndispensable ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),

              // Campo de notas para la orden de compra
              TextField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Observaciones o condiciones para la cotización (opcional)',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // BOTÓN FINALIZAR Y CERRAR PROYECTO
              ElevatedButton.icon(
                onPressed: _finalizeAndCloseProject,
                icon: const Icon(Icons.flag, color: Colors.white, size: 22),
                label: const Text(
                  '🏁 Finalizar y Cerrar Proyecto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          content,
        ],
      ),
    );
  }
}
