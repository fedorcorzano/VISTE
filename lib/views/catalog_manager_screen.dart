import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/catalog_visual_service.dart';
import '../services/google_sheets_service.dart';

class CatalogManagerScreen extends StatefulWidget {
  final String? initialSearch;

  const CatalogManagerScreen({super.key, this.initialSearch});

  @override
  State<CatalogManagerScreen> createState() => _CatalogManagerScreenState();
}

class _CatalogManagerScreenState extends State<CatalogManagerScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'TODAS';
  bool _onlyPending = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchCtrl.text = widget.initialSearch!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VisualCatalogItem> _getFilteredItems() {
    final allItems = CatalogVisualService.getAllRegisteredItems();
    final query = _searchCtrl.text.trim().toLowerCase();

    return allItems.where((item) {
      // Filtro por texto
      if (query.isNotEmpty) {
        final matchTitle = item.title.toLowerCase().contains(query);
        final matchCommercial = item.commercialName.toLowerCase().contains(query);
        final matchSpec = item.specification.toLowerCase().contains(query);
        if (!matchTitle && !matchCommercial && !matchSpec) {
          return false;
        }
      }

      // Filtro por categoría
      if (_selectedCategory != 'TODAS') {
        final cat = item.category.toLowerCase();
        if (_selectedCategory == 'HERRAMIENTAS' && !cat.contains('herram')) return false;
        if (_selectedCategory == 'MATERIALES' && !cat.contains('mat')) return false;
        if (_selectedCategory == 'ACCESORIOS' && !cat.contains('acc') && !cat.contains('consum')) return false;
      }

      // Filtro de solo pendientes de foto
      if (_onlyPending && item.imageUrl.isNotEmpty && item.imageUrl.startsWith('http')) {
        return false;
      }

      return true;
    }).toList();
  }

  // Sincronizar masivamente desde Google Drive (Método 2)
  Future<void> _triggerDriveSync() async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Sincronizando fotos desde carpeta Google Drive...', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 2),
      ),
    );

    final res = await _sheetsService.syncDriveCatalog();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Tomar foto con cámara o elegir de galería (Método 1)
  Future<void> _capturePhotoForItem(VisualCatalogItem item, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );

      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      if (!mounted) return;

      // Mostrar diálogo de confirmación y vista previa
      _showUploadConfirmDialog(item, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar imagen: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // Diálogo de confirmación antes de subir a Google Drive y Sheets
  void _showUploadConfirmDialog(VisualCatalogItem item, Uint8List imageBytes) {
    final commercialCtrl = TextEditingController(text: item.commercialName);
    final specCtrl = TextEditingController(text: item.specification);
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined, color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guardar Foto: ${item.title}',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vista previa de la foto capturada
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Nombre Comercial / Ferretero:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: commercialCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'Especificación para Cotizaciones:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: specCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'Se subirá a la carpeta Google Drive (VIGILARTE_CATALOGO_FOTOS) y se actualizará automáticamente la pestaña CATALOGO_VISUAL en Excel.',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton.icon(
                onPressed: isUploading
                    ? null
                    : () async {
                        setDialogState(() => isUploading = true);
                        final messenger = ScaffoldMessenger.of(context);

                        final res = await _sheetsService.uploadCatalogImage(
                          itemName: item.title,
                          category: item.category,
                          commercialName: commercialCtrl.text.trim(),
                          specification: specCtrl.text.trim(),
                          imageBytes: imageBytes,
                        );

                        if (!mounted) return;
                        if (dialogCtx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        setState(() {}); // Refrescar lista

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload, size: 16),
                label: Text(isUploading ? 'Subiendo...' : 'Guardar en Catálogo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modal para elegir Cámara o Galería
  void _showSourceSelectionModal(VisualCatalogItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_a_photo_outlined, color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Asignar Foto: ${item.title}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Toma una foto real del producto o selecciona una imagen de catálogo.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 20),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
              ),
              title: const Text('Tomar Foto con Cámara', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Fotografiar herramienta u objeto físico en campo', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.of(ctx).pop();
                _capturePhotoForItem(item, ImageSource.camera);
              },
            ),
            const Divider(color: Color(0xFF334155)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: Color(0xFF38BDF8)),
              ),
              title: const Text('Seleccionar de Galería', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Elegir foto guardada o descargada de catálogo comercial', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.of(ctx).pop();
                _capturePhotoForItem(item, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo para registrar un ítem nuevo personalizado (en caliente)
  void _showAddNewItemDialog() {
    final nameCtrl = TextEditingController();
    final commercialCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    String category = 'Herramienta';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 8),
                Text('Nuevo Ítem de Catálogo', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nombre Técnico:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ej. Escalera dieléctrica 24 pasos',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text('Categoría:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: category,
                      dropdownColor: const Color(0xFF0F172A),
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'Herramienta', child: Text('Herramienta')),
                        DropdownMenuItem(value: 'Material', child: Text('Material')),
                        DropdownMenuItem(value: 'Accesorio', child: Text('Accesorio')),
                        DropdownMenuItem(value: 'Consumible', child: Text('Consumible')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text('Nombre Comercial:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: commercialCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Nombre de ferretería o tienda',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text('Especificación:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: specCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Medidas, potencia, material...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final newItem = VisualCatalogItem(
                    title: name,
                    category: category,
                    commercialName: commercialCtrl.text.trim().isNotEmpty ? commercialCtrl.text.trim() : name,
                    specification: specCtrl.text.trim().isNotEmpty ? specCtrl.text.trim() : 'Registrado en catálogo',
                    imageUrl: '',
                    fallbackIcon: category.toLowerCase().contains('mat') ? Icons.inventory_2 : Icons.handyman,
                    badgeColor: category.toLowerCase().contains('mat') ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8),
                  );

                  CatalogVisualService.setSingleItem(newItem);
                  Navigator.of(ctx).pop();
                  setState(() {});

                  // Abrir modal de foto inmediatamente
                  _showSourceSelectionModal(newItem);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Continuar a Foto'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.photo_camera_back, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('Catálogo Visual VIGILARTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar Fotos desde Google Drive',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                  )
                : const Icon(Icons.sync, color: Color(0xFF38BDF8)),
            onPressed: _isSyncing ? null : _triggerDriveSync,
          ),
          IconButton(
            tooltip: 'Agregar Nuevo Ítem',
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
            onPressed: _showAddNewItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Superior Explicativo (Método 1 y 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_outlined, color: Color(0xFF38BDF8), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Base de Datos Visual de Herramientas & Materiales',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '• Método 1: Toca [📷 Foto] para capturar con la cámara.\n• Método 2: Suelta fotos en Google Drive (VIGILARTE_CATALOGO_FOTOS) y presiona Sincronizar.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Buscador y Filtros
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar herramienta, material o accesorio...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),

                // Filtros por Categoría y Pendientes
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('TODAS'),
                      _buildFilterChip('HERRAMIENTAS'),
                      _buildFilterChip('MATERIALES'),
                      _buildFilterChip('ACCESORIOS'),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _onlyPending,
                        label: const Text('Solo sin foto', style: TextStyle(fontSize: 11)),
                        labelStyle: TextStyle(
                          color: _onlyPending ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: const Color(0xFF1E293B),
                        selectedColor: const Color(0xFFF59E0B),
                        checkmarkColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (val) => setState(() => _onlyPending = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contador de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredItems.length} elementos encontrados',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (_isSyncing)
                  const Text('Sincronizando con Drive...', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Lista de Ítems
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text('No se encontraron elementos', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAddNewItemDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agregar Nuevo al Catálogo'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      final hasPhoto = item.imageUrl.isNotEmpty && item.imageUrl.startsWith('http');

                      return Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: hasPhoto ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Miniatura de Foto Real o Placeholder
                              GestureDetector(
                                onTap: () => _showSourceSelectionModal(item),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: hasPhoto ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                      width: 1.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: hasPhoto
                                      ? Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Icon(item.fallbackIcon, color: item.badgeColor, size: 28),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(item.fallbackIcon, color: const Color(0xFFF59E0B), size: 24),
                                            const SizedBox(height: 2),
                                            const Text('+ Foto', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Información Técnica del Ítem
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: hasPhoto ? const Color(0xFF065F46) : const Color(0xFF78350F),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            hasPhoto ? 'FOTO CONFORME' : 'SIN FOTO',
                                            style: TextStyle(
                                              color: hasPhoto ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.commercialName,
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.specification,
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Botón de Acción para Tomar / Cambiar Foto
                              IconButton(
                                tooltip: hasPhoto ? 'Cambiar Foto' : 'Tomar Foto',
                                icon: Icon(
                                  hasPhoto ? Icons.edit_outlined : Icons.add_a_photo,
                                  color: hasPhoto ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                                  size: 20,
                                ),
                                onPressed: () => _showSourceSelectionModal(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: const TextStyle(fontSize: 11)),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: const Color(0xFF38BDF8),
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (_) => setState(() => _selectedCategory = label),
      ),
    );
  }
}
