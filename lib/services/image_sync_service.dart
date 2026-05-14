import 'dart:io';
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Modelo que representa una imagen pendiente de sincronización
class PendingImage {
  final int? id;
  final String imagePath;
  final String folder; // 'equipment', 'hydraulic_tests', 'valve_maintenance', etc
  final String entityId; // ID del equipo, válvula, etc
  final String documentPath; // Ruta en Firestore donde se debe guardar
  final String? fieldName; // Campo en Firestore donde guardar la URL ('photoUrls', etc)
  final DateTime createdAt;
  final bool isCompressed;

  PendingImage({
    this.id,
    required this.imagePath,
    required this.folder,
    required this.entityId,
    required this.documentPath,
    this.fieldName,
    required this.createdAt,
    this.isCompressed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'folder': folder,
      'entityId': entityId,
      'documentPath': documentPath,
      'fieldName': fieldName,
      'createdAt': createdAt.toIso8601String(),
      'isCompressed': isCompressed ? 1 : 0,
    };
  }

  static PendingImage fromMap(Map<String, dynamic> map) {
    return PendingImage(
      id: map['id'],
      imagePath: map['imagePath'],
      folder: map['folder'],
      entityId: map['entityId'],
      documentPath: map['documentPath'],
      fieldName: map['fieldName'],
      createdAt: DateTime.parse(map['createdAt']),
      isCompressed: map['isCompressed'] == 1,
    );
  }
}

/// Servicio para gestionar la sincronización de imágenes
class ImageSyncService {
  static final ImageSyncService _instance = ImageSyncService._internal();
  static Database? _database;
  bool _isSyncing = false;

  factory ImageSyncService() {
    return _instance;
  }

  ImageSyncService._internal();

  /// Inicializar la base de datos
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'image_sync.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pending_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT NOT NULL,
            folder TEXT NOT NULL,
            entityId TEXT NOT NULL,
            documentPath TEXT NOT NULL,
            fieldName TEXT,
            createdAt TEXT NOT NULL,
            isCompressed INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // La tabla upload_jobs es creada por UploadQueueManager en su migración
      },
    );

    return _database!;
  }

  /// Agregar una imagen a la cola de sincronización
  Future<void> addPendingImage({
    required String imagePath,
    required String folder,
    required String entityId,
    required String documentPath,
    String? fieldName,
  }) async {
    final db = await _getDatabase();
    final pending = PendingImage(
      imagePath: imagePath,
      folder: folder,
      entityId: entityId,
      documentPath: documentPath,
      fieldName: fieldName,
      createdAt: DateTime.now(),
    );

    await db.insert('pending_images', pending.toMap());
    
    // Intentar sincronizar si hay conexión
    await trySyncPendingImages();
  }

  /// Obtener todas las imágenes pendientes
  Future<List<PendingImage>> getPendingImages() async {
    final db = await _getDatabase();
    final maps = await db.query('pending_images');
    return List.generate(maps.length, (i) => PendingImage.fromMap(maps[i]));
  }

  /// Eliminar una imagen pendiente de la cola
  Future<void> removePendingImage(int id) async {
    final db = await _getDatabase();
    await db.delete('pending_images', where: 'id = ?', whereArgs: [id]);
  }

  /// Intentar sincronizar las imágenes pendientes si hay conexión
  Future<void> trySyncPendingImages() async {
    if (_isSyncing) return;

    // Verificar conexión
    final connectivity = Connectivity();
    final connectionStatus = await connectivity.checkConnectivity();

    if (connectionStatus.every((r) => r == ConnectivityResult.none)) {
      // Sin conexión, no hacer nada
      return;
    }

    // Hay conexión, sincronizar
    await _syncPendingImages();
  }

  /// Sincronizar todas las imágenes pendientes
  Future<void> _syncPendingImages() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingImages = await getPendingImages();

      for (final pending in pendingImages) {
        try {
          // Comprimir y subir la imagen
          final imageFile = File(pending.imagePath);
          
          if (!imageFile.existsSync()) {
            // El archivo fue eliminado, remover de la cola
            await removePendingImage(pending.id!);
            continue;
          }

          // Comprimir
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            '${imageFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
            quality: 80,
            format: CompressFormat.jpeg,
          );

          final fileToUpload =
              compressedFile != null ? File(compressedFile.path) : imageFile;

          // Subir a Firebase
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${basename(imageFile.path).replaceAll('.png', '.jpg')}';
          final ref = FirebaseStorage.instance
              .ref()
              .child('${pending.folder}/${pending.entityId}/$fileName');

          final uploadTask = ref.putFile(
            fileToUpload,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          // Esperar con timeout
          await uploadTask.timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              uploadTask.cancel();
              throw TimeoutException(
                  'Timeout subiendo imagen', const Duration(seconds: 90));
            },
          );

          // Obtener URL
          final url = await ref.getDownloadURL();

          // Actualizar en Firestore
          final db = FirebaseFirestore.instance;
          final docRef = db.doc(pending.documentPath);

          if (pending.fieldName != null) {
            // Agregar URL a un array (ej: photoUrls)
            await docRef.update({
              pending.fieldName!: FieldValue.arrayUnion([url])
            });
          }

          // Remover de la cola
          await removePendingImage(pending.id!);

          // Limpiar archivo comprimido
          try {
            if (compressedFile != null) {
              await File(compressedFile.path).delete();
            }
          } catch (_) {}
        } catch (_) {
          // Si falla una imagen, continuar con las siguientes
          continue;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Escuchar cambios de conectividad
  Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map((results) {
      return results.isNotEmpty && 
        !results.every((r) => r == ConnectivityResult.none);
    });
  }

}
