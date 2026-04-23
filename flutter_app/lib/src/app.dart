import 'package:flutter/material.dart';

import 'data/pos_repository.dart';
import 'localization/app_localizations.dart';
import 'models/auth_session.dart';
import 'screens/customer_self_service_screen.dart';
import 'screens/login_screen.dart';
import 'screens/machine_list_screen.dart';
import 'services/app_routes.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';

class WashPosApp extends StatefulWidget {
  const WashPosApp({
    super.key,
    required this.repository,
    required this.sessionStore,
    required this.currentSession,
  });

  final PosRepository repository;
  final SessionStore sessionStore;
  final AuthSession? currentSession;

  @override
  State<WashPosApp> createState() => _WashPosAppState();
}

class _WashPosAppState extends State<WashPosApp> {
  late AuthSession? _currentSession;
  bool _shouldAutoOpenCustomerScreen = false;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _currentSession = widget.currentSession;
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final localeCode = await widget.sessionStore.loadLocaleCode();
    if (!mounted || localeCode == null || localeCode.isEmpty) {
      return;
    }
    setState(() {
      _locale = Locale(localeCode);
    });
  }

  Future<void> _handleLogin(AuthSession session) async {
    await widget.sessionStore.saveSession(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentSession = session;
      _shouldAutoOpenCustomerScreen = true;
    });
  }

  Future<void> _handleLogout() async {
    await widget.sessionStore.clearSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentSession = null;
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

  Future<void> _handleLocaleChanged(Locale locale) async {
    await widget.sessionStore.saveLocaleCode(locale.languageCode);
    if (!mounted) {
      return;
    }
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AppRoutes.isCustomerDisplayMode
          ? CustomerSelfServiceScreen(repository: widget.repository)
          : _currentSession == null
              ? LoginScreen(
                  repository: widget.repository,
                  onLoginSuccess: _handleLogin,
                  currentLocale: _locale,
                  onLocaleChanged: _handleLocaleChanged,
                )
              : MachineListScreen(
                  repository: widget.repository,
                  user: _currentSession!.user,
                  onLogout: _handleLogout,
                  currentLocale: _locale,
                  onLocaleChanged: _handleLocaleChanged,
                  shouldAutoOpenCustomerScreen: _shouldAutoOpenCustomerScreen,
                  onCustomerScreenAutoOpened: _handleCustomerScreenAutoOpened,
                ),
    );
  }
}
