import 'dart:io';

Future<bool> openCustomerDisplayWindow({
  required String? executablePath,
  required List<String> arguments,
}) async {
  final path = executablePath;
  if (path == null || path.isEmpty) {
    return false;
  }

  try {
    final process = await Process.start(
      path,
      arguments,
      mode: ProcessStartMode.detached,
    );
    return process.pid > 0;
  } on ProcessException {
    return false;
  }
}
