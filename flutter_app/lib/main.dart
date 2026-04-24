import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/backend_pos_repository.dart';
import 'src/data/demo_pos_repository.dart';
import 'src/data/pos_repository.dart';
import 'src/services/backend_api_client.dart';
import 'src/services/backend_config.dart';
import 'src/services/app_runtime.dart';
import 'src/services/session_store.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  configureRuntimeArguments(args);
  final sessionStore = SessionStore();
  final PosRepository repository =
      BackendConfig.useBackend && BackendConfig.hasBackendBaseUrl
          ? BackendPosRepository(
              apiClient: BackendApiClient(
                baseUrl: BackendConfig.baseUrl,
                sessionStore: sessionStore,
              ),
            )
          : DemoPosRepository();
  await repository.initialize();
  final currentSession = await sessionStore.loadSession();
  runApp(
    WashPosApp(
      repository: repository,
      sessionStore: sessionStore,
      currentSession: currentSession,
    ),
  );
}
