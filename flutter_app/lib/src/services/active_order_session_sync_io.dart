import 'dart:io';

const _appDirectoryName = 'washpos_flutter';
const _activeOrderSessionFileName = 'active_order_session_v1.json';

Future<String?> readActiveOrderSessionRaw() async {
  final file = await _activeOrderSessionFile();
  if (file == null || !await file.exists()) {
    return null;
  }

  try {
    final raw = await file.readAsString();
    final normalized = raw.trim();
    return normalized.isEmpty ? null : normalized;
  } on FileSystemException {
    return null;
  }
}

Future<void> writeActiveOrderSessionRaw(String raw) async {
  final file = await _activeOrderSessionFile();
  if (file == null) {
    return;
  }

  try {
    await file.parent.create(recursive: true);
    await file.writeAsString(raw, flush: true);
  } on FileSystemException {
    // Ignore cross-process sync failures and keep in-app persistence working.
  }
}

Future<void> clearActiveOrderSessionRaw() async {
  final file = await _activeOrderSessionFile();
  if (file == null || !await file.exists()) {
    return;
  }

  try {
    await file.delete();
  } on FileSystemException {
    // Ignore cleanup failures and let the preference-backed fallback continue.
  }
}

Future<File?> _activeOrderSessionFile() async {
  final baseDirectory = _baseDirectoryPath();
  if (baseDirectory == null || baseDirectory.isEmpty) {
    return null;
  }

  final directory = Directory(
    '$baseDirectory${Platform.pathSeparator}$_appDirectoryName',
  );
  return File(
    '${directory.path}${Platform.pathSeparator}$_activeOrderSessionFileName',
  );
}

String? _baseDirectoryPath() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.trim().isNotEmpty) {
    return localAppData;
  }

  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.trim().isNotEmpty) {
    return appData;
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    return '$userProfile${Platform.pathSeparator}AppData${Platform.pathSeparator}Local';
  }

  return null;
}
