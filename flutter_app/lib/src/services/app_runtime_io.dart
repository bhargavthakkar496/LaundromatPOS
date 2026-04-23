import 'dart:io';

List<String> get runtimeArguments => Platform.executableArguments;

String? get currentExecutablePath => Platform.resolvedExecutable;
