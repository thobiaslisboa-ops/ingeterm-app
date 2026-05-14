import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/maintenance_extended_model.dart';

/// Dialog para registrar cambio de componente/válvula
class ComponentReplacementDialog extends StatefulWidget {
  final String componentName;
  final String? currentSerialNumber;
  final String currentModel;
  final String? valveTag;
  final String? valveStatus;
  final Function(ComponentReplacement) onReplacementRecorded;

  const ComponentReplacementDialog({
    super.key,
    required this.componentName,
    this.currentSerialNumber,
    required this.currentModel,
    this.valveTag,
    this.valveStatus,
    required this.onReplacementRecorded,
  });

  @override
  State<ComponentReplacementDialog> createState() =>
      _ComponentReplacementDialogState();
}

class _ComponentReplacementDialogState extends State<ComponentReplacementDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _newSerialController;
  late TextEditingController _newModelController;
  late TextEditingController _reasonController;
  late TextEditingController _notesController;
  TestResult _testResult = TestResult.passed;
  final List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    _newSerialController = TextEditingController();
    _newModelController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _newSerialController.dispose();
    _newModelController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrar Cambio de Componente'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info clave de la válvula
                if (widget.valveTag != null && widget.valveTag!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.label, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'TAG: ${widget.valveTag}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (widget.valveStatus != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.valveStatus!,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Información actual
                _buildSectionTitle('🔴 Componente Actual (A Retirar)'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Componente', widget.componentName),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Serial',
                        widget.currentSerialNumber ?? 'No registrado',
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Modelo', widget.currentModel),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nuevo componente
                _buildSectionTitle('🟢 Componente Nuevo (A Instalar)'),
                TextFormField(
                  controller: _newSerialController,
                  decoration: const InputDecoration(
                    labelText: 'Serial del componente nuevo *',
                    hintText: 'Ej: SN-2026-0145',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'El serial es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newModelController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo del componente nuevo *',
                    hintText: 'Ej: ASCO 300-05',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'El modelo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Motivo del reemplazo
                _buildSectionTitle('❓ Motivo del Cambio'),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Razón del reemplazo *',
                    hintText:
                        'Ej: Válvula no mantiene presión, diafragma desgastado...',
                    prefixIcon: Icon(Icons.warning),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Describe la razón del cambio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Prueba de funcionamiento
                _buildSectionTitle('✅ Prueba de Funcionamiento'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<TestResult>(
                        title: const Text('✅ PASA - Funciona correctamente'),
                        subtitle: const Text('El componente nuevo funciona bien'),
                        value: TestResult.passed,
                        groupValue: _testResult,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _testResult = value);
                          }
                        },
                      ),
                      RadioListTile<TestResult>(
                        title: const Text('❌ FALLA - No funciona'),
                        subtitle: const Text('Hay problemas con el componente'),
                        value: TestResult.failed,
                        groupValue: _testResult,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _testResult = value);
                          }
                        },
                      ),
                      RadioListTile<TestResult>(
                        title: const Text('⚠️ PARCIAL - Funcionamiento limitado'),
                        subtitle:
                            const Text('Funciona pero con limitaciones'),
                        value: TestResult.partial,
                        groupValue: _testResult,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _testResult = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Notas adicionales
                _buildSectionTitle('📝 Notas Adicionales (Opcional)'),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas del técnico',
                    hintText: 'Observaciones importantes...',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Información de sincronización
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Este registro se guardará localmente y se sincronizará cuando hay conexión',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveReplacement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Guardar Cambio',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            color: highlight ? Colors.red : Colors.black,
          ),
        ),
      ],
    );
  }

  void _saveReplacement() {
    if (_formKey.currentState!.validate()) {
      final replacement = ComponentReplacement(
        id: const Uuid().v4(),
        componentName: widget.componentName,
        oldSerialNumber: widget.currentSerialNumber,
        newSerialNumber: _newSerialController.text.trim(),
        oldModel: widget.currentModel,
        newModel: _newModelController.text.trim(),
        replacementReason: _reasonController.text.trim(),
        replacementDateTime: DateTime.now(),
        functionalTest: _testResult,
        photoUrls: _photoUrls,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      widget.onReplacementRecorded(replacement);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cambio de ${widget.componentName} registrado ✅',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
