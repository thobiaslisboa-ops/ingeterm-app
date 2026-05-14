import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  late Box<Map> _offlineBox;
  bool _isOnline = false;

  factory OfflineSyncService() {
    return _instance;
  }

  OfflineSyncService._internal();

  /// Inicializar Hive y monitorear conectividad
  Future<void> initialize() async {
    // Inicializar Hive
    await Hive.initFlutter();
    _offlineBox = await Hive.openBox<Map>('offline_operations');

    // Monitorear cambios de conectividad
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline) {
        _syncOfflineData();
      }
    });

    // Verificar estado inicial de conexión
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    // Si hay internet, sincronizar datos pendientes
    if (_isOnline) {
      _syncOfflineData();
    }
  }

  /// Sincronizar datos offline con Firestore
  Future<void> _syncOfflineData() async {
    if (!_isOnline) return;

    final db = FirebaseFirestore.instance;

    try {
      final allKeys = _offlineBox.keys.toList();
      
      for (var key in allKeys) {
        final operation = _offlineBox.get(key);
        if (operation == null) continue;
        
        final operationType = operation['operationType'] as String;
        final collection = operation['collection'] as String;
        final docId = operation['docId'] as String;
        final data = Map<String, dynamic>.from(operation['data']);

        try {
          switch (operationType) {
            case 'add':
              await db.collection(collection).doc(docId).set(data);
              break;
            case 'update':
              await db.collection(collection).doc(docId).update(data);
              break;
            case 'delete':
              await db.collection(collection).doc(docId).delete();
              break;
          }

          // Eliminar operación del caché después de sincronizar
          await _offlineBox.delete(key);
        } catch (_) {
          // Si falla la sincronización, dejar la operación en caché para intentar más tarde
        }
      }
    } catch (_) {
      // Error durante sincronización offline
    }
  }

  /// Retorna true si hay conexión en el momento de la llamada.
  bool get isOnline => _isOnline;

  /// Ejecuta [fn] (un write a Firestore) y retorna si había conexión.
  /// Firestore offline persistence garantiza que el write quede en caché
  /// y se sincronice automáticamente al reconectar, por lo que [fn] siempre
  /// completa sin error (a menos que haya un problema de permisos/lógica).
  Future<bool> checkAndSave(Future<void> Function() fn) async {
    final conn = await Connectivity().checkConnectivity();
    final online = !conn.every((r) => r == ConnectivityResult.none);
    await fn();
    return online;
  }

  /// Habilitar Firestore offline persistence
  static void enableFirestorePersistence() {
    if (kIsWeb) return; // En web siempre consultar al servidor directamente
    final db = FirebaseFirestore.instance;
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}
