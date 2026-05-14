import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/component_model.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/photo_manager_widget.dart';

class ComponentDetailScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;

  /// null = crear nuevo componente
  final String? componentId;

  const ComponentDetailScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    this.componentId,
  });

  @override
  State<ComponentDetailScreen> createState() => _ComponentDetailScreenState();
}

class _ComponentDetailScreenState extends State<ComponentDetailScreen> {
  // ── Firestore ref ─────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _colRef =>
      FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('equipments')
          .doc(widget.equipmentId)
          .collection('components');

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _colRef.doc(widget.componentId);

  bool get _isCreateMode => widget.componentId == null;

  // ── Estado UI ─────────────────────────────────────────────────────────────
  bool _isEditing = false;
  bool _isSaving = false;

  // ── Controladores de texto ────────────────────────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _numeroSerieCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _valorSeteoCtrl = TextEditingController();
  final _valorCorteCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _rangoOperacionCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _motivoReemplazoCtrl = TextEditingController();
  final _nuevoMarcaCtrl = TextEditingController();
  final _nuevoModeloCtrl = TextEditingController();
  final _nuevoNumeroSerieCtrl = TextEditingController();

  // ── Estado del formulario ─────────────────────────────────────────────────
  ComponentType _editTipo = ComponentType.otro;
  ComponentStatus _editEstado = ComponentStatus.operativo;
  bool _editTieneSubComponentes = false;
  DateTime? _editFechaReemplazo;
  DateTime? _editFechaInstalacion;


  @override
  void initState() {
    super.initState();
    if (_isCreateMode) _isEditing = true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _tagCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _numeroSerieCtrl.dispose();
    _proveedorCtrl.dispose();
    _valorSeteoCtrl.dispose();
    _valorCorteCtrl.dispose();
    _unidadCtrl.dispose();
    _rangoOperacionCtrl.dispose();
    _ubicacionCtrl.dispose();
    _observacionesCtrl.dispose();
    _motivoReemplazoCtrl.dispose();
    _nuevoMarcaCtrl.dispose();
    _nuevoModeloCtrl.dispose();
    _nuevoNumeroSerieCtrl.dispose();
    super.dispose();
  }

  // ── Inicializar controladores desde modelo ────────────────────────────────
  void _startEditing(ComponentModel c) {
    _nombreCtrl.text = c.nombre;
    _descripcionCtrl.text = c.descripcion ?? '';
    _tagCtrl.text = c.tag ?? '';
    _marcaCtrl.text = c.marca ?? '';
    _modeloCtrl.text = c.modelo ?? '';
    _numeroSerieCtrl.text = c.numeroSerie ?? '';
    _proveedorCtrl.text = c.proveedor ?? '';
    _valorSeteoCtrl.text = c.valorSeteo?.toString() ?? '';
    _valorCorteCtrl.text = c.valorCorte?.toString() ?? '';
    _unidadCtrl.text = c.unidad ?? '';
    _rangoOperacionCtrl.text = c.rangoOperacion ?? '';
    _ubicacionCtrl.text = c.ubicacionEnEquipo ?? '';
    _observacionesCtrl.text = c.observacionesTecnico ?? '';
    _motivoReemplazoCtrl.text = c.motivoReemplazo ?? '';
    _nuevoMarcaCtrl.text = c.nuevoMarca ?? '';
    _nuevoModeloCtrl.text = c.nuevoModelo ?? '';
    _nuevoNumeroSerieCtrl.text = c.nuevoNumeroSerie ?? '';
    _editTipo = c.tipo;
    _editEstado = c.estado;
    _editTieneSubComponentes = c.tieneSubComponentes;
    _editFechaReemplazo = c.fechaReemplazo;
    _editFechaInstalacion = c.fechaInstalacion;
    setState(() => _isEditing = true);
  }

  // ── Construir mapa para guardar ───────────────────────────────────────────
  Map<String, dynamic> _buildMap() {
    String? nv(String s) {
      final v = s.trim();
      return v.isEmpty ? null : v;
    }

    double? dv(String s) => double.tryParse(s.trim());

    return {
      'equipoId': widget.equipmentId,
      'nombre': _nombreCtrl.text.trim(),
      if (nv(_descripcionCtrl.text) != null)
        'descripcion': nv(_descripcionCtrl.text),
      if (nv(_tagCtrl.text) != null) 'tag': nv(_tagCtrl.text),
      'tipo': _editTipo.value,
      if (nv(_marcaCtrl.text) != null) 'marca': nv(_marcaCtrl.text),
      if (nv(_modeloCtrl.text) != null) 'modelo': nv(_modeloCtrl.text),
      if (nv(_numeroSerieCtrl.text) != null)
        'numeroSerie': nv(_numeroSerieCtrl.text),
      if (nv(_proveedorCtrl.text) != null)
        'proveedor': nv(_proveedorCtrl.text),
      if (dv(_valorSeteoCtrl.text) != null)
        'valorSeteo': dv(_valorSeteoCtrl.text),
      if (dv(_valorCorteCtrl.text) != null)
        'valorCorte': dv(_valorCorteCtrl.text),
      if (nv(_unidadCtrl.text) != null) 'unidad': nv(_unidadCtrl.text),
      if (nv(_rangoOperacionCtrl.text) != null)
        'rangoOperacion': nv(_rangoOperacionCtrl.text),
      'estado': _editEstado.value,
      if (nv(_ubicacionCtrl.text) != null)
        'ubicacionEnEquipo': nv(_ubicacionCtrl.text),
      if (nv(_observacionesCtrl.text) != null)
        'observacionesTecnico': nv(_observacionesCtrl.text),
      if (_editFechaReemplazo != null)
        'fechaReemplazo': Timestamp.fromDate(_editFechaReemplazo!),
      if (nv(_motivoReemplazoCtrl.text) != null)
        'motivoReemplazo': nv(_motivoReemplazoCtrl.text),
      if (nv(_nuevoMarcaCtrl.text) != null)
        'nuevoMarca': nv(_nuevoMarcaCtrl.text),
      if (nv(_nuevoModeloCtrl.text) != null)
        'nuevoModelo': nv(_nuevoModeloCtrl.text),
      if (nv(_nuevoNumeroSerieCtrl.text) != null)
        'nuevoNumeroSerie': nv(_nuevoNumeroSerieCtrl.text),
      'tieneSubComponentes': _editTieneSubComponentes,
      if (_editFechaInstalacion != null)
        'fechaInstalacion': Timestamp.fromDate(_editFechaInstalacion!),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final data = _buildMap();
      if (_isCreateMode) {
        // Crear nuevo documento
        data['creadoEn'] = FieldValue.serverTimestamp();
        data['createdAt'] = FieldValue.serverTimestamp(); // compat legacy
        data['fotos'] = <String>[];
        await _colRef.add(data);
        if (mounted) {
          navigator.pop();
          messenger.showSnackBar(const SnackBar(
            content: Text('Componente creado exitosamente'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        await _docRef.update(data);
        if (mounted) setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isCreateMode) {
      return _buildCreateScaffold();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppAppBar(
                title: 'Componente', showBackButton: true),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppAppBar(
                title: 'Cargando…', showBackButton: true),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final component = ComponentModel.fromFirestore(snap.data!);
        return _buildExistingScaffold(component);
      },
    );
  }

  // ── Scaffold: nuevo componente ────────────────────────────────────────────

  Widget _buildCreateScaffold() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: 'Nuevo Componente',
        icon: Icons.sensors,
        showBackButton: true,
        actions: _isSaving
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: _save,
                  child: const Text('Guardar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSection(
              title: 'Identificación',
              icon: Icons.badge_outlined,
              child: _buildIdentificacionEdit(),
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Valores Técnicos',
              icon: Icons.tune,
              child: _buildTecnicosEdit(),
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Estado y Ubicación',
              icon: Icons.location_on_outlined,
              child: _buildEstadoEdit(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Scaffold: componente existente ────────────────────────────────────────

  Widget _buildExistingScaffold(ComponentModel c) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: c.nombre,
        subtitle: _isEditing ? 'Editando…' : c.tipo.label,
        icon: c.tipo.icon,
        showBackButton: true,
        actions: _buildAppBarActions(c),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_isEditing) _buildStatusBanner(c),
            if (!_isEditing) const SizedBox(height: 12),
            _buildSection(
              title: 'Identificación',
              icon: Icons.badge_outlined,
              child: _isEditing
                  ? _buildIdentificacionEdit()
                  : _buildIdentificacionView(c),
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Valores Técnicos',
              icon: Icons.tune,
              child: _isEditing
                  ? _buildTecnicosEdit()
                  : _buildTecnicosView(c),
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Estado y Ubicación',
              icon: Icons.location_on_outlined,
              child: _isEditing
                  ? _buildEstadoEdit()
                  : _buildEstadoView(c),
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Fotografías',
              icon: Icons.photo_library_outlined,
              child: _buildFotos(c.fotos),
            ),
            // Sección reemplazo (visible cuando estado lo requiere)
            if (_isEditing ||
                c.estado == ComponentStatus.requiereReemplazo ||
                c.estado == ComponentStatus.reemplazado) ...[
              const SizedBox(height: 12),
              _buildSection(
                title: 'Reemplazo',
                icon: Icons.swap_horiz,
                child: _isEditing
                    ? _buildReemplazoEdit()
                    : _buildReemplazoView(c),
              ),
            ],
            // Sección sub-componentes
            if (_isEditing || c.tieneSubComponentes) ...[
              const SizedBox(height: 12),
              _buildSection(
                title: 'Sub-componentes',
                icon: Icons.account_tree_outlined,
                child: _buildSubComponentes(c),
              ),
            ],
            const SizedBox(height: 12),
            _buildSection(
              title: 'Trazabilidad',
              icon: Icons.history_outlined,
              child: _isEditing
                  ? _buildTrazabilidadEdit()
                  : _buildTrazabilidadView(c),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(ComponentModel c) {
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
          onPressed: _save,
          child: const Text('Guardar',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Editar',
        onPressed: () => _startEditing(c),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BANNER DE ESTADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusBanner(ComponentModel c) {
    final statusColor = c.estado.color;
    final typeColor = c.tipo.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade700],
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
            child: Icon(c.tipo.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nombre,
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
                        color: statusColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.estado.icon,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            c.estado.label,
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
                      c.tipo.label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                if (c.tag?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('TAG: ${c.tag}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ],
            ),
          ),
          // Badge de tipo con color
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: IDENTIFICACIÓN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildIdentificacionView(ComponentModel c) {
    return Column(children: [
      _infoRow('Nombre', c.nombre),
      _infoRow('Tipo', c.tipo.label),
      if (c.tag?.isNotEmpty == true) _infoRow('TAG', c.tag!),
      if (c.descripcion?.isNotEmpty == true)
        _infoRow('Descripción', c.descripcion!),
      if (c.marca?.isNotEmpty == true) _infoRow('Marca', c.marca!),
      if (c.modelo?.isNotEmpty == true) _infoRow('Modelo', c.modelo!),
      if (c.numeroSerie?.isNotEmpty == true)
        _infoRow('N° de Serie', c.numeroSerie!),
      if (c.proveedor?.isNotEmpty == true)
        _infoRow('Proveedor', c.proveedor!),
    ]);
  }

  Widget _buildIdentificacionEdit() {
    return Column(children: [
      _editField('Nombre *', _nombreCtrl),
      _editDropdown<ComponentType>(
        label: 'Tipo de componente *',
        value: _editTipo,
        items: ComponentType.values,
        labelOf: (t) => t.label,
        onChanged: (t) => setState(() => _editTipo = t!),
      ),
      _editField('TAG', _tagCtrl, hint: 'Ej: PS-101'),
      _editField('Descripción', _descripcionCtrl, maxLines: 2),
      _editField('Marca', _marcaCtrl),
      _editField('Modelo', _modeloCtrl),
      _editField('N° de Serie', _numeroSerieCtrl),
      _editField('Proveedor', _proveedorCtrl),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: VALORES TÉCNICOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTecnicosView(ComponentModel c) {
    final hasTecnicos = c.valorSeteo != null ||
        c.valorCorte != null ||
        c.unidad?.isNotEmpty == true ||
        c.rangoOperacion?.isNotEmpty == true;
    if (!hasTecnicos) return _emptyHint('Sin valores técnicos registrados');
    return Column(children: [
      if (c.valorSeteo != null)
        _infoRow('Valor de Seteo',
            '${c.valorSeteo}${c.unidad != null ? ' ${c.unidad}' : ''}'),
      if (c.valorCorte != null)
        _infoRow('Valor de Corte',
            '${c.valorCorte}${c.unidad != null ? ' ${c.unidad}' : ''}'),
      if (c.unidad?.isNotEmpty == true) _infoRow('Unidad', c.unidad!),
      if (c.rangoOperacion?.isNotEmpty == true)
        _infoRow('Rango de Operación', c.rangoOperacion!),
    ]);
  }

  Widget _buildTecnicosEdit() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: _editField('Valor de Seteo', _valorSeteoCtrl,
              hint: 'ej: 4.5',
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _editField('Valor de Corte', _valorCorteCtrl,
              hint: 'ej: 5.0',
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ),
      ]),
      _editField('Unidad', _unidadCtrl, hint: 'bar, PSI, °C, %…'),
      _editField('Rango de Operación', _rangoOperacionCtrl,
          hint: 'ej: 0–10 bar'),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: ESTADO Y UBICACIÓN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEstadoView(ComponentModel c) {
    return Column(children: [
      _infoRowWithBadge('Estado', c.estado.label, c.estado.color),
      if (c.ubicacionEnEquipo?.isNotEmpty == true)
        _infoRow('Ubicación en Equipo', c.ubicacionEnEquipo!),
      if (c.observacionesTecnico?.isNotEmpty == true)
        _infoRow('Observaciones', c.observacionesTecnico!),
    ]);
  }

  Widget _buildEstadoEdit() {
    return Column(children: [
      _editDropdown<ComponentStatus>(
        label: 'Estado',
        value: _editEstado,
        items: ComponentStatus.values,
        labelOf: (s) => s.label,
        onChanged: (s) => setState(() => _editEstado = s!),
      ),
      _editField('Ubicación en Equipo', _ubicacionCtrl,
          hint: 'Ej: Línea de vapor principal'),
      _editField('Observaciones del Técnico', _observacionesCtrl,
          maxLines: 3),
      // Toggle sub-componentes
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Tiene sub-componentes',
            style: TextStyle(fontSize: 14)),
        subtitle:
            const Text('Activar para gestionar piezas internas',
                style: TextStyle(fontSize: 12)),
        value: _editTieneSubComponentes,
        onChanged: (v) => setState(() => _editTieneSubComponentes = v),
        activeThumbColor: Colors.teal,
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: FOTOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFotos(List<String> fotos) {
    return PhotoManagerWidget(
      urls: fotos,
      storagePath:
          'equipos/${widget.equipmentId}/componentes/${widget.componentId}/fotos',
      docRef: _docRef,
      fieldName: 'fotos',
      entityId: widget.componentId!,
      entityName: _nombreCtrl.text.isNotEmpty ? _nombreCtrl.text : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: REEMPLAZO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReemplazoView(ComponentModel c) {
    final hasData = c.motivoReemplazo?.isNotEmpty == true ||
        c.nuevoMarca?.isNotEmpty == true ||
        c.fechaReemplazo != null;
    if (!hasData) return _emptyHint('Sin datos de reemplazo registrados');
    return Column(children: [
      if (c.fechaReemplazo != null)
        _infoRow('Fecha de Reemplazo',
            DateFormat('dd/MM/yyyy').format(c.fechaReemplazo!)),
      if (c.motivoReemplazo?.isNotEmpty == true)
        _infoRow('Motivo', c.motivoReemplazo!),
      if (c.nuevoMarca?.isNotEmpty == true ||
          c.nuevoModelo?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.new_releases,
                    size: 14, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text('Componente Nuevo',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700)),
              ]),
              const SizedBox(height: 6),
              if (c.nuevoMarca?.isNotEmpty == true)
                _infoRow('Marca', c.nuevoMarca!),
              if (c.nuevoModelo?.isNotEmpty == true)
                _infoRow('Modelo', c.nuevoModelo!),
              if (c.nuevoNumeroSerie?.isNotEmpty == true)
                _infoRow('N° de Serie', c.nuevoNumeroSerie!),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _buildReemplazoEdit() {
    return Column(children: [
      // Fecha de reemplazo
      GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _editFechaReemplazo ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            locale: const Locale('es', 'CL'),
          );
          if (date != null) {
            setState(() => _editFechaReemplazo = date);
          }
        },
        child: AbsorbPointer(
          child: TextField(
            controller: TextEditingController(
              text: _editFechaReemplazo != null
                  ? DateFormat('dd/MM/yyyy')
                      .format(_editFechaReemplazo!)
                  : '',
            ),
            decoration: InputDecoration(
              labelText: 'Fecha de Reemplazo',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editFechaReemplazo != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(
                          () => _editFechaReemplazo = null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _editField('Motivo del Reemplazo', _motivoReemplazoCtrl,
          maxLines: 2,
          hint: 'Describe la razón del reemplazo'),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Datos del componente nuevo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),
      ),
      _editField('Marca (nuevo)', _nuevoMarcaCtrl),
      _editField('Modelo (nuevo)', _nuevoModeloCtrl),
      _editField('N° de Serie (nuevo)', _nuevoNumeroSerieCtrl),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: SUB-COMPONENTES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSubComponentes(ComponentModel c) {
    if (!c.tieneSubComponentes && !_isEditing) {
      return _emptyHint('Sin sub-componentes');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _docRef.collection('sub_components').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...docs.map((doc) {
              final d = doc.data();
              final nombre = (d['nombre'] ?? d['name'] ?? '') as String;
              final tipoStr = (d['tipo'] ?? d['type'] ?? '') as String;
              final tipo = componentTypeFromValue(tipoStr);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tipo.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tipo.icon, size: 18, color: tipo.color),
                ),
                title: Text(nombre,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(tipo.label,
                    style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _deleteSubComponent(doc.id),
                ),
              );
            }),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _addSubComponentDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar sub-componente'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSubComponentDialog() async {
    final nombreCtrl = TextEditingController();
    ComponentType tipo = ComponentType.otro;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Agregar Sub-componente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ComponentType>(
                initialValue: tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: ComponentType.values
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setD(() => tipo = t!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                await _docRef.collection('sub_components').add({
                  'nombre': nombreCtrl.text.trim(),
                  'tipo': tipo.value,
                  'creadoEn': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSubComponent(String subId) async {
    await _docRef.collection('sub_components').doc(subId).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECCIÓN: TRAZABILIDAD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTrazabilidadView(ComponentModel c) {
    return Column(children: [
      if (c.fechaInstalacion != null)
        _infoRow('Fecha de Instalación',
            DateFormat('dd/MM/yyyy').format(c.fechaInstalacion!)),
      if (c.fechaUltimaRevision != null)
        _infoRow('Última Revisión',
            DateFormat('dd/MM/yyyy').format(c.fechaUltimaRevision!)),
      _infoRow('Creado',
          DateFormat('dd/MM/yyyy HH:mm').format(c.creadoEn)),
      if (c.actualizadoEn != null)
        _infoRow('Actualizado',
            DateFormat('dd/MM/yyyy HH:mm').format(c.actualizadoEn!)),
    ]);
  }

  Widget _buildTrazabilidadEdit() {
    return Column(children: [
      // Fecha instalación
      GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _editFechaInstalacion ?? DateTime.now(),
            firstDate: DateTime(1990),
            lastDate: DateTime(2100),
            locale: const Locale('es', 'CL'),
          );
          if (date != null) {
            setState(() => _editFechaInstalacion = date);
          }
        },
        child: AbsorbPointer(
          child: TextField(
            controller: TextEditingController(
              text: _editFechaInstalacion != null
                  ? DateFormat('dd/MM/yyyy')
                      .format(_editFechaInstalacion!)
                  : '',
            ),
            decoration: InputDecoration(
              labelText: 'Fecha de Instalación',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editFechaInstalacion != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(
                          () => _editFechaInstalacion = null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS DE UI
  // ══════════════════════════════════════════════════════════════════════════

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
            Row(children: [
              Icon(icon, size: 18, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.teal.shade800,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithBadge(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _editDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: items
            .map((i) => DropdownMenuItem(
                value: i, child: Text(labelOf(i))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _emptyHint(String text) => Text(
        text,
        style:
            TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
}
