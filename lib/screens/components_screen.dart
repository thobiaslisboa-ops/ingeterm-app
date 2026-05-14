import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/component_model.dart';
import '../widgets/component_card.dart';
import '../widgets/smooth_page_transition.dart';
import 'component_detail_screen.dart';

class ComponentsScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String equipmentName;

  const ComponentsScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  State<ComponentsScreen> createState() => _ComponentsScreenState();
}

class _ComponentsScreenState extends State<ComponentsScreen> {
  ComponentType? _filterTipo;
  ComponentStatus? _filterEstado;

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('equipments')
          .doc(widget.equipmentId)
          .collection('components');

  void _goToDetail({String? componentId}) {
    Navigator.push(
      context,
      SmoothPageTransition(
        page: ComponentDetailScreen(
          clientId: widget.clientId,
          equipmentId: widget.equipmentId,
          componentId: componentId,
        ),
      ),
    );
  }

  Future<void> _deleteComponent(
      String componentId, List<String> fotos) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Componente'),
        content: const Text(
          '¿Eliminar este componente?\n\n'
          'También se eliminarán todas sus mantenciones y fotos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final docRef = _ref.doc(componentId);

      // Sub-componentes
      final subSnap = await docRef.collection('sub_components').get();
      for (final sub in subSnap.docs) {
        await sub.reference.delete();
      }

      // Mantenciones y sus fotos
      final mainSnap = await docRef.collection('maintenances').get();
      for (final m in mainSnap.docs) {
        final photosSnap = await m.reference.collection('photos').get();
        for (final p in photosSnap.docs) {
          final url = (p.data()['url'] as String?) ?? '';
          if (url.isNotEmpty) {
            try {
              await FirebaseStorage.instance.refFromURL(url).delete();
            } catch (_) {}
          }
          await p.reference.delete();
        }
        await m.reference.delete();
      }

      // Fotos del componente
      for (final url in fotos) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }

      await docRef.delete();
      messenger.showSnackBar(const SnackBar(
        content: Text('Componente eliminado'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];

        // Convertir a modelo y ordenar por fecha de creación
        final all = allDocs
            .map((d) => ComponentModel.fromFirestore(d))
            .toList()
          ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

        // Aplicar filtros
        final filtered = all.where((c) {
          if (_filterTipo != null && c.tipo != _filterTipo) return false;
          if (_filterEstado != null && c.estado != _filterEstado) return false;
          return true;
        }).toList();

        return Column(
          children: [
            _buildHeader(all.length),
            _buildFilterBar(),
            Expanded(child: _buildList(snapshot, filtered)),
          ],
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade700],
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count componente${count != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Instrumentos y accesorios',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _goToDetail(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de filtros ──────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ComponentType?>(
              initialValue: _filterTipo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos'),
                ),
                ...ComponentType.values.map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 14, color: t.color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(t.label,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (t) => setState(() => _filterTipo = t),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<ComponentStatus?>(
              initialValue: _filterEstado,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos'),
                ),
                ...ComponentStatus.values.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 14, color: s.color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(s.label,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (s) => setState(() => _filterEstado = s),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista ─────────────────────────────────────────────────────────────────

  Widget _buildList(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<ComponentModel> components,
  ) {
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (components.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off_outlined,
                size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _filterTipo != null || _filterEstado != null
                  ? 'Sin resultados para el filtro aplicado'
                  : 'No hay componentes registrados',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_filterTipo == null && _filterEstado == null)
              ElevatedButton.icon(
                onPressed: () => _goToDetail(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar componente'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: components.length,
      itemBuilder: (_, i) {
        final c = components[i];
        return ComponentCard(
          component: c,
          onTap: () => _goToDetail(componentId: c.id),
          onEdit: () => _goToDetail(componentId: c.id),
          onDelete: () => _deleteComponent(c.id, c.fotos),
        );
      },
    );
  }
}
