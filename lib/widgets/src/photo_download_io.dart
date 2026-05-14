import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> saveToGallery(String url) async {
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

    await Gal.putImage(path, album: 'Mantenciones');
    return true;
  } catch (_) {
    return false;
  }
}
