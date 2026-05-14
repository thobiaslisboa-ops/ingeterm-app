// lib/widgets/sync_status_bar.dart
//
// Barra de estado de sincronización. Muestra: guardado, offline,
// subiendo fotos, o error. Controlada externamente via SyncStatusController.

import 'dart:async';
import 'package:flutter/material.dart';

// ── Estados ───────────────────────────────────────────────────────────────────

enum SyncState { idle, saved, offline, uploading, error }

// ── Controlador ───────────────────────────────────────────────────────────────

class SyncStatusController extends ChangeNotifier {
  SyncState _state = SyncState.idle;
  String _message = '';
  VoidCallback? _onRetry;
  Timer? _hideTimer;

  SyncState get state => _state;
  String get message => _message;
  VoidCallback? get onRetry => _onRetry;

  /// Muestra "✓ Cambios guardados" y desaparece a los 3 segundos.
  void showSaved({String message = '✓ Cambios guardados'}) {
    _hideTimer?.cancel();
    _state = SyncState.saved;
    _message = message;
    _onRetry = null;
    notifyListeners();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_state == SyncState.saved) {
        _state = SyncState.idle;
        _message = '';
        notifyListeners();
      }
    });
  }

  /// Muestra barra naranja persistente de modo offline.
  void showOffline(
      {String message =
          'Sin conexión — los cambios se guardarán al reconectar'}) {
    _hideTimer?.cancel();
    _state = SyncState.offline;
    _message = message;
    _onRetry = null;
    notifyListeners();
  }

  /// Muestra barra azul mientras se suben fotos.
  /// [current] y [total] son opcionales para mostrar progreso (ej: "2/3").
  void showUploading({int? current, int? total}) {
    _hideTimer?.cancel();
    _state = SyncState.uploading;
    _message = (current != null && total != null)
        ? 'Subiendo fotos... ($current/$total)'
        : 'Subiendo fotos...';
    _onRetry = null;
    notifyListeners();
  }

  /// Muestra barra roja persistente de error con opción de reintentar.
  void showError({
    String message = 'Error al guardar — toca para reintentar',
    VoidCallback? onRetry,
  }) {
    _hideTimer?.cancel();
    _state = SyncState.error;
    _message = message;
    _onRetry = onRetry;
    notifyListeners();
  }

  /// Oculta la barra inmediatamente.
  void hide() {
    _hideTimer?.cancel();
    _state = SyncState.idle;
    _message = '';
    _onRetry = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

// ── SyncStatusBar ─────────────────────────────────────────────────────────────

class SyncStatusBar extends StatelessWidget {
  final SyncStatusController controller;

  const SyncStatusBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        if (controller.state == SyncState.idle) {
          return const SizedBox.shrink();
        }

        final config = _configFor(controller.state);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: config.color,
          child: Material(
            color: config.color,
            child: InkWell(
              onTap: controller.onRetry,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    // Spinner para uploading, icono fijo para el resto
                    if (controller.state == SyncState.uploading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    else
                      Icon(config.icon, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Icono de reintentar solo en error
                    if (controller.state == SyncState.error &&
                        controller.onRetry != null)
                      const Icon(Icons.refresh, size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _BarConfig _configFor(SyncState state) {
    switch (state) {
      case SyncState.saved:
        return _BarConfig(Colors.green.shade600, Icons.check_circle_outline);
      case SyncState.offline:
        return _BarConfig(Colors.orange.shade700, Icons.cloud_off_outlined);
      case SyncState.uploading:
        return const _BarConfig(Color(0xFF1A5DB5), Icons.cloud_upload_outlined);
      case SyncState.error:
        return _BarConfig(Colors.red.shade700, Icons.error_outline);
      case SyncState.idle:
        return const _BarConfig(Colors.transparent, Icons.circle);
    }
  }
}

class _BarConfig {
  final Color color;
  final IconData icon;
  const _BarConfig(this.color, this.icon);
}
