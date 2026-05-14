import 'package:web/web.dart' as web;

Future<bool> saveToGallery(String url) async {
  try {
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..setAttribute('download', 'foto.jpg')
      ..click();
    return true;
  } catch (_) {
    return false;
  }
}
