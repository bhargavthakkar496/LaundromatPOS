import 'package:flutter/material.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/auth_session.dart';
import 'customer_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLoginSuccess,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  final PosRepository repository;
  final Future<void> Function(AuthSession session) onLoginSuccess;
  final Locale currentLocale;
  final Future<void> Function(Locale locale) onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _pinController = TextEditingController(text: '1234');
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _submitting = true;
      _message = null;
    });

    final AuthSession? session = await widget.repository.login(
      _usernameController.text.trim(),
      _pinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (session == null) {
      setState(() {
        _message = context.l10n.loginFailed;
      });
      return;
    }

    await widget.onLoginSuccess(session);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: l10n.language,
                          onSelected: (value) =>
                              widget.onLocaleChanged(Locale(value)),
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'en',
                              child: Text(l10n.english),
                            ),
                            PopupMenuItem<String>(
                              value: 'ar',
                              child: Text(l10n.arabic),
                            ),
                            PopupMenuItem<String>(
                              value: 'th',
                              child: Text(l10n.thai),
                            ),
                            PopupMenuItem<String>(
                              value: 'hi',
                              child: Text(l10n.hindi),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language_outlined, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.languageName(
                                    widget.currentLocale.languageCode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loginSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: l10n.username),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.pin),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message ?? l10n.loginHint,
                      style: TextStyle(
                        color: _message == null
                            ? Colors.black54
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _login,
                      child: Text(_submitting ? l10n.signingIn : l10n.login),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerProfileScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                            },
                      child: Text(l10n.customerProfileHistory),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
