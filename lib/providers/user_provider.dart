// lib/providers/user_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.rol == UserRole.administrador;
  bool get isTecnico => _currentUser?.rol == UserRole.tecnico;
  bool get isLoaded => _currentUser != null;
  String get nombreCompleto => _currentUser?.nombreCompleto ?? '';
  String get uid => _currentUser?.uid ?? '';

  Future<void> loadUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      _currentUser = UserModel.fromFirestore(doc);
      // Fire-and-forget: actualizar último acceso sin bloquear
      doc.reference.update({'ultimoAcceso': FieldValue.serverTimestamp()});
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }
}
