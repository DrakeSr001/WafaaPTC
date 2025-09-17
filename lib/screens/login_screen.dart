import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: ''); // for dev
  final _password = TextEditingController(text: '');    // for dev
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    // if token exists, go to home
    TokenStorage.read().then((t) {
      if (t != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      final api = ApiClient();
      await api.login(_email.text.trim(), _password.text.trim());
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _err = 'Login failed. Check email/password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('مركز العلاج الطبيعي - الوفاء و الأمل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), )),
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
                        validator: (v) => (v==null || v.isEmpty) ? 'Enter email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (v) => (v==null || v.length<6) ? 'Min 6 chars' : null,
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
                          child: _busy ? const CircularProgressIndicator() : const Text('Login'),
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
