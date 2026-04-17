import 'package:web/web.dart' as web;

Future<bool> openExternalUrl(Uri url) async {
  web.window.open(url.toString(), '_blank');
  return true;
}
