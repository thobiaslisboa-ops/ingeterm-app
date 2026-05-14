import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/valve_model.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/valve_card.dart';
import '../widgets/smooth_page_transition.dart';
import 'valve_detail_screen.dart';

class ValvesScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String equipmentName;

  /// false = sin Scaffold/AppBar (para usar dentro de TabBarView)
  final bool showAppBar;

  const ValvesScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.equipmentName,
    this.showAppBar = true,
  });

  @override
  State<ValvesScreen> createState() => _ValvesScreenState();
}

class _ValvesScreenState extends State<ValvesScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _search = '';
  ValveStatus? _filterStatus;

  CollectionReference get _valvesRef => _db
      .collection('clients')
      .doc(widget.clientId)
      .collection('equipments')
      .doc(widget.equipmentId)
      .collection('valves');

  Stream<QuerySnapshot> get _stream =>
      _valvesRef.orderBy('name').snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Agregar válvula ───────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    var selectedType = ValveType.seguridad;
    var selectedStatus = ValveStatus.enOperacion;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Agregar Válvula'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Válvula de seguridad caldera',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(
                    labelText: 'TAG',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: PSV-001',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ValveType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de válvula',
                    border: OutlineInputBorder(),
                  ),
                  items: ValveType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ValveStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Estado inicial',
                    border: OutlineInputBorder(),
                  ),
                  items: ValveStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Icon(s.icon, color: s.color, size: 16),
                                const SizedBox(width: 8),
                                Text(s.label),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedStatus = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _valvesRef.add({
                    'name': nameCtrl.text.trim(),
                    'tag': tagCtrl.text.trim().isEmpty
                        ? null
                        : tagCtrl.text.trim(),
                    'valveType': selectedType.name,
                    'status': selectedStatus.name,
                    'photoUrls': [],
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Válvula agregada')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    tagCtrl.dispose();
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  Future<void> _deleteValve(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar válvula'),
        content: Text(
          '¿Eliminar "$name" y todas sus mantenciones?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final maintenances =
          await doc.reference.collection('maintenances').get();
      for (final m in maintenances.docs) {
        await m.reference.delete();
      }
      await doc.reference.delete();
      messenger.showSnackBar(
          const SnackBar(content: Text('Válvula eliminada')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (!widget.showAppBar) _buildTabHeader(),
        _buildSearchBar(),
        Expanded(child: _buildList()),
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppAppBar(
        title: 'Válvulas',
        subtitle: widget.equipmentName,
        icon: Icons.plumbing,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar válvula',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildTabHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.length;
        final urgent = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['status'] as String?) ==
              ValveStatus.requiereReemplazo.name;
        }).length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.blue.shade800],
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total válvula${total != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (urgent > 0)
                    Text(
                      '$urgent requiere${urgent != 1 ? 'n' : ''} reemplazo',
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 12),
                    ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o TAG…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _search = '';
                        }),
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<ValveStatus?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterStatus != null ? Colors.blue : Colors.grey,
            ),
            tooltip: 'Filtrar por estado',
            onSelected: (s) => setState(() => _filterStatus = s),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              ...ValveStatus.values.map(
                (s) => PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(s.icon, color: s.color, size: 16),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  maxLines: 3, overflow: TextOverflow.ellipsis));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data!.docs;

        if (_search.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['name'] as String? ?? '').toLowerCase();
            final tag = (data['tag'] as String? ?? '').toLowerCase();
            return name.contains(_search) || tag.contains(_search);
          }).toList();
        }

        if (_filterStatus != null) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['status'] as String?) == _filterStatus!.name;
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.plumbing, size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _search.isNotEmpty || _filterStatus != null
                      ? 'No se encontraron válvulas'
                      : 'No hay válvulas registradas',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                if (_search.isEmpty && _filterStatus == null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar primera válvula'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final rawData = doc.data() as Map<String, dynamic>;
            final valve = Valve.fromMap(doc.id, rawData);

            return ValveCard(
              valve: valve,
              onTap: () => _openDetail(valve),
              menuItems: const [
                PopupMenuItem(
                  value: 'detail',
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Ver detalle'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
              onMenuSelected: (action) {
                if (action == 'detail') _openDetail(valve);
                if (action == 'delete') _deleteValve(doc);
              },
            );
          },
        );
      },
    );
  }

  void _openDetail(Valve valve) {
    Navigator.push(
      context,
      SmoothPageTransition(
        page: ValveDetailScreen(
          clientId: widget.clientId,
          equipmentId: widget.equipmentId,
          valveId: valve.id,
          valveName: valve.name,
        ),
      ),
    );
  }
}
