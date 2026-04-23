import 'app_runtime_stub.dart'
    if (dart.library.io) 'app_runtime_io.dart' as impl;

List<String> get runtimeArguments => impl.runtimeArguments;

String? get currentExecutablePath => impl.currentExecutablePath;
