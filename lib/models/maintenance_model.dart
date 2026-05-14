// lib/models/maintenance_model.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Estado enum ───────────────────────────────────────────────────────────────

enum EstadoMantencion {
  programada,
  enEjecucion,
  finalizada,
  cerrada,
}

extension EstadoMantencionExt on EstadoMantencion {
  String get label {
    switch (this) {
      case EstadoMantencion.programada:
        return 'Programada';
      case EstadoMantencion.enEjecucion:
        return 'En Ejecución';
      case EstadoMantencion.finalizada:
        return 'Finalizada';
      case EstadoMantencion.cerrada:
        return 'Cerrada';
    }
  }

  String get value {
    switch (this) {
      case EstadoMantencion.programada:
        return 'programada';
      case EstadoMantencion.enEjecucion:
        return 'en_ejecucion';
      case EstadoMantencion.finalizada:
        return 'finalizada';
      case EstadoMantencion.cerrada:
        return 'cerrada';
    }
  }
}

EstadoMantencion estadoMantencionFromString(String? v) {
  switch (v) {
    case 'programada':
      return EstadoMantencion.programada;
    case 'en_ejecucion':
      return EstadoMantencion.enEjecucion;
    // fallbacks valores antiguos
    case 'borrador':
      return EstadoMantencion.programada;
    case 'en_progreso':
      return EstadoMantencion.enEjecucion;
    case 'finalizada':
      return EstadoMantencion.finalizada;
    case 'cerrada':
      return EstadoMantencion.cerrada;
    case 'informe_generado':
      return EstadoMantencion.cerrada;
    default:
      return EstadoMantencion.programada;
  }
}

// ── RepuestoItem ──────────────────────────────────────────────────────────────

class RepuestoItem {
  final String id;
  final String nombre;
  final double cantidad;
  final String unidad;

  const RepuestoItem({
    required this.id,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'cantidad': cantidad,
        'unidad': unidad,
      };

  factory RepuestoItem.fromMap(Map<String, dynamic> map) => RepuestoItem(
        id: map['id'] as String? ?? '',
        nombre: map['nombre'] as String? ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 1,
        unidad: map['unidad'] as String? ?? '',
      );
}

// ── AumentoObra ───────────────────────────────────────────────────────────────

class AumentoObra {
  final String id;
  final String descripcion;

  const AumentoObra({required this.id, required this.descripcion});

  Map<String, dynamic> toMap() => {'id': id, 'descripcion': descripcion};

  factory AumentoObra.fromMap(Map<String, dynamic> map) => AumentoObra(
        id: map['id'] as String? ?? '',
        descripcion: map['descripcion'] as String? ?? '',
      );
}

// ── MaintenanceModel ──────────────────────────────────────────────────────────

class MaintenanceModel {
  // Identificación
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String equipoId;
  final String equipoNombre;
  final int numeroOrden;
  final String titulo;
  final String tecnicoId;
  final String tecnicoNombre;

  // Estado
  final EstadoMantencion estado;

  // Tiempo de ejecución
  final DateTime? horaInicio;
  final DateTime? horaTermino;

  // Planificación
  final DateTime? fechaProgramada;
  final TimeOfDay? horaProgramada;

  // Tipos de trabajo
  final List<String> tiposTrabajo;

  // Secciones generales
  final String observacionesGenerales;
  final List<RepuestoItem> repuestos;
  final List<AumentoObra> aumentosObra;
  final List<String> fotos;

  // Contadores denormalizados para el card
  final int totalItems;
  final int itemsCompletados;

  // Trazabilidad
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final String creadoPor;

  const MaintenanceModel({
    required this.id,
    required this.clienteId,
    this.clienteNombre = '',
    required this.equipoId,
    this.equipoNombre = '',
    required this.numeroOrden,
    required this.titulo,
    required this.tecnicoId,
    required this.tecnicoNombre,
    required this.estado,
    this.horaInicio,
    this.horaTermino,
    this.fechaProgramada,
    this.horaProgramada,
    this.tiposTrabajo = const [],
    required this.observacionesGenerales,
    required this.repuestos,
    required this.aumentosObra,
    required this.fotos,
    required this.totalItems,
    required this.itemsCompletados,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.creadoPor,
  });

  // Duración calculada automáticamente
  int? get duracionMinutos {
    if (horaInicio == null || horaTermino == null) return null;
    return horaTermino!.difference(horaInicio!).inMinutes;
  }

  double get porcentajeCompletado {
    if (totalItems == 0) return 0;
    return itemsCompletados / totalItems;
  }

  factory MaintenanceModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Leer horaProgramada desde mapa {hour, minute}
    final horaMap = data['horaProgramada'] as Map<String, dynamic>?;
    final TimeOfDay? horaProgramada = horaMap != null
        ? TimeOfDay(
            hour: (horaMap['hour'] as int?) ?? 0,
            minute: (horaMap['minute'] as int?) ?? 0,
          )
        : null;

    return MaintenanceModel(
      id: doc.id,
      clienteId: data['clienteId'] as String? ?? '',
      clienteNombre: data['clienteNombre'] as String? ?? '',
      equipoId: data['equipoId'] as String? ?? '',
      equipoNombre: data['equipoNombre'] as String? ?? '',
      numeroOrden: (data['numeroOrden'] as int?) ?? 0,
      titulo: data['titulo'] as String? ?? 'Sin título',
      tecnicoId: data['tecnicoId'] as String? ?? '',
      tecnicoNombre: data['tecnicoNombre'] as String? ?? '',
      estado: estadoMantencionFromString(data['estado'] as String?),
      horaInicio: (data['horaInicio'] as Timestamp?)?.toDate(),
      horaTermino: (data['horaTermino'] as Timestamp?)?.toDate(),
      fechaProgramada: (data['fechaProgramada'] as Timestamp?)?.toDate(),
      horaProgramada: horaProgramada,
      tiposTrabajo: List<String>.from(data['tiposTrabajo'] ?? []),
      observacionesGenerales:
          data['observacionesGenerales'] as String? ?? '',
      repuestos: (data['repuestos'] as List<dynamic>? ?? [])
          .map((e) => RepuestoItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      aumentosObra: (data['aumentosObra'] as List<dynamic>? ?? [])
          .map((e) => AumentoObra.fromMap(e as Map<String, dynamic>))
          .toList(),
      fotos: List<String>.from(data['fotos'] ?? []),
      totalItems: (data['totalItems'] as int?) ?? 0,
      itemsCompletados: (data['itemsCompletados'] as int?) ?? 0,
      creadoEn:
          (data['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualizadoEn:
          (data['actualizadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creadoPor: data['creadoPor'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) => {
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'equipoId': equipoId,
        'equipoNombre': equipoNombre,
        'numeroOrden': numeroOrden,
        'titulo': titulo,
        'tecnicoId': tecnicoId,
        'tecnicoNombre': tecnicoNombre,
        'estado': estado.value,
        if (horaInicio != null)
          'horaInicio': Timestamp.fromDate(horaInicio!),
        if (horaTermino != null)
          'horaTermino': Timestamp.fromDate(horaTermino!),
        if (fechaProgramada != null)
          'fechaProgramada': Timestamp.fromDate(fechaProgramada!),
        if (horaProgramada != null)
          'horaProgramada': {
            'hour': horaProgramada!.hour,
            'minute': horaProgramada!.minute,
          },
        'tiposTrabajo': tiposTrabajo,
        'observacionesGenerales': observacionesGenerales,
        'repuestos': repuestos.map((r) => r.toMap()).toList(),
        'aumentosObra': aumentosObra.map((a) => a.toMap()).toList(),
        'fotos': fotos,
        'totalItems': totalItems,
        'itemsCompletados': itemsCompletados,
        // Marcador para distinguir en collectionGroup queries
        'tipo': 'orden_trabajo',
        'creadoPor': creadoPor,
        'actualizadoEn': FieldValue.serverTimestamp(),
        if (includeTimestamp) 'creadoEn': FieldValue.serverTimestamp(),
      };

  MaintenanceModel copyWith({
    String? clienteNombre,
    String? titulo,
    String? tecnicoId,
    String? tecnicoNombre,
    EstadoMantencion? estado,
    DateTime? horaInicio,
    DateTime? horaTermino,
    DateTime? fechaProgramada,
    TimeOfDay? horaProgramada,
    List<String>? tiposTrabajo,
    String? observacionesGenerales,
    List<RepuestoItem>? repuestos,
    List<AumentoObra>? aumentosObra,
    List<String>? fotos,
    int? totalItems,
    int? itemsCompletados,
  }) =>
      MaintenanceModel(
        id: id,
        clienteId: clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        equipoId: equipoId,
        numeroOrden: numeroOrden,
        titulo: titulo ?? this.titulo,
        tecnicoId: tecnicoId ?? this.tecnicoId,
        tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
        estado: estado ?? this.estado,
        horaInicio: horaInicio ?? this.horaInicio,
        horaTermino: horaTermino ?? this.horaTermino,
        fechaProgramada: fechaProgramada ?? this.fechaProgramada,
        horaProgramada: horaProgramada ?? this.horaProgramada,
        tiposTrabajo: tiposTrabajo ?? this.tiposTrabajo,
        observacionesGenerales:
            observacionesGenerales ?? this.observacionesGenerales,
        repuestos: repuestos ?? this.repuestos,
        aumentosObra: aumentosObra ?? this.aumentosObra,
        fotos: fotos ?? this.fotos,
        totalItems: totalItems ?? this.totalItems,
        itemsCompletados: itemsCompletados ?? this.itemsCompletados,
        creadoEn: creadoEn,
        actualizadoEn: DateTime.now(),
        creadoPor: creadoPor,
      );
}
