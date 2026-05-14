// Historial de mantenciones por componente.
// Pantalla preservada del módulo anterior — será integrada al módulo de
// Mantenciones/Órdenes de Trabajo en una etapa futura.
// NO modificar ni mezclar con la ficha del componente (component_detail_screen).

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/photo_manager_widget.dart';

class ComponentMaintenanceHistoryScreen extends StatefulWidget {
  final String clientId;
  final String equipmentId;
  final String componentId;
  final String componentName;

  const ComponentMaintenanceHistoryScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.componentId,
    required this.componentName,
  });

  @override
  State<ComponentMaintenanceHistoryScreen> createState() =>
      _ComponentMaintenanceHistoryScreenState();
}

class _ComponentMaintenanceHistoryScreenState
    extends State<ComponentMaintenanceHistoryScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _maintenanceRef(String id) => db
      .collection('clients')
      .doc(widget.clientId)
      .collection('equipments')
      .doc(widget.equipmentId)
      .collection('components')
      .doc(widget.componentId)
      .collection('maintenances')
      .doc(id);

  Future<void> _openMaintenanceDialog({DocumentSnapshot? maintenance}) async {
    final notesController =
        TextEditingController(text: maintenance?['notes'] ?? '');
    final nextMaintenanceDateController = TextEditingController();

    // Pre-generar o reutilizar el ID del documento
    final maintenanceId =
        maintenance?.id ?? db.collection('maintenances').doc().id;
    final maintenanceRef = _maintenanceRef(maintenanceId);

    final existingUrls = maintenance != null
        ? (maintenance['fotos'] as List<dynamic>? ?? []).cast<String>()
        : <String>[];

    if (maintenance != null) {
      final nextDate =
          (maintenance['nextMaintenanceDate'] as Timestamp?)?.toDate();
      if (nextDate != null) {
        nextMaintenanceDateController.text =
            DateFormat('dd/MM/yyyy').format(nextDate);
      }
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              maintenance == null ? Icons.add_circle : Icons.edit,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(maintenance == null ? 'Nueva Mantención' : 'Editar Mantención'),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                    hintText: 'Describa el trabajo realizado...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nextMaintenanceDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Próxima Mantención (dd/MM/yyyy)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          locale: const Locale('es', 'CL'),
                        );
                        if (date != null && context.mounted) {
                          setStateDialog(() {
                            nextMaintenanceDateController.text =
                                DateFormat('dd/MM/yyyy').format(date);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.photo_library, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Fotografías',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                PhotoManagerWidget(
                  urls: existingUrls,
                  storagePath:
                      'componentes/${widget.componentId}/maintenances/$maintenanceId/fotos',
                  docRef: maintenanceRef,
                  fieldName: 'fotos',
                  entityId: maintenanceId,
                  imageSize: 90,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe completar al menos las observaciones'),
                  ),
                );
                return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final nextDateTimestamp =
                    nextMaintenanceDateController.text.isNotEmpty
                        ? Timestamp.fromDate(DateFormat('dd/MM/yyyy')
                            .parse(nextMaintenanceDateController.text))
                        : null;

                if (maintenance == null) {
                  await maintenanceRef.set({
                    'notes': notesController.text.trim(),
                    'date': FieldValue.serverTimestamp(),
                    'nextMaintenanceDate': nextDateTimestamp,
                  }, SetOptions(merge: true));
                } else {
                  await maintenanceRef.update({
                    'notes': notesController.text.trim(),
                    'nextMaintenanceDate': nextDateTimestamp,
                  });
                }

                await db
                    .collection('clients')
                    .doc(widget.clientId)
                    .collection('equipments')
                    .doc(widget.equipmentId)
                    .collection('components')
                    .doc(widget.componentId)
                    .update({
                  'lastMaintenanceDate': FieldValue.serverTimestamp(),
                });

                navigator.pop();
                messenger.showSnackBar(SnackBar(
                  content: Text(maintenance == null
                      ? 'Mantención registrada exitosamente'
                      : 'Mantención actualizada exitosamente'),
                  backgroundColor: Colors.green,
                ));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaintenance(DocumentSnapshot maintenance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mantención'),
        content: const Text(
            '¿Estás seguro de eliminar esta mantención?\n\nEsta acción no se puede deshacer.'),
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

    if (confirm == true) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await maintenance.reference.delete();
        messenger.showSnackBar(const SnackBar(
          content: Text('Mantención eliminada exitosamente'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: 'Mantenciones',
        icon: Icons.build_circle,
        showBackButton: true,
        subtitle: widget.componentName,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: ElevatedButton.icon(
              onPressed: () => _openMaintenanceDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Registrar Nueva Mantención'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('clients')
                  .doc(widget.clientId)
                  .collection('equipments')
                  .doc(widget.equipmentId)
                  .collection('components')
                  .doc(widget.componentId)
                  .collection('maintenances')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay mantenciones registradas',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openMaintenanceDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar mantención'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final maintenance = docs[index];
                    final mdata =
                        maintenance.data() as Map<String, dynamic>?;
                    final ts = mdata?['date'] as Timestamp?;
                    final date = ts?.toDate() ?? DateTime.now();
                    final dateStr =
                        DateFormat('dd/MM/yyyy HH:mm').format(date);
                    final notes = (mdata?['notes'] as String?) ?? '';
                    final nextDate =
                        (mdata?['nextMaintenanceDate'] as Timestamp?)
                            ?.toDate();
                    final nextDateStr = nextDate != null
                        ? DateFormat('dd/MM/yyyy').format(nextDate)
                        : null;
                    final fotos =
                        (mdata?['fotos'] as List<dynamic>? ?? [])
                            .cast<String>();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text('${index + 1}',
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                        title: Row(children: [
                          const Icon(Icons.build,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('Mantención - $dateStr')),
                        ]),
                        subtitle: nextDateStr != null
                            ? Text('Próxima: $nextDateStr')
                            : null,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (notes.isNotEmpty) ...[
                                  const Row(children: [
                                    Icon(Icons.note,
                                        size: 18, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text('Observaciones:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(notes),
                                  const SizedBox(height: 16),
                                ],
                                if (fotos.isNotEmpty) ...[
                                  Row(children: [
                                    const Icon(Icons.photo_library,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                        'Fotografías (${fotos.length}):',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold)),
                                  ]),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: fotos.length,
                                      itemBuilder: (_, i) => Container(
                                        margin: const EdgeInsets.only(
                                            right: 8),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: fotos[i],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            placeholder: (c, u) =>
                                                Container(
                                              width: 120,
                                              height: 120,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth:
                                                              2)),
                                            ),
                                            errorWidget: (c, u, e) =>
                                                Container(
                                              width: 120,
                                              height: 120,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  const Text(
                                    'Sin fotografías',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          _openMaintenanceDialog(
                                              maintenance: maintenance),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Editar'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _deleteMaintenance(maintenance),
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      label: const Text('Eliminar',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}
