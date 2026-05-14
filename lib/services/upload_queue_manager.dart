import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/upload_job.dart';

/// Singleton que gestiona colas de subida de fotos en background.
///
/// Características:
/// - Una cola FIFO por entityId (equipo, válvula, etc.)
/// - Colas de distintas entidades se procesan en PARALELO
/// - Persiste en SQLite → sobrevive a reinicios de pantalla
/// - Usa set(merge:true) → funciona aunque el doc Firestore no exista aún
/// - Retry automático al reconectar
class UploadQueueManager {
  static final UploadQueueManager instance = UploadQueueManager._();
  UploadQueueManager._();

  Database? _db;

  // jobs en memoria, agrupados por entityId
  final Map<String, List<UploadJob>> _jobs = {};

  // broadcast stream → los widgets se suscriben por entityId
  final _controller = StreamController<List<UploadJob>>.broadcast();

  // entidades cuya cola está siendo procesada activamente
  final Set<String> _active = {};

  // ── Inicialización ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _db = await _openDb();

    // Cargar jobs no completados desde SQLite
    final rows = await _db!.query(
      'upload_jobs',
      where: "status != 'uploaded'",
      orderBy: 'created_at ASC',
    );
    for (final row in rows) {
      UploadJob job = UploadJob.fromMap(row);
      // Si estaba "uploading" cuando la app cerró, resetear a queued
      if (job.status == UploadStatus.uploading) {
        job = job.resetToQueued();
        await _db!.update(
          'upload_jobs',
          {'status': 'queued', 'progress': 0.0},
          where: 'id = ?',
          whereArgs: [job.id],
        );
      }
      _jobs.putIfAbsent(job.entityId, () => []).add(job);
    }
    _emit();

    // Retry automático al reconectar
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) retryPending();
    });
  }

  // ── API pública ────────────────────────────────────────────────────────────

  /// Encola [files] para subida. Retorna los jobs creados.
  Future<List<UploadJob>> enqueue(
    List<XFile> files, {
    required String storagePath,
    required String docPath,
    required String fieldName,
    required String entityId,
  }) async {
    if (_db == null || files.isEmpty) return [];

    final jobs = <UploadJob>[];
    final ts = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < files.length; i++) {
      final ext = p.extension(files[i].path).toLowerCase();
      final fname = '${ts}_$i${ext.isEmpty ? '.jpg' : ext}';
      final job = UploadJob(
        entityId: entityId,
        localPath: files[i].path,
        storagePath: '$storagePath/$fname',
        docPath: docPath,
        fieldName: fieldName,
      );
      jobs.add(job);
      _jobs.putIfAbsent(entityId, () => []).add(job);
      await _db!.insert(
        'upload_jobs',
        job.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    _emit();
    _kickQueue(entityId);
    return jobs;
  }

  /// Stream de jobs para un entityId específico.
  Stream<List<UploadJob>> watchEntity(String entityId) =>
      _controller.stream.map(
        (all) => all.where((j) => j.entityId == entityId).toList(),
      );

  /// Snapshot sincrónico de jobs para un entityId.
  List<UploadJob> jobsForEntity(String entityId) =>
      List.unmodifiable(_jobs[entityId] ?? []);

  /// Reintenta un job en estado error.
  Future<void> retry(String jobId) async {
    _mutate(jobId, (j) => j.resetToQueued());
    await _db?.update(
      'upload_jobs',
      {'status': 'queued', 'progress': 0.0, 'error': null},
      where: 'id = ?',
      whereArgs: [jobId],
    );
    _emit();
    final entityId = _entityOf(jobId);
    if (entityId != null) _kickQueue(entityId);
  }

  /// Reintenta todos los jobs queued/error (llamado al reconectar).
  void retryPending() {
    final entities = <String>{};
    for (final jobs in _jobs.values) {
      for (final j in jobs) {
        if (j.status == UploadStatus.queued ||
            j.status == UploadStatus.error) {
          entities.add(j.entityId);
        }
      }
    }
    for (final e in entities) {
      _kickQueue(e);
    }
  }

  /// Cancela un job (y borra su archivo de Storage si ya subió).
  Future<void> cancel(String jobId) async {
    String? remoteUrl;
    for (final jobs in _jobs.values) {
      final idx = jobs.indexWhere((j) => j.id == jobId);
      if (idx != -1) {
        remoteUrl = jobs[idx].remoteUrl;
        jobs.removeAt(idx);
        break;
      }
    }
    await _db?.delete('upload_jobs', where: 'id = ?', whereArgs: [jobId]);
    if (remoteUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(remoteUrl).delete();
      } catch (_) {}
    }
    _emit();
  }

  // ── Procesamiento interno ──────────────────────────────────────────────────

  void _kickQueue(String entityId) {
    if (_active.contains(entityId)) return;
    _active.add(entityId);
    _drainQueue(entityId).whenComplete(() => _active.remove(entityId));
  }

  Future<void> _drainQueue(String entityId) async {
    while (true) {
      final next = _nextQueued(entityId);
      if (next == null) break;
      await _processJob(next);
    }
  }

  Future<void> _processJob(UploadJob job) async {
    // Verificar conectividad antes de empezar
    final conn = await Connectivity().checkConnectivity();
    if (conn.every((r) => r == ConnectivityResult.none)) return;

    _mutate(job.id, (j) => j.withStatus(UploadStatus.uploading, progress: 0));
    _emit();

    StreamSubscription? progressSub;
    try {
      final file = File(job.localPath);
      if (!file.existsSync()) {
        _removeJob(job.id);
        _emit();
        return;
      }

      // Comprimir
      final compressedPath =
          '${file.parent.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        compressedPath,
        quality: 80,
        minWidth: 1280,
        format: CompressFormat.jpeg,
      );
      final toUpload = compressed != null ? File(compressed.path) : file;

      // Subir a Firebase Storage
      final ref = FirebaseStorage.instance.ref(job.storagePath);
      final task = ref.putFile(
        toUpload,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      progressSub = task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          final pct = snap.bytesTransferred / snap.totalBytes;
          _mutate(job.id, (j) => j.withProgress(pct));
          _emit();
        }
      });

      await task.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          task.cancel();
          throw TimeoutException('Timeout', const Duration(seconds: 90));
        },
      );

      await progressSub.cancel();
      progressSub = null;

      final url = await ref.getDownloadURL();

      // Guardar URL en Firestore con merge para soportar docs que aún no existen
      await FirebaseFirestore.instance.doc(job.docPath).set(
        {job.fieldName: FieldValue.arrayUnion([url])},
        SetOptions(merge: true),
      );

      _mutate(job.id, (j) => j.withSuccess(url));
      await _persist(job.id);
      _emit();

      // Limpiar archivo comprimido temporal
      try {
        if (compressed != null) await File(compressed.path).delete();
      } catch (_) {}
    } catch (e) {
      await progressSub?.cancel();
      _mutate(job.id, (j) => j.withError(e.toString()));
      await _persist(job.id);
      _emit();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_jobs.values.expand((l) => l).toList());
    }
  }

  void _mutate(String jobId, UploadJob Function(UploadJob) fn) {
    for (final jobs in _jobs.values) {
      final idx = jobs.indexWhere((j) => j.id == jobId);
      if (idx != -1) {
        jobs[idx] = fn(jobs[idx]);
        return;
      }
    }
  }

  Future<void> _persist(String jobId) async {
    for (final jobs in _jobs.values) {
      for (final j in jobs) {
        if (j.id == jobId) {
          await _db?.update(
            'upload_jobs',
            j.toMap(),
            where: 'id = ?',
            whereArgs: [jobId],
          );
          return;
        }
      }
    }
  }

  void _removeJob(String jobId) {
    for (final jobs in _jobs.values) {
      jobs.removeWhere((j) => j.id == jobId);
    }
    _db?.delete('upload_jobs', where: 'id = ?', whereArgs: [jobId]);
  }

  UploadJob? _nextQueued(String entityId) {
    for (final j in (_jobs[entityId] ?? [])) {
      if (j.status == UploadStatus.queued) return j;
    }
    return null;
  }

  String? _entityOf(String jobId) {
    for (final entry in _jobs.entries) {
      if (entry.value.any((j) => j.id == jobId)) return entry.key;
    }
    return null;
  }

  // ── Base de datos ──────────────────────────────────────────────────────────

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'image_sync.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, v) async {
        await db.execute(_sqlPendingImages);
        await db.execute(_sqlUploadJobs);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await db.execute(_sqlUploadJobs);
      },
    );
  }

  static const _sqlPendingImages = '''
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
  ''';

  static const _sqlUploadJobs = '''
    CREATE TABLE IF NOT EXISTS upload_jobs (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL,
      local_path TEXT NOT NULL,
      storage_path TEXT NOT NULL,
      doc_path TEXT NOT NULL,
      field_name TEXT NOT NULL,
      status TEXT NOT NULL,
      progress REAL DEFAULT 0,
      remote_url TEXT,
      error TEXT,
      retry_count INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''';
}
