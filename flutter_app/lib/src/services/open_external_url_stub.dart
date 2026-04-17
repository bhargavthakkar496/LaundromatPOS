import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}
