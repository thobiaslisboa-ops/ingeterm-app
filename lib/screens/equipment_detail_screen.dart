import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/equipment_model.dart';
import '../models/maintenance_model.dart';
import 'components_screen.dart';
import 'valves_screen.dart';
import 'hydro_tests_screen.dart';
import 'maintenance_detail_screen.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/maintenance_card.dart';
import '../widgets/photo_manager_widget.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String equipmentName;

  const EquipmentDetailScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = FirebaseFirestore.instance;

  // ── Estado edición inline ─────────────────────────────────────────────────
  bool _isEditing = false;
  bool _isSaving = false;

  // Controladores de campos
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _mfgYearCtrl = TextEditingController();
  final _installYearCtrl = TextEditingController();
  final _designPressureCtrl = TextEditingController();
  final _operatingPressureCtrl = TextEditingController();
  final _designTempCtrl = TextEditingController();
  final _operatingTempCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _capacityUnitCtrl = TextEditingController();
  final _fluidCtrl = TextEditingController();
  final _plantCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _locationDescCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  EquipmentType _editType = EquipmentType.caldera;
  EquipmentStatus _editStatus = EquipmentStatus.operational;

  DocumentReference<Map<String, dynamic>> get _equipmentRef => db
      .collection('clients')
      .doc(widget.clientId)
      .collection('equipments')
      .doc(widget.equipmentId);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Salir de edición si el usuario cambia de tab
    _tabController.addListener(() {
      if (_isEditing && _tabController.index != 0) {
        setState(() => _isEditing = false);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _mfgYearCtrl.dispose();
    _installYearCtrl.dispose();
    _designPressureCtrl.dispose();
    _operatingPressureCtrl.dispose();
    _designTempCtrl.dispose();
    _operatingTempCtrl.dispose();
    _capacityCtrl.dispose();
    _capacityUnitCtrl.dispose();
    _fluidCtrl.dispose();
    _plantCtrl.dispose();
    _areaCtrl.dispose();
    _lineCtrl.dispose();
    _locationDescCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Edición inline ────────────────────────────────────────────────────────

  void _startEditing(Equipment e) {
    _nameCtrl.text = e.name;
    _tagCtrl.text = e.tag ?? '';
    _manufacturerCtrl.text = e.manufacturer ?? '';
    _modelCtrl.text = e.model ?? '';
    _serialCtrl.text = e.serialNumber ?? '';
    _mfgYearCtrl.text = e.manufacturingYear?.toString() ?? '';
    _installYearCtrl.text = e.installationYear?.toString() ?? '';
    _designPressureCtrl.text = e.designPressure?.toString() ?? '';
    _operatingPressureCtrl.text = e.operatingPressure?.toString() ?? '';
    _designTempCtrl.text = e.designTemperature?.toString() ?? '';
    _operatingTempCtrl.text = e.operatingTemperature?.toString() ?? '';
    _capacityCtrl.text = e.capacity?.toString() ?? '';
    _capacityUnitCtrl.text = e.capacityUnit ?? '';
    _fluidCtrl.text = e.fluid ?? '';
    _plantCtrl.text = e.plant ?? '';
    _areaCtrl.text = e.area ?? '';
    _lineCtrl.text = e.line ?? '';
    _locationDescCtrl.text = e.locationDescription ?? '';
    _descriptionCtrl.text = e.description ?? '';
    _editType = e.type;
    _editStatus = e.status;
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
      String? n(String s) => s.trim().isEmpty ? null : s.trim();
      double? d(String s) => double.tryParse(s.trim());
      int? i(String s) => int.tryParse(s.trim());

      await _equipmentRef.update({
        'name': _nameCtrl.text.trim(),
        'tag': n(_tagCtrl.text),
        'manufacturer': n(_manufacturerCtrl.text),
        'model': n(_modelCtrl.text),
        'serialNumber': n(_serialCtrl.text),
        'manufacturingYear': i(_mfgYearCtrl.text),
        'installationYear': i(_installYearCtrl.text),
        'type': _editType.value,
        'status': _editStatus.value,
        'designPressure': d(_designPressureCtrl.text),
        'operatingPressure': d(_operatingPressureCtrl.text),
        'designTemperature': d(_designTempCtrl.text),
        'operatingTemperature': d(_operatingTempCtrl.text),
        'capacity': d(_capacityCtrl.text),
        'capacityUnit': n(_capacityUnitCtrl.text),
        'fluid': n(_fluidCtrl.text),
        'plant': n(_plantCtrl.text),
        'area': n(_areaCtrl.text),
        'line': n(_lineCtrl.text),
        'locationDescription': n(_locationDescCtrl.text),
        'description': n(_descriptionCtrl.text),
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


  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: 'Detalle del Equipo',
        icon: Icons.precision_manufacturing,
        showBackButton: true,
        subtitle: widget.equipmentName,
        actions: _buildAppBarActions(),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Información'),
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Pruebas Hidráulicas'),
            Tab(icon: Icon(Icons.plumbing), text: 'Válvulas'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Componentes'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildHydraulicTestsTab(),
          _buildValvesTab(),
          _buildComponentsTab(),
          _buildHistorialTab(),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    // Botón editar solo visible en el tab Información
    if (_tabController.index != 0) return [];
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
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white70)),
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
        tooltip: 'Editar información',
        onPressed: () {
          // Necesitamos el equipo para inicializar los controllers;
          // la carga viene del StreamBuilder del tab, pero lo disparamos
          // desde el AppBar — usamos un get() puntual.
          _equipmentRef.get().then((snap) {
            if (snap.exists && mounted) {
              _startEditing(
                  Equipment.fromFirestore(snap));
            }
          });
        },
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 1 — INFORMACIÓN DEL EQUIPO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInfoTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _equipmentRef.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData || snap.data?.exists == false) {
          return const Center(child: CircularProgressIndicator());
        }
        final equipment = Equipment.fromFirestore(snap.data!);

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!_isEditing) _buildStatusBanner(equipment),
              if (!_isEditing) const SizedBox(height: 16),

              // Datos Básicos
              _buildSection(
                title: 'Datos Básicos',
                icon: Icons.assignment_outlined,
                child: _buildBasicFields(equipment),
              ),
              const SizedBox(height: 12),

              // Datos Técnicos
              _buildSection(
                title: 'Datos Técnicos',
                icon: Icons.engineering,
                child: _buildTechnicalFields(equipment),
              ),
              const SizedBox(height: 12),

              // Ubicación
              _buildSection(
                title: 'Ubicación en Planta',
                icon: Icons.location_on_outlined,
                child: _buildLocationFields(equipment),
              ),
              const SizedBox(height: 12),

              // Fotos
              _buildSection(
                title: 'Fotografías',
                icon: Icons.photo_library_outlined,
                child: _buildPhotosSection(equipment),
              ),

              if (equipment.description?.isNotEmpty == true ||
                  _isEditing) ...[
                const SizedBox(height: 12),
                _buildSection(
                  title: 'Descripción',
                  icon: Icons.notes_outlined,
                  child: _buildDescriptionField(equipment),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────

  Widget _buildStatusBanner(Equipment e) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(e.type.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: e.status.color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(e.status.icon,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            e.status.label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.type.label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                if (_locationSummary(e).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationSummary(e),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _locationSummary(Equipment e) {
    final parts = [e.plant, e.area, e.line]
        .where((p) => p?.isNotEmpty == true)
        .map((p) => p!)
        .toList();
    if (parts.isNotEmpty) return parts.join(' › ');
    return e.locationDescription ?? '';
  }

  // ── Section card ──────────────────────────────────────────────────────────

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

  // ── Datos Básicos ─────────────────────────────────────────────────────────

  Widget _buildBasicFields(Equipment e) {
    if (_isEditing) {
      return Column(children: [
        _editField('Nombre *', _nameCtrl),
        _editField('TAG', _tagCtrl, hint: 'Ej: C-001'),
        _editField('Fabricante / Marca', _manufacturerCtrl),
        Row(children: [
          Expanded(child: _editField('Modelo', _modelCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _editField('N° de Serie', _serialCtrl)),
        ]),
        Row(children: [
          Expanded(
              child: _editField('Año Fabricación', _mfgYearCtrl,
                  keyboard: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(
              child: _editField('Año Instalación', _installYearCtrl,
                  keyboard: TextInputType.number)),
        ]),
        DropdownButtonFormField<EquipmentType>(
          initialValue: _editType,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Tipo de equipo', border: OutlineInputBorder()),
          items: EquipmentType.values
              .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (t) => setState(() => _editType = t!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EquipmentStatus>(
          initialValue: _editStatus,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Estado', border: OutlineInputBorder()),
          items: EquipmentStatus.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(s.icon, color: s.color, size: 16),
                      const SizedBox(width: 8),
                      Text(s.label, overflow: TextOverflow.ellipsis),
                    ]),
                  ))
              .toList(),
          onChanged: (s) => setState(() => _editStatus = s!),
        ),
        const SizedBox(height: 12),
      ]);
    }
    return Column(children: [
      _infoRow('Nombre', e.name),
      if (e.tag != null) _infoRow('TAG', e.tag!),
      _infoRow('Tipo', e.type.label),
      _infoRow('Estado', e.status.label),
      if (e.manufacturer != null) _infoRow('Fabricante', e.manufacturer!),
      if (e.model != null) _infoRow('Modelo', e.model!),
      if (e.serialNumber != null) _infoRow('N° de Serie', e.serialNumber!),
      if (e.manufacturingYear != null)
        _infoRow('Año Fabricación', e.manufacturingYear.toString()),
      if (e.installationYear != null)
        _infoRow('Año Instalación', e.installationYear.toString()),
      if (e.createdAt != DateTime(0))
        _infoRow('Registrado',
            DateFormat('dd/MM/yyyy').format(e.createdAt)),
    ]);
  }

  // ── Datos Técnicos ────────────────────────────────────────────────────────

  Widget _buildTechnicalFields(Equipment e) {
    if (_isEditing) {
      return Column(children: [
        Row(children: [
          Expanded(
              child: _editField('Presión Diseño',
                  _designPressureCtrl,
                  hint: 'bar',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true))),
          const SizedBox(width: 12),
          Expanded(
              child: _editField('Presión Operación',
                  _operatingPressureCtrl,
                  hint: 'bar',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true))),
        ]),
        Row(children: [
          Expanded(
              child: _editField('Temp. Diseño',
                  _designTempCtrl,
                  hint: '°C',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true))),
          const SizedBox(width: 12),
          Expanded(
              child: _editField('Temp. Operación',
                  _operatingTempCtrl,
                  hint: '°C',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true))),
        ]),
        Row(children: [
          Expanded(
              child: _editField('Capacidad', _capacityCtrl,
                  hint: 'valor',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true))),
          const SizedBox(width: 12),
          Expanded(
              child:
                  _editField('Unidad', _capacityUnitCtrl, hint: 'm³, kg, L…')),
        ]),
        _editField('Fluido Contenido', _fluidCtrl,
            hint: 'Ej: Vapor saturado, agua, aire…'),
      ]);
    }

    final hasTechnical = e.designPressure != null ||
        e.operatingPressure != null ||
        e.designTemperature != null ||
        e.operatingTemperature != null ||
        e.capacity != null ||
        e.fluid != null;

    if (!hasTechnical) {
      return _emptyHint('Sin datos técnicos registrados');
    }

    return Column(children: [
      if (e.designPressure != null)
        _infoRow('Presión Diseño',
            '${e.designPressure!.toStringAsFixed(2)} bar'),
      if (e.operatingPressure != null)
        _infoRow('Presión Operación',
            '${e.operatingPressure!.toStringAsFixed(2)} bar'),
      if (e.designTemperature != null)
        _infoRow('Temp. Diseño',
            '${e.designTemperature!.toStringAsFixed(1)} °C'),
      if (e.operatingTemperature != null)
        _infoRow('Temp. Operación',
            '${e.operatingTemperature!.toStringAsFixed(1)} °C'),
      if (e.capacity != null)
        _infoRow('Capacidad',
            '${e.capacity!.toStringAsFixed(2)} ${e.capacityUnit ?? ''}'),
      if (e.fluid != null) _infoRow('Fluido', e.fluid!),
    ]);
  }

  // ── Ubicación ─────────────────────────────────────────────────────────────

  Widget _buildLocationFields(Equipment e) {
    if (_isEditing) {
      return Column(children: [
        Row(children: [
          Expanded(child: _editField('Planta', _plantCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _editField('Área', _areaCtrl)),
        ]),
        _editField('Línea', _lineCtrl, hint: 'Ej: Línea 3'),
        _editField('Descripción de ubicación', _locationDescCtrl,
            maxLines: 2,
            hint: 'Ej: Sector sur, junto a calderas'),
      ]);
    }

    final hasLocation = e.plant != null ||
        e.area != null ||
        e.line != null ||
        e.locationDescription != null;

    if (!hasLocation) return _emptyHint('Sin ubicación registrada');

    return Column(children: [
      if (e.plant != null) _infoRow('Planta', e.plant!),
      if (e.area != null) _infoRow('Área', e.area!),
      if (e.line != null) _infoRow('Línea', e.line!),
      if (e.locationDescription != null)
        _infoRow('Descripción', e.locationDescription!),
    ]);
  }

  // ── Descripción ───────────────────────────────────────────────────────────

  Widget _buildDescriptionField(Equipment e) {
    if (_isEditing) {
      return _editField('Descripción del equipo', _descriptionCtrl,
          maxLines: 4,
          hint: 'Información adicional, notas técnicas…');
    }
    if (e.description?.isNotEmpty != true) {
      return _emptyHint('Sin descripción');
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        e.description!,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }

  // ── Fotografías ───────────────────────────────────────────────────────────

  Widget _buildPhotosSection(Equipment e) {
    return PhotoManagerWidget(
      urls: e.photoUrls,
      storagePath: 'equipos/${widget.equipmentId}/fotos',
      docRef: _equipmentRef,
      fieldName: 'photoUrls',
      entityId: widget.equipmentId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 2 — PRUEBAS HIDROSTÁTICAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHydraulicTestsTab() {
    return HydroTestsScreen(
      clientId: widget.clientId,
      equipmentId: widget.equipmentId,
      equipmentName: widget.equipmentName,
      showAppBar: false,
    );
  }

    // ══════════════════════════════════════════════════════════════════════════
  //  TAB 3 — VÁLVULAS  (preservado exactamente)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildValvesTab() {
    return ValvesScreen(
      clientId: widget.clientId,
      equipmentId: widget.equipmentId,
      equipmentName: widget.equipmentName,
      showAppBar: false,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 4 — COMPONENTES  (preservado exactamente)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildComponentsTab() {
    return ComponentsScreen(
      clientId: widget.clientId,
      equipmentId: widget.equipmentId,
      equipmentName: widget.equipmentName,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 5 — HISTORIAL DE MANTENCIONES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHistorialTab() {
    final query = db
        .collectionGroup('maintenances')
        .where('tipo', isEqualTo: 'orden_trabajo')
        .where('equipoId', isEqualTo: widget.equipmentId)
        .orderBy('fechaProgramada', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          // Error frecuente en dev: índice no creado todavía
          if (snap.error.toString().contains('index')) {
            return _historialEmptyState(
              icon: Icons.manage_search,
              mensaje:
                  'Requiere índice en Firestore.\nEjecuta la app con conexión para crearlo automáticamente.',
            );
          }
          return _historialEmptyState(
            icon: Icons.error_outline,
            mensaje: 'Error al cargar historial:\n${snap.error}',
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return _historialEmptyState(
            icon: Icons.history,
            mensaje: 'Sin mantenciones registradas para este equipo.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = MaintenanceModel.fromFirestore(
                docs[i] as DocumentSnapshot<Map<String, dynamic>>);
            return _HistorialCard(
              mantencion: m,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MaintenanceDetailScreen(
                    maintenanceId: m.id,
                    clienteId: m.clienteId,
                    equipoId: m.equipoId,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _historialEmptyState({
    required IconData icon,
    required String mensaje,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS DE UI
  // ══════════════════════════════════════════════════════════════════════════

  /// Fila etiqueta–valor reutilizada también en el tab de pruebas hidráulicas
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) =>
      _buildInfoRow(label, value);

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

  Widget _emptyHint(String text) => Text(
        text,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card para una orden de mantención en el historial del equipo
// ═══════════════════════════════════════════════════════════════════════════════

class _HistorialCard extends StatelessWidget {
  final MaintenanceModel mantencion;
  final VoidCallback onTap;

  const _HistorialCard({
    required this.mantencion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = mantencion;
    final fecha = m.fechaProgramada ?? m.creadoEn;
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';

    final estadoColor = MaintenanceCard.estadoColor(m.estado);
    final estadoIcon = MaintenanceCard.estadoIcon(m.estado);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: OT número + estado chip
              Row(
                children: [
                  Text(
                    'OT-${m.numeroOrden.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1A5DB5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: estadoColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 11, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          m.estado.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: estadoColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila: fecha + técnico
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(fechaStr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  if (m.tecnicoNombre.isNotEmpty) ...[
                    Icon(Icons.engineering_outlined,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.tecnicoNombre,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              // Chips de tipos de trabajo
              if (m.tiposTrabajo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: m.tiposTrabajo
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A5DB5)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1A5DB5))),
                          ))
                      .toList(),
                ),
              ],

              // Progreso ítems (si hay)
              if (m.totalItems > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: m.porcentajeCompletado,
                          minHeight: 4,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              estadoColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${m.itemsCompletados}/${m.totalItems} trabajos',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
