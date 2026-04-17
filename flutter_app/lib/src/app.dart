import 'package:flutter/material.dart';

import 'data/demo_pos_repository.dart';
import 'models/pos_user.dart';
import 'screens/customer_self_service_screen.dart';
import 'screens/login_screen.dart';
import 'screens/machine_list_screen.dart';
import 'services/app_routes.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';

class LaundromatPosApp extends StatefulWidget {
  const LaundromatPosApp({
    super.key,
    required this.repository,
    required this.sessionStore,
    required this.currentUser,
  });

  final DemoPosRepository repository;
  final SessionStore sessionStore;
  final PosUser? currentUser;

  @override
  State<LaundromatPosApp> createState() => _LaundromatPosAppState();
}

class _LaundromatPosAppState extends State<LaundromatPosApp> {
  late PosUser? _currentUser;
  bool _shouldAutoOpenCustomerScreen = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
  }

  Future<void> _handleLogin(PosUser user) async {
    await widget.sessionStore.saveSession(user);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = user;
      _shouldAutoOpenCustomerScreen = true;
    });
  }

  Future<void> _handleLogout() async {
    await widget.sessionStore.clearSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUser = null;
      _shouldAutoOpenCustomerScreen = false;
    });
  }

  void _handleCustomerScreenAutoOpened() {
    if (!_shouldAutoOpenCustomerScreen) {
      return;
    }
    setState(() {
      _shouldAutoOpenCustomerScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundromat POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AppRoutes.isCustomerDisplayMode
          ? CustomerSelfServiceScreen(repository: widget.repository)
          : _currentUser == null
              ? LoginScreen(
                  repository: widget.repository,
                  onLoginSuccess: _handleLogin,
                )
              : MachineListScreen(
                  repository: widget.repository,
                  user: _currentUser!,
                  onLogout: _handleLogout,
                  shouldAutoOpenCustomerScreen: _shouldAutoOpenCustomerScreen,
                  onCustomerScreenAutoOpened: _handleCustomerScreenAutoOpened,
                ),
    );
  }
}
