import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════
//  VALVE STATUS  (4 estados del técnico en terreno)
// ══════════════════════════════════════════════════════

enum ValveStatus {
  enOperacion,
  enMantencion,
  enBodegaCliente,
  requiereReemplazo,
}

extension ValveStatusX on ValveStatus {
  String get label {
    switch (this) {
      case ValveStatus.enOperacion:       return 'En Operación';
      case ValveStatus.enMantencion:      return 'En Mantención';
      case ValveStatus.enBodegaCliente:   return 'En Bodega Cliente';
      case ValveStatus.requiereReemplazo: return 'Requiere Reemplazo';
    }
  }

  Color get color {
    switch (this) {
      case ValveStatus.enOperacion:       return Colors.green;
      case ValveStatus.enMantencion:      return Colors.orange;
      case ValveStatus.enBodegaCliente:   return Colors.blue;
      case ValveStatus.requiereReemplazo: return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case ValveStatus.enOperacion:       return Icons.check_circle_outline;
      case ValveStatus.enMantencion:      return Icons.build_outlined;
      case ValveStatus.enBodegaCliente:   return Icons.warehouse_outlined;
      case ValveStatus.requiereReemplazo: return Icons.warning_amber_outlined;
    }
  }
}

ValveStatus valveStatusFromString(String? s) {
  if (s == null) return ValveStatus.enOperacion;
  return ValveStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => ValveStatus.enOperacion,
  );
}

// ══════════════════════════════════════════════════════
//  VALVE TYPE
// ══════════════════════════════════════════════════════

enum ValveType {
  seguridad,
  alivio,
  control,
  check,
  paso,
  otro,
}

extension ValveTypeX on ValveType {
  String get label {
    switch (this) {
      case ValveType.seguridad: return 'Seguridad';
      case ValveType.alivio:    return 'Alivio';
      case ValveType.control:   return 'Control';
      case ValveType.check:     return 'Check';
      case ValveType.paso:      return 'Paso';
      case ValveType.otro:      return 'Otro';
    }
  }
}

ValveType valveTypeFromString(String? s) {
  if (s == null) return ValveType.seguridad;
  return ValveType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => ValveType.seguridad,
  );
}

// ══════════════════════════════════════════════════════
//  VALVE MODEL
//  Diseñado para exportación a certificado PDF (fase 2)
// ══════════════════════════════════════════════════════

class Valve {
  // — Identificación —
  final String id;
  final String name;
  final String? tag;
  final String? description;
  final String? brand;
  final String? model;
  final String? serialNumber;

  // — Valores técnicos (exportables a certificado) —
  final double? setPoint;   // valor al que debe abrir/cerrar
  final double? cutPoint;   // valor donde corta efectivamente
  final String? unit;       // bar, PSI, °C, kg/cm², etc.
  final ValveType valveType;

  // — Estado en terreno —
  final ValveStatus status;
  final String? locationInEquipment;
  final String? technicianNotes;

  // — Reemplazo —
  final String? replacedByValveId;
  final DateTime? replacementDate;

  // — Fotos —
  final List<String> photoUrls;

  // — Trazabilidad —
  final DateTime? lastRevisionDate;
  final String? technicianId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Valve({
    required this.id,
    required this.name,
    this.tag,
    this.description,
    this.brand,
    this.model,
    this.serialNumber,
    this.setPoint,
    this.cutPoint,
    this.unit,
    this.valveType = ValveType.seguridad,
    this.status = ValveStatus.enOperacion,
    this.locationInEquipment,
    this.technicianNotes,
    this.replacedByValveId,
    this.replacementDate,
    this.photoUrls = const [],
    this.lastRevisionDate,
    this.technicianId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Valve.fromMap(String id, Map<String, dynamic> d) {
    return Valve(
      id: id,
      name: d['name'] as String? ?? '',
      tag: d['tag'] as String?,
      description: d['description'] as String?,
      brand: d['brand'] as String?,
      model: d['model'] as String?,
      serialNumber: d['serialNumber'] as String?,
      setPoint: (d['setPoint'] as num?)?.toDouble(),
      cutPoint: (d['cutPoint'] as num?)?.toDouble(),
      unit: d['unit'] as String?,
      valveType: valveTypeFromString(d['valveType'] as String?),
      status: valveStatusFromString(d['status'] as String?),
      locationInEquipment: d['locationInEquipment'] as String?,
      technicianNotes: d['technicianNotes'] as String?,
      replacedByValveId: d['replacedByValveId'] as String?,
      replacementDate: (d['replacementDate'] as Timestamp?)?.toDate(),
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
      lastRevisionDate: (d['lastRevisionDate'] as Timestamp?)?.toDate(),
      technicianId: d['technicianId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Valve.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Valve.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tag': tag,
      'description': description,
      'brand': brand,
      'model': model,
      'serialNumber': serialNumber,
      'setPoint': setPoint,
      'cutPoint': cutPoint,
      'unit': unit,
      'valveType': valveType.name,
      'status': status.name,
      'locationInEquipment': locationInEquipment,
      'technicianNotes': technicianNotes,
      'replacedByValveId': replacedByValveId,
      if (replacementDate != null)
        'replacementDate': Timestamp.fromDate(replacementDate!),
      'photoUrls': photoUrls,
      if (lastRevisionDate != null)
        'lastRevisionDate': Timestamp.fromDate(lastRevisionDate!),
      'technicianId': technicianId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Valve copyWith({
    String? name,
    String? tag,
    String? description,
    String? brand,
    String? model,
    String? serialNumber,
    double? setPoint,
    double? cutPoint,
    String? unit,
    ValveType? valveType,
    ValveStatus? status,
    String? locationInEquipment,
    String? technicianNotes,
    String? replacedByValveId,
    DateTime? replacementDate,
    List<String>? photoUrls,
    DateTime? lastRevisionDate,
    String? technicianId,
    DateTime? updatedAt,
  }) {
    return Valve(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      setPoint: setPoint ?? this.setPoint,
      cutPoint: cutPoint ?? this.cutPoint,
      unit: unit ?? this.unit,
      valveType: valveType ?? this.valveType,
      status: status ?? this.status,
      locationInEquipment: locationInEquipment ?? this.locationInEquipment,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      replacedByValveId: replacedByValveId ?? this.replacedByValveId,
      replacementDate: replacementDate ?? this.replacementDate,
      photoUrls: photoUrls ?? this.photoUrls,
      lastRevisionDate: lastRevisionDate ?? this.lastRevisionDate,
      technicianId: technicianId ?? this.technicianId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
