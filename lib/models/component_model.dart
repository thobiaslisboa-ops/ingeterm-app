import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  COMPONENT TYPE
// ══════════════════════════════════════════════════════════════════════════════

enum ComponentType {
  // Tipos principales — calderas y sistemas de vapor
  presostato,
  controladorNivel,
  termostato,
  trampaVapor,
  valvulaSolenoide,
  manometro,
  termometro,
  // Tipos legacy — preservados para compatibilidad con datos existentes en Firestore
  indicator,
  controller,
  pump,
  filter,
  otro,
}

extension ComponentTypeX on ComponentType {
  String get label {
    switch (this) {
      case ComponentType.presostato:       return 'Presostato';
      case ComponentType.controladorNivel: return 'Controlador de Nivel';
      case ComponentType.termostato:       return 'Termostato';
      case ComponentType.trampaVapor:      return 'Trampa de Vapor';
      case ComponentType.valvulaSolenoide: return 'Válvula Solenoide';
      case ComponentType.manometro:        return 'Manómetro';
      case ComponentType.termometro:       return 'Termómetro';
      case ComponentType.indicator:        return 'Indicador';
      case ComponentType.controller:       return 'Controlador';
      case ComponentType.pump:             return 'Bomba';
      case ComponentType.filter:           return 'Filtro';
      case ComponentType.otro:             return 'Otro';
    }
  }

  // Valor guardado en Firestore — compatible con valores legacy (.name)
  String get value {
    switch (this) {
      case ComponentType.presostato:       return 'presostato';
      case ComponentType.controladorNivel: return 'controlador_nivel';
      case ComponentType.termostato:       return 'termostato';
      case ComponentType.trampaVapor:      return 'trampa_vapor';
      case ComponentType.valvulaSolenoide: return 'valvula_solenoide';
      case ComponentType.manometro:        return 'manometro';
      case ComponentType.termometro:       return 'termometro';
      case ComponentType.indicator:        return 'indicator';
      case ComponentType.controller:       return 'controller';
      case ComponentType.pump:             return 'pump';
      case ComponentType.filter:           return 'filter';
      case ComponentType.otro:             return 'otro';
    }
  }

  IconData get icon {
    switch (this) {
      case ComponentType.presostato:       return Icons.speed;
      case ComponentType.controladorNivel: return Icons.water;
      case ComponentType.termostato:       return Icons.thermostat;
      case ComponentType.trampaVapor:      return Icons.compare_arrows;
      case ComponentType.valvulaSolenoide: return Icons.bolt;
      case ComponentType.manometro:        return Icons.dashboard;
      case ComponentType.termometro:       return Icons.device_thermostat;
      case ComponentType.indicator:        return Icons.show_chart;
      case ComponentType.controller:       return Icons.settings;
      case ComponentType.pump:             return Icons.water_drop;
      case ComponentType.filter:           return Icons.filter_alt;
      case ComponentType.otro:             return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case ComponentType.presostato:       return Colors.blue;
      case ComponentType.controladorNivel: return Colors.cyan;
      case ComponentType.termostato:       return Colors.orange;
      case ComponentType.trampaVapor:      return Colors.teal;
      case ComponentType.valvulaSolenoide: return Colors.purple;
      case ComponentType.manometro:        return Colors.indigo;
      case ComponentType.termometro:       return Colors.red;
      case ComponentType.indicator:        return Colors.teal;
      case ComponentType.controller:       return Colors.orange;
      case ComponentType.pump:             return Colors.green;
      case ComponentType.filter:           return Colors.deepPurple;
      case ComponentType.otro:             return Colors.grey;
    }
  }
}

ComponentType componentTypeFromValue(String? v) {
  if (v == null) return ComponentType.otro;
  // Intenta por .value primero, luego por .name (legacy)
  return ComponentType.values.firstWhere(
    (e) => e.value == v || e.name == v,
    orElse: () => ComponentType.otro,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPONENT STATUS
// ══════════════════════════════════════════════════════════════════════════════

enum ComponentStatus {
  operativo,
  observado,
  requiereReemplazo,
  reemplazado,
}

extension ComponentStatusX on ComponentStatus {
  String get label {
    switch (this) {
      case ComponentStatus.operativo:         return 'Operativo';
      case ComponentStatus.observado:         return 'Observado';
      case ComponentStatus.requiereReemplazo: return 'Requiere Reemplazo';
      case ComponentStatus.reemplazado:       return 'Reemplazado';
    }
  }

  String get value {
    switch (this) {
      case ComponentStatus.operativo:         return 'operativo';
      case ComponentStatus.observado:         return 'observado';
      case ComponentStatus.requiereReemplazo: return 'requiere_reemplazo';
      case ComponentStatus.reemplazado:       return 'reemplazado';
    }
  }

  Color get color {
    switch (this) {
      case ComponentStatus.operativo:         return Colors.green;
      case ComponentStatus.observado:         return Colors.orange;
      case ComponentStatus.requiereReemplazo: return Colors.red;
      case ComponentStatus.reemplazado:       return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case ComponentStatus.operativo:         return Icons.check_circle;
      case ComponentStatus.observado:         return Icons.warning_amber_rounded;
      case ComponentStatus.requiereReemplazo: return Icons.error;
      case ComponentStatus.reemplazado:       return Icons.swap_horiz;
    }
  }
}

ComponentStatus componentStatusFromValue(String? v) {
  if (v == null) return ComponentStatus.operativo;
  return ComponentStatus.values.firstWhere(
    (e) => e.value == v || e.name == v,
    orElse: () => ComponentStatus.operativo,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPONENT MODEL
// ══════════════════════════════════════════════════════════════════════════════

class ComponentModel {
  // Identificación
  final String id;
  final String equipoId;
  final String nombre;
  final String? descripcion;
  final String? tag;
  final ComponentType tipo;
  final String? marca;
  final String? modelo;
  final String? numeroSerie;
  final String? proveedor;

  // Valores técnicos (opcionales según tipo)
  final double? valorSeteo;
  final double? valorCorte;
  final String? unidad;      // bar, PSI, °C, etc.
  final String? rangoOperacion; // ej: "0–10 bar"

  // Estado
  final ComponentStatus estado;
  final String? ubicacionEnEquipo;
  final String? observacionesTecnico;

  // Reemplazo (simple, sin bodega)
  final DateTime? fechaReemplazo;
  final String? motivoReemplazo;
  final String? nuevoMarca;
  final String? nuevoModelo;
  final String? nuevoNumeroSerie;

  // Sub-componentes
  final bool tieneSubComponentes;

  // Fotos
  final List<String> fotos; // URLs Firebase Storage

  // Trazabilidad
  final DateTime? fechaInstalacion;
  final DateTime? fechaUltimaRevision;
  final String? tecnicoId;
  final DateTime creadoEn;
  final DateTime? actualizadoEn;

  const ComponentModel({
    required this.id,
    required this.equipoId,
    required this.nombre,
    this.descripcion,
    this.tag,
    required this.tipo,
    this.marca,
    this.modelo,
    this.numeroSerie,
    this.proveedor,
    this.valorSeteo,
    this.valorCorte,
    this.unidad,
    this.rangoOperacion,
    this.estado = ComponentStatus.operativo,
    this.ubicacionEnEquipo,
    this.observacionesTecnico,
    this.fechaReemplazo,
    this.motivoReemplazo,
    this.nuevoMarca,
    this.nuevoModelo,
    this.nuevoNumeroSerie,
    this.tieneSubComponentes = false,
    this.fotos = const [],
    this.fechaInstalacion,
    this.fechaUltimaRevision,
    this.tecnicoId,
    required this.creadoEn,
    this.actualizadoEn,
  });

  factory ComponentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ComponentModel(
      id: doc.id,
      // Fallback a campos legacy
      equipoId: (d['equipoId'] ?? d['equipmentId'] ?? '') as String,
      nombre: (d['nombre'] ?? d['name'] ?? '') as String,
      descripcion: d['descripcion'] as String?,
      tag: d['tag'] as String?,
      tipo: componentTypeFromValue((d['tipo'] ?? d['type']) as String?),
      marca: (d['marca'] ?? d['manufacturer']) as String?,
      modelo: (d['modelo'] ?? d['model']) as String?,
      numeroSerie: (d['numeroSerie'] ?? d['serialNumber']) as String?,
      proveedor: d['proveedor'] as String?,
      valorSeteo: (d['valorSeteo'] as num?)?.toDouble(),
      valorCorte: (d['valorCorte'] as num?)?.toDouble(),
      unidad: d['unidad'] as String?,
      rangoOperacion: d['rangoOperacion'] as String?,
      estado: componentStatusFromValue(d['estado'] as String?),
      ubicacionEnEquipo:
          (d['ubicacionEnEquipo'] ?? d['location']) as String?,
      observacionesTecnico: d['observacionesTecnico'] as String?,
      fechaReemplazo: (d['fechaReemplazo'] as Timestamp?)?.toDate(),
      motivoReemplazo: d['motivoReemplazo'] as String?,
      nuevoMarca: d['nuevoMarca'] as String?,
      nuevoModelo: d['nuevoModelo'] as String?,
      nuevoNumeroSerie: d['nuevoNumeroSerie'] as String?,
      tieneSubComponentes: (d['tieneSubComponentes'] as bool?) ?? false,
      fotos: List<String>.from(d['fotos'] ?? d['photoUrls'] ?? []),
      fechaInstalacion: (d['fechaInstalacion'] as Timestamp?)?.toDate(),
      fechaUltimaRevision:
          (d['fechaUltimaRevision'] as Timestamp?)?.toDate(),
      tecnicoId: d['tecnicoId'] as String?,
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      actualizadoEn: (d['actualizadoEn'] as Timestamp?)?.toDate(),
    );
  }

  /// Usado para actualizaciones (update). No incluye creadoEn.
  Map<String, dynamic> toMap() {
    String? nv(String? s) => (s?.trim().isEmpty ?? true) ? null : s!.trim();
    return {
      'equipoId': equipoId,
      'nombre': nombre,
      if (nv(descripcion) != null) 'descripcion': nv(descripcion),
      if (nv(tag) != null) 'tag': nv(tag),
      'tipo': tipo.value,
      if (nv(marca) != null) 'marca': nv(marca),
      if (nv(modelo) != null) 'modelo': nv(modelo),
      if (nv(numeroSerie) != null) 'numeroSerie': nv(numeroSerie),
      if (nv(proveedor) != null) 'proveedor': nv(proveedor),
      if (valorSeteo != null) 'valorSeteo': valorSeteo,
      if (valorCorte != null) 'valorCorte': valorCorte,
      if (nv(unidad) != null) 'unidad': nv(unidad),
      if (nv(rangoOperacion) != null) 'rangoOperacion': nv(rangoOperacion),
      'estado': estado.value,
      if (nv(ubicacionEnEquipo) != null)
        'ubicacionEnEquipo': nv(ubicacionEnEquipo),
      if (nv(observacionesTecnico) != null)
        'observacionesTecnico': nv(observacionesTecnico),
      if (fechaReemplazo != null)
        'fechaReemplazo': Timestamp.fromDate(fechaReemplazo!),
      if (nv(motivoReemplazo) != null) 'motivoReemplazo': nv(motivoReemplazo),
      if (nv(nuevoMarca) != null) 'nuevoMarca': nv(nuevoMarca),
      if (nv(nuevoModelo) != null) 'nuevoModelo': nv(nuevoModelo),
      if (nv(nuevoNumeroSerie) != null)
        'nuevoNumeroSerie': nv(nuevoNumeroSerie),
      'tieneSubComponentes': tieneSubComponentes,
      'fotos': fotos,
      if (fechaInstalacion != null)
        'fechaInstalacion': Timestamp.fromDate(fechaInstalacion!),
      if (nv(tecnicoId) != null) 'tecnicoId': nv(tecnicoId),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }
}
