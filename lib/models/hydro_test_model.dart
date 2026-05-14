import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Resultado de la prueba ────────────────────────────────────────────────

enum HydroTestResult { aprobado, rechazado, observado }

extension HydroTestResultExt on HydroTestResult {
  String get label {
    switch (this) {
      case HydroTestResult.aprobado:
        return 'Aprobado';
      case HydroTestResult.rechazado:
        return 'Rechazado';
      case HydroTestResult.observado:
        return 'Con Observaciones';
    }
  }

  Color get color {
    switch (this) {
      case HydroTestResult.aprobado:
        return const Color(0xFF4CAF50);
      case HydroTestResult.rechazado:
        return const Color(0xFFF44336);
      case HydroTestResult.observado:
        return const Color(0xFFFFC107);
    }
  }

  IconData get icon {
    switch (this) {
      case HydroTestResult.aprobado:
        return Icons.check_circle;
      case HydroTestResult.rechazado:
        return Icons.cancel;
      case HydroTestResult.observado:
        return Icons.warning_amber;
    }
  }

  String get value {
    switch (this) {
      case HydroTestResult.aprobado:
        return 'aprobado';
      case HydroTestResult.rechazado:
        return 'rechazado';
      case HydroTestResult.observado:
        return 'observado';
    }
  }
}

HydroTestResult? hydroTestResultFromString(String? s) {
  if (s == null) return null;
  for (final v in HydroTestResult.values) {
    if (v.value == s) return v;
  }
  return null;
}

// ─── Modelo principal ──────────────────────────────────────────────────────

class HydroTest {
  final String id;
  final String equipmentId;

  // Identificación
  final int? numeroPrueba;
  final DateTime fechaPrueba;
  final String? tecnicoId;
  final String? tecnicoNombre;

  // Datos de la prueba
  /// presionPrueba ← campo antiguo: pmta (Presión Máxima de Trabajo Admisible)
  final double? presionPrueba;
  /// phMultiplier: factor PH/PMTA, guardado como dato técnico extra
  final double? phMultiplier;
  /// presionCalculada ← campo antiguo: calculatedPressure (presionPrueba × phMultiplier)
  final double? presionCalculada;
  final String unidadPresion; // bar | PSI | kPa
  final int? duracionMinutos;

  // Resultado
  final HydroTestResult? resultado;
  /// observaciones ← campo antiguo: comments
  final String? observaciones;
  final List<String> hallazgos;

  // Fotos
  /// fotos ← campo antiguo: photoUrls
  final List<String> fotos;

  // Certificado
  final bool certificadoGenerado;
  final DateTime? fechaCertificado;
  final String? numeroCertificado;

  // Trazabilidad
  /// creadoEn ← campo antiguo: createdAt
  final DateTime creadoEn;
  final DateTime? actualizadoEn;

  const HydroTest({
    required this.id,
    required this.equipmentId,
    this.numeroPrueba,
    required this.fechaPrueba,
    this.tecnicoId,
    this.tecnicoNombre,
    this.presionPrueba,
    this.phMultiplier,
    this.presionCalculada,
    this.unidadPresion = 'bar',
    this.duracionMinutos,
    this.resultado,
    this.observaciones,
    this.hallazgos = const [],
    this.fotos = const [],
    this.certificadoGenerado = false,
    this.fechaCertificado,
    this.numeroCertificado,
    required this.creadoEn,
    this.actualizadoEn,
  });

  factory HydroTest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return HydroTest(
      id: doc.id,
      equipmentId: d['equipmentId'] as String? ?? '',
      numeroPrueba: d['numeroPrueba'] as int?,
      // Backward compat: date → fechaPrueba
      fechaPrueba: (d['fechaPrueba'] as Timestamp?)?.toDate() ??
          (d['date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      tecnicoId: d['tecnicoId'] as String?,
      tecnicoNombre: d['tecnicoNombre'] as String?,
      // Backward compat: pmta → presionPrueba
      presionPrueba: (d['presionPrueba'] as num?)?.toDouble() ??
          (d['pmta'] as num?)?.toDouble(),
      phMultiplier: (d['phMultiplier'] as num?)?.toDouble(),
      // Backward compat: calculatedPressure → presionCalculada
      presionCalculada: (d['presionCalculada'] as num?)?.toDouble() ??
          (d['calculatedPressure'] as num?)?.toDouble(),
      unidadPresion: d['unidadPresion'] as String? ?? 'bar',
      duracionMinutos: d['duracionMinutos'] as int?,
      resultado: hydroTestResultFromString(d['resultado'] as String?),
      // Backward compat: comments → observaciones
      observaciones: d['observaciones'] as String? ??
          d['comments'] as String?,
      hallazgos: List<String>.from(d['hallazgos'] ?? []),
      // Backward compat: photoUrls → fotos
      fotos: List<String>.from(d['fotos'] ?? d['photoUrls'] ?? []),
      certificadoGenerado: d['certificadoGenerado'] as bool? ?? false,
      fechaCertificado: (d['fechaCertificado'] as Timestamp?)?.toDate(),
      numeroCertificado: d['numeroCertificado'] as String?,
      // Backward compat: createdAt → creadoEn
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ??
          (d['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      actualizadoEn: (d['actualizadoEn'] as Timestamp?)?.toDate(),
    );
  }

  /// [isCreate] = true solo al crear un documento nuevo (escribe creadoEn).
  Map<String, dynamic> toMap({bool isCreate = false}) {
    return {
      'equipmentId': equipmentId,
      if (numeroPrueba != null) 'numeroPrueba': numeroPrueba,
      'fechaPrueba': Timestamp.fromDate(fechaPrueba),
      if (tecnicoId != null) 'tecnicoId': tecnicoId,
      if (tecnicoNombre != null) 'tecnicoNombre': tecnicoNombre,
      if (presionPrueba != null) 'presionPrueba': presionPrueba,
      if (phMultiplier != null) 'phMultiplier': phMultiplier,
      if (presionCalculada != null) 'presionCalculada': presionCalculada,
      'unidadPresion': unidadPresion,
      if (duracionMinutos != null) 'duracionMinutos': duracionMinutos,
      if (resultado != null) 'resultado': resultado!.value,
      if (observaciones != null && observaciones!.isNotEmpty)
        'observaciones': observaciones,
      'hallazgos': hallazgos,
      'fotos': fotos,
      'certificadoGenerado': certificadoGenerado,
      if (fechaCertificado != null)
        'fechaCertificado': Timestamp.fromDate(fechaCertificado!),
      if (numeroCertificado != null) 'numeroCertificado': numeroCertificado,
      if (isCreate) 'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  HydroTest copyWith({
    String? equipmentId,
    int? numeroPrueba,
    DateTime? fechaPrueba,
    String? tecnicoId,
    String? tecnicoNombre,
    double? presionPrueba,
    double? phMultiplier,
    double? presionCalculada,
    String? unidadPresion,
    int? duracionMinutos,
    HydroTestResult? resultado,
    String? observaciones,
    List<String>? hallazgos,
    List<String>? fotos,
    bool? certificadoGenerado,
    DateTime? fechaCertificado,
    String? numeroCertificado,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return HydroTest(
      id: id,
      equipmentId: equipmentId ?? this.equipmentId,
      numeroPrueba: numeroPrueba ?? this.numeroPrueba,
      fechaPrueba: fechaPrueba ?? this.fechaPrueba,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      presionPrueba: presionPrueba ?? this.presionPrueba,
      phMultiplier: phMultiplier ?? this.phMultiplier,
      presionCalculada: presionCalculada ?? this.presionCalculada,
      unidadPresion: unidadPresion ?? this.unidadPresion,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      resultado: resultado ?? this.resultado,
      observaciones: observaciones ?? this.observaciones,
      hallazgos: hallazgos ?? this.hallazgos,
      fotos: fotos ?? this.fotos,
      certificadoGenerado: certificadoGenerado ?? this.certificadoGenerado,
      fechaCertificado: fechaCertificado ?? this.fechaCertificado,
      numeroCertificado: numeroCertificado ?? this.numeroCertificado,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}
