// lib/screens/maintenance_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_model.dart';
import '../models/work_item_model.dart';
import '../providers/user_provider.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/maintenance_card.dart';
import '../widgets/photo_manager_widget.dart';
import '../widgets/sync_status_bar.dart';
import '../services/offline_sync_service.dart';
import '../services/maintenance_sync_service.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final String maintenanceId;
  final String clienteId;
  final String equipoId;

  const MaintenanceDetailScreen({
    super.key,
    required this.maintenanceId,
    required this.clienteId,
    required this.equipoId,
  });

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState
    extends State<MaintenanceDetailScreen> {
  final _db = FirebaseFirestore.instance;
  final _syncController = SyncStatusController();

  String _clienteNombre = '';
  String _equipoNombre = '';

  // ── Referencias Firestore ─────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _maintenanceRef => _db
      .collection('clients')
      .doc(widget.clienteId)
      .collection('equipments')
      .doc(widget.equipoId)
      .collection('maintenances')
      .doc(widget.maintenanceId);

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _maintenanceRef.collection('items');

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadNombres();
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  // ── Guardar con estado visible ─────────────────────────────────────────────

  /// Ejecuta [fn] (write a Firestore), muestra "✓ Guardado" si hay conexión
  /// o "Sin conexión" si no la hay. Firestore persistence garantiza que el
  /// write se sincronizará cuando la conexión se recupere.
  Future<void> _saveWithStatus(Future<void> Function() fn) async {
    try {
      final online = await OfflineSyncService().checkAndSave(fn);
      if (online) {
        _syncController.showSaved();
      } else {
        _syncController.showOffline();
      }
    } catch (e) {
      _syncController.showError(
        onRetry: () => _saveWithStatus(fn),
      );
    }
  }

  Future<void> _loadNombres() async {
    final clienteSnap =
        await _db.collection('clients').doc(widget.clienteId).get();
    final equipoSnap = await _db
        .collection('clients')
        .doc(widget.clienteId)
        .collection('equipments')
        .doc(widget.equipoId)
        .get();
    if (mounted) {
      setState(() {
        _clienteNombre =
            clienteSnap.data()?['name'] as String? ?? widget.clienteId;
        _equipoNombre =
            equipoSnap.data()?['name'] as String? ?? widget.equipoId;
      });
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _maintenanceRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppAppBar(title: 'Mantención', showBackButton: true),
            body: Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red))),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppAppBar(title: 'Mantención', showBackButton: true),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.data!.exists) {
          return Scaffold(
            appBar: AppAppBar(title: 'Mantención', showBackButton: true),
            body: const Center(child: Text('Mantención no encontrada')),
          );
        }
        final m = MaintenanceModel.fromFirestore(snap.data!);
        return _buildScaffold(m);
      },
    );
  }

  Widget _buildScaffold(MaintenanceModel m) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: 'OT-${m.numeroOrden.toString().padLeft(4, '0')}',
        subtitle: m.titulo,
        icon: Icons.build_circle,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOpciones(m),
          ),
        ],
      ),
      body: Column(
        children: [
          SyncStatusBar(controller: _syncController),
          Expanded(
            child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
              child: _buildSeccion1Encabezado(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('2 — Tiempo')),
          SliverToBoxAdapter(
              child: _buildSeccion2Tiempo(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('3 — Ítems de Trabajo')),
          SliverToBoxAdapter(
              child: _buildSeccion3Items(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('4 — Repuestos')),
          SliverToBoxAdapter(
              child: _buildSeccion4Repuestos(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('5 — Aumentos de Obra')),
          SliverToBoxAdapter(
              child: _buildSeccion5AumentosObra(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('6 — Fotos Generales')),
          SliverToBoxAdapter(
              child: _buildSeccion6Fotos(m)),
          SliverToBoxAdapter(
              child: _buildSectionDivider('7 — Observaciones Generales')),
          SliverToBoxAdapter(
              child: _buildSeccion7Observaciones(m)),
          if (m.estado != EstadoMantencion.finalizada &&
              m.estado != EstadoMantencion.cerrada)
            SliverToBoxAdapter(child: _buildBotonFinalizar(m)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 1 — Encabezado
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion1Encabezado(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado chip + botón cambiar
          Row(
            children: [
              _estadoChip(m.estado),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _cambiarEstado(m),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Cambiar estado',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título editable
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _editarTexto(
              label: 'Título',
              valor: m.titulo,
              onGuardar: (v) => _maintenanceRef.update({
                'titulo': v,
                'actualizadoEn': FieldValue.serverTimestamp(),
              }),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m.titulo,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(Icons.edit, size: 15, color: Colors.grey[400]),
              ],
            ),
          ),
          if (m.tiposTrabajo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: m.tiposTrabajo
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1A5DB5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF1A5DB5)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A5DB5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),

          // Cliente
          _infoRow(
              Icons.business_outlined,
              _clienteNombre.isNotEmpty ? _clienteNombre : '…'),
          const SizedBox(height: 6),

          // Equipo
          _infoRow(
              Icons.precision_manufacturing_outlined,
              _equipoNombre.isNotEmpty ? _equipoNombre : '…'),
          const SizedBox(height: 10),

          // Técnico editable
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _editarTexto(
              label: 'Técnico',
              valor: m.tecnicoNombre,
              onGuardar: (v) => _maintenanceRef.update({
                'tecnicoNombre': v,
                'actualizadoEn': FieldValue.serverTimestamp(),
              }),
            ),
            child: Row(
              children: [
                Icon(Icons.engineering, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Técnico: ',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13)),
                Text(
                  m.tecnicoNombre.isNotEmpty
                      ? m.tecnicoNombre
                      : 'Agregar técnico',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: m.tecnicoNombre.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: m.tecnicoNombre.isNotEmpty
                        ? Colors.black87
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 13, color: Colors.grey[400]),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 2 — Tiempo
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion2Tiempo(MaintenanceModel m) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _tiempoRow(
            icon: Icons.play_circle_outline,
            label: 'Hora de inicio',
            valor: m.horaInicio != null ? fmt.format(m.horaInicio!) : null,
            color: Colors.green,
            botonLabel: 'Registrar inicio',
            onBoton: m.horaInicio == null
                ? () => _maintenanceRef.update({
                      'horaInicio': FieldValue.serverTimestamp(),
                      'estado': EstadoMantencion.enEjecucion.value,
                      'actualizadoEn': FieldValue.serverTimestamp(),
                    })
                : null,
          ),
          const SizedBox(height: 10),
          _tiempoRow(
            icon: Icons.stop_circle_outlined,
            label: 'Hora de término',
            valor: m.horaTermino != null
                ? fmt.format(m.horaTermino!)
                : null,
            color: Colors.red[700]!,
            botonLabel: 'Registrar término',
            onBoton: m.horaTermino == null
                ? () => _maintenanceRef.update({
                      'horaTermino': FieldValue.serverTimestamp(),
                      'actualizadoEn': FieldValue.serverTimestamp(),
                    })
                : null,
          ),
          if (m.duracionMinutos != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5DB5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer,
                      size: 16, color: Color(0xFF1A5DB5)),
                  const SizedBox(width: 6),
                  Text('Duración total: ',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 13)),
                  Text(
                    _formatDuracion(m.duracionMinutos!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5DB5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 3 — Trabajos realizados
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion3Items(MaintenanceModel m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _itemsRef.orderBy('creadoEn').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Text(
                  'Sin trabajos registrados. Agrega uno abajo.',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final item = WorkItemModel.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>);
                return _buildWorkItemTile(item);
              }).toList(),
            );
          },
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () => _showAddTrabajoSheet(m),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar trabajo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5DB5),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkItemTile(WorkItemModel item) {
    final color = _workItemColor(item.tipo);
    final icon = _workItemIcon(item.tipo);

    final String titulo;
    if (item.tipo == WorkItemType.pruebaHidrostatica) {
      titulo = 'Prueba Hidrostática';
    } else if (item.tipo == WorkItemType.pruebaValvula) {
      titulo = item.referenciaNombre != null
          ? 'Válvula: ${item.referenciaNombre}'
          : 'Prueba de Válvula';
    } else if (item.tipo == WorkItemType.otro) {
      titulo = item.titulo ?? 'Otro';
    } else {
      titulo = item.referenciaNombre ?? item.tipo.label;
    }

    final String? subtituloExtra = () {
      if (item.tipo == WorkItemType.pruebaHidrostatica &&
          item.resultado != null) {
        const icons = {
          'aprobado': '✓',
          'rechazado': '✗',
          'observado': '⚠',
        };
        return '${icons[item.resultado] ?? ''} ${item.resultado}';
      }
      if (item.tipo == WorkItemType.pruebaValvula &&
          item.resultadoValvula != null) {
        const labels = {
          'verificada_ok': '✓ Verificada OK',
          'requiere_mantencion': '🔧 Requiere mantención',
          'solo_calibracion': '📐 Solo calibración',
        };
        return labels[item.resultadoValvula];
      }
      return null;
    }();

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(titulo,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(item.tipo.label,
                style: TextStyle(fontSize: 11, color: color)),
          ),
          if (subtituloExtra != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(subtituloExtra,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
          if (item.completado) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle,
                size: 14, color: Colors.green),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.fotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.photo_library_outlined,
                  size: 15, color: Colors.grey[400]),
            ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () => _showEditWorkItemSheet(item),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 4 — Repuestos
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion4Repuestos(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ...m.repuestos.asMap().entries.map((e) {
            final idx = e.key;
            final r = e.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: Colors.grey),
              title: Text(r.nombre,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                '${r.cantidad % 1 == 0 ? r.cantidad.toInt() : r.cantidad} ${r.unidad}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red[300], size: 18),
                onPressed: () => _eliminarRepuesto(m, idx),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _showAgregarRepuesto(m),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar repuesto',
                style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 5 — Aumentos de obra
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion5AumentosObra(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ...m.aumentosObra.asMap().entries.map((e) {
            final idx = e.key;
            final a = e.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.add_task,
                  size: 18, color: Colors.orange),
              title: Text(a.descripcion,
                  style: const TextStyle(fontSize: 14)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red[300], size: 18),
                onPressed: () => _eliminarAumento(m, idx),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => _showAgregarAumento(m),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar aumento de obra',
                style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 6 — Fotos generales
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion6Fotos(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: PhotoManagerWidget(
        urls: m.fotos,
        storagePath: 'maintenances/${m.id}/fotos',
        docRef: _maintenanceRef,
        fieldName: 'fotos',
        entityId: m.id,
        imageSize: 130,
        entityName: 'OT-${m.numeroOrden.toString().padLeft(4, '0')}',
        onStatusChange: (status) {
          switch (status.state) {
            case PhotoUploadState.uploading:
              _syncController.showUploading();
              break;
            case PhotoUploadState.done:
              _syncController.showSaved(message: '✓ Foto guardada');
              break;
            case PhotoUploadState.error:
              _syncController.showError();
              break;
            case PhotoUploadState.offlineQueued:
              _syncController.showOffline(
                  message: 'Sin conexión — la foto se subirá al reconectar');
              break;
            case PhotoUploadState.idle:
              break;
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN 7 — Observaciones generales
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeccion7Observaciones(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _editarTexto(
          label: 'Observaciones generales',
          valor: m.observacionesGenerales,
          multiline: true,
          onGuardar: (v) => _maintenanceRef.update({
            'observacionesGenerales': v,
            'actualizadoEn': FieldValue.serverTimestamp(),
          }),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  m.observacionesGenerales.isNotEmpty
                      ? m.observacionesGenerales
                      : 'Tap para agregar observaciones...',
                  style: TextStyle(
                    color: m.observacionesGenerales.isNotEmpty
                        ? Colors.black87
                        : Colors.grey,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTÓN FINALIZAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBotonFinalizar(MaintenanceModel m) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: ElevatedButton.icon(
        onPressed: () => _finalizar(m),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Finalizar Mantención'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
                thickness: 1, color: Colors.grey[300], height: 1),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(EstadoMantencion estado) {
    final color = MaintenanceCard.estadoColor(estado);
    final icon = MaintenanceCard.estadoIcon(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            estado.label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
      ],
    );
  }

  Widget _tiempoRow({
    required IconData icon,
    required String label,
    required String? valor,
    required Color color,
    required String botonLabel,
    required VoidCallback? onBoton,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600])),
              Text(
                valor ?? 'No registrada',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: valor != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: valor != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        if (onBoton != null)
          OutlinedButton(
            onPressed: onBoton,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(botonLabel),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES — Edición de campos
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _editarTexto({
    required String label,
    required String valor,
    bool multiline = false,
    required Future<void> Function(String) onGuardar,
  }) async {
    final ctrl = TextEditingController(text: valor);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(
          controller: ctrl,
          maxLines: multiline ? 5 : 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result != valor) {
      await _saveWithStatus(() => onGuardar(result));
    }
  }

  Future<void> _cambiarEstado(MaintenanceModel m) async {
    final nuevo = await showDialog<EstadoMantencion>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Cambiar estado'),
        children: EstadoMantencion.values
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e),
                  child: Row(
                    children: [
                      Icon(MaintenanceCard.estadoIcon(e),
                          color: MaintenanceCard.estadoColor(e), size: 20),
                      const SizedBox(width: 12),
                      Text(e.label),
                      if (e == m.estado) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check, size: 16,
                            color: Colors.green),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (nuevo != null && nuevo != m.estado) {
      await _saveWithStatus(() => _maintenanceRef.update({
            'estado': nuevo.value,
            'actualizadoEn': FieldValue.serverTimestamp(),
          }));
    }
  }

  Future<void> _finalizar(MaintenanceModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar mantención'),
        content: const Text(
            '¿Confirmas que la mantención está completa? Se registrará la hora de término si no fue registrada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final updates = <String, dynamic>{
      'estado': EstadoMantencion.finalizada.value,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    if (m.horaTermino == null) {
      updates['horaTermino'] = FieldValue.serverTimestamp();
    }
    await _saveWithStatus(() => _maintenanceRef.update(updates));
    if (mounted) _showSnack('Mantención finalizada');
  }

  void _showOpciones(MaintenanceModel m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Cambiar estado'),
              onTap: () {
                Navigator.pop(context);
                _cambiarEstado(m);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red[400]),
              title: Text('Eliminar mantención',
                  style: TextStyle(color: Colors.red[400])),
              onTap: () {
                Navigator.pop(context);
                _confirmarEliminar();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar mantención'),
        content: const Text(
            'Esta acción no se puede deshacer. ¿Eliminar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _maintenanceRef.delete();
    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES — Repuestos
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showAgregarRepuesto(MaintenanceModel m) async {
    final nombreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');
    final unidadCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar repuesto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre del repuesto',
                  border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cantidadCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unidadCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Unidad',
                        hintText: 'unid, kg, m',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar')),
        ],
      ),
    );

    if (ok != true) return;
    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    final nuevo = RepuestoItem(
      id: _db.collection('_').doc().id,
      nombre: nombre,
      cantidad: double.tryParse(cantidadCtrl.text) ?? 1,
      unidad: unidadCtrl.text.trim(),
    );
    final lista = [...m.repuestos, nuevo];
    await _maintenanceRef.update({
      'repuestos': lista.map((r) => r.toMap()).toList(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _eliminarRepuesto(MaintenanceModel m, int idx) async {
    final lista = [...m.repuestos]..removeAt(idx);
    await _maintenanceRef.update({
      'repuestos': lista.map((r) => r.toMap()).toList(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES — Aumentos de obra
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showAgregarAumento(MaintenanceModel m) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar aumento de obra'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Descripción del trabajo extra',
              border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agregar')),
        ],
      ),
    );

    if (ok != true) return;
    final desc = ctrl.text.trim();
    if (desc.isEmpty) return;

    final nuevo = AumentoObra(
      id: _db.collection('_').doc().id,
      descripcion: desc,
    );
    final lista = [...m.aumentosObra, nuevo];
    await _maintenanceRef.update({
      'aumentosObra': lista.map((a) => a.toMap()).toList(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _eliminarAumento(MaintenanceModel m, int idx) async {
    final lista = [...m.aumentosObra]..removeAt(idx);
    await _maintenanceRef.update({
      'aumentosObra': lista.map((a) => a.toMap()).toList(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES — Agregar ítem de trabajo
  // ═══════════════════════════════════════════════════════════════════════════

  void _showAddTrabajoSheet(MaintenanceModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTrabajoSheet(
        clienteId: widget.clienteId,
        equipoId: widget.equipoId,
        equipoNombre: _equipoNombre,
        maintenanceId: widget.maintenanceId,
        tecnicoNombre: m.tecnicoNombre,
        onCreated: () async {
          await _recalcularContadores();
        },
        itemsRef: _itemsRef,
      ),
    );
  }

  void _showEditWorkItemSheet(WorkItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditWorkItemSheet(
        item: item,
        clienteId: widget.clienteId,
        equipoId: widget.equipoId,
        maintenanceId: widget.maintenanceId,
        itemsRef: _itemsRef,
        onChanged: () async {
          await _recalcularContadores();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTADORES DENORMALIZADOS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _recalcularContadores() async {
    final snap = await _itemsRef.get();
    final total = snap.docs.length;
    final completados = snap.docs.where((d) {
      return d.data()['completado'] as bool? ?? false;
    }).length;
    await _maintenanceRef.update({
      'totalItems': total,
      'itemsCompletados': completados,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Color _workItemColor(WorkItemType tipo) {
    switch (tipo) {
      case WorkItemType.pruebaHidrostatica:   return Colors.blue;
      case WorkItemType.pruebaValvula:        return Colors.orange;
      case WorkItemType.mantencionEquipo:     return const Color(0xFF1A5DB5);
      case WorkItemType.mantencionComponente: return Colors.teal;
      case WorkItemType.otro:                 return Colors.grey;
    }
  }

  IconData _workItemIcon(WorkItemType tipo) {
    switch (tipo) {
      case WorkItemType.pruebaHidrostatica:   return Icons.water_drop_outlined;
      case WorkItemType.pruebaValvula:        return Icons.plumbing;
      case WorkItemType.mantencionEquipo:     return Icons.precision_manufacturing;
      case WorkItemType.mantencionComponente: return Icons.settings;
      case WorkItemType.otro:                 return Icons.edit_note;
    }
  }

  String _formatDuracion(int minutos) {
    if (minutos < 60) return '${minutos}min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _AddTrabajoSheet — Agregar nuevo trabajo a la orden
// ═══════════════════════════════════════════════════════════════════════════════

class _AddTrabajoSheet extends StatefulWidget {
  final String clienteId;
  final String equipoId;
  final String equipoNombre;
  final String maintenanceId;
  final String tecnicoNombre;
  final VoidCallback onCreated;
  final CollectionReference<Map<String, dynamic>> itemsRef;

  const _AddTrabajoSheet({
    required this.clienteId,
    required this.equipoId,
    required this.equipoNombre,
    required this.maintenanceId,
    required this.tecnicoNombre,
    required this.onCreated,
    required this.itemsRef,
  });

  @override
  State<_AddTrabajoSheet> createState() => _AddTrabajoSheetState();
}

class _AddTrabajoSheetState extends State<_AddTrabajoSheet> {
  final _db = FirebaseFirestore.instance;

  WorkItemType? _tipo;
  bool _guardando = false;

  // ── Prueba Hidrostática ──────────────────────────────────────────────────
  final _presionCtrl = TextEditingController();
  String _unidadPresion = 'bar';
  final _duracionCtrl = TextEditingController();
  String? _resultadoHidro;
  final _obsHidroCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  // ── Prueba de Válvula ────────────────────────────────────────────────────
  String? _valvulaId;
  String? _valvulaNombre;
  bool _valvulaManual = false;
  final _valvulaNombreManualCtrl = TextEditingController();
  bool _valvulaConfirmada = false;
  String? _resultadoValvula;
  final List<String> _tareasValvula = [];
  final List<String> _repuestosValvula = [];
  final _seteoAntCtrl = TextEditingController();
  final _seteoNuevoCtrl = TextEditingController();
  final _corteAntCtrl = TextEditingController();
  final _corteNuevoCtrl = TextEditingController();
  String _unidadValvula = 'bar';
  final _obsValvulaCtrl = TextEditingController();

  // ── Mantención ───────────────────────────────────────────────────────────
  bool _esComponente = false;
  String? _componenteId;
  String? _componenteNombre;
  final _descMantencionCtrl = TextEditingController();
  final List<String> _tareasMantencion = [];
  final List<String> _repuestosMantencion = [];
  final _obsMantencionCtrl = TextEditingController();

  // ── Otro ─────────────────────────────────────────────────────────────────
  final _tituloOtroCtrl = TextEditingController();
  final _descOtroCtrl = TextEditingController();

  // ── Controladores "agregar ítem" para listas dinámicas ────────────────────
  // Uno por lista para que el texto no se pierda entre rebuilds.
  final _addTareaValvulaCtrl    = TextEditingController();
  final _addRepuestoValvulaCtrl = TextEditingController();
  final _addTareaMantencionCtrl    = TextEditingController();
  final _addRepuestoMantencionCtrl = TextEditingController();

  // ── Trazabilidad: quién realizó el trabajo ────────────────────────────────
  final _realizadoPorCtrl = TextEditingController();

  // ── Futures cacheados para evitar recarga en cada setState ────────────────
  Future<QuerySnapshot<Map<String, dynamic>>>? _valvesFuture;
  Future<QuerySnapshot<Map<String, dynamic>>>? _componentesFuture;

  @override
  void initState() {
    super.initState();
    // Pre-rellenar con el nombre del usuario logueado (editable)
    _realizadoPorCtrl.text = context.read<UserProvider>().nombreCompleto;
  }

  @override
  void dispose() {
    _presionCtrl.dispose();
    _duracionCtrl.dispose();
    _obsHidroCtrl.dispose();
    _certCtrl.dispose();
    _valvulaNombreManualCtrl.dispose();
    _seteoAntCtrl.dispose();
    _seteoNuevoCtrl.dispose();
    _corteAntCtrl.dispose();
    _corteNuevoCtrl.dispose();
    _obsValvulaCtrl.dispose();
    _descMantencionCtrl.dispose();
    _obsMantencionCtrl.dispose();
    _tituloOtroCtrl.dispose();
    _descOtroCtrl.dispose();
    _addTareaValvulaCtrl.dispose();
    _addRepuestoValvulaCtrl.dispose();
    _addTareaMantencionCtrl.dispose();
    _addRepuestoMantencionCtrl.dispose();
    _realizadoPorCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _tipo == null ? 0.5 : 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildSheetHeader(),
            const Divider(height: 1),
            Expanded(
              child: _tipo == null
                  ? _buildTipoSelector(ctrl)
                  : _buildFormForTipo(ctrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _buildSheetHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF1A5DB5)),
            const SizedBox(width: 10),
            Text(
              _tipo == null ? 'Tipo de trabajo' : _tipo!.label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_tipo != null) ...[
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _tipo = null;
                  _valvulaConfirmada = false;
                }),
                child: const Text('Cambiar'),
              ),
            ],
          ],
        ),
      );

  // ── Selector de tipo ──────────────────────────────────────────────────────

  Widget _buildTipoSelector(ScrollController ctrl) {
    final opciones = [
      (WorkItemType.pruebaHidrostatica, Icons.water_drop_outlined,
          Colors.blue, 'Registra presión, duración y resultado'),
      (WorkItemType.pruebaValvula, Icons.plumbing, Colors.orange,
          'Verifica o calibra una válvula del equipo'),
      (WorkItemType.mantencionEquipo, Icons.build_outlined,
          const Color(0xFF1A5DB5),
          'Trabajos en el equipo o sus componentes'),
      (WorkItemType.otro, Icons.edit_note, Colors.grey,
          'Descripción libre de trabajo'),
    ];
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: opciones.map((o) {
        final (tipo, icon, color, desc) = o;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(tipo.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(desc,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _tipo = tipo),
          ),
        );
      }).toList(),
    );
  }

  // ── Despachador de formularios ────────────────────────────────────────────

  Widget _buildFormForTipo(ScrollController ctrl) {
    Widget form;
    switch (_tipo!) {
      case WorkItemType.pruebaHidrostatica:
        form = _buildHidroForm(ctrl);
        break;
      case WorkItemType.pruebaValvula:
        form = _valvulaConfirmada
            ? _buildValvulaResultForm(ctrl)
            : _buildValvulaSelector(ctrl);
        break;
      case WorkItemType.mantencionEquipo:
      case WorkItemType.mantencionComponente:
        form = _buildMantencionForm(ctrl);
        break;
      case WorkItemType.otro:
        form = _buildOtroForm(ctrl);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _realizadoPorCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Realizado por',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Modifica si otra persona realizó el trabajo',
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: form),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORMULARIO — Prueba Hidrostática
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHidroForm(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        // Presión + unidad
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _field(
                controller: _presionCtrl,
                label: 'Presión de prueba',
                hint: 'Ej: 24.0',
                keyboard: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<String>(
                value: _unidadPresion,
                decoration: const InputDecoration(
                    labelText: 'Unidad', border: OutlineInputBorder()),
                items: ['bar', 'PSI', 'kPa']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unidadPresion = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Duración
        _field(
          controller: _duracionCtrl,
          label: 'Duración (minutos)',
          hint: 'Ej: 30',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 14),

        // Resultado
        const Text('Resultado',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        _resultadoChips(
          opciones: const ['aprobado', 'rechazado', 'observado'],
          labels: const ['Aprobado', 'Rechazado', 'Con observaciones'],
          colores: const [Colors.green, Colors.red, Colors.orange],
          seleccionado: _resultadoHidro,
          onSelect: (v) => setState(() => _resultadoHidro = v),
        ),
        const SizedBox(height: 14),

        // Observaciones
        _field(
          controller: _obsHidroCtrl,
          label: 'Observaciones',
          hint: 'Hallazgos, condiciones de prueba...',
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        // Nº certificado (opcional)
        _field(
          controller: _certCtrl,
          label: 'Nº certificado (opcional)',
          hint: 'Ej: HT-2024-001',
        ),
        const SizedBox(height: 24),

        _botonGuardar(
          onPressed: _resultadoHidro != null ? _guardarHidro : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _guardarHidro() async {
    setState(() => _guardando = true);
    try {
      final ref = widget.itemsRef.doc();
      final item = WorkItemModel(
        id: ref.id,
        maintenanceId: widget.maintenanceId,
        equipoId: widget.equipoId,
        clienteId: widget.clienteId,
        tipo: WorkItemType.pruebaHidrostatica,
        descripcion: _obsHidroCtrl.text.trim(),
        fotos: const [],
        observaciones: _obsHidroCtrl.text.trim(),
        completado: false,
        presionPrueba: double.tryParse(_presionCtrl.text.trim()),
        unidadPresion: _unidadPresion,
        duracionMinutos: int.tryParse(_duracionCtrl.text.trim()),
        resultado: _resultadoHidro,
        numeroCertificado: _certCtrl.text.trim().isEmpty
            ? null
            : _certCtrl.text.trim(),
        realizadoPor: _realizadoPorCtrl.text.trim().isEmpty
            ? null
            : _realizadoPorCtrl.text.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await ref.set(item.toMap(isCreate: true));

      // Sincronizar con módulo de pruebas hidrostáticas
      final online = await MaintenanceSyncService.instance.syncWorkItem(
        item,
        tecnicoNombre: widget.tecnicoNombre.isNotEmpty
            ? widget.tecnicoNombre
            : null,
      );

      widget.onCreated();
      if (mounted) {
        if (!online) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión — se sincronizará al reconectar'),
            duration: Duration(seconds: 3),
          ));
        }
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORMULARIO — Prueba de Válvula (fase 1: selector)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildValvulaSelector(ScrollController ctrl) {
    _valvesFuture ??= _db
        .collection('clients')
        .doc(widget.clienteId)
        .collection('equipments')
        .doc(widget.equipoId)
        .collection('valves')
        .get();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _valvesFuture,
      builder: (_, snap) {
        return ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Selecciona la válvula',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 10),

            // Válvulas registradas
            if (snap.hasData && snap.data!.docs.isNotEmpty) ...[
              ...snap.data!.docs.map((doc) {
                final d = doc.data();
                final tag = d['tag'] as String? ?? '';
                final name = d['name'] as String? ?? doc.id;
                final label = tag.isNotEmpty ? tag : name;
                final sub = tag.isNotEmpty ? name : '';
                final selected = _valvulaId == doc.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: selected
                      ? Colors.orange.withValues(alpha: 0.08)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: selected
                            ? Colors.orange
                            : Colors.transparent),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.plumbing,
                        color: selected ? Colors.orange : Colors.grey),
                    title: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: sub.isNotEmpty ? Text(sub) : null,
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: Colors.orange)
                        : null,
                    onTap: () => setState(() {
                      _valvulaId = doc.id;
                      _valvulaNombre = label;
                      _valvulaManual = false;
                    }),
                  ),
                );
              }),
              const Divider(height: 24),
            ] else if (!snap.hasData) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ],

            // Ingreso manual
            Card(
              margin: EdgeInsets.zero,
              color: _valvulaManual
                  ? Colors.orange.withValues(alpha: 0.08)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: _valvulaManual
                        ? Colors.orange
                        : Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: Colors.orange[700], size: 18),
                        const SizedBox(width: 8),
                        Text('Válvula no está en la lista',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _valvulaNombreManualCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Tag o nombre (ej: VR-101)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _valvulaManual = v.trim().isNotEmpty;
                        _valvulaId = null;
                        _valvulaNombre = v.trim();
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: ((_valvulaId != null) ||
                      (_valvulaManual &&
                          _valvulaNombreManualCtrl.text.trim().isNotEmpty))
                  ? () => setState(() => _valvulaConfirmada = true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Continuar →'),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORMULARIO — Prueba de Válvula (fase 2: resultado)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildValvulaResultForm(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        // Válvula seleccionada
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.plumbing, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(_valvulaNombre ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (_valvulaManual) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('nueva',
                      style:
                          TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Resultado
        const Text('Resultado de la prueba',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        _resultadoChips(
          opciones: const [
            'verificada_ok',
            'requiere_mantencion',
            'solo_calibracion'
          ],
          labels: const [
            '✓ Verificada OK',
            '🔧 Requiere mantención',
            '📐 Solo calibración'
          ],
          colores: const [Colors.green, Colors.red, Colors.orange],
          seleccionado: _resultadoValvula,
          onSelect: (v) => setState(() => _resultadoValvula = v),
        ),
        const SizedBox(height: 14),

        // Campos condicionales según resultado
        if (_resultadoValvula == 'requiere_mantencion') ...[
          _buildListaEditable(
            titulo: 'Tareas realizadas',
            items: _tareasValvula,
            hint: 'Descripción de la tarea...',
            addCtrl: _addTareaValvulaCtrl,
            onAdd: (v) => setState(() => _tareasValvula.add(v)),
            onRemove: (i) => setState(() => _tareasValvula.removeAt(i)),
          ),
          const SizedBox(height: 14),
          _buildListaEditable(
            titulo: 'Repuestos usados',
            items: _repuestosValvula,
            hint: 'Ej: Sello, resorte...',
            addCtrl: _addRepuestoValvulaCtrl,
            onAdd: (v) => setState(() => _repuestosValvula.add(v)),
            onRemove: (i) => setState(() => _repuestosValvula.removeAt(i)),
          ),
        ],

        if (_resultadoValvula == 'solo_calibracion') ...[
          const Text('Valores de seteo',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field(
                    controller: _seteoAntCtrl,
                    label: 'Anterior',
                    keyboard:
                        TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
                child: _field(
                    controller: _seteoNuevoCtrl,
                    label: 'Nuevo',
                    keyboard:
                        TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 12),
          const Text('Valores de corte',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field(
                    controller: _corteAntCtrl,
                    label: 'Anterior',
                    keyboard:
                        TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
                child: _field(
                    controller: _corteNuevoCtrl,
                    label: 'Nuevo',
                    keyboard:
                        TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Unidad: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 10),
              ...['bar', 'PSI', '°C'].map((u) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(u),
                      selected: _unidadValvula == u,
                      onSelected: (_) =>
                          setState(() => _unidadValvula = u),
                    ),
                  )),
            ],
          ),
        ],

        const SizedBox(height: 14),
        _field(
          controller: _obsValvulaCtrl,
          label: 'Observaciones',
          hint: 'Notas adicionales...',
          maxLines: 3,
        ),
        const SizedBox(height: 24),

        _botonGuardar(
          onPressed: _resultadoValvula != null ? _guardarValvula : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _guardarValvula() async {
    setState(() => _guardando = true);
    try {
      final ref = widget.itemsRef.doc();
      final item = WorkItemModel(
        id: ref.id,
        maintenanceId: widget.maintenanceId,
        equipoId: widget.equipoId,
        clienteId: widget.clienteId,
        tipo: WorkItemType.pruebaValvula,
        referenciaId: _valvulaId,
        referenciaNombre: _valvulaNombre,
        descripcion: _obsValvulaCtrl.text.trim(),
        fotos: const [],
        observaciones: _obsValvulaCtrl.text.trim(),
        completado: false,
        resultadoValvula: _resultadoValvula,
        tareasRealizadas:
            _tareasValvula.isNotEmpty ? List.from(_tareasValvula) : null,
        repuestosUsados:
            _repuestosValvula.isNotEmpty ? List.from(_repuestosValvula) : null,
        valorSeteoAnterior: double.tryParse(_seteoAntCtrl.text.trim()),
        valorSeteoNuevo: double.tryParse(_seteoNuevoCtrl.text.trim()),
        valorCorteAnterior: double.tryParse(_corteAntCtrl.text.trim()),
        valorCorteNuevo: double.tryParse(_corteNuevoCtrl.text.trim()),
        unidadValvula:
            _resultadoValvula == 'solo_calibracion' ? _unidadValvula : null,
        realizadoPor: _realizadoPorCtrl.text.trim().isEmpty
            ? null
            : _realizadoPorCtrl.text.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await ref.set(item.toMap(isCreate: true));

      // Sincronizar con módulo de válvulas (crea o actualiza válvula + historial)
      final online = await MaintenanceSyncService.instance.syncWorkItem(item);

      widget.onCreated();
      if (mounted) {
        if (!online) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión — se sincronizará al reconectar'),
            duration: Duration(seconds: 3),
          ));
        }
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORMULARIO — Mantención equipo / componente
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMantencionForm(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        // Selector equipo / componente
        Row(
          children: [
            const Text('Tipo:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Equipo general'),
              selected: !_esComponente,
              onSelected: (_) => setState(() {
                _esComponente = false;
                _componenteId = null;
                _componenteNombre = null;
                _tipo = WorkItemType.mantencionEquipo;
              }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Componente'),
              selected: _esComponente,
              onSelected: (_) => setState(() {
                _esComponente = true;
                _tipo = WorkItemType.mantencionComponente;
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Lista de componentes si es componente
        if (_esComponente) ...[
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _componentesFuture ??= _db
                .collection('clients')
                .doc(widget.clienteId)
                .collection('equipments')
                .doc(widget.equipoId)
                .collection('components')
                .get(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Text('Sin componentes registrados.',
                    style: TextStyle(color: Colors.grey[500]));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selecciona el componente',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  ...docs.map((doc) {
                    final d = doc.data();
                    final name = d['name'] as String? ?? doc.id;
                    final selected = _componenteId == doc.id;
                    return ListTile(
                      dense: true,
                      leading: Radio<String>(
                        value: doc.id,
                        groupValue: _componenteId,
                        onChanged: (v) => setState(() {
                          _componenteId = v;
                          _componenteNombre = name;
                        }),
                      ),
                      title: Text(name),
                      selected: selected,
                      onTap: () => setState(() {
                        _componenteId = doc.id;
                        _componenteNombre = name;
                      }),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
        ],

        // Descripción
        _field(
          controller: _descMantencionCtrl,
          label: 'Descripción del trabajo',
          hint: 'Ej: Limpieza e inspección general...',
          maxLines: 2,
        ),
        const SizedBox(height: 14),

        // Tareas
        _buildListaEditable(
          titulo: 'Tareas realizadas',
          items: _tareasMantencion,
          hint: 'Descripción de la tarea...',
          addCtrl: _addTareaMantencionCtrl,
          onAdd: (v) => setState(() => _tareasMantencion.add(v)),
          onRemove: (i) => setState(() => _tareasMantencion.removeAt(i)),
        ),
        const SizedBox(height: 14),

        // Repuestos
        _buildListaEditable(
          titulo: 'Repuestos usados',
          items: _repuestosMantencion,
          hint: 'Ej: Empaque 3/4", filtro de aceite...',
          addCtrl: _addRepuestoMantencionCtrl,
          onAdd: (v) => setState(() => _repuestosMantencion.add(v)),
          onRemove: (i) =>
              setState(() => _repuestosMantencion.removeAt(i)),
        ),
        const SizedBox(height: 14),

        _field(
          controller: _obsMantencionCtrl,
          label: 'Observaciones',
          hint: 'Notas adicionales...',
          maxLines: 3,
        ),
        const SizedBox(height: 24),

        _botonGuardar(
          onPressed: _descMantencionCtrl.text.trim().isNotEmpty ||
                  _tareasMantencion.isNotEmpty
              ? _guardarMantencion
              : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _guardarMantencion() async {
    setState(() => _guardando = true);
    try {
      final ref = widget.itemsRef.doc();
      final item = WorkItemModel(
        id: ref.id,
        maintenanceId: widget.maintenanceId,
        equipoId: widget.equipoId,
        clienteId: widget.clienteId,
        tipo: _esComponente
            ? WorkItemType.mantencionComponente
            : WorkItemType.mantencionEquipo,
        referenciaId: _esComponente ? _componenteId : widget.equipoId,
        referenciaNombre:
            _esComponente ? _componenteNombre : widget.equipoNombre,
        descripcion: _descMantencionCtrl.text.trim(),
        fotos: const [],
        observaciones: _obsMantencionCtrl.text.trim(),
        completado: false,
        tareasRealizadas: _tareasMantencion.isNotEmpty
            ? List.from(_tareasMantencion)
            : null,
        repuestosUsados: _repuestosMantencion.isNotEmpty
            ? List.from(_repuestosMantencion)
            : null,
        realizadoPor: _realizadoPorCtrl.text.trim().isEmpty
            ? null
            : _realizadoPorCtrl.text.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await ref.set(item.toMap(isCreate: true));
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORMULARIO — Otro
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOtroForm(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          controller: _tituloOtroCtrl,
          label: 'Título',
          hint: 'Ej: Inspección visual, limpieza filtros...',
          autofocus: true,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _descOtroCtrl,
          label: 'Descripción',
          hint: 'Detalla el trabajo realizado...',
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        _botonGuardar(
          onPressed: _tituloOtroCtrl.text.trim().isNotEmpty
              ? _guardarOtro
              : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _guardarOtro() async {
    setState(() => _guardando = true);
    try {
      final ref = widget.itemsRef.doc();
      final item = WorkItemModel(
        id: ref.id,
        maintenanceId: widget.maintenanceId,
        equipoId: widget.equipoId,
        clienteId: widget.clienteId,
        tipo: WorkItemType.otro,
        titulo: _tituloOtroCtrl.text.trim(),
        descripcion: _descOtroCtrl.text.trim(),
        fotos: const [],
        observaciones: '',
        completado: false,
        realizadoPor: _realizadoPorCtrl.text.trim().isEmpty
            ? null
            : _realizadoPorCtrl.text.trim(),
        creadoEn: DateTime.now(),
        actualizadoEn: DateTime.now(),
      );
      await ref.set(item.toMap(isCreate: true));
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Helpers compartidos ───────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _resultadoChips({
    required List<String> opciones,
    required List<String> labels,
    required List<Color> colores,
    required String? seleccionado,
    required void Function(String) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(opciones.length, (i) {
        final sel = seleccionado == opciones[i];
        return ChoiceChip(
          label: Text(labels[i],
              style: TextStyle(
                  fontSize: 12,
                  color: sel ? Colors.white : Colors.black87)),
          selected: sel,
          selectedColor: colores[i],
          onSelected: (_) => onSelect(opciones[i]),
        );
      }),
    );
  }

  Widget _buildListaEditable({
    required String titulo,
    required List<String> items,
    required String hint,
    required TextEditingController addCtrl,
    required void Function(String) onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        ...items.asMap().entries.map((e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_box_outlined,
                  size: 18, color: Color(0xFF1A5DB5)),
              title: Text(e.value, style: const TextStyle(fontSize: 13)),
              trailing: IconButton(
                icon: Icon(Icons.close,
                    size: 16, color: Colors.red[300]),
                onPressed: () => onRemove(e.key),
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: addCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final v = addCtrl.text.trim();
                if (v.isNotEmpty) {
                  onAdd(v);
                  addCtrl.clear();
                }
              },
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFF1A5DB5)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonGuardar({required VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      onPressed: _guardando ? null : onPressed,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check),
      label: Text(_guardando ? 'Guardando…' : 'Guardar trabajo'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A5DB5),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _EditWorkItemSheet — Ver/editar trabajo existente + fotos
// ═══════════════════════════════════════════════════════════════════════════════

class _EditWorkItemSheet extends StatefulWidget {
  final WorkItemModel item;
  final String clienteId;
  final String equipoId;
  final String maintenanceId;
  final CollectionReference<Map<String, dynamic>> itemsRef;
  final VoidCallback onChanged;

  const _EditWorkItemSheet({
    required this.item,
    required this.clienteId,
    required this.equipoId,
    required this.maintenanceId,
    required this.itemsRef,
    required this.onChanged,
  });

  @override
  State<_EditWorkItemSheet> createState() => _EditWorkItemSheetState();
}

class _EditWorkItemSheetState extends State<_EditWorkItemSheet> {
  final _db = FirebaseFirestore.instance;
  bool _guardando = false;

  DocumentReference<Map<String, dynamic>> get _itemRef =>
      _db
          .collection('clients')
          .doc(widget.clienteId)
          .collection('equipments')
          .doc(widget.equipoId)
          .collection('maintenances')
          .doc(widget.maintenanceId)
          .collection('items')
          .doc(widget.item.id);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _itemRef.snapshots(),
        builder: (_, snap) {
          final item = snap.hasData && snap.data!.exists
              ? WorkItemModel.fromFirestore(snap.data!)
              : widget.item;
          return _buildContent(item, ctrl);
        },
      ),
    );
  }

  Widget _buildContent(WorkItemModel item, ScrollController ctrl) {
    final String titulo = _tituloItem(item);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _tipoBadge(item.tipo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                // Completado toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Completo',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                    Switch(
                      value: item.completado,
                      activeTrackColor: Colors.green,
                      onChanged: _guardando
                          ? null
                          : (v) => _toggleCompletado(item, v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Resumen según tipo
                _buildResumen(item),
                const SizedBox(height: 20),

                // Fotos con PhotoManagerWidget
                const Text('Fotos',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                PhotoManagerWidget(
                  urls: item.fotos,
                  storagePath:
                      'maintenances/${widget.maintenanceId}/items/${item.id}/fotos',
                  docRef: _itemRef,
                  fieldName: 'fotos',
                  entityId: widget.maintenanceId,
                  imageSize: 110,
                  entityName: item.referenciaNombre,
                ),
                const SizedBox(height: 24),

                // Botón eliminar
                OutlinedButton.icon(
                  onPressed: _guardando ? null : () => _confirmarEliminar(),
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  label: Text('Eliminar trabajo',
                      style: TextStyle(color: Colors.red[400])),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tituloItem(WorkItemModel item) {
    switch (item.tipo) {
      case WorkItemType.pruebaHidrostatica:
        return 'Prueba Hidrostática';
      case WorkItemType.pruebaValvula:
        return item.referenciaNombre != null
            ? 'Válvula: ${item.referenciaNombre}'
            : 'Prueba de Válvula';
      case WorkItemType.otro:
        return item.titulo ?? 'Otro';
      default:
        return item.referenciaNombre ?? item.tipo.label;
    }
  }

  Widget _tipoBadge(WorkItemType tipo) {
    final color = _colorForTipo(tipo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(tipo.label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Color _colorForTipo(WorkItemType tipo) {
    switch (tipo) {
      case WorkItemType.pruebaHidrostatica:   return Colors.blue;
      case WorkItemType.pruebaValvula:        return Colors.orange;
      case WorkItemType.mantencionEquipo:     return const Color(0xFF1A5DB5);
      case WorkItemType.mantencionComponente: return Colors.teal;
      case WorkItemType.otro:                 return Colors.grey;
    }
  }

  Widget _buildResumen(WorkItemModel item) {
    final rows = <Widget>[];

    // Prueba hidrostática
    if (item.tipo == WorkItemType.pruebaHidrostatica) {
      if (item.presionPrueba != null) {
        rows.add(_resumenRow('Presión',
            '${item.presionPrueba} ${item.unidadPresion ?? 'bar'}'));
      }
      if (item.duracionMinutos != null) {
        rows.add(_resumenRow('Duración', '${item.duracionMinutos} min'));
      }
      if (item.resultado != null) {
        rows.add(_resumenRow('Resultado', item.resultado!));
      }
      if (item.numeroCertificado != null) {
        rows.add(_resumenRow('Certificado', item.numeroCertificado!));
      }
    }

    // Prueba de válvula
    if (item.tipo == WorkItemType.pruebaValvula) {
      if (item.resultadoValvula != null) {
        const map = {
          'verificada_ok': '✓ Verificada OK',
          'requiere_mantencion': '🔧 Requiere mantención',
          'solo_calibracion': '📐 Solo calibración',
        };
        rows.add(_resumenRow(
            'Resultado', map[item.resultadoValvula] ?? item.resultadoValvula!));
      }
      if (item.valorSeteoAnterior != null || item.valorSeteoNuevo != null) {
        rows.add(_resumenRow('Seteo',
            '${item.valorSeteoAnterior ?? '—'} → ${item.valorSeteoNuevo ?? '—'} ${item.unidadValvula ?? ''}'));
      }
      if (item.valorCorteAnterior != null || item.valorCorteNuevo != null) {
        rows.add(_resumenRow('Corte',
            '${item.valorCorteAnterior ?? '—'} → ${item.valorCorteNuevo ?? '—'} ${item.unidadValvula ?? ''}'));
      }
      if (item.tareasRealizadas != null && item.tareasRealizadas!.isNotEmpty) {
        rows.add(_resumenRow(
            'Tareas', item.tareasRealizadas!.join(', ')));
      }
      if (item.repuestosUsados != null && item.repuestosUsados!.isNotEmpty) {
        rows.add(_resumenRow(
            'Repuestos', item.repuestosUsados!.join(', ')));
      }
    }

    // Mantención
    if (item.tipo == WorkItemType.mantencionEquipo ||
        item.tipo == WorkItemType.mantencionComponente) {
      if (item.descripcion.isNotEmpty) {
        rows.add(_resumenRow('Descripción', item.descripcion));
      }
      if (item.tareasRealizadas != null && item.tareasRealizadas!.isNotEmpty) {
        rows.add(_resumenRow(
            'Tareas', item.tareasRealizadas!.join(', ')));
      }
      if (item.repuestosUsados != null && item.repuestosUsados!.isNotEmpty) {
        rows.add(_resumenRow(
            'Repuestos', item.repuestosUsados!.join(', ')));
      }
    }

    // Otro
    if (item.tipo == WorkItemType.otro && item.descripcion.isNotEmpty) {
      rows.add(_resumenRow('Descripción', item.descripcion));
    }

    // Observaciones (todas)
    if (item.observaciones.isNotEmpty) {
      rows.add(_resumenRow('Observaciones', item.observaciones));
    }

    if (rows.isEmpty) {
      return Text('Sin detalles registrados.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: rows),
    );
  }

  Widget _resumenRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Future<void> _toggleCompletado(WorkItemModel item, bool value) async {
    setState(() => _guardando = true);
    try {
      await _itemRef.update({
        'completado': value,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar trabajo'),
        content: const Text(
            '¿Eliminar este registro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _guardando = true);
    try {
      await _itemRef.delete();
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
