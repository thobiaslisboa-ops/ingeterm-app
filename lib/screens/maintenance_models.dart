// lib/models/maintenance_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// ================= CLIENT =================

class Client {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory Client.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      contactPerson: data['contactPerson'],
      phone: data['phone'],
      email: data['email'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) {
    return {
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      if (includeTimestamp) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// ================= EQUIPMENT TYPE ENUM =================
enum EquipmentType {
  caldera,
  autoclave,
  vapConsumer,
}

extension EquipmentTypeExtension on EquipmentType {
  String get label {
    switch (this) {
      case EquipmentType.caldera:
        return 'Caldera';
      case EquipmentType.autoclave:
        return 'Autoclave';
      case EquipmentType.vapConsumer:
        return 'Equipo que Consume Vapor';
    }
  }

  String get value {
    switch (this) {
      case EquipmentType.caldera:
        return 'caldera';
      case EquipmentType.autoclave:
        return 'autoclave';
      case EquipmentType.vapConsumer:
        return 'vap_consumer';
    }
  }
}

EquipmentType equipmentTypeFromString(String? value) {
  switch (value) {
    case 'caldera':
      return EquipmentType.caldera;
    case 'autoclave':
      return EquipmentType.autoclave;
    case 'vap_consumer':
      return EquipmentType.vapConsumer;
    default:
      return EquipmentType.caldera;
  }
}

/// ================= EQUIPMENT STATUS ENUM =================
enum EquipmentStatus {
  operational,
  maintenance,
  outOfService,
}

extension EquipmentStatusExtension on EquipmentStatus {
  String get label {
    switch (this) {
      case EquipmentStatus.operational:
        return 'En Operación';
      case EquipmentStatus.maintenance:
        return 'En Mantenimiento';
      case EquipmentStatus.outOfService:
        return 'Fuera de Servicio';
    }
  }

  String get value {
    switch (this) {
      case EquipmentStatus.operational:
        return 'operational';
      case EquipmentStatus.maintenance:
        return 'maintenance';
      case EquipmentStatus.outOfService:
        return 'out_of_service';
    }
  }
}

EquipmentStatus equipmentStatusFromString(String? value) {
  switch (value) {
    case 'operational':
      return EquipmentStatus.operational;
    case 'maintenance':
      return EquipmentStatus.maintenance;
    case 'out_of_service':
      return EquipmentStatus.outOfService;
    default:
      return EquipmentStatus.operational;
  }
}

/// ================= EQUIPMENT =================

class Equipment {
  final String id;
  final String name;
  final String? tag;
  final EquipmentType type;
  final EquipmentStatus status;
  final int? manufacturingYear;
  final int? installationYear;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final String? maxWorkingPressure;
  final String? location;
  final String? description;
  final List<String> photoUrls;
  final DateTime? nextInspectionDate;
  final DateTime createdAt;

  Equipment({
    required this.id,
    required this.name,
    this.tag,
    this.type = EquipmentType.caldera,
    this.status = EquipmentStatus.operational,
    this.manufacturingYear,
    this.installationYear,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.maxWorkingPressure,
    this.location,
    this.description,
    this.photoUrls = const [],
    this.nextInspectionDate,
    required this.createdAt,
  });

  factory Equipment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Equipment(
      id: doc.id,
      name: data['name'] ?? '',
      tag: data['tag'],
      type: equipmentTypeFromString(data['type'] as String?),
      status: equipmentStatusFromString(data['status'] as String?),
      manufacturingYear: data['manufacturingYear'] as int?,
      installationYear: data['installationYear'] as int?,
      manufacturer: data['manufacturer'],
      model: data['model'],
      serialNumber: data['serialNumber'],
      maxWorkingPressure: data['maxWorkingPressure'],
      location: data['location'],
      description: data['description'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      nextInspectionDate: (data['nextInspectionDate'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) {
    return {
      'name': name,
      'tag': tag,
      'type': type.value,
      'status': status.value,
      'manufacturingYear': manufacturingYear,
      'installationYear': installationYear,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'maxWorkingPressure': maxWorkingPressure,
      'location': location,
      'description': description,
      'photoUrls': photoUrls,
      if (nextInspectionDate != null) 'nextInspectionDate': Timestamp.fromDate(nextInspectionDate!),
      if (includeTimestamp) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// ================= HYDRAULIC TEST =================

class HydraulicTest {
  final String id;
  final String equipmentId;
  final double? pmta;
  final double? phMultiplier;
  final double? calculatedPressure;
  final String? comments;
  final List<String> photoUrls;
  final DateTime date;
  final DateTime createdAt;

  HydraulicTest({
    required this.id,
    required this.equipmentId,
    this.pmta,
    this.phMultiplier,
    this.calculatedPressure,
    this.comments,
    this.photoUrls = const [],
    required this.date,
    required this.createdAt,
  });

  factory HydraulicTest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HydraulicTest(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      pmta: (data['pmta'] as num?)?.toDouble(),
      phMultiplier: (data['phMultiplier'] as num?)?.toDouble(),
      calculatedPressure: (data['calculatedPressure'] as num?)?.toDouble(),
      comments: data['comments'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) {
    return {
      'equipmentId': equipmentId,
      'pmta': pmta,
      'phMultiplier': phMultiplier,
      'calculatedPressure': calculatedPressure,
      'comments': comments,
      'photoUrls': photoUrls,
      'date': Timestamp.fromDate(date),
      if (includeTimestamp) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// ================= COMPONENT =================

enum ComponentType {
  valve,
  indicator,
  controller,
  pump,
  filter,
  other,
}

String componentTypeToString(ComponentType t) => t.name;
ComponentType componentTypeFromString(String? s) {
  if (s == null) return ComponentType.other;
  return ComponentType.values.firstWhere((e) => e.name == s, orElse: () => ComponentType.other);
}

class Component {
  final String id;
  final String equipmentId;
  final String name;
  final ComponentType type;
  final String? tag;
  final String? serialNumber;
  final String? model;
  final String? manufacturer;
  final String? location;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime? lastMaintenanceDate;
  final Map<String, dynamic>? additionalData;

  Component({
    required this.id,
    required this.equipmentId,
    required this.name,
    required this.type,
    this.tag,
    this.serialNumber,
    this.model,
    this.manufacturer,
    this.location,
    this.photoUrls = const [],
    required this.createdAt,
    this.lastMaintenanceDate,
    this.additionalData,
  });

  factory Component.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Component(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      name: data['name'] ?? '',
      type: componentTypeFromString(data['type']),
      tag: data['tag'],
      serialNumber: data['serialNumber'],
      model: data['model'],
      manufacturer: data['manufacturer'],
      location: data['location'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMaintenanceDate:
          (data['lastMaintenanceDate'] as Timestamp?)?.toDate(),
      additionalData: data['additionalData'],
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) {
    return {
      'equipmentId': equipmentId,
      'name': name,
      'type': type.name,
      'tag': tag,
      'serialNumber': serialNumber,
      'model': model,
      'manufacturer': manufacturer,
      'location': location,
      'photoUrls': photoUrls,
      if (lastMaintenanceDate != null)
        'lastMaintenanceDate': Timestamp.fromDate(lastMaintenanceDate!),
      if (additionalData != null) 'additionalData': additionalData,
      if (includeTimestamp) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// ================= VALVE =================

enum ValveStatus {
  enOperacion,
  enMantencion,
  enBodegaCliente,
}

enum ValveType {
  safety,
  relief,
}

String valveStatusToString(ValveStatus s) => s.name;
ValveStatus valveStatusFromString(String? s) {
  if (s == null) return ValveStatus.enOperacion;
  return ValveStatus.values.firstWhere((e) => e.name == s, orElse: () => ValveStatus.enOperacion);
}

String valveTypeToString(ValveType t) => t.name;
ValveType valveTypeFromString(String? s) {
  if (s == null) return ValveType.safety;
  return ValveType.values.firstWhere((e) => e.name == s, orElse: () => ValveType.safety);
}

class Valve {
  final String id;
  final String name;
  final String? tag;
  final String? type;
  final ValveStatus status;
  final ValveType valveType; // safety or relief
  final String? location; // 'enTaller', 'enPañol', 'operativa'
  final String? setPoint; // presión de seteo
  final String? cutPoint; // presión de corte
  final DateTime? calibrationDate;
  final DateTime? nextMaintenanceDate;
  final int? maintenanceIntervalMonths;
  final DateTime? lastMaintenanceDate;
  final DateTime? replacementDate;
  final String? replacementReason;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalData;

  Valve({
    required this.id,
    required this.name,
    this.tag,
    this.type,
    this.status = ValveStatus.enOperacion,
    this.valveType = ValveType.safety,
    this.location,
    this.setPoint,
    this.cutPoint,
    this.calibrationDate,
    this.nextMaintenanceDate,
    this.maintenanceIntervalMonths,
    this.lastMaintenanceDate,
    this.replacementDate,
    this.replacementReason,
    required this.createdAt,
    this.additionalData,
  });

  factory Valve.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final parsedStatus = valveStatusFromString(data['status'] as String?);
    final parsedValveType = valveTypeFromString(data['valveType'] as String?);

    return Valve(
      id: doc.id,
      name: data['name'] ?? '',
      tag: data['tag'],
      type: data['type'],
      status: parsedStatus,
      valveType: parsedValveType,
      location: data['location'] as String?,
      setPoint: data['setPoint'],
      cutPoint: data['cutPoint'],
      calibrationDate:
          (data['calibrationDate'] as Timestamp?)?.toDate(),
      maintenanceIntervalMonths: (data['maintenanceIntervalMonths'] is int) ? data['maintenanceIntervalMonths'] as int : (data['maintenanceIntervalMonths'] is String ? int.tryParse(data['maintenanceIntervalMonths']) : null),
      replacementDate: (data['replacementDate'] as Timestamp?)?.toDate(),
      replacementReason: data['replacementReason'] as String?,
      additionalData: data['additionalData'],
      lastMaintenanceDate:
          (data['lastMaintenanceDate'] as Timestamp?)?.toDate(),
      nextMaintenanceDate:
          (data['nextMaintenanceDate'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) {
    return {
      'name': name,
      'tag': tag,
      'type': type,
      'status': status.name,
      'valveType': valveType.name,
      if (location != null) 'location': location,
      if (setPoint != null) 'setPoint': setPoint,
      if (cutPoint != null) 'cutPoint': cutPoint,
      if (calibrationDate != null) 'calibrationDate': Timestamp.fromDate(calibrationDate!),
      if (nextMaintenanceDate != null) 'nextMaintenanceDate': Timestamp.fromDate(nextMaintenanceDate!),
      if (maintenanceIntervalMonths != null) 'maintenanceIntervalMonths': maintenanceIntervalMonths,
      'lastMaintenanceDate':
          lastMaintenanceDate != null
              ? Timestamp.fromDate(lastMaintenanceDate!)
              : null,
      if (replacementDate != null) 'replacementDate': Timestamp.fromDate(replacementDate!),
      if (replacementReason != null) 'replacementReason': replacementReason,
      if (includeTimestamp) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String getStatusText() {
    switch (status) {
      case ValveStatus.enMantencion:
        return 'En Mantención';
      case ValveStatus.enOperacion:
        return 'En Operación';
      case ValveStatus.enBodegaCliente:
        return 'En Bodega Cliente';
    }
  }

  String getValveTypeText() {
    return valveType == ValveType.safety ? 'Válvula de Seguridad' : 'Válvula de Alivio';
  }
}

/// ================= MAINTENANCE =================

class Maintenance {
  final String id;
  final DateTime date;
  final String notes;
  final String? setPoint;
  final String? cutOff;
  final String? technician;
  final List<String> photoUrls;
  final Map<String, dynamic>? additionalData;

  Maintenance({
    required this.id,
    required this.date,
    required this.notes,
    this.setPoint,
    this.cutOff,
    this.technician,
    this.photoUrls = const [],
    this.additionalData,
  });

  factory Maintenance.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Maintenance(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] ?? '',
      setPoint: data['setPoint'],
      cutOff: data['cutOff'],
      technician: data['technician'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      additionalData: data['additionalData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'setPoint': setPoint,
      'cutOff': cutOff,
      'technician': technician,
      'photoUrls': photoUrls,
      'additionalData': additionalData,
    };
  }
}
