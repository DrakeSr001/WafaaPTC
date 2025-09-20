import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../config.dart';
import '../services/pending_scan.dart';
import '../services/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _scanErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      if (data is Map && data['message'] is String) {
        final raw = (data['message'] as String).trim();
        switch (raw) {
          case 'daily_limit_reached':
            return 'Scan blocked: already checked out today.';
          case 'invalid':
          case 'expired':
            return 'Scan failed: invalid or expired code.';
          default:
            final code = status?.toString() ?? 'error';
            return 'Scan failed (' + code + '): ' + raw;
        }
      }
    }
    return 'Scan failed (expired or invalid code).';
  }

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: ''); // for dev
  final _password = TextEditingController(text: ''); // for dev
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    () async {
      final t = await TokenStorage.read();
      final role = await TokenStorage.readRole();
      if (mounted && t != null) {
        Navigator.pushReplacementNamed(
          context,
          (role ?? 'doctor').toLowerCase() == 'admin' ? '/admin' : '/home',
        );
      }
    }();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final api = ApiClient();
    try {
      final user = await api.loginAndGetUser(
        _email.text.trim(),
        _password.text.trim(),
      );
      if (!mounted) return;
      final role = (user['role'] as String? ?? 'doctor').toLowerCase();
      Navigator.pushReplacementNamed(
          context, role == 'admin' ? '/admin' : '/home');

      if (kIsWeb) {
        final code = PendingScan.readFromUrl();
        if (code != null) {
          await Future.delayed(const Duration(milliseconds: 250));
          try {
            final res = await api.scanAttendance(code);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Scanned: ${res['action']} at ${res['at']}')),
              );
            }
          } catch (err) {
            if (mounted) {
              final msg = _scanErrorMessage(err);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            }
          }
        }
      }
    } catch (_) {
      setState(() => _err = 'Login failed. Check email/password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          arabicAppTitle,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 500.0),
            child: Center(
              child: Opacity(
                opacity: 1, // Change to 0.4 if you want semi-transparent
                child: SizedBox(
                  width: 300,
                  child: Image.asset(
                    "images/gameya.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_err != null) ...[
                        Text(_err!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const CircularProgressIndicator()
                              : const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

