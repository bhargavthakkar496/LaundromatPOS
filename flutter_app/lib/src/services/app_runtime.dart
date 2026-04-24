import 'app_runtime_stub.dart'
    if (dart.library.io) 'app_runtime_io.dart' as impl;

List<String> _runtimeArguments = const <String>[];

void configureRuntimeArguments(List<String> arguments) {
  _runtimeArguments = List<String>.unmodifiable(arguments);
}

List<String> get runtimeArguments => _runtimeArguments;

String? get currentExecutablePath => impl.currentExecutablePath;
