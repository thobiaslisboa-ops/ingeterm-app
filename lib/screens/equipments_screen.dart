import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'equipment_detail_screen.dart';
import 'maintenance_models.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/smooth_page_transition.dart';
import '../providers/user_provider.dart';

class EquipmentsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const EquipmentsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<EquipmentsScreen> createState() => _EquipmentsScreenState();
}

class _EquipmentsScreenState extends State<EquipmentsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _showEquipmentDialog({DocumentSnapshot? equipment}) async {
    if (equipment == null) {
      // Para crear nuevo equipo, mostrar formulario simple
      final nameController = TextEditingController();
      EquipmentType selectedType = EquipmentType.caldera;
      EquipmentStatus selectedStatus = EquipmentStatus.operational;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Crear Nuevo Equipo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del equipo *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EquipmentType>(
                    initialValue: selectedType,
                    onChanged: (type) {
                      if (type != null) {
                        setStateDialog(() {
                          selectedType = type;
                        });
                      }
                    },
                    isExpanded: true,
                    items: EquipmentType.values
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Flexible(
                                child: Text(
                                  type.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ))
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Equipo *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EquipmentStatus>(
                    initialValue: selectedStatus,
                    onChanged: (status) {
                      if (status != null) {
                        setStateDialog(() {
                          selectedStatus = status;
                        });
                      }
                    },
                    isExpanded: true,
                    items: EquipmentStatus.values
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Flexible(
                                child: Text(
                                  status.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ))
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Estado del Equipo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es obligatorio')),
                    );
                    return;
                  }

                  try {
                    final docRef = await _db
                        .collection('clients')
                        .doc(widget.clientId)
                        .collection('equipments')
                        .add({
                      'name': nameController.text.trim(),
                      'tag': '',
                      'type': selectedType.value,
                      'status': selectedStatus.value,
                      'manufacturer': '',
                      'model': '',
                      'manufacturingYear': null,
                      'installationYear': null,
                      'serialNumber': '',
                      'maxWorkingPressure': '',
                      'location': '',
                      'description': '',
                      'photoUrls': [],
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      // Navegar a equipment_detail_screen para completar la edición
                      Navigator.push(
                        context,
                        SmoothPageTransition(
                          page: EquipmentDetailScreen(
                            clientId: widget.clientId,
                            equipmentId: docRef.id,
                            equipmentName: nameController.text.trim(),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Para editar equipo existente, navegar a equipment_detail_screen
      final edata = equipment.data() as Map<String, dynamic>?;
      Navigator.push(
        context,
        SmoothPageTransition(
          page: EquipmentDetailScreen(
            clientId: widget.clientId,
            equipmentId: equipment.id,
            equipmentName: edata?['name'] ?? '',
          ),
        ),
      ).then((_) {
        // Refrescar la lista cuando vuelva
        setState(() {});
      });
    }
  }

  Future<void> _deleteEquipment(DocumentSnapshot equipment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Equipo'),
        content: Text(
          '¿Estás seguro de eliminar "${equipment['name']}" y todas sus válvulas y componentes?\n\n'
          'Esta acción no se puede deshacer.',
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

    if (confirm == true) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Eliminar valves y maintenances
        final valvesSnap = await equipment.reference.collection('valves').get();
        for (var valve in valvesSnap.docs) {
          final maintenancesSnap =
              await valve.reference.collection('maintenances').get();
          for (var maintenance in maintenancesSnap.docs) {
            await maintenance.reference.delete();
          }
          await valve.reference.delete();
        }

        // Eliminar componentes, sus mantenciones y fotos
        final componentsSnap = await equipment.reference.collection('components').get();
        for (var component in componentsSnap.docs) {
          final maintenancesSnap =
              await component.reference.collection('maintenances').get();
          for (var maintenance in maintenancesSnap.docs) {
            await maintenance.reference.delete();
          }
          await component.reference.delete();
        }

        // Eliminar información general del equipo
        final equipmentInfoSnap = await equipment.reference.collection('equipmentInfo').get();
        for (var info in equipmentInfoSnap.docs) {
          await info.reference.delete();
        }

        // Eliminar pruebas hidráulicas
        final hydraulicTestsSnap = await equipment.reference.collection('hydraulicTests').get();
        for (var test in hydraulicTestsSnap.docs) {
          await test.reference.delete();
        }

        await equipment.reference.delete();
        messenger.showSnackBar(
          const SnackBar(content: Text('Equipo eliminado exitosamente')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<int> _getValveCount(String equipmentId) async {
    final snapshot = await _db
        .collection('clients')
        .doc(widget.clientId)
        .collection('equipments')
        .doc(equipmentId)
        .collection('valves')
        .get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<UserProvider>().isAdmin;
    return Scaffold(
      appBar: AppAppBar(
        title: 'Equipos',
        icon: Icons.precision_manufacturing,
        showBackButton: true,
        subtitle: widget.clientName,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEquipmentDialog(),
            tooltip: 'Agregar equipo',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar equipo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista de equipos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('clients')
                  .doc(widget.clientId)
                  .collection('equipments')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var equipments = snapshot.data!.docs;

                // Filtrar por búsqueda
                if (_searchQuery.isNotEmpty) {
                  equipments = equipments.where((equipment) {
                    final Map<String, dynamic>? edata = equipment.data() as Map<String, dynamic>?;
                    final name = (edata?['name'] as String? ?? '').toLowerCase();
                    final tag = (edata?['tag'] as String? ?? '').toLowerCase();
                    final location = (edata?['location'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        tag.contains(_searchQuery) ||
                        location.contains(_searchQuery);
                  }).toList();
                }

                if (equipments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.precision_manufacturing_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No hay equipos registrados'
                              : 'No se encontraron equipos',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showEquipmentDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar primer equipo'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: equipments.length,
                  itemBuilder: (context, index) {
                    final equipment = equipments[index];
                    final Map<String, dynamic>? edata = equipment.data() as Map<String, dynamic>?;
                    final hasTag = (edata?['tag'] as String?)?.isNotEmpty ?? false;
                    final hasLocation = (edata?['location'] as String?)?.isNotEmpty ?? false;
                    final hasManufacturer = (edata?['manufacturer'] as String?)?.isNotEmpty ?? false;
                    final equipmentType = equipmentTypeFromString(edata?['type'] as String?);
                    final equipmentStatus = equipmentStatusFromString(edata?['status'] as String?);
                    final year = edata?['manufacturingYear'] as int?;
                    final nextInspection = (edata?['nextInspectionDate'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: equipmentStatus == EquipmentStatus.operational
                              ? Colors.green.withValues(alpha: 0.7)
                              : equipmentStatus == EquipmentStatus.maintenance
                                  ? Colors.orange.withValues(alpha: 0.7)
                                  : Colors.red.withValues(alpha: 0.7),
                          child: Icon(
                            equipmentStatus == EquipmentStatus.operational
                                ? Icons.check_circle
                                : equipmentStatus == EquipmentStatus.maintenance
                                    ? Icons.build
                                    : Icons.do_not_disturb,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          edata?['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.category_outlined,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    equipmentType.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: equipmentStatus == EquipmentStatus.operational
                                        ? Colors.green.withOpacity(0.2)
                                        : equipmentStatus == EquipmentStatus.maintenance
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    equipmentStatus.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: equipmentStatus == EquipmentStatus.operational
                                          ? Colors.green[700]
                                          : equipmentStatus == EquipmentStatus.maintenance
                                              ? Colors.orange[700]
                                              : Colors.red[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasTag) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.tag,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'TAG: ${edata?['tag'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (hasManufacturer) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.factory,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text('${edata?['manufacturer'] ?? ''}'),
                                  ),
                                ],
                              ),
                            ],
                            if (year != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.date_range,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Fabricado: $year',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (hasLocation) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(edata?['location'] ?? ''),
                                  ),
                                ],
                              ),
                            ],
                            if (nextInspection != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Próx. Insp: ${nextInspection.day}/${nextInspection.month}/${nextInspection.year}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            FutureBuilder<int>(
                              future: _getValveCount(equipment.id),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Row(
                                    children: [
                                      const Icon(Icons.plumbing,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${snapshot.data} válvula${snapshot.data != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showEquipmentDialog(equipment: equipment),
                              tooltip: 'Editar',
                            ),
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEquipment(equipment),
                                tooltip: 'Eliminar',
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EquipmentDetailScreen(
                                clientId: widget.clientId,
                                equipmentId: equipment.id,
                                equipmentName: edata?['name'] ?? '',
                              ),
                            ),
                          );
                        },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}