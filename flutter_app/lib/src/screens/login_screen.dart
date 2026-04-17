import 'package:flutter/material.dart';

import '../data/demo_pos_repository.dart';
import '../models/pos_user.dart';
import 'customer_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLoginSuccess,
  });

  final DemoPosRepository repository;
  final Future<void> Function(PosUser user) onLoginSuccess;

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

    final PosUser? user = await widget.repository.login(
      _usernameController.text.trim(),
      _pinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (user == null) {
      setState(() {
        _message = 'Login failed. Use admin / 1234.';
      });
      return;
    }

    await widget.onLoginSuccess(user);
  }

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Laundromat POS',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Flutter scaffold for the current Android demo flow.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'PIN'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message ?? 'Demo credentials: admin / 1234',
                      style: TextStyle(
                        color: _message == null
                            ? Colors.black54
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _login,
                      child: Text(_submitting ? 'Signing in...' : 'Login'),
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
                      child: const Text('Customer Profile & History'),
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
