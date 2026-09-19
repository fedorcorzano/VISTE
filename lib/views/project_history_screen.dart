import 'package:flutter/material.dart';
import '../models/session_evidence_model.dart';
import '../services/project_storage_service.dart';
import 'camera_overlay_screen.dart';
import 'project_summary_report_screen.dart';

/// Pantalla de Historial y Recuperación de Proyectos
/// Permite buscar, auditar y generar reportes técnicos en PDF en cualquier momento
class ProjectHistoryScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final bool autoFocusSearch;

  const ProjectHistoryScreen({
    super.key,
    this.initialSearchQuery,
    this.autoFocusSearch = false,
  });

  @override
  State<ProjectHistoryScreen> createState() => _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends State<ProjectHistoryScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  List<ProjectSessionModel> _allSessions = [];
  List<ProjectSessionModel> _filteredSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery ?? '');
    _searchFocusNode = FocusNode();
    _loadSessions();

    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await ProjectStorageService.getAllSessions();
    if (!mounted) return;
    setState(() {
      _allSessions = sessions;
      _applyFilter(_searchController.text);
      _isLoading = false;
    });
  }

  void _applyFilter(String query) {
    if (query.trim().isEmpty) {
      _filteredSessions = List.from(_allSessions);
    } else {
      final q = query.trim().toLowerCase();
      _filteredSessions = _allSessions.where((s) {
        final contacto = s.project.contacto.toLowerCase();
        final proyecto = s.project.proyecto.toLowerCase();
        final fecha = s.project.fecha.toLowerCase();
        final responsable = s.project.responsable.toLowerCase();
        return contacto.contains(q) ||
            proyecto.contains(q) ||
            fecha.contains(q) ||
            responsable.contains(q);
      }).toList();
    }
  }

  Future<void> _confirmDelete(ProjectSessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Eliminar Proyecto', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '¿Deseas eliminar el registro de "${session.project.proyecto}" (${session.project.contacto})?\n\nEsta acción quitará el proyecto del historial.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProjectStorageService.deleteSession(session.id);
      await _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proyecto eliminado del historial'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Historial de Proyectos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
            tooltip: 'Actualizar lista',
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda moderna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1E293B),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) {
                setState(() => _applyFilter(val));
              },
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, proyecto, fecha o gestor...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilter(''));
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
            ),
          ),

          // Lista de proyectos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  )
                : _filteredSessions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSessions,
                        color: const Color(0xFF38BDF8),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSessions.length,
                          itemBuilder: (context, index) {
                            final session = _filteredSessions[index];
                            return _buildProjectCard(session);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasSearch = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.folder_open_rounded,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No se encontraron proyectos'
                  : 'Aún no hay proyectos guardados',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Intenta con otro término de búsqueda.'
                  : 'Cada vez que registres y tomes fotos en un proyecto, se guardará automáticamente aquí para generar tus 5 reportes en cualquier momento.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectSessionModel session) {
    final hazardsCount = session.getConsolidatedHazards().length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la tarjeta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF162032),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.project.proyecto.isNotEmpty
                              ? session.project.proyecto
                              : 'Proyecto sin título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          session.project.contacto.isNotEmpty
                              ? session.project.contacto
                              : 'Sin cliente especificado',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                    tooltip: 'Eliminar proyecto',
                    onPressed: () => _confirmDelete(session),
                  ),
                ],
              ),
            ),

            // Contenido y métricas
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges de información
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        icon: Icons.camera_alt_outlined,
                        label: '${session.totalPhotos} ${session.totalPhotos == 1 ? 'Foto' : 'Fotos'}',
                        color: const Color(0xFF38BDF8),
                      ),
                      _buildBadge(
                        icon: Icons.calendar_today_outlined,
                        label: session.displayDate,
                        color: const Color(0xFF94A3B8),
                      ),
                      if (session.project.responsable.isNotEmpty)
                        _buildBadge(
                          icon: Icons.person_outline,
                          label: session.project.responsable,
                          color: const Color(0xFFA78BFA),
                        ),
                      if (hazardsCount > 0)
                        _buildBadge(
                          icon: Icons.warning_amber_rounded,
                          label: '$hazardsCount Riesgos SST',
                          color: const Color(0xFFF59E0B),
                        ),
                    ],
                  ),

                  if (session.project.direccion.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session.project.direccion,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),

                  // Botones de acción principales
                  Row(
                    children: [
                      // Botón Continuar / Tomar más fotos
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_a_photo, size: 16),
                          label: const Text(
                            'Continuar',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CameraOverlayScreen(
                                  project: session.project,
                                  existingSession: session,
                                ),
                              ),
                            );
                            _loadSessions();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón Generar Reportes PDF
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text(
                            'Generar Reportes',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProjectSummaryReportScreen(session: session),
                              ),
                            );
                            _loadSessions();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
