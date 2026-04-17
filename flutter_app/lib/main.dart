import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/demo_pos_repository.dart';
import 'src/services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = DemoPosRepository();
  await repository.initialize();
  final sessionStore = SessionStore();
  final currentUser = await sessionStore.loadSession();
  runApp(
    LaundromatPosApp(
      repository: repository,
      sessionStore: sessionStore,
      currentUser: currentUser,
    ),
  );
}
