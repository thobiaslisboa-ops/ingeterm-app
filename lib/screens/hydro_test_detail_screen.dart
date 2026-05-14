import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/hydro_test_model.dart';
import '../services/certificate_service.dart';
import '../widgets/photo_manager_widget.dart';

class HydroTestDetailScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String equipmentName;
  /// null = crear nueva prueba
  final String? testId;
  /// correlativo para pruebas nuevas
  final int? nextTestNumber;

  const HydroTestDetailScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.equipmentName,
    this.testId,
    this.nextTestNumber,
  });

  @override
  State<HydroTestDetailScreen> createState() => _HydroTestDetailScreenState();
}

class _HydroTestDetailScreenState extends State<HydroTestDetailScreen> {
  final _db = FirebaseFirestore.instance;

  bool get _isCreateMode => widget.testId == null;
  bool _isEditing = false;

  // ── Controllers ──────────────────────────────────────────────────────────
  final _tecnicoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _presionController = TextEditingController();
  final _duracionController = TextEditingController();
  final _hallazgoInputController = TextEditingController();

  // ── Estado de edición ─────────────────────────────────────────────────────
  HydroTestResult? _resultado;
  String _unidadPresion = 'bar';
  double _phMultiplier = 1.5;
  double? _presionCalculada;
  DateTime _fechaPrueba = DateTime.now();
  List<String> _hallazgos = [];
  bool _saving = false;
  late final String _effectiveTestId;

  // ── Referencia Firestore ──────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _testRef => _db
      .collection('clients')
      .doc(widget.clientId)
      .collection('equipments')
      .doc(widget.equipmentId)
      .collection('hydraulicTests')
      .doc(_effectiveTestId);


  @override
  void initState() {
    super.initState();
    _effectiveTestId =
        widget.testId ?? _db.collection('hydraulicTests').doc().id;
    if (_isCreateMode) _isEditing = true;
  }

  @override
  void dispose() {
    _tecnicoController.dispose();
    _observacionesController.dispose();
    _presionController.dispose();
    _duracionController.dispose();
    _hallazgoInputController.dispose();
    super.dispose();
  }

  // ── Poblar controllers desde el modelo ───────────────────────────────────

  void _populateFromTest(HydroTest test) {
    _tecnicoController.text = test.tecnicoNombre ?? '';
    _observacionesController.text = test.observaciones ?? '';
    _presionController.text =
        test.presionPrueba?.toStringAsFixed(2) ?? '';
    _duracionController.text = test.duracionMinutos?.toString() ?? '';
    _resultado = test.resultado;
    _unidadPresion = test.unidadPresion;
    _phMultiplier = test.phMultiplier ?? 1.5;
    _fechaPrueba = test.fechaPrueba;
    _hallazgos = List.from(test.hallazgos);
    _recalcularPresion();
  }

  void _recalcularPresion() {
    final p = double.tryParse(_presionController.text);
    setState(() {
      _presionCalculada = p != null ? p * _phMultiplier : null;
    });
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _save(HydroTest? existing) async {
    if (_presionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La presión de prueba es obligatoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final presion = double.tryParse(_presionController.text.trim());
      final calculada = presion != null ? presion * _phMultiplier : null;
      final duracion = int.tryParse(_duracionController.text.trim());

      if (_isCreateMode) {
        // set+merge preserva campo 'fotos' si UploadQueueManager
        // ya subió alguna foto antes de que el usuario tocara Guardar
        await _testRef.set({
          'equipmentId': widget.equipmentId,
          'numeroPrueba': widget.nextTestNumber,
          'fechaPrueba': Timestamp.fromDate(_fechaPrueba),
          if (_tecnicoController.text.trim().isNotEmpty)
            'tecnicoNombre': _tecnicoController.text.trim(),
          if (presion != null) 'presionPrueba': presion,
          'phMultiplier': _phMultiplier,
          if (calculada != null) 'presionCalculada': calculada,
          'unidadPresion': _unidadPresion,
          if (duracion != null) 'duracionMinutos': duracion,
          if (_resultado != null) 'resultado': _resultado!.value,
          if (_observacionesController.text.trim().isNotEmpty)
            'observaciones': _observacionesController.text.trim(),
          'hallazgos': _hallazgos,
          'certificadoGenerado': false,
          'creadoEn': FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // 'fotos' es gestionado exclusivamente por PhotoManagerWidget
        await _testRef.update({
          'fechaPrueba': Timestamp.fromDate(_fechaPrueba),
          'tecnicoNombre': _tecnicoController.text.trim().isNotEmpty
              ? _tecnicoController.text.trim()
              : null,
          if (presion != null) 'presionPrueba': presion,
          'phMultiplier': _phMultiplier,
          if (calculada != null) 'presionCalculada': calculada,
          'unidadPresion': _unidadPresion,
          'duracionMinutos': duracion,
          if (_resultado != null) 'resultado': _resultado!.value,
          'observaciones': _observacionesController.text.trim().isNotEmpty
              ? _observacionesController.text.trim()
              : null,
          'hallazgos': _hallazgos,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCreateMode ? 'Prueba registrada' : 'Prueba actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        if (_isCreateMode) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  Future<void> _delete(HydroTest test) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Prueba'),
        content: const Text('¿Estás seguro de eliminar esta prueba?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      for (final url in test.fotos) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
      await _testRef.delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isCreateMode) {
      return _buildScaffold(context, null);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('clients')
          .doc(widget.clientId)
          .collection('equipments')
          .doc(widget.equipmentId)
          .collection('hydraulicTests')
          .doc(widget.testId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final test = HydroTest.fromFirestore(snapshot.data!);
        return _buildScaffold(context, test);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, HydroTest? test) {
    final title = test?.numeroPrueba != null
        ? 'Prueba #${test!.numeroPrueba}'
        : _isCreateMode
            ? 'Nueva Prueba${widget.nextTestNumber != null ? ' #${widget.nextTestNumber}' : ''}'
            : 'Prueba Hidrostática';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        actions: [
          if (!_isCreateMode && !_isEditing && test != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar',
              onPressed: () {
                _populateFromTest(test);
                setState(() => _isEditing = true);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete(test);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
          if (_isEditing) ...[
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else ...[
              TextButton(
                onPressed: () {
                  if (_isCreateMode) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _isEditing = false);
                  }
                },
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => _save(test),
                child: const Text('Guardar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ],
      ),
      body: _isEditing
          ? _buildEditForm(context, test)
          : _buildReadView(context, test!),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODO LECTURA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReadView(BuildContext context, HydroTest test) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResultBanner(test),
        const SizedBox(height: 16),
        _buildSection(
          title: 'Datos de la Prueba',
          icon: Icons.science_outlined,
          children: [
            _infoRow('Fecha',
                DateFormat('dd/MM/yyyy').format(test.fechaPrueba)),
            if (test.presionPrueba != null)
              _infoRow('Presión de prueba (PMTA)',
                  '${test.presionPrueba!.toStringAsFixed(2)} ${test.unidadPresion}'),
            if (test.phMultiplier != null)
              _infoRow('Factor PH/PMTA',
                  '${test.phMultiplier!.toStringAsFixed(2)}x'),
            if (test.presionCalculada != null)
              _highlightRow(
                  'Presión hidrostática (PH)',
                  '${test.presionCalculada!.toStringAsFixed(2)} ${test.unidadPresion}'),
            if (test.duracionMinutos != null)
              _infoRow('Duración', '${test.duracionMinutos} minutos'),
            if (test.tecnicoNombre != null &&
                test.tecnicoNombre!.isNotEmpty)
              _infoRow('Técnico', test.tecnicoNombre!),
          ],
        ),
        if (test.observaciones != null && test.observaciones!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSection(
            title: 'Observaciones',
            icon: Icons.notes,
            children: [
              Text(test.observaciones!,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ],
        if (test.hallazgos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSection(
            title: 'Hallazgos (${test.hallazgos.length})',
            icon: Icons.find_in_page_outlined,
            children: test.hallazgos
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(h)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
        if (test.fotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSection(
            title: 'Fotografías (${test.fotos.length})',
            icon: Icons.photo_library_outlined,
            children: [_buildPhotoGrid(test.fotos)],
          ),
        ],
        const SizedBox(height: 12),
        _buildCertificateSection(context, test),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResultBanner(HydroTest test) {
    if (test.resultado == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.grey),
            SizedBox(width: 10),
            Text('Sin resultado registrado',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    final r = test.resultado!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: r.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(r.icon, color: r.color, size: 28),
          const SizedBox(width: 12),
          Text(
            r.label.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: r.color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSection(BuildContext context, HydroTest test) {
    if (test.resultado != HydroTestResult.aprobado) return const SizedBox();

    return _buildSection(
      title: 'Certificado',
      icon: Icons.verified_outlined,
      children: [
        if (test.certificadoGenerado) ...[
          _infoRow('N° Certificado', test.numeroCertificado ?? '-'),
          if (test.fechaCertificado != null)
            _infoRow('Fecha emisión',
                DateFormat('dd/MM/yyyy').format(test.fechaCertificado!)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _generarCertificado(test),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Ver / Reimprimir Certificado'),
            ),
          ),
        ] else ...[
          const Text(
            'Esta prueba está aprobada. Puedes generar el certificado oficial.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _generarCertificado(test),
              icon: const Icon(Icons.verified),
              label: const Text('Generar Certificado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _generarCertificado(HydroTest test) async {
    try {
      await CertificateService.generateAndShare(
        test: test,
        clientId: widget.clientId,
        equipmentName: widget.equipmentName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error generando certificado: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MODO EDICIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEditForm(BuildContext context, HydroTest? existing) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fecha ──────────────────────────────────────────────────────
          _buildSection(
            title: 'Fecha de la Prueba',
            icon: Icons.calendar_today,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_fechaPrueba),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fechaPrueba,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        locale: const Locale('es', 'CL'),
                      );
                      if (picked != null) {
                        setState(() => _fechaPrueba = picked);
                      }
                    },
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Cambiar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Presión ────────────────────────────────────────────────────
          _buildSection(
            title: 'Datos de Presión',
            icon: Icons.compress,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _presionController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Presión PMTA *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _recalcularPresion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _unidadPresion,
                    items: const [
                      DropdownMenuItem(value: 'bar', child: Text('bar')),
                      DropdownMenuItem(value: 'PSI', child: Text('PSI')),
                      DropdownMenuItem(value: 'kPa', child: Text('kPa')),
                      DropdownMenuItem(value: 'kg/cm²', child: Text('kg/cm²')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _unidadPresion = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Factor PH / PMTA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Slider(
                      value: _phMultiplier,
                      min: 1.0,
                      max: 2.0,
                      divisions: 100,
                      label: _phMultiplier.toStringAsFixed(2),
                      onChanged: (v) {
                        setState(() {
                          _phMultiplier = v;
                          _recalcularPresion();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_phMultiplier.toStringAsFixed(2)}x'),
                        if (_presionCalculada != null)
                          Text(
                            'PH = ${_presionCalculada!.toStringAsFixed(2)} $_unidadPresion',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Duración ───────────────────────────────────────────────────
          _buildSection(
            title: 'Duración',
            icon: Icons.timer_outlined,
            children: [
              TextField(
                controller: _duracionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duración (minutos)',
                  border: OutlineInputBorder(),
                  suffixText: 'min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Resultado ──────────────────────────────────────────────────
          _buildSection(
            title: 'Resultado',
            icon: Icons.fact_check_outlined,
            children: [
              DropdownButtonFormField<HydroTestResult>(
                initialValue: _resultado,
                decoration: const InputDecoration(
                  labelText: 'Resultado',
                  border: OutlineInputBorder(),
                ),
                items: HydroTestResult.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              Icon(r.icon, color: r.color, size: 18),
                              const SizedBox(width: 8),
                              Text(r.label),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _resultado = v),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Observaciones ──────────────────────────────────────────────
          _buildSection(
            title: 'Observaciones',
            icon: Icons.notes,
            children: [
              TextField(
                controller: _observacionesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Hallazgos ──────────────────────────────────────────────────
          _buildSection(
            title: 'Hallazgos',
            icon: Icons.find_in_page_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hallazgoInputController,
                      decoration: const InputDecoration(
                        labelText: 'Agregar hallazgo',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addHallazgo(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    color: Colors.blue,
                    onPressed: _addHallazgo,
                  ),
                ],
              ),
              if (_hallazgos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _hallazgos
                      .asMap()
                      .entries
                      .map((e) => Chip(
                            label: Text(e.value,
                                style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(
                                () => _hallazgos.removeAt(e.key)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ── Técnico ────────────────────────────────────────────────────
          _buildSection(
            title: 'Técnico',
            icon: Icons.person_outline,
            children: [
              TextField(
                controller: _tecnicoController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del técnico',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Fotos ──────────────────────────────────────────────────────
          _buildSection(
            title: 'Fotografías',
            icon: Icons.photo_library_outlined,
            children: [
              PhotoManagerWidget(
                urls: existing?.fotos ?? const [],
                storagePath:
                    'equipos/${widget.equipmentId}/pruebas_hidro',
                docRef: _testRef,
                fieldName: 'fotos',
                entityId: _effectiveTestId,
                imageSize: 100,
                entityName: widget.equipmentName,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Botón guardar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(existing),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isCreateMode ? 'Registrar Prueba' : 'Guardar Cambios'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _addHallazgo() {
    final text = _hallazgoInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _hallazgos.add(text);
      _hallazgoInputController.clear();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS UI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
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
            width: 160,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _highlightRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> urls) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) {
        return GestureDetector(
          onTap: () => _viewPhoto(context, urls, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey[200],
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewPhoto(BuildContext context, List<String> urls, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: CachedNetworkImage(
          imageUrl: urls[index],
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
