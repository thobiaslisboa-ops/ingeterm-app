import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/upload_job.dart';
import '../services/upload_queue_manager.dart';
import 'photo_upload_item.dart';
import 'src/photo_download_io.dart'
    if (dart.library.html) 'src/photo_download_web.dart';
import 'src/photo_zip_io.dart'
    if (dart.library.html) 'src/photo_zip_web.dart';

// ── Tipos de estado general (backward-compat con maintenance_detail_screen) ──

enum PhotoUploadState { idle, uploading, done, error, offlineQueued }

class PhotoUploadStatus {
  final PhotoUploadState state;
  final double progress;
  final String? error;
  const PhotoUploadStatus(this.state, {this.progress = 0, this.error});
}

// ── Widget principal ──────────────────────────────────────────────────────────

class PhotoManagerWidget extends StatefulWidget {
  /// URLs ya subidas (del campo Firestore). Se actualizan desde el padre.
  final List<String> urls;

  /// Ruta base en Firebase Storage. Ej: 'equipos/123/fotos'
  final String storagePath;

  /// Referencia al documento Firestore donde se hace arrayUnion.
  final DocumentReference<Map<String, dynamic>> docRef;

  /// Campo del array en Firestore. Ej: 'fotos', 'photoUrls'
  final String fieldName;

  /// ID único de entidad para agrupar la cola. Ej: equipmentId, valveId
  final String entityId;

  /// Tamaño en px de cada thumbnail. Default 120.
  final double imageSize;

  /// Nombre para el ZIP descargado. Ej: 'Caldera_3'. Si null usa 'Ingeterm'.
  final String? entityName;

  /// Callback opcional con estado global de la cola (para sync indicators).
  final void Function(PhotoUploadStatus)? onStatusChange;

  const PhotoManagerWidget({
    super.key,
    required this.urls,
    required this.storagePath,
    required this.docRef,
    required this.fieldName,
    required this.entityId,
    this.imageSize = 120,
    this.entityName,
    this.onStatusChange,
  });

  @override
  State<PhotoManagerWidget> createState() => _PhotoManagerWidgetState();
}

class _PhotoManagerWidgetState extends State<PhotoManagerWidget> {
  final _picker = ImagePicker();
  StreamSubscription<List<UploadJob>>? _sub;
  List<UploadJob> _jobs = [];
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _jobs = UploadQueueManager.instance.jobsForEntity(widget.entityId);
    _sub = UploadQueueManager.instance
        .watchEntity(widget.entityId)
        .listen((jobs) {
      if (mounted) {
        setState(() => _jobs = jobs);
        _notifyStatus(jobs);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Jobs que mostrar: todos excepto los ya confirmados en widget.urls ─────

  List<UploadJob> get _displayJobs => _jobs
      .where((j) =>
          j.status != UploadStatus.uploaded ||
          !widget.urls.contains(j.remoteUrl))
      .toList();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final display = _displayJobs;
    final hasContent = widget.urls.isNotEmpty || display.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasContent) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Fotos ya guardadas en Firestore
              for (final url in widget.urls)
                _uploadedThumbnail(url),
              // Jobs activos (en cola / subiendo / error / recién subidos)
              for (final job in display)
                PhotoUploadItem(
                  key: ValueKey(job.id),
                  job: job,
                  size: widget.imageSize,
                  onRetry: () => UploadQueueManager.instance.retry(job.id),
                  onDelete: () => UploadQueueManager.instance.cancel(job.id),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Botón agregar fotos
        OutlinedButton.icon(
          onPressed: _addPhotos,
          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
          label: const Text('Agregar fotos', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 40),
          ),
        ),

        // Botón descargar todas las fotos (visible solo si hay fotos)
        if (widget.urls.isNotEmpty) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _downloading ? null : _downloadAll,
            icon: _downloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 16),
            label: Text(
              _downloading
                  ? 'Preparando descarga...'
                  : 'Descargar todas las fotos',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ],
    );
  }

  // ── Thumbnail de foto ya subida ───────────────────────────────────────────

  Widget _uploadedThumbnail(String url) {
    final sz = widget.imageSize;
    return SizedBox(
      width: sz,
      height: sz,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              final idx = widget.urls.indexOf(url);
              _openGallery(widget.urls, idx < 0 ? 0 : idx);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              // Web: <img> nativo no requiere CORS para renderizar.
              // pointer-events:none permite que Flutter maneje gestos y botones.
              child: kIsWeb
                  ? HtmlElementView.fromTagName(
                      tagName: 'img',
                      onElementCreated: (Object element) {
                        (element as dynamic)
                          ..src = url
                          ..setAttribute(
                            'style',
                            'width:100%;height:100%;'
                            'object-fit:cover;pointer-events:none;',
                          );
                      },
                    )
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_outlined,
                              color: Colors.grey, size: 32),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.red.shade50,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.red, size: 32),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _deleteUploaded(url),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child:
                    const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _addPhotos() async {
    final source = await _pickSource();
    if (source == null) return;

    List<XFile> files;
    if (source == ImageSource.camera) {
      final img = await _picker.pickImage(source: ImageSource.camera);
      if (img == null) return;
      files = [img];
    } else {
      files = await _picker.pickMultiImage();
      if (files.isEmpty) return;
    }

    await UploadQueueManager.instance.enqueue(
      files,
      storagePath: widget.storagePath,
      docPath: widget.docRef.path,
      fieldName: widget.fieldName,
      entityId: widget.entityId,
    );
  }

  Future<void> _deleteUploaded(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.docRef.update({
      widget.fieldName: FieldValue.arrayRemove([url]),
    });
  }

  // MEJORA 1: abre el visor como Dialog en lugar de ruta nueva
  void _openGallery(List<String> urls, int initialIndex) {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (_) => _FullscreenGallery(
        urls: urls,
        initialIndex: initialIndex,
      ),
    );
  }

  // MEJORA 3: descarga ZIP de todas las fotos
  Future<void> _downloadAll() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Usa el visor para guardar fotos individualmente'),
        ),
      );
      return;
    }
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparando descarga...'),
        duration: Duration(seconds: 60),
      ),
    );
    try {
      final fecha = DateTime.now().toIso8601String().substring(0, 10);
      final base = (widget.entityName ?? 'Ingeterm')
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(' ', '_');
      await downloadAllPhotos(widget.urls, '${base}_$fecha.zip');
      messenger.clearSnackBars();
      messenger.showSnackBar(const SnackBar(
        content: Text('Descarga iniciada'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text('Error al descargar: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería (múltiples)'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

  // ── Estado global para backward-compat ───────────────────────────────────

  void _notifyStatus(List<UploadJob> jobs) {
    if (widget.onStatusChange == null) return;
    final active = jobs
        .where((j) =>
            j.status != UploadStatus.uploaded ||
            !widget.urls.contains(j.remoteUrl))
        .toList();

    PhotoUploadState state;
    if (active.isEmpty) {
      state = PhotoUploadState.idle;
    } else if (active.any((j) => j.status == UploadStatus.uploading)) {
      state = PhotoUploadState.uploading;
    } else if (active.any((j) => j.status == UploadStatus.error)) {
      state = PhotoUploadState.error;
    } else if (active.any((j) => j.status == UploadStatus.queued)) {
      state = PhotoUploadState.offlineQueued;
    } else {
      state = PhotoUploadState.done;
    }
    widget.onStatusChange!(PhotoUploadStatus(state));
  }
}

// ── Visor de fotos en pantalla completa ──────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _FullscreenGallery({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _sharing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    final url = widget.urls[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: total > 1
            ? Text(
                '${_currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              )
            : null,
        centerTitle: true,
        actions: [
          // Botón guardar / descargar
          _saving
              ? const _SpinnerAction()
              : IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.white),
                  tooltip: kIsWeb ? 'Descargar' : 'Guardar en galería',
                  onPressed: () => _saveToDevice(url),
                ),
          // Botón compartir (solo en móvil)
          if (!kIsWeb)
            _sharing
                ? const _SpinnerAction()
                : IconButton(
                    icon:
                        const Icon(Icons.share_outlined, color: Colors.white),
                    tooltip: 'Compartir',
                    onPressed: () => _share(url),
                  ),
        ],
      ),
      // BUG 1: Stack con PageView + flechas de navegación
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 600) Navigator.pop(context);
            },
            // En web, PageView no recibe swipes con HtmlElementView;
            // GestureDetector los captura y llama _goTo.
            onHorizontalDragEnd: (kIsWeb && total > 1)
                ? (details) {
                    final dx = details.primaryVelocity ?? 0;
                    if (dx.abs() < 200) return;
                    _goTo(dx < 0 ? 1 : -1);
                  }
                : null,
            child: PageView.builder(
              controller: _pageController,
              // En web desactivamos el scroll interno para que el
              // GestureDetector capture los swipes sin competencia.
              physics: kIsWeb ? const NeverScrollableScrollPhysics() : null,
              itemCount: total,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              // Web: <img> nativo (sin CORS). Móvil: CachedNetworkImage con zoom.
              itemBuilder: (_, i) => kIsWeb
                  ? HtmlElementView.fromTagName(
                      tagName: 'img',
                      onElementCreated: (Object element) {
                        (element as dynamic)
                          ..src = widget.urls[i]
                          ..setAttribute(
                            'style',
                            'max-width:100%;max-height:100%;'
                            'object-fit:contain;pointer-events:none;',
                          );
                      },
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.urls[i],
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white54, size: 64),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Flechas < > (visibles cuando hay más de una foto)
          if (total > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrow(
                  icon: Icons.chevron_left,
                  onTap: () => _goTo(-1),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrow(
                  icon: Icons.chevron_right,
                  onTap: () => _goTo(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Navegación circular entre fotos
  void _goTo(int delta) {
    final total = widget.urls.length;
    final next = (_currentIndex + delta + total) % total;
    if (kIsWeb) {
      _pageController.jumpToPage(next);
    } else {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // BUG 2: blob download para web (evita que se abra la URL en el navegador)
  Future<void> _saveToDevice(String url) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (kIsWeb) {
        final name =
            'foto_${(_currentIndex + 1).toString().padLeft(3, '0')}.jpg';
        await downloadSinglePhoto(url, name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Descarga iniciada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        }
      } else {
        final ok = await saveToGallery(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Guardado en galería' : 'Error al guardar'),
            backgroundColor: ok ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(String url) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      client.close();

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(bytes);

      await Share.shareXFiles([XFile(path)]);
    } catch (_) {
      await Share.share(url);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

// Flecha de navegación en el visor fullscreen
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      );
}

// Spinner compacto para reemplazar un botón mientras procesa
class _SpinnerAction extends StatelessWidget {
  const _SpinnerAction();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
}
