import 'package:flutter/material.dart';
import '../models/session_evidence_model.dart';
import '../services/project_storage_service.dart';

/// Abre el modal de Validación del Gestor de Proyectos (Herramientas, Materiales y Responsables de SST)
Future<void> showManagerValidationSheet({
  required BuildContext context,
  required ProjectSessionModel session,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ManagerValidationSheet(
      session: session,
      onSaved: onSaved,
    ),
  );
}

/// ============================================================================
/// MODAL DE VALIDACIÓN Y CONTROL PARA EL GESTOR DE PROYECTOS (VIGILARTE V3.6)
/// ============================================================================
class ManagerValidationSheet extends StatefulWidget {
  final ProjectSessionModel session;
  final VoidCallback onSaved;

  const ManagerValidationSheet({
    super.key,
    required this.session,
    required this.onSaved,
  });

  @override
  State<ManagerValidationSheet> createState() => _ManagerValidationSheetState();
}

class _ManagerValidationSheetState extends State<ManagerValidationSheet>
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

  Future<void> _saveChanges() async {
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

    widget.onSaved();

    if (mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Validación guardada. Herramientas, materiales y SST actualizados.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }

    // Persistir de inmediato en almacenamiento local para no perder validaciones
    try {
      await ProjectStorageService.saveSession(widget.session);
    } catch (e) {
      debugPrint('Error guardando validación en disco: $e');
    }
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
                          'Valida herramientas, materiales y responsables de SST para almacén, compras y cliente',
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
                    'Guardar Validación y Actualizar Reportes',
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
            child: Material(
              color: Colors.transparent,
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
              child: Material(
                color: Colors.transparent,
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
              child: Material(
                color: Colors.transparent,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                level,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Responsable Asignado',
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                backgroundColor: const Color(0xFF1E293B),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () => controller.text = s,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
