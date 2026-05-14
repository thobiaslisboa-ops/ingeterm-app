import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════
//  EQUIPMENT TYPE  (7 tipos de equipo industrial)
// ══════════════════════════════════════════════════════

enum EquipmentType {
  caldera,
  autoclave,
  compressor,
  heatExchanger,
  pressureVessel,
  vapConsumer,
  other,
}

extension EquipmentTypeX on EquipmentType {
  String get label {
    switch (this) {
      case EquipmentType.caldera:        return 'Caldera';
      case EquipmentType.autoclave:      return 'Autoclave';
      case EquipmentType.compressor:     return 'Compresor';
      case EquipmentType.heatExchanger:  return 'Intercambiador de Calor';
      case EquipmentType.pressureVessel: return 'Recipiente a Presión';
      case EquipmentType.vapConsumer:    return 'Consumidor de Vapor';
      case EquipmentType.other:          return 'Otro';
    }
  }

  // Valor guardado en Firestore — compatible con valores antiguos
  String get value {
    switch (this) {
      case EquipmentType.caldera:        return 'caldera';
      case EquipmentType.autoclave:      return 'autoclave';
      case EquipmentType.compressor:     return 'compressor';
      case EquipmentType.heatExchanger:  return 'heat_exchanger';
      case EquipmentType.pressureVessel: return 'pressure_vessel';
      case EquipmentType.vapConsumer:    return 'vap_consumer';
      case EquipmentType.other:          return 'other';
    }
  }

  IconData get icon {
    switch (this) {
      case EquipmentType.caldera:        return Icons.local_fire_department;
      case EquipmentType.autoclave:      return Icons.science;
      case EquipmentType.compressor:     return Icons.air;
      case EquipmentType.heatExchanger:  return Icons.device_thermostat;
      case EquipmentType.pressureVessel: return Icons.radio_button_unchecked;
      case EquipmentType.vapConsumer:    return Icons.cloud_outlined;
      case EquipmentType.other:          return Icons.settings;
    }
  }
}

EquipmentType equipmentTypeFromString(String? s) {
  switch (s) {
    case 'caldera':          return EquipmentType.caldera;
    case 'autoclave':        return EquipmentType.autoclave;
    case 'compressor':       return EquipmentType.compressor;
    case 'heat_exchanger':   return EquipmentType.heatExchanger;
    case 'pressure_vessel':  return EquipmentType.pressureVessel;
    case 'vap_consumer':     return EquipmentType.vapConsumer;  // valor antiguo
    case 'other':            return EquipmentType.other;
    default:                 return EquipmentType.caldera;
  }
}

// ══════════════════════════════════════════════════════
//  EQUIPMENT STATUS
// ══════════════════════════════════════════════════════

enum EquipmentStatus {
  operational,
  maintenance,
  outOfService,
}

extension EquipmentStatusX on EquipmentStatus {
  String get label {
    switch (this) {
      case EquipmentStatus.operational:  return 'En Operación';
      case EquipmentStatus.maintenance:  return 'En Mantenimiento';
      case EquipmentStatus.outOfService: return 'Fuera de Servicio';
    }
  }

  String get value {
    switch (this) {
      case EquipmentStatus.operational:  return 'operational';
      case EquipmentStatus.maintenance:  return 'maintenance';
      case EquipmentStatus.outOfService: return 'out_of_service';
    }
  }

  Color get color {
    switch (this) {
      case EquipmentStatus.operational:  return Colors.green;
      case EquipmentStatus.maintenance:  return Colors.orange;
      case EquipmentStatus.outOfService: return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case EquipmentStatus.operational:  return Icons.check_circle_outline;
      case EquipmentStatus.maintenance:  return Icons.build_outlined;
      case EquipmentStatus.outOfService: return Icons.do_not_disturb_outlined;
    }
  }
}

EquipmentStatus equipmentStatusFromString(String? s) {
  switch (s) {
    case 'operational':    return EquipmentStatus.operational;
    case 'maintenance':    return EquipmentStatus.maintenance;
    case 'out_of_service': return EquipmentStatus.outOfService;
    default:               return EquipmentStatus.operational;
  }
}

// ══════════════════════════════════════════════════════
//  EQUIPMENT MODEL
//  Diseñado para exportación a informe y certificado PDF
// ══════════════════════════════════════════════════════

class Equipment {
  // — Identificación —
  final String id;
  final String name;
  final String? tag;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final int? manufacturingYear;
  final int? installationYear;

  // — Clasificación —
  final EquipmentType type;
  final EquipmentStatus status;

  // — Datos técnicos (exportables a certificado/informe) —
  final double? designPressure;       // presión de diseño
  final double? operatingPressure;    // presión de operación
  final double? designTemperature;    // temperatura de diseño
  final double? operatingTemperature; // temperatura de operación
  final double? capacity;
  final String? capacityUnit;         // unidad de capacidad
  final String? fluid;                // fluido contenido

  // — Ubicación —
  final String? plant;
  final String? area;
  final String? line;
  final String? locationDescription;  // descripción libre

  // — General —
  final String? description;
  final List<String> photoUrls;
  final DateTime? nextInspectionDate;

  // — Trazabilidad —
  final String? clientId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Equipment({
    required this.id,
    required this.name,
    this.tag,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.manufacturingYear,
    this.installationYear,
    this.type = EquipmentType.caldera,
    this.status = EquipmentStatus.operational,
    this.designPressure,
    this.operatingPressure,
    this.designTemperature,
    this.operatingTemperature,
    this.capacity,
    this.capacityUnit,
    this.fluid,
    this.plant,
    this.area,
    this.line,
    this.locationDescription,
    this.description,
    this.photoUrls = const [],
    this.nextInspectionDate,
    this.clientId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Equipment.fromMap(String id, Map<String, dynamic> d) {
    // Backward compat: operatingPressure ← maxWorkingPressure (String en modelo antiguo)
    double? operatingPressure = (d['operatingPressure'] as num?)?.toDouble();
    if (operatingPressure == null) {
      operatingPressure =
          double.tryParse((d['maxWorkingPressure'] as String?) ?? '');
    }

    // Backward compat: locationDescription ← location (campo antiguo)
    String? locationDescription = _nonEmpty(d['locationDescription']);
    locationDescription ??= _nonEmpty(d['location']);

    return Equipment(
      id: id,
      name: d['name'] as String? ?? '',
      tag: _nonEmpty(d['tag']),
      manufacturer: _nonEmpty(d['manufacturer']),
      model: _nonEmpty(d['model']),
      serialNumber: _nonEmpty(d['serialNumber']),
      manufacturingYear: d['manufacturingYear'] as int?,
      installationYear: d['installationYear'] as int?,
      type: equipmentTypeFromString(d['type'] as String?),
      status: equipmentStatusFromString(d['status'] as String?),
      designPressure: (d['designPressure'] as num?)?.toDouble(),
      operatingPressure: operatingPressure,
      designTemperature: (d['designTemperature'] as num?)?.toDouble(),
      operatingTemperature: (d['operatingTemperature'] as num?)?.toDouble(),
      capacity: (d['capacity'] as num?)?.toDouble(),
      capacityUnit: _nonEmpty(d['capacityUnit']),
      fluid: _nonEmpty(d['fluid']),
      plant: _nonEmpty(d['plant']),
      area: _nonEmpty(d['area']),
      line: _nonEmpty(d['line']),
      locationDescription: locationDescription,
      description: _nonEmpty(d['description']),
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
      nextInspectionDate: (d['nextInspectionDate'] as Timestamp?)?.toDate(),
      clientId: _nonEmpty(d['clientId']),
      createdBy: _nonEmpty(d['createdBy']),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Equipment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return Equipment.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tag': tag,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'manufacturingYear': manufacturingYear,
      'installationYear': installationYear,
      'type': type.value,
      'status': status.value,
      'designPressure': designPressure,
      'operatingPressure': operatingPressure,
      'designTemperature': designTemperature,
      'operatingTemperature': operatingTemperature,
      'capacity': capacity,
      'capacityUnit': capacityUnit,
      'fluid': fluid,
      'plant': plant,
      'area': area,
      'line': line,
      'locationDescription': locationDescription,
      'description': description,
      'photoUrls': photoUrls,
      if (nextInspectionDate != null)
        'nextInspectionDate': Timestamp.fromDate(nextInspectionDate!),
      'clientId': clientId,
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper: convierte cadenas vacías a null
  static String? _nonEmpty(dynamic v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }
}
