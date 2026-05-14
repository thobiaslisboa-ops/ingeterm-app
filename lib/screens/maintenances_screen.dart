// lib/screens/maintenances_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_model.dart';
import '../providers/user_provider.dart';
import '../widgets/maintenance_card.dart';
import '../widgets/app_app_bar.dart';
import 'maintenance_detail_screen.dart';

class MaintenancesScreen extends StatefulWidget {
  const MaintenancesScreen({super.key});

  @override
  State<MaintenancesScreen> createState() => _MaintenancesScreenState();
}

class _MaintenancesScreenState extends State<MaintenancesScreen> {
  final _db = FirebaseFirestore.instance;
  EstadoMantencion? _filtroEstado;

  Stream<QuerySnapshot> get _streamFiltrado {
    return _db
        .collectionGroup('maintenances')
        .where('tipo', isEqualTo: 'orden_trabajo')
        .orderBy('creadoEn', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: 'Mantenciones',
        icon: Icons.build_circle,
        showBackButton: false,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _streamFiltrado,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = snap.data!.docs;
                final docs = _filtroEstado == null
                    ? allDocs
                    : allDocs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['estado'] == _filtroEstado!.value;
                      }).toList();
                if (docs.isEmpty) return _buildEmpty();
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index]
                          as DocumentSnapshot<Map<String, dynamic>>;
                      final m = MaintenanceModel.fromFirestore(doc);
                      return MaintenanceCard(
                        maintenance: m,
                        clienteNombre: m.clienteNombre.isNotEmpty
                            ? m.clienteNombre
                            : null,
                        equipoNombre: m.equipoNombre.isNotEmpty
                            ? m.equipoNombre
                            : null,
                        onTap: () => _openDetail(m, doc.reference.path),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Mantención'),
        backgroundColor: const Color(0xFF1A5DB5),
      ),
    );
  }

  // ── Filtros de estado ──────────────────────────────────────────────────────

  Widget _buildFiltros() {
    final opciones = [null, ...EstadoMantencion.values];
    return Container(
      height: 44,
      color: Colors.grey[50],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: opciones.length,
        itemBuilder: (_, i) {
          final estado = opciones[i];
          final selected = _filtroEstado == estado;
          final color = estado != null
              ? MaintenanceCard.estadoColor(estado)
              : const Color(0xFF1A5DB5);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(estado?.label ?? 'Todas'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: color,
              checkmarkColor: Colors.white,
              backgroundColor: color.withValues(alpha: 0.08),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              onSelected: (_) => setState(() => _filtroEstado = estado),
            ),
          );
        },
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _filtroEstado != null
                ? 'No hay mantenciones ${_filtroEstado!.label.toLowerCase()}'
                : 'No hay mantenciones registradas',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateSheet,
            icon: const Icon(Icons.add),
            label: const Text('Crear primera mantención'),
          ),
        ],
      ),
    );
  }

  // ── Navegación al detalle ─────────────────────────────────────────────────

  void _openDetail(MaintenanceModel m, String docPath) {
    // Path: clients/{clienteId}/equipments/{equipoId}/maintenances/{id}
    final segments = docPath.split('/');
    final clienteId = segments.length > 1 ? segments[1] : m.clienteId;
    final equipoId = segments.length > 3 ? segments[3] : m.equipoId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceDetailScreen(
          maintenanceId: m.id,
          clienteId: clienteId,
          equipoId: equipoId,
        ),
      ),
    );
  }

  // ── Crear nueva mantención ────────────────────────────────────────────────

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateMaintenanceSheet(
        onCreated: (clienteId, equipoId, maintenanceId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaintenanceDetailScreen(
                maintenanceId: maintenanceId,
                clienteId: clienteId,
                equipoId: equipoId,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sheet para crear nueva mantención
// ═══════════════════════════════════════════════════════════════════════════════

class _CreateMaintenanceSheet extends StatefulWidget {
  final void Function(String clienteId, String equipoId, String maintenanceId)
      onCreated;

  const _CreateMaintenanceSheet({required this.onCreated});

  @override
  State<_CreateMaintenanceSheet> createState() =>
      _CreateMaintenanceSheetState();
}

class _CreateMaintenanceSheetState extends State<_CreateMaintenanceSheet> {
  static const _tiposOpciones = [
    'Prueba hidrostática',
    'Mantención de válvulas de seguridad',
    'Calibración de instrumentos',
  ];

  final _db = FirebaseFirestore.instance;
  final _tecnicoController = TextEditingController();
  final _otroController = TextEditingController();
  final _observacionesController = TextEditingController();

  String? _clienteId;
  String _clienteNombre = '';
  String _tecnicoUid = '';
  // equipoId → nombre para mostrar
  final Map<String, String> _equiposSeleccionados = {};
  final Set<String> _tiposSeleccionados = {};
  bool _otroChecked = false;
  DateTime? _fechaProgramada;
  TimeOfDay? _horaProgramada;
  bool _creando = false;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    _tecnicoController.text = userProvider.nombreCompleto;
    _tecnicoUid = userProvider.uid;
  }

  @override
  void dispose() {
    _tecnicoController.dispose();
    _otroController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  List<String> get _tiposFinales => [
        ..._tiposSeleccionados,
        if (_otroChecked && _otroController.text.trim().isNotEmpty)
          _otroController.text.trim(),
      ];

  String get _tituloGenerado => _tiposFinales.isEmpty
      ? 'Orden de Mantención'
      : _tiposFinales.join(' · ');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Color(0xFF1A5DB5)),
                  SizedBox(width: 10),
                  Text(
                    'Nueva Orden de Mantención',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // ── 1. Cliente ──────────────────────────────────────────────
                  _buildStepLabel('1', 'Cliente'),
                  const SizedBox(height: 8),
                  _buildClienteDropdown(),
                  const SizedBox(height: 16),

                  // ── 2. Equipos ─────────────────────────────────────────────
                  _buildStepLabel('2', 'Equipo/s'),
                  const SizedBox(height: 8),
                  _buildEquipoMultiSelect(),
                  const SizedBox(height: 16),

                  // ── 3. Tipos de trabajo ────────────────────────────────────
                  _buildStepLabel('3', 'Tipos de trabajo'),
                  const SizedBox(height: 8),
                  _buildTiposTrabajoChecklist(),
                  const SizedBox(height: 16),

                  // ── 4. Fecha y hora ────────────────────────────────────────
                  _buildStepLabel('4', 'Fecha y hora programada (opcional)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildFechaPicker()),
                      const SizedBox(width: 8),
                      Expanded(child: _buildHoraPicker()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 5. Técnico ─────────────────────────────────────────────
                  _buildStepLabel('5', 'Técnico asignado'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tecnicoController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre del técnico',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // ── 6. Observaciones ───────────────────────────────────────
                  _buildStepLabel('6', 'Observaciones iniciales (opcional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _observacionesController,
                    decoration: const InputDecoration(
                      hintText: 'Notas previas, condiciones, etc.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 28),

                  // ── Botón crear ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creando ? null : _crear,
                      icon: _creando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(_creando
                          ? 'Creando...'
                          : _equiposSeleccionados.length > 1
                              ? 'Crear ${_equiposSeleccionados.length} mantenciones'
                              : 'Crear Mantención'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5DB5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets del formulario ──────────────────────────────────────────────────

  Widget _buildStepLabel(String number, String label) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF1A5DB5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildClienteDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('clients').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('No hay clientes registrados',
              style: TextStyle(color: Colors.grey));
        }
        return DropdownButtonFormField<String>(
          value: _clienteId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Seleccionar cliente',
          ),
          items: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name'] as String? ?? doc.id),
            );
          }).toList(),
          onChanged: (val) {
            final doc = docs.firstWhere((d) => d.id == val);
            final ddata = doc.data() as Map<String, dynamic>;
            setState(() {
              _clienteId = val;
              _clienteNombre = ddata['name'] as String? ?? '';
              _equiposSeleccionados.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildEquipoMultiSelect() {
    if (_clienteId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Primero selecciona un cliente',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('clients')
          .doc(_clienteId)
          .collection('equipments')
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('No hay equipos para este cliente',
              style: TextStyle(color: Colors.grey));
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final tag = data['tag'] as String?;
              final nombre = tag != null
                  ? '${data['name']} (TAG: $tag)'
                  : data['name'] as String? ?? doc.id;
              final selected = _equiposSeleccionados.containsKey(doc.id);
              return CheckboxListTile(
                dense: true,
                title: Text(nombre, style: const TextStyle(fontSize: 14)),
                value: selected,
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _equiposSeleccionados[doc.id] = nombre;
                  } else {
                    _equiposSeleccionados.remove(doc.id);
                  }
                }),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTiposTrabajoChecklist() {
    return Column(
      children: [
        ..._tiposOpciones.map((tipo) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(tipo, style: const TextStyle(fontSize: 14)),
              value: _tiposSeleccionados.contains(tipo),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _tiposSeleccionados.add(tipo);
                } else {
                  _tiposSeleccionados.remove(tipo);
                }
              }),
            )),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Otro', style: TextStyle(fontSize: 14)),
          value: _otroChecked,
          onChanged: (checked) =>
              setState(() => _otroChecked = checked ?? false),
        ),
        if (_otroChecked)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: TextField(
              controller: _otroController,
              decoration: const InputDecoration(
                hintText: 'Describe el tipo de trabajo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildFechaPicker() {
    final label = _fechaProgramada != null
        ? '${_fechaProgramada!.day.toString().padLeft(2, '0')}/'
            '${_fechaProgramada!.month.toString().padLeft(2, '0')}/'
            '${_fechaProgramada!.year}'
        : 'Fecha';
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _fechaProgramada ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('es', 'CL'),
        );
        if (picked != null) setState(() => _fechaProgramada = picked);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _buildHoraPicker() {
    final label = _horaProgramada != null
        ? '${_horaProgramada!.hour.toString().padLeft(2, '0')}:'
            '${_horaProgramada!.minute.toString().padLeft(2, '0')}'
        : 'Hora';
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _horaProgramada ?? TimeOfDay.now(),
          builder: (context, child) => Localizations.override(
            context: context,
            locale: const Locale('es', 'CL'),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _horaProgramada = picked);
      },
      icon: const Icon(Icons.access_time, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  // ── Lógica de creación ──────────────────────────────────────────────────────

  Future<void> _crear() async {
    final tecnico = _tecnicoController.text.trim();
    final observaciones = _observacionesController.text.trim();

    if (_clienteId == null) {
      _showSnack('Selecciona un cliente');
      return;
    }
    if (_equiposSeleccionados.isEmpty) {
      _showSnack('Selecciona al menos un equipo');
      return;
    }
    if (tecnico.isEmpty) {
      _showSnack('Ingresa el nombre del técnico');
      return;
    }

    setState(() => _creando = true);

    try {
      String? primerClienteId;
      String? primerEquipoId;
      String? primerMaintenanceId;

      for (final entry in _equiposSeleccionados.entries) {
        final equipoId = entry.key;
        final numeroOrden = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        final ref = _db
            .collection('clients')
            .doc(_clienteId)
            .collection('equipments')
            .doc(equipoId)
            .collection('maintenances')
            .doc();

        final model = MaintenanceModel(
          id: ref.id,
          clienteId: _clienteId!,
          clienteNombre: _clienteNombre,
          equipoId: equipoId,
          equipoNombre: entry.value,
          numeroOrden: numeroOrden,
          titulo: _tituloGenerado,
          tecnicoId: _tecnicoUid,
          tecnicoNombre: tecnico,
          estado: EstadoMantencion.programada,
          fechaProgramada: _fechaProgramada,
          horaProgramada: _horaProgramada,
          tiposTrabajo: _tiposFinales,
          observacionesGenerales: observaciones,
          repuestos: const [],
          aumentosObra: const [],
          fotos: const [],
          totalItems: 0,
          itemsCompletados: 0,
          creadoEn: DateTime.now(),
          actualizadoEn: DateTime.now(),
          creadoPor: tecnico,
        );

        await ref.set(model.toMap());

        primerClienteId ??= _clienteId;
        primerEquipoId ??= equipoId;
        primerMaintenanceId ??= ref.id;
      }

      if (mounted) Navigator.pop(context);
      widget.onCreated(primerClienteId!, primerEquipoId!, primerMaintenanceId!);
    } catch (e) {
      setState(() => _creando = false);
      _showSnack('Error al crear: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
