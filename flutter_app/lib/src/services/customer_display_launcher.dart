import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_routes.dart';
import 'app_runtime.dart';
import 'open_external_url.dart';

import 'customer_display_launcher_stub.dart'
    if (dart.library.io) 'customer_display_launcher_io.dart' as launcher_impl;

class CustomerDisplayLauncher {
  static const MethodChannel _channel =
      MethodChannel('washpos/customer_display');

  static Future<bool> open() async {
    if (kIsWeb) {
      return openExternalUrl(AppRoutes.customerDisplayUri());
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        try {
          final launched =
              await _channel.invokeMethod<bool>('openCustomerDisplay');
          return launched ?? false;
        } on PlatformException {
          return false;
        } on MissingPluginException {
          return false;
        }
      default:
        return launcher_impl.openCustomerDisplayWindow(
          executablePath: currentExecutablePath,
          arguments: const <String>[AppRoutes.customerDisplayLaunchArgument],
        );
    }
  }
}
