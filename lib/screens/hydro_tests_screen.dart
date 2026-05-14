import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hydro_test_model.dart';
import '../widgets/hydro_test_card.dart';
import 'hydro_test_detail_screen.dart';

class HydroTestsScreen extends StatelessWidget {
  final String clientId;
  final String equipmentId;
  final String equipmentName;
  final bool showAppBar;

  const HydroTestsScreen({
    super.key,
    required this.clientId,
    required this.equipmentId,
    required this.equipmentName,
    this.showAppBar = true,
  });

  CollectionReference<Map<String, dynamic>> get _testsRef =>
      FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .collection('equipments')
          .doc(equipmentId)
          .collection('hydraulicTests');

  @override
  Widget build(BuildContext context) {
    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(equipmentName),
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        body: _buildBody(context),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _testsRef
          .orderBy('fechaPrueba', descending: true)
          .snapshots()
          .handleError((_) => _testsRef
              .orderBy('date', descending: true)
              .snapshots()),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final nextNumber = docs.length + 1;

        return Column(
          children: [
            _buildHeader(context, docs.length, nextNumber),
            Expanded(child: _buildList(context, docs, nextNumber)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
      BuildContext context, int count, int nextNumber) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[700]!],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pruebas Hidrostáticas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count prueba${count != 1 ? 's' : ''} registrada${count != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _navigateToDetail(context, null, nextNumber),
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[700],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int nextNumber,
  ) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay pruebas registradas',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _navigateToDetail(context, null, nextNumber),
              icon: const Icon(Icons.add),
              label: const Text('Registrar primera prueba'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final test = HydroTest.fromFirestore(doc);
        return HydroTestCard(
          test: test,
          onTap: () => _navigateToDetail(context, test.id, null),
        );
      },
    );
  }

  void _navigateToDetail(
      BuildContext context, String? testId, int? nextNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HydroTestDetailScreen(
          clientId: clientId,
          equipmentId: equipmentId,
          equipmentName: equipmentName,
          testId: testId,
          nextTestNumber: nextNumber,
        ),
      ),
    );
  }
}
