import 'image_sync_service.dart';
import 'upload_queue_manager.dart';

/// Inicializa los servicios de sincronización al arrancar la app.
void initializeImageSync() {
  // Cola nueva: gestiona todas las subidas en background con indicadores por foto
  UploadQueueManager.instance.init();

  // Cola legacy: reintenta imágenes encoladas por versiones anteriores
  final legacy = ImageSyncService();
  legacy.connectivityStream.listen((isOnline) {
    if (isOnline) legacy.trySyncPendingImages();
  });
  legacy.trySyncPendingImages();
}
