import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;

Future<Uint8List> _fetchBytes(String url) async {
  final completer = Completer<Uint8List>();
  final xhr = web.XMLHttpRequest();
  xhr.responseType = 'arraybuffer';
  xhr.open('GET', url, true);
  xhr.addEventListener(
    'load',
    (web.Event _) {
      try {
        final buf = xhr.response! as JSArrayBuffer;
        completer.complete(buf.toDart.asUint8List());
      } catch (e) {
        completer.completeError(e);
      }
    }.toJS,
  );
  xhr.addEventListener(
    'error',
    (web.Event _) {
      completer.completeError('Error fetching $url');
    }.toJS,
  );
  xhr.send();
  return completer.future;
}

Future<void> downloadAllPhotos(List<String> urls, String fileName) async {
  final archive = Archive();
  for (var i = 0; i < urls.length; i++) {
    try {
      final bytes = await _fetchBytes(urls[i]);
      final name = 'foto_${(i + 1).toString().padLeft(3, '0')}.jpg';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    } catch (_) {
      // Omite fotos que no se pueden descargar
    }
  }
  final zipBytes = ZipEncoder().encode(archive) ?? [];
  final uint8 = Uint8List.fromList(zipBytes);
  final blob = web.Blob(
    [uint8.toJS as web.BlobPart].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..setAttribute('download', fileName)
    ..click();
  web.URL.revokeObjectURL(url);
}
