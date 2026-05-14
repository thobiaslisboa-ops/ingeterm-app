// lib/models/maintenance_extended_model.dart
//
// Modelo legacy usado por:
//   - component_replacement_dialog.dart
//   - pdf_report_service.dart
//
// NO eliminar hasta migrar esos dos archivos al nuevo MaintenanceModel.

import 'package:cloud_firestore/cloud_firestore.dart';

// ── TestResult ────────────────────────────────────────────────────────────────

enum TestResult {
  passed,
  failed,
  partial,
}

extension TestResultExt on TestResult {
  String get label {
    switch (this) {
      case TestResult.passed:
        return 'PASA';
      case TestResult.failed:
        return 'FALLA';
      case TestResult.partial:
        return 'PARCIAL';
    }
  }

  String get emoji {
    switch (this) {
      case TestResult.passed:
        return '✅';
      case TestResult.failed:
        return '❌';
      case TestResult.partial:
        return '⚠️';
    }
  }
}

TestResult testResultFromString(String? v) {
  switch (v) {
    case 'failed':
      return TestResult.failed;
    case 'partial':
      return TestResult.partial;
    default:
      return TestResult.passed;
  }
}

// ── MaintenanceTypeExtended ───────────────────────────────────────────────────

enum MaintenanceTypeExtended {
  preventivo,
  correctivo,
  urgente,
}

extension MaintenanceTypeExtendedExt on MaintenanceTypeExtended {
  String get label {
    switch (this) {
      case MaintenanceTypeExtended.preventivo:
        return 'Preventivo';
      case MaintenanceTypeExtended.correctivo:
        return 'Correctivo';
      case MaintenanceTypeExtended.urgente:
        return 'Urgente';
    }
  }

  String get emoji {
    switch (this) {
      case MaintenanceTypeExtended.preventivo:
        return '🔧';
      case MaintenanceTypeExtended.correctivo:
        return '🔨';
      case MaintenanceTypeExtended.urgente:
        return '🚨';
    }
  }
}

MaintenanceTypeExtended maintenanceTypeFromString(String? v) {
  switch (v) {
    case 'correctivo':
      return MaintenanceTypeExtended.correctivo;
    case 'urgente':
      return MaintenanceTypeExtended.urgente;
    default:
      return MaintenanceTypeExtended.preventivo;
  }
}

// ── PressureReading ───────────────────────────────────────────────────────────

class PressureReading {
  final DateTime timestamp;
  final double pressure;
  final double? temperature;
  final String? label;

  const PressureReading({
    required this.timestamp,
    required this.pressure,
    this.temperature,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'pressure': pressure,
        if (temperature != null) 'temperature': temperature,
        if (label != null) 'label': label,
      };

  factory PressureReading.fromMap(Map<String, dynamic> map) => PressureReading(
        timestamp:
            (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        pressure: (map['pressure'] as num?)?.toDouble() ?? 0,
        temperature: (map['temperature'] as num?)?.toDouble(),
        label: map['label'] as String?,
      );
}

// ── ComponentReplacement ──────────────────────────────────────────────────────

class ComponentReplacement {
  final String id;
  final String componentName;
  final String? oldSerialNumber;
  final String? newSerialNumber;
  final String oldModel;
  final String newModel;
  final String replacementReason;
  final DateTime replacementDateTime;
  final TestResult functionalTest;
  final List<String> photoUrls;
  final String? notes;

  const ComponentReplacement({
    required this.id,
    required this.componentName,
    this.oldSerialNumber,
    this.newSerialNumber,
    required this.oldModel,
    required this.newModel,
    required this.replacementReason,
    required this.replacementDateTime,
    required this.functionalTest,
    required this.photoUrls,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'componentName': componentName,
        'oldSerialNumber': oldSerialNumber,
        'newSerialNumber': newSerialNumber,
        'oldModel': oldModel,
        'newModel': newModel,
        'replacementReason': replacementReason,
        'replacementDateTime': Timestamp.fromDate(replacementDateTime),
        'functionalTest': functionalTest.name,
        'photoUrls': photoUrls,
        'notes': notes,
      };

  factory ComponentReplacement.fromMap(Map<String, dynamic> map) =>
      ComponentReplacement(
        id: map['id'] as String? ?? '',
        componentName: map['componentName'] as String? ?? '',
        oldSerialNumber: map['oldSerialNumber'] as String?,
        newSerialNumber: map['newSerialNumber'] as String?,
        oldModel: map['oldModel'] as String? ?? '',
        newModel: map['newModel'] as String? ?? '',
        replacementReason: map['replacementReason'] as String? ?? '',
        replacementDateTime:
            (map['replacementDateTime'] as Timestamp?)?.toDate() ??
                DateTime.now(),
        functionalTest:
            testResultFromString(map['functionalTest'] as String?),
        photoUrls: List<String>.from(map['photoUrls'] ?? []),
        notes: map['notes'] as String?,
      );
}

// ── MaintenanceRecordExtended ─────────────────────────────────────────────────

class MaintenanceRecordExtended {
  final String id;
  final MaintenanceTypeExtended type;
  final DateTime dateTime;
  final String technicianName;
  final double? durationHours;
  final String? partNumber;
  final String description;
  final String problemsFound;
  final String solutionApplied;
  final List<PressureReading> pressureReadings;
  final List<ComponentReplacement> replacements;
  final List<String> photoUrls;
  final DateTime? nextScheduledMaintenance;

  const MaintenanceRecordExtended({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.technicianName,
    this.durationHours,
    this.partNumber,
    required this.description,
    required this.problemsFound,
    required this.solutionApplied,
    required this.pressureReadings,
    required this.replacements,
    required this.photoUrls,
    this.nextScheduledMaintenance,
  });

  factory MaintenanceRecordExtended.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MaintenanceRecordExtended(
      id: doc.id,
      type: maintenanceTypeFromString(data['type'] as String?),
      dateTime:
          (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      technicianName: data['technicianName'] as String? ?? '',
      durationHours: (data['durationHours'] as num?)?.toDouble(),
      partNumber: data['partNumber'] as String?,
      description: data['description'] as String? ?? '',
      problemsFound: data['problemsFound'] as String? ?? '',
      solutionApplied: data['solutionApplied'] as String? ?? '',
      pressureReadings: (data['pressureReadings'] as List<dynamic>? ?? [])
          .map((e) => PressureReading.fromMap(e as Map<String, dynamic>))
          .toList(),
      replacements: (data['replacements'] as List<dynamic>? ?? [])
          .map((e) =>
              ComponentReplacement.fromMap(e as Map<String, dynamic>))
          .toList(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      nextScheduledMaintenance:
          (data['nextScheduledMaintenance'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeTimestamp = true}) => {
        'type': type.name,
        'dateTime': Timestamp.fromDate(dateTime),
        'technicianName': technicianName,
        if (durationHours != null) 'durationHours': durationHours,
        if (partNumber != null) 'partNumber': partNumber,
        'description': description,
        'problemsFound': problemsFound,
        'solutionApplied': solutionApplied,
        'pressureReadings':
            pressureReadings.map((r) => r.toMap()).toList(),
        'replacements': replacements.map((r) => r.toMap()).toList(),
        'photoUrls': photoUrls,
        if (nextScheduledMaintenance != null)
          'nextScheduledMaintenance':
              Timestamp.fromDate(nextScheduledMaintenance!),
        if (includeTimestamp)
          'createdAt': FieldValue.serverTimestamp(),
      };
}
