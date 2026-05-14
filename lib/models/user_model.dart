// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { administrador, tecnico }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.administrador:
        return 'Administrador';
      case UserRole.tecnico:
        return 'Técnico';
    }
  }

  String get value {
    switch (this) {
      case UserRole.administrador:
        return 'administrador';
      case UserRole.tecnico:
        return 'tecnico';
    }
  }
}

UserRole userRoleFromString(String? v) {
  switch (v) {
    case 'administrador':
      return UserRole.administrador;
    case 'tecnico':
      return UserRole.tecnico;
    default:
      return UserRole.tecnico;
  }
}

class UserModel {
  final String uid;
  final String nombre;
  final String apellido;
  final String email;
  final UserRole rol;
  final bool activo;
  final String? fotoUrl;
  final DateTime creadoEn;
  final DateTime? ultimoAcceso;

  const UserModel({
    required this.uid,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    required this.activo,
    this.fotoUrl,
    required this.creadoEn,
    this.ultimoAcceso,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  factory UserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      nombre: d['nombre'] as String? ?? '',
      apellido: d['apellido'] as String? ?? '',
      email: d['email'] as String? ?? '',
      rol: userRoleFromString(d['rol'] as String?),
      activo: d['activo'] as bool? ?? true,
      fotoUrl: d['fotoUrl'] as String?,
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ultimoAcceso: (d['ultimoAcceso'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'rol': rol.value,
        'activo': activo,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        'creadoEn': FieldValue.serverTimestamp(),
        'ultimoAcceso': null,
      };
}
