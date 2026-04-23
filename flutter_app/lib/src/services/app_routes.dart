import 'dart:ui';

import 'app_runtime.dart';

class AppRoutes {
  static const customerDisplayFragment = 'customer-display';
  static const customerDisplayRoute = '/customer-display';

  static String get _defaultRouteName =>
      PlatformDispatcher.instance.defaultRouteName;

  static bool get isCustomerDisplayMode =>
      Uri.base.fragment == customerDisplayFragment ||
      _defaultRouteName == customerDisplayRoute ||
      runtimeArguments.contains(customerDisplayLaunchArgument);

  static const customerDisplayLaunchArgument = '--customer-display';

  static Uri customerDisplayUri() {
    return Uri.base.replace(fragment: customerDisplayFragment);
  }
}
