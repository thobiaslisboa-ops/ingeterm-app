// lib/services/maintenance_sync_service.dart
//
// Sincronización bidireccional entre WorkItems de una orden de mantención
// y los módulos independientes del sistema (pruebas hidrostáticas, válvulas).
//
// Uso:
//   await MaintenanceSyncService.instance.syncWorkItem(item);
//
// Internamente usa batch write → todas las operaciones son atómicas.
// Si no hay conexión, Firestore persistence encola y sincroniza al reconectar.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_item_model.dart';
import '../models/valve_model.dart';
import 'offline_sync_service.dart';

class MaintenanceSyncService {
  static final MaintenanceSyncService instance =
      MaintenanceSyncService._internal();
  MaintenanceSyncService._internal();

  final _db = FirebaseFirestore.instance;

  // ── Entrada pública ───────────────────────────────────────────────────────

  /// Sincroniza [item] con los módulos correspondientes según su tipo.
  ///
  /// - pruebaHidrostatica → crea documento en hydraulicTests del equipo.
  /// - pruebaValvula      → crea/actualiza válvula + historial de válvula.
  /// - otros tipos        → no requieren sincronización adicional
  ///                        (quedan visibles vía jerarquía Firestore).
  ///
  /// Retorna true si había conexión al momento de ejecutar.
  Future<bool> syncWorkItem(
    WorkItemModel item, {
    String? tecnicoNombre,
    String? tecnicoId,
  }) async {
    return OfflineSyncService().checkAndSave(() async {
      switch (item.tipo) {
        case WorkItemType.pruebaHidrostatica:
          await _syncHidrostatica(item,
              tecnicoNombre: tecnicoNombre, tecnicoId: tecnicoId);
          break;
        case WorkItemType.pruebaValvula:
          await _syncValvula(item, tecnicoId: tecnicoId);
          break;
        // mantencionEquipo, mantencionComponente, otro:
        // quedan dentro de la subcolección items/ de la orden → visibles
        // automáticamente desde el historial del equipo. Sin sync extra.
        default:
          break;
      }
    });
  }

  // ── Sincronización: Prueba Hidrostática ───────────────────────────────────

  Future<void> _syncHidrostatica(
    WorkItemModel item, {
    String? tecnicoNombre,
    String? tecnicoId,
  }) async {
    final batch = _db.batch();

    // 1. Referencia al nuevo documento en hydraulicTests
    final hydroRef = _db
        .collection('clients')
        .doc(item.clienteId)
        .collection('equipments')
        .doc(item.equipoId)
        .collection('hydraulicTests')
        .doc();

    batch.set(hydroRef, {
      'equipmentId': item.equipoId,
      'fechaPrueba': FieldValue.serverTimestamp(),
      if (item.presionPrueba != null) 'presionPrueba': item.presionPrueba,
      'unidadPresion': item.unidadPresion ?? 'bar',
      if (item.duracionMinutos != null)
        'duracionMinutos': item.duracionMinutos,
      if (item.resultado != null) 'resultado': item.resultado,
      if (item.observaciones.isNotEmpty)
        'observaciones': item.observaciones,
      'hallazgos': const [],
      'fotos': item.fotos,
      'certificadoGenerado': false,
      if (item.numeroCertificado != null)
        'numeroCertificado': item.numeroCertificado,
      if (tecnicoId != null) 'tecnicoId': tecnicoId,
      if (tecnicoNombre != null) 'tecnicoNombre': tecnicoNombre,
      if (item.realizadoPor != null) 'realizadoPor': item.realizadoPor,
      // Trazabilidad de origen
      'origenOrdenId': item.maintenanceId,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    // 2. Marcar el WorkItem con el path sincronizado
    final itemRef = _itemRef(item);
    batch.update(itemRef, {
      'sincronizadoEnPath': hydroRef.path,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Sincronización: Prueba de Válvula ─────────────────────────────────────

  Future<void> _syncValvula(
    WorkItemModel item, {
    String? tecnicoId,
  }) async {
    final batch = _db.batch();

    final valvesCol = _db
        .collection('clients')
        .doc(item.clienteId)
        .collection('equipments')
        .doc(item.equipoId)
        .collection('valves');

    String resolvedValveId;
    DocumentReference<Map<String, dynamic>> valveRef;

    // ── Caso A: válvula nueva (ingresada manualmente, no estaba en la lista) ──
    if (item.referenciaId == null) {
      valveRef = valvesCol.doc();
      resolvedValveId = valveRef.id;

      final estadoInicial = _statusParaResultado(item.resultadoValvula);

      batch.set(valveRef, {
        'name': item.referenciaNombre ?? 'Sin nombre',
        'tag': item.referenciaNombre ?? '',
        'status': estadoInicial.name,
        'lastRevisionDate': FieldValue.serverTimestamp(),
        // Valores de seteo/corte si se calibró en el primer registro
        if (item.resultadoValvula == 'solo_calibracion') ...{
          if (item.valorSeteoNuevo != null) 'setPoint': item.valorSeteoNuevo,
          if (item.valorCorteNuevo != null) 'cutPoint': item.valorCorteNuevo,
          if (item.unidadValvula != null) 'unit': item.unidadValvula,
        },
        'creadoDesdeOrden': true,
        'origenOrdenId': item.maintenanceId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    // ── Caso B: válvula existente seleccionada de la lista ────────────────────
    else {
      resolvedValveId = item.referenciaId!;
      valveRef = valvesCol.doc(item.referenciaId);

      final nuevoEstado = _statusParaResultado(item.resultadoValvula);
      final Map<String, dynamic> valveUpdate = {
        'status': nuevoEstado.name,
        'lastRevisionDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Solo calibración → actualizar valores de seteo y corte
      if (item.resultadoValvula == 'solo_calibracion') {
        if (item.valorSeteoNuevo != null) {
          valveUpdate['setPoint'] = item.valorSeteoNuevo;
        }
        if (item.valorCorteNuevo != null) {
          valveUpdate['cutPoint'] = item.valorCorteNuevo;
        }
        if (item.unidadValvula != null) {
          valveUpdate['unit'] = item.unidadValvula;
        }
      }

      batch.update(valveRef, valveUpdate);
    }

    // ── Entrada en el historial de la válvula ──────────────────────────────
    final historialRef =
        valveRef.collection('maintenances').doc();

    batch.set(historialRef, {
      // Campos legacy compatibles con valve_detail_screen
      'date': FieldValue.serverTimestamp(),
      if (item.observaciones.isNotEmpty) 'notes': item.observaciones,
      if (tecnicoId != null) 'technician': tecnicoId,
      if (item.valorSeteoNuevo != null)
        'setPoint':
            '${item.valorSeteoNuevo} ${item.unidadValvula ?? ''}'.trim(),
      if (item.valorCorteNuevo != null)
        'cutOff':
            '${item.valorCorteNuevo} ${item.unidadValvula ?? ''}'.trim(),

      // Campos nuevos de trazabilidad
      'origenOrdenId': item.maintenanceId,
      'resultadoValvula': item.resultadoValvula,
      if (item.realizadoPor != null) 'realizadoPor': item.realizadoPor,
      if (item.tareasRealizadas != null && item.tareasRealizadas!.isNotEmpty)
        'tareasRealizadas': item.tareasRealizadas,
      if (item.repuestosUsados != null && item.repuestosUsados!.isNotEmpty)
        'repuestosUsados': item.repuestosUsados,
      if (item.valorSeteoAnterior != null)
        'valorSeteoAnterior': item.valorSeteoAnterior,
      if (item.valorSeteoNuevo != null)
        'valorSeteoNuevo': item.valorSeteoNuevo,
      if (item.valorCorteAnterior != null)
        'valorCorteAnterior': item.valorCorteAnterior,
      if (item.valorCorteNuevo != null)
        'valorCorteNuevo': item.valorCorteNuevo,
      if (item.unidadValvula != null) 'unidad': item.unidadValvula,
      'fotos': item.fotos,
    });

    // ── Actualizar WorkItem con path sincronizado y valveId resuelto ──────
    final itemRef = _itemRef(item);
    final Map<String, dynamic> itemUpdate = {
      'sincronizadoEnPath': historialRef.path,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    // Si la válvula era nueva, guardar el ID generado para referencias futuras
    if (item.referenciaId == null) {
      itemUpdate['referenciaId'] = resolvedValveId;
    }
    batch.update(itemRef, itemUpdate);

    await batch.commit();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Path al documento WorkItem dentro de su orden de mantención.
  DocumentReference<Map<String, dynamic>> _itemRef(WorkItemModel item) =>
      _db
          .collection('clients')
          .doc(item.clienteId)
          .collection('equipments')
          .doc(item.equipoId)
          .collection('maintenances')
          .doc(item.maintenanceId)
          .collection('items')
          .doc(item.id);

  /// Mapea el resultado de la prueba de válvula al estado correspondiente.
  ValveStatus _statusParaResultado(String? resultado) {
    switch (resultado) {
      case 'verificada_ok':
        return ValveStatus.enOperacion;
      case 'requiere_mantencion':
        return ValveStatus.enMantencion;
      case 'solo_calibracion':
      default:
        return ValveStatus.enOperacion;
    }
  }
}
