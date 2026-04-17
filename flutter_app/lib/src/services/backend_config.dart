class BackendConfig {
  static const baseUrl = String.fromEnvironment(
    'POS_BACKEND_BASE_URL',
    defaultValue: '',
  );

  static const useBackend = bool.fromEnvironment(
    'POS_USE_BACKEND',
    defaultValue: false,
  );

  static bool get hasBackendBaseUrl => baseUrl.trim().isNotEmpty;
}
