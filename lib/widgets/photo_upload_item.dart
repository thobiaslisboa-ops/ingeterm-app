import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/upload_job.dart';

/// Item individual del grid de fotos con indicador de estado de subida.
///
/// Estados visuales:
///   queued   → gris + reloj (en cola)
///   uploading → azul + porcentaje (subiendo)
///   uploaded  → imagen nítida + check verde (completado)
///   error     → rojo + botón reintentar
class PhotoUploadItem extends StatelessWidget {
  final UploadJob job;
  final double size;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const PhotoUploadItem({
    super.key,
    required this.job,
    this.size = 100,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _image(),
          ),
          _overlay(),
          if (onDelete != null && job.status != UploadStatus.uploading)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _image() {
    if (job.status == UploadStatus.uploaded && job.remoteUrl != null) {
      return CachedNetworkImage(
        imageUrl: job.remoteUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _grey(),
        errorWidget: (_, __, ___) => _grey(),
      );
    }
    final file = File(job.localPath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return _grey();
  }

  Widget _overlay() {
    switch (job.status) {
      case UploadStatus.queued:
        return _dimmed(
          child: const Icon(Icons.access_time, color: Colors.white, size: 26),
        );

      case UploadStatus.uploading:
        return _dimmed(
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: job.progress > 0 ? job.progress : null,
                  strokeWidth: 3,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                ),
                if (job.progress > 0)
                  Text(
                    '${(job.progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );

      case UploadStatus.uploaded:
        return Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 11),
          ),
        );

      case UploadStatus.error:
        return Positioned.fill(
          child: GestureDetector(
            onTap: onRetry,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _dimmed({required Widget child}) => Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: child),
        ),
      );

  Widget _grey() => Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
        ),
      );
}
