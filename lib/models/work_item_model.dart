// lib/models/work_item_model.dart
//
// Reemplaza a MaintenanceItemModel con soporte para todos los tipos de trabajo:
// prueba hidrostática, prueba de válvula, mantención equipo/componente, y otro.
//
// Subcolección: clients/{clienteId}/equipments/{equipoId}/maintenances/{maintenanceId}/items/{itemId}

import 'package:cloud_firestore/cloud_firestore.dart';

// ── WorkItemType ──────────────────────────────────────────────────────────────

enum WorkItemType {
  pruebaHidrostatica,
  pruebaValvula,
  mantencionEquipo,
  mantencionComponente,
  otro,
}

extension WorkItemTypeX on WorkItemType {
  String get label {
    switch (this) {
      case WorkItemType.pruebaHidrostatica:   return 'Prueba Hidrostática';
      case WorkItemType.pruebaValvula:        return 'Prueba de Válvula';
      case WorkItemType.mantencionEquipo:     return 'Mantención Equipo';
      case WorkItemType.mantencionComponente: return 'Mantención Componente';
      case WorkItemType.otro:                 return 'Otro';
    }
  }

  String get value => name;
}

WorkItemType workItemTypeFromString(String? s) {
  if (s == null) return WorkItemType.otro;
  return WorkItemType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => WorkItemType.otro,
  );
}

// ── WorkItemModel ─────────────────────────────────────────────────────────────

class WorkItemModel {
  final String id;
  final String maintenanceId;
  final String equipoId;
  final String clienteId;
  final WorkItemType tipo;

  // Referencia opcional → válvula o componente vinculado
  final String? referenciaId;
  final String? referenciaNombre;

  // Campos comunes
  final String descripcion;
  final List<String> fotos;
  final String observaciones;
  final bool completado;
  final String? titulo; // solo para WorkItemType.otro

  // ── Solo para pruebaHidrostatica ──────────────────────────────────────────
  final double? presionPrueba;
  final String? unidadPresion; // bar | PSI | kPa
  final int? duracionMinutos;
  final String? resultado; // aprobado | rechazado | observado
  final String? numeroCertificado;

  // ── Solo para pruebaValvula ───────────────────────────────────────────────
  final String? resultadoValvula; // verificada_ok | requiere_mantencion | solo_calibracion
  final double? valorSeteoAnterior;
  final double? valorSeteoNuevo;
  final double? valorCorteAnterior;
  final double? valorCorteNuevo;
  final String? unidadValvula; // bar | PSI | °C
  final List<String>? tareasRealizadas;
  final List<String>? repuestosUsados;

  // ── Trazabilidad ──────────────────────────────────────────────────────────
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  // Nombre editable de quien realizó el trabajo (puede diferir del login en cuenta compartida)
  final String? realizadoPor;

  // Path completo del documento sincronizado (ej. hydraulicTests/{id})
  final String? sincronizadoEnPath;

  const WorkItemModel({
    required this.id,
    required this.maintenanceId,
    required this.equipoId,
    required this.clienteId,
    required this.tipo,
    this.referenciaId,
    this.referenciaNombre,
    required this.descripcion,
    required this.fotos,
    required this.observaciones,
    required this.completado,
    this.titulo,
    this.presionPrueba,
    this.unidadPresion,
    this.duracionMinutos,
    this.resultado,
    this.numeroCertificado,
    this.resultadoValvula,
    this.valorSeteoAnterior,
    this.valorSeteoNuevo,
    this.valorCorteAnterior,
    this.valorCorteNuevo,
    this.unidadValvula,
    this.tareasRealizadas,
    this.repuestosUsados,
    required this.creadoEn,
    required this.actualizadoEn,
    this.realizadoPor,
    this.sincronizadoEnPath,
  });

  factory WorkItemModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WorkItemModel(
      id: doc.id,
      maintenanceId: d['maintenanceId'] as String? ?? '',
      equipoId: d['equipoId'] as String? ?? '',
      clienteId: d['clienteId'] as String? ?? '',
      tipo: workItemTypeFromString(d['tipo'] as String?),
      referenciaId: d['referenciaId'] as String?,
      referenciaNombre: d['referenciaNombre'] as String?,
      descripcion: d['descripcion'] as String? ?? '',
      fotos: List<String>.from(d['fotos'] ?? []),
      observaciones: d['observaciones'] as String? ?? '',
      completado: d['completado'] as bool? ?? false,
      titulo: d['titulo'] as String?,
      presionPrueba: (d['presionPrueba'] as num?)?.toDouble(),
      unidadPresion: d['unidadPresion'] as String?,
      duracionMinutos: d['duracionMinutos'] as int?,
      resultado: d['resultado'] as String?,
      numeroCertificado: d['numeroCertificado'] as String?,
      resultadoValvula: d['resultadoValvula'] as String?,
      valorSeteoAnterior: (d['valorSeteoAnterior'] as num?)?.toDouble(),
      valorSeteoNuevo: (d['valorSeteoNuevo'] as num?)?.toDouble(),
      valorCorteAnterior: (d['valorCorteAnterior'] as num?)?.toDouble(),
      valorCorteNuevo: (d['valorCorteNuevo'] as num?)?.toDouble(),
      unidadValvula: d['unidadValvula'] as String?,
      tareasRealizadas: d['tareasRealizadas'] != null
          ? List<String>.from(d['tareasRealizadas'])
          : null,
      repuestosUsados: d['repuestosUsados'] != null
          ? List<String>.from(d['repuestosUsados'])
          : null,
      creadoEn:
          (d['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualizadoEn:
          (d['actualizadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      realizadoPor: d['realizadoPor'] as String?,
      sincronizadoEnPath: d['sincronizadoEnPath'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool isCreate = false}) {
    return {
      'maintenanceId': maintenanceId,
      'equipoId': equipoId,
      'clienteId': clienteId,
      'tipo': tipo.value,
      if (referenciaId != null) 'referenciaId': referenciaId,
      if (referenciaNombre != null) 'referenciaNombre': referenciaNombre,
      'descripcion': descripcion,
      'fotos': fotos,
      'observaciones': observaciones,
      'completado': completado,
      if (titulo != null) 'titulo': titulo,
      if (presionPrueba != null) 'presionPrueba': presionPrueba,
      if (unidadPresion != null) 'unidadPresion': unidadPresion,
      if (duracionMinutos != null) 'duracionMinutos': duracionMinutos,
      if (resultado != null) 'resultado': resultado,
      if (numeroCertificado != null) 'numeroCertificado': numeroCertificado,
      if (resultadoValvula != null) 'resultadoValvula': resultadoValvula,
      if (valorSeteoAnterior != null) 'valorSeteoAnterior': valorSeteoAnterior,
      if (valorSeteoNuevo != null) 'valorSeteoNuevo': valorSeteoNuevo,
      if (valorCorteAnterior != null) 'valorCorteAnterior': valorCorteAnterior,
      if (valorCorteNuevo != null) 'valorCorteNuevo': valorCorteNuevo,
      if (unidadValvula != null) 'unidadValvula': unidadValvula,
      if (tareasRealizadas != null) 'tareasRealizadas': tareasRealizadas,
      if (repuestosUsados != null) 'repuestosUsados': repuestosUsados,
      if (realizadoPor != null && realizadoPor!.isNotEmpty)
        'realizadoPor': realizadoPor,
      if (sincronizadoEnPath != null) 'sincronizadoEnPath': sincronizadoEnPath,
      if (isCreate) 'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  WorkItemModel copyWith({
    String? referenciaId,
    String? referenciaNombre,
    String? descripcion,
    List<String>? fotos,
    String? observaciones,
    bool? completado,
    String? titulo,
    double? presionPrueba,
    String? unidadPresion,
    int? duracionMinutos,
    String? resultado,
    String? numeroCertificado,
    String? resultadoValvula,
    double? valorSeteoAnterior,
    double? valorSeteoNuevo,
    double? valorCorteAnterior,
    double? valorCorteNuevo,
    String? unidadValvula,
    List<String>? tareasRealizadas,
    List<String>? repuestosUsados,
    String? realizadoPor,
    String? sincronizadoEnPath,
    DateTime? actualizadoEn,
  }) {
    return WorkItemModel(
      id: id,
      maintenanceId: maintenanceId,
      equipoId: equipoId,
      clienteId: clienteId,
      tipo: tipo,
      referenciaId: referenciaId ?? this.referenciaId,
      referenciaNombre: referenciaNombre ?? this.referenciaNombre,
      descripcion: descripcion ?? this.descripcion,
      fotos: fotos ?? this.fotos,
      observaciones: observaciones ?? this.observaciones,
      completado: completado ?? this.completado,
      titulo: titulo ?? this.titulo,
      presionPrueba: presionPrueba ?? this.presionPrueba,
      unidadPresion: unidadPresion ?? this.unidadPresion,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      resultado: resultado ?? this.resultado,
      numeroCertificado: numeroCertificado ?? this.numeroCertificado,
      resultadoValvula: resultadoValvula ?? this.resultadoValvula,
      valorSeteoAnterior: valorSeteoAnterior ?? this.valorSeteoAnterior,
      valorSeteoNuevo: valorSeteoNuevo ?? this.valorSeteoNuevo,
      valorCorteAnterior: valorCorteAnterior ?? this.valorCorteAnterior,
      valorCorteNuevo: valorCorteNuevo ?? this.valorCorteNuevo,
      unidadValvula: unidadValvula ?? this.unidadValvula,
      tareasRealizadas: tareasRealizadas ?? this.tareasRealizadas,
      repuestosUsados: repuestosUsados ?? this.repuestosUsados,
      realizadoPor: realizadoPor ?? this.realizadoPor,
      sincronizadoEnPath: sincronizadoEnPath ?? this.sincronizadoEnPath,
      creadoEn: creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}
