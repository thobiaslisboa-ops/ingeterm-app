import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'equipments_screen.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/smooth_page_transition.dart';
import '../providers/user_provider.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _showClientDialog({DocumentSnapshot? client}) async {
    final Map<String, dynamic>? cdataInit = client?.data() as Map<String, dynamic>?;
    final nameController = TextEditingController(text: cdataInit?['name'] as String? ?? '');
    final contactController = TextEditingController(text: cdataInit?['contactPerson'] as String? ?? '');
    final phoneController = TextEditingController(text: cdataInit?['phone'] as String? ?? '');
    final emailController = TextEditingController(text: cdataInit?['email'] as String? ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Agregar Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Persona de contacto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
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
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);              try {
                if (client == null) {
                  await _db.collection('clients').add({
                    'name': nameController.text.trim(),
                    'contactPerson': contactController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await _db.collection('clients').doc(client.id).update({
                    'name': nameController.text.trim(),
                    'contactPerson': contactController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                  });
                }
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(client == null 
                      ? 'Cliente agregado exitosamente' 
                      : 'Cliente actualizado exitosamente'),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(DocumentSnapshot client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text(
          '¿Estás seguro de eliminar "${((client.data() as Map<String,dynamic>?)?['name'] ?? '')}" y todo su contenido?\n\n'
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

    if (!mounted) return;
    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Eliminar subcollections (equipments, valves, maintenances)
        final equipmentsSnap = await _db
            .collection('clients')
            .doc(client.id)
            .collection('equipments')
            .get();

        for (var equipment in equipmentsSnap.docs) {
          // Eliminar valves y sus maintenances
          final valvesSnap = await equipment.reference.collection('valves').get();
          for (var valve in valvesSnap.docs) {
            final maintenancesSnap = await valve.reference.collection('maintenances').get();
            for (var maintenance in maintenancesSnap.docs) {
              await maintenance.reference.delete();
            }
            await valve.reference.delete();
          }
          await equipment.reference.delete();
        }

        await _db.collection('clients').doc(client.id).delete();
        messenger.showSnackBar(
          const SnackBar(content: Text('Cliente eliminado exitosamente')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<UserProvider>().isAdmin;
    return Scaffold(
      appBar: AppAppBar(
        title: 'Gestión de Clientes',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showClientDialog(),
            tooltip: 'Agregar cliente',
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
                labelText: 'Buscar cliente',
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
          
          // Lista de clientes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('clients')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var clients = snapshot.data!.docs;

                // Filtrar por búsqueda
                if (_searchQuery.isNotEmpty) {
                  clients = clients.where((client) {
                    final Map<String, dynamic>? cdata = client.data() as Map<String, dynamic>?;
                    final name = (cdata?['name'] as String? ?? '').toLowerCase();
                    final contact = (cdata?['contactPerson'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) || contact.contains(_searchQuery);
                  }).toList();
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No hay clientes registrados'
                              : 'No se encontraron clientes',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showClientDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar primer cliente'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final Map<String, dynamic>? cdata = client.data() as Map<String, dynamic>?;
                    final hasContact = (cdata?['contactPerson'] as String?)?.isNotEmpty ?? false;
                    final hasPhone = (cdata?['phone'] as String?)?.isNotEmpty ?? false;
                    final cname = cdata?['name'] as String? ?? '';  

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            cname.isNotEmpty ? cname[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          cname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasContact) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      cdata?['contactPerson'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (hasPhone) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      cdata?['phone'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showClientDialog(client: client),
                              tooltip: 'Editar',
                            ),
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteClient(client),
                                tooltip: 'Eliminar',
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            SmoothPageTransition(
                              page: EquipmentsScreen(
                                clientId: client.id,
                                clientName: cname,
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