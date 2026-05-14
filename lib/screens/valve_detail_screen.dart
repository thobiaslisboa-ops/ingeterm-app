import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/valve_model.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/photo_manager_widget.dart';

class ValveDetailScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String valveId;
  final String valveName;

  const ValveDetailScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.valveId,
    required this.valveName,
  });

  @override
  State<ValveDetailScreen> createState() => _ValveDetailScreenState();
}

class _ValveDetailScreenState extends State<ValveDetailScreen> {
  final _db = FirebaseFirestore.instance;

  bool _isEditing = false;
  bool _isSaving = false;

  // Controladores de edición
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _setPointCtrl = TextEditingController();
  final _cutPointCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  ValveStatus _editStatus = ValveStatus.enOperacion;
  ValveType _editValveType = ValveType.seguridad;

  DocumentReference<Map<String, dynamic>> get _valveRef => _db
      .collection('clients')
      .doc(widget.clientId)
      .collection('equipments')
      .doc(widget.equipmentId)
      .collection('valves')
      .doc(widget.valveId);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _descCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _setPointCtrl.dispose();
    _cutPointCtrl.dispose();
    _unitCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Edición ───────────────────────────────────────────────────────────────

  void _startEditing(Valve v) {
    _nameCtrl.text = v.name;
    _tagCtrl.text = v.tag ?? '';
    _descCtrl.text = v.description ?? '';
    _brandCtrl.text = v.brand ?? '';
    _modelCtrl.text = v.model ?? '';
    _serialCtrl.text = v.serialNumber ?? '';
    _setPointCtrl.text = v.setPoint?.toString() ?? '';
    _cutPointCtrl.text = v.cutPoint?.toString() ?? '';
    _unitCtrl.text = v.unit ?? '';
    _locationCtrl.text = v.locationInEquipment ?? '';
    _notesCtrl.text = v.technicianNotes ?? '';
    _editStatus = v.status;
    _editValveType = v.valveType;
    setState(() => _isEditing = true);
  }

  Future<void> _saveEditing() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _valveRef.update({
        'name': _nameCtrl.text.trim(),
        'tag': _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'brand':
            _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'model':
            _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        'serialNumber':
            _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        'setPoint': double.tryParse(_setPointCtrl.text.trim()),
        'cutPoint': double.tryParse(_cutPointCtrl.text.trim()),
        'unit': _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        'valveType': _editValveType.name,
        'status': _editStatus.name,
        'locationInEquipment':
            _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'technicianNotes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  // ── Reemplazo ─────────────────────────────────────────────────────────────

  Future<void> _showReplaceDialog(Valve current) async {
    final snap = await _db
        .collection('clients')
        .doc(widget.clientId)
        .collection('equipments')
        .doc(widget.equipmentId)
        .collection('valves')
        .where('status', isEqualTo: ValveStatus.enBodegaCliente.name)
        .get();

    final candidates =
        snap.docs.where((d) => d.id != widget.valveId).toList();

    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay válvulas disponibles en bodega')),
      );
      return;
    }

    String? selectedId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Reemplazar válvula'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Válvula que sale
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.outbox,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sale: ${current.name}'
                          '${current.tag != null ? '  (${current.tag})' : ''}',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Seleccionar válvula de bodega:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...candidates.map((doc) {
                  final d = doc.data();
                  final name = d['name'] as String? ?? '';
                  final tag = d['tag'] as String?;
                  final isSelected = selectedId == doc.id;
                  return GestureDetector(
                    onTap: () => setDlg(() => selectedId = doc.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.green.shade300
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color:
                                isSelected ? Colors.green : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (tag != null && tag.isNotEmpty)
                                  Text('TAG: $tag',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _performReplacement(selectedId!);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
              child: const Text('Confirmar reemplazo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performReplacement(String newValveId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final batch = _db.batch();
      final now = Timestamp.now();

      // Válvula actual → va a bodega, queda registrado el reemplazo
      batch.update(_valveRef, {
        'status': ValveStatus.enBodegaCliente.name,
        'replacedByValveId': newValveId,
        'replacementDate': now,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Válvula de bodega → pasa a operación
      final newRef = _db
          .collection('clients')
          .doc(widget.clientId)
          .collection('equipments')
          .doc(widget.equipmentId)
          .collection('valves')
          .doc(newValveId);
      batch.update(newRef, {
        'status': ValveStatus.enOperacion.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Reemplazo registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Error al registrar reemplazo: $e')));
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _valveRef.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppAppBar(
                title: widget.valveName,
                icon: Icons.plumbing,
                showBackButton: true),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        if (!snap.hasData || snap.data?.exists == false) {
          return Scaffold(
            appBar: AppAppBar(
                title: widget.valveName,
                icon: Icons.plumbing,
                showBackButton: true),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final valve = Valve.fromFirestore(snap.data!);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppAppBar(
            title: _isEditing ? 'Editando válvula' : valve.name,
            subtitle: valve.tag?.isNotEmpty == true
                ? valve.tag
                : valve.valveType.label,
            icon: Icons.plumbing,
            showBackButton: true,
            actions: _buildAppBarActions(valve),
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_isEditing) _buildStatusBanner(valve),
                if (!_isEditing) const SizedBox(height: 16),
                _buildSection(
                  title: 'Identificación',
                  icon: Icons.label_outline,
                  child: _buildIdentificationFields(valve),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Valores Técnicos',
                  icon: Icons.tune,
                  child: _buildTechnicalFields(valve),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Estado en Terreno',
                  icon: Icons.location_on_outlined,
                  child: _buildStatusFields(valve),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Fotos',
                  icon: Icons.photo_library_outlined,
                  child: _buildPhotosSection(valve),
                ),
                if (valve.status != ValveStatus.enBodegaCliente) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    title: 'Reemplazo',
                    icon: Icons.swap_horiz,
                    child: _buildReplacementSection(valve),
                  ),
                ],
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Historial de Mantenciones',
                  icon: Icons.history,
                  child: _buildMaintenanceHistory(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(Valve valve) {
    if (_isSaving) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ),
        ),
      ];
    }
    if (_isEditing) {
      return [
        TextButton(
          onPressed: () => setState(() => _isEditing = false),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _saveEditing,
          child: const Text('Guardar',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Editar',
        onPressed: () => _startEditing(valve),
      ),
    ];
  }

  // ── Status banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner(Valve valve) {
    final color = valve.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(valve.status.icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valve.status.label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                if (valve.updatedAt != null)
                  Text(
                    'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(valve.updatedAt!)}',
                    style:
                        TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de sección ───────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Identificación ────────────────────────────────────────────────────────

  Widget _buildIdentificationFields(Valve v) {
    if (_isEditing) {
      return Column(children: [
        _editField('Nombre *', _nameCtrl),
        _editField('TAG', _tagCtrl, hint: 'Ej: PSV-001'),
        _editField('Descripción', _descCtrl, maxLines: 2),
        _editField('Marca', _brandCtrl),
        _editField('Modelo', _modelCtrl),
        _editField('N° de Serie', _serialCtrl),
      ]);
    }
    return Column(children: [
      _infoRow('Nombre', v.name),
      if (v.tag != null) _infoRow('TAG', v.tag!),
      if (v.description != null) _infoRow('Descripción', v.description!),
      if (v.brand != null) _infoRow('Marca', v.brand!),
      if (v.model != null) _infoRow('Modelo', v.model!),
      if (v.serialNumber != null) _infoRow('N° de Serie', v.serialNumber!),
      _infoRow('Creado', DateFormat('dd/MM/yyyy').format(v.createdAt)),
    ]);
  }

  // ── Valores técnicos ──────────────────────────────────────────────────────

  Widget _buildTechnicalFields(Valve v) {
    if (_isEditing) {
      return Column(children: [
        Row(children: [
          Expanded(
              child: _editField('Valor Seteo', _setPointCtrl,
                  hint: 'Ej: 10.5',
                  keyboard: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 12),
          Expanded(
              child: _editField('Valor Corte', _cutPointCtrl,
                  hint: 'Ej: 11.2',
                  keyboard: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        _editField('Unidad', _unitCtrl, hint: 'bar, PSI, °C, kg/cm²…'),
        DropdownButtonFormField<ValveType>(
          initialValue: _editValveType,
          decoration: const InputDecoration(
            labelText: 'Tipo de válvula',
            border: OutlineInputBorder(),
          ),
          items: ValveType.values
              .map((t) =>
                  DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (t) => setState(() => _editValveType = t!),
        ),
        const SizedBox(height: 12),
      ]);
    }
    return Column(children: [
      _infoRow('Tipo', v.valveType.label),
      if (v.setPoint != null)
        _infoRow('Valor de Seteo',
            '${v.setPoint!.toStringAsFixed(2)} ${v.unit ?? ''}'),
      if (v.cutPoint != null)
        _infoRow('Valor de Corte',
            '${v.cutPoint!.toStringAsFixed(2)} ${v.unit ?? ''}'),
      if (v.unit != null) _infoRow('Unidad', v.unit!),
      if (v.setPoint == null && v.cutPoint == null)
        _emptyHint('Sin valores técnicos registrados'),
    ]);
  }

  // ── Estado en terreno ─────────────────────────────────────────────────────

  Widget _buildStatusFields(Valve v) {
    if (_isEditing) {
      return Column(children: [
        DropdownButtonFormField<ValveStatus>(
          initialValue: _editStatus,
          decoration: const InputDecoration(
            labelText: 'Estado',
            border: OutlineInputBorder(),
          ),
          items: ValveStatus.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(s.icon, color: s.color, size: 16),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ]),
                  ))
              .toList(),
          onChanged: (s) => setState(() => _editStatus = s!),
        ),
        const SizedBox(height: 12),
        _editField('Ubicación en equipo', _locationCtrl,
            hint: 'Ej: Línea de vapor principal, salida caldera'),
        _editField('Observaciones técnico', _notesCtrl, maxLines: 3),
      ]);
    }
    return Column(children: [
      if (v.locationInEquipment != null)
        _infoRow('Ubicación', v.locationInEquipment!),
      if (v.technicianNotes != null)
        _infoRow('Observaciones', v.technicianNotes!),
      if (v.replacedByValveId != null)
        _infoRow('Reemplazada por ID', v.replacedByValveId!),
      if (v.replacementDate != null)
        _infoRow('Fecha reemplazo',
            DateFormat('dd/MM/yyyy').format(v.replacementDate!)),
      if (v.lastRevisionDate != null)
        _infoRow('Última revisión',
            DateFormat('dd/MM/yyyy').format(v.lastRevisionDate!)),
      if (v.locationInEquipment == null &&
          v.technicianNotes == null &&
          v.replacedByValveId == null)
        _emptyHint('Sin información de terreno registrada'),
    ]);
  }

  // ── Fotos ─────────────────────────────────────────────────────────────────

  Widget _buildPhotosSection(Valve v) {
    return PhotoManagerWidget(
      urls: v.photoUrls,
      storagePath: 'valvulas/${widget.valveId}/fotos',
      docRef: _valveRef,
      fieldName: 'photoUrls',
      entityId: widget.valveId,
    );
  }

  // ── Reemplazo ─────────────────────────────────────────────────────────────

  Widget _buildReplacementSection(Valve v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reemplaza esta válvula por una disponible en bodega del mismo equipo.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showReplaceDialog(v),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Reemplazar válvula'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  // ── Historial de mantenciones ─────────────────────────────────────────────

  Widget _buildMaintenanceHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _valveRef
          .collection('maintenances')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _emptyHint('Sin mantenciones registradas');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final date = (d['date'] as Timestamp?)?.toDate();
            final notes = d['notes'] as String? ?? '';
            final technician = d['technician'] as String?;
            final setPoint = d['setPoint'] as String?;
            final cutOff = d['cutOff'] as String?;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.build_outlined,
                        size: 18, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (date != null)
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        if (notes.isNotEmpty)
                          Text(notes,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                        if (technician != null)
                          Text('Técnico: $technician',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        if (setPoint != null || cutOff != null)
                          Text(
                            [
                              if (setPoint != null) 'Seteo: $setPoint',
                              if (cutOff != null) 'Corte: $cutOff',
                            ].join('  |  '),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _editField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        textCapitalization: keyboard == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Text(text,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
  }
}
