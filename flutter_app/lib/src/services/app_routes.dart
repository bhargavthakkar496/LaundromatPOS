class AppRoutes {
  static const customerDisplayFragment = 'customer-display';

  static bool get isCustomerDisplayMode =>
      Uri.base.fragment == customerDisplayFragment;

  static Uri customerDisplayUri() {
    final base = Uri.base;
    return Uri.parse('${base.origin}${base.path}#$customerDisplayFragment');
  }
}
