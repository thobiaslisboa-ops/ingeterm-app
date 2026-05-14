import 'dart:math';

enum UploadStatus { queued, uploading, uploaded, error }

class UploadJob {
  final String id;
  final String entityId;
  final String localPath;
  final String storagePath;
  final String docPath;
  final String fieldName;
  final UploadStatus status;
  final double progress;
  final String? remoteUrl;
  final String? error;
  final int retryCount;
  final DateTime createdAt;

  UploadJob({
    String? id,
    required this.entityId,
    required this.localPath,
    required this.storagePath,
    required this.docPath,
    required this.fieldName,
    this.status = UploadStatus.queued,
    this.progress = 0.0,
    this.remoteUrl,
    this.error,
    this.retryCount = 0,
    DateTime? createdAt,
  })  : id = id ?? _generateId(),
        createdAt = createdAt ?? DateTime.now();

  static final _rng = Random();

  static String _generateId() =>
      List.generate(20, (_) => _rng.nextInt(16).toRadixString(16)).join();

  UploadJob withStatus(UploadStatus s, {double progress = 0}) => UploadJob(
        id: id,
        entityId: entityId,
        localPath: localPath,
        storagePath: storagePath,
        docPath: docPath,
        fieldName: fieldName,
        status: s,
        progress: progress,
        remoteUrl: remoteUrl,
        error: error,
        retryCount: retryCount,
        createdAt: createdAt,
      );

  UploadJob withProgress(double p) => UploadJob(
        id: id,
        entityId: entityId,
        localPath: localPath,
        storagePath: storagePath,
        docPath: docPath,
        fieldName: fieldName,
        status: status,
        progress: p,
        remoteUrl: remoteUrl,
        error: error,
        retryCount: retryCount,
        createdAt: createdAt,
      );

  UploadJob withSuccess(String url) => UploadJob(
        id: id,
        entityId: entityId,
        localPath: localPath,
        storagePath: storagePath,
        docPath: docPath,
        fieldName: fieldName,
        status: UploadStatus.uploaded,
        progress: 1.0,
        remoteUrl: url,
        error: null,
        retryCount: retryCount,
        createdAt: createdAt,
      );

  UploadJob withError(String msg) => UploadJob(
        id: id,
        entityId: entityId,
        localPath: localPath,
        storagePath: storagePath,
        docPath: docPath,
        fieldName: fieldName,
        status: UploadStatus.error,
        progress: 0,
        remoteUrl: null,
        error: msg,
        retryCount: retryCount + 1,
        createdAt: createdAt,
      );

  UploadJob resetToQueued() => UploadJob(
        id: id,
        entityId: entityId,
        localPath: localPath,
        storagePath: storagePath,
        docPath: docPath,
        fieldName: fieldName,
        status: UploadStatus.queued,
        progress: 0,
        remoteUrl: null,
        error: null,
        retryCount: retryCount,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_id': entityId,
        'local_path': localPath,
        'storage_path': storagePath,
        'doc_path': docPath,
        'field_name': fieldName,
        'status': status.name,
        'progress': progress,
        'remote_url': remoteUrl,
        'error': error,
        'retry_count': retryCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static UploadJob fromMap(Map<String, dynamic> m) => UploadJob(
        id: m['id'] as String,
        entityId: m['entity_id'] as String,
        localPath: m['local_path'] as String,
        storagePath: m['storage_path'] as String,
        docPath: m['doc_path'] as String,
        fieldName: m['field_name'] as String,
        status: UploadStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => UploadStatus.queued,
        ),
        progress: (m['progress'] as num?)?.toDouble() ?? 0.0,
        remoteUrl: m['remote_url'] as String?,
        error: m['error'] as String?,
        retryCount: (m['retry_count'] as int?) ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
