import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/device_id.dart';
import '../services/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: '');
  final _password = TextEditingController(text: '');

  bool _busy = false;
  bool _showPassword = false;
  bool _rememberMe = false;
  String? _err;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _primeData();
  }

  Future<void> _primeData() async {
    final id = await ensureDeviceId();
    final refresh = await TokenStorage.readRefreshToken();
    if (mounted) {
      setState(() {
        _deviceId = id;
        _rememberMe = refresh != null && refresh.isNotEmpty;
      });
    }

    final token = await TokenStorage.read();
    final role = await TokenStorage.readRole();
    if (!mounted) return;
    if (token != null) {
      Navigator.pushReplacementNamed(
        context,
        (role ?? 'doctor').toLowerCase() == 'admin' ? '/admin' : '/home',
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _resolveErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      final rawMessage = data is Map && data['message'] is String
          ? (data['message'] as String).trim()
          : null;

      if (rawMessage != null && rawMessage.isNotEmpty) {
        final normalized = rawMessage.toLowerCase();
        switch (normalized) {
          case 'invalid_credentials':
          case 'invalid credentials':
            return 'Your email and password did not match an active account. If you recently changed devices or were deactivated, ask the administrator to reset or reactivate your login.';
          case 'device_not_registered':
            return 'This account is already paired with another device. Share the Device ID shown below with the administrator so they can release the previous device before you sign in here.';
          case 'device_required':
            return 'We need to confirm this device before you can sign in. Wait for the Device ID to finish generating and try again.';
        }
        return rawMessage;
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The server took too long to respond. Check your connection and try again.';
      }

      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }

      if (status != null) {
        return 'Login failed ($status).';
      }
    }
    return 'Login failed. Check your connection or credentials.';
  }

  Future<void> _submit() async {
    final form = _form.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _err = null;
    });

    final api = ApiClient();
    final deviceId = _deviceId ?? await ensureDeviceId();

    try {
      final user = await api.loginAndGetUser(
        _email.text.trim(),
        _password.text.trim(),
        deviceId,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      final role = (user['role'] as String? ?? 'doctor').toLowerCase();
      Navigator.pushReplacementNamed(
        context,
        role == 'admin' ? '/admin' : '/home',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _err = _resolveErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyDeviceId() async {
    final id = _deviceId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device ID copied to clipboard.')),
    );
  }

  void _showDeviceHelp() {
    final id = _deviceId ?? 'Generating a secure identifier...';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Device Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This unique ID links your account to the current device.'),
            const SizedBox(height: 8),
            Text(
              id,
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share it with the administrator only if they ask to approve your device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          if (_deviceId != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _copyDeviceId();
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy ID'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final accent = isLight ? scheme.primary : Colors.white;
    final subtitleColor = accent.withOpacity(isLight ? 0.7 : 0.75);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withOpacity(isLight ? 0.12 : 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Image.asset(
            'images/gameya.png',
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          arabicAppTitle,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          welcome,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final backgroundGradientColors = isLight
        ? [
            Color.alphaBlend(
              scheme.primary.withOpacity(0.04),
              theme.scaffoldBackgroundColor,
            ),
            theme.scaffoldBackgroundColor,
          ]
        : [
            Color.alphaBlend(
              scheme.primary.withOpacity(0.18),
              theme.scaffoldBackgroundColor,
            ),
            Color.alphaBlend(
              Colors.black.withOpacity(0.55),
              theme.scaffoldBackgroundColor,
            ),
            theme.scaffoldBackgroundColor,
          ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundGradientColors,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth.clamp(320.0, 540.0);
              return Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 32),
                        _GlassCard(
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sign in to continue',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Access your schedule, log attendance, and manage your day seamlessly.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _email,
                                  decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty ||
                                          !v.contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _password,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                          () => _showPassword = !_showPassword),
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                    ),
                                  ),
                                  obscureText: !_showPassword,
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Password must be at least 6 characters'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _err == null
                                      ? const SizedBox.shrink()
                                      : Container(
                                          key: ValueKey(_err),
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme.errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.error_outline,
                                                  color:
                                                      theme.colorScheme.error),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _err!,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onErrorContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 24),
                                _RememberMeToggle(
                                  value: _rememberMe,
                                  enabled: !_busy,
                                  onChanged: _busy
                                      ? null
                                      : (value) {
                                          setState(() => _rememberMe = value);
                                        },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Login'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Need help accessing your account? Contact the administrator.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.verified_user,
                                    color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Trusted device ID',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      _deviceId ??
                                          'Generating a secure identifier...',

                                      style: GoogleFonts.robotoMono(
                                          fontSize: 14,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (_deviceId != null)
                                          TextButton.icon(
                                            onPressed: _copyDeviceId,
                                            icon: const Icon(Icons.copy_all,
                                                size: 18),
                                            label: const Text('Copy'),
                                          ),
                                        TextButton.icon(
                                          onPressed: _showDeviceHelp,
                                          icon: const Icon(Icons.info_outline,
                                              size: 18),
                                          label: const Text('What is this?'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RememberMeToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _RememberMeToggle({
    required this.value,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOn = value;

    final gradient = isOn
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(0.92),
              scheme.primaryContainer.withOpacity(0.88),
            ],
          )
        : null;

    final fallbackSurface = scheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.55 : 0.35,
    );

    final borderColor = isOn
        ? scheme.primary.withOpacity(0.55)
        : scheme.outlineVariant.withOpacity(0.7);

    final titleColor = isOn
        ? scheme.onPrimary
        : theme.textTheme.titleSmall?.color ?? scheme.onSurface;

    final subtitleColor = isOn
        ? scheme.onPrimary.withOpacity(0.85)
        : (theme.textTheme.bodySmall?.color ?? scheme.onSurfaceVariant)
            .withOpacity(0.85);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(22),
        splashColor: scheme.primary.withOpacity(0.14),
        highlightColor: scheme.primary.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: gradient,
            color: isOn ? null : fallbackSurface,
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark ? 0.42 : 0.1,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  color: isOn ? scheme.onPrimary : scheme.surface,
                  border: Border.all(
                    color: isOn ? scheme.onPrimary : scheme.outline.withOpacity(0.55),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isOn ? Icons.check_rounded : Icons.today_outlined,
                  size: 20,
                  color: isOn ? scheme.primary : scheme.outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remember me',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOn
                          ? 'Stay signed in until you choose to log out.'
                          : 'Sign me out after today. Tick to stay signed in.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 44,
                height: 22,
                padding: const EdgeInsets.all(3),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: isOn
                      ? scheme.onPrimary.withOpacity(0.9)
                      : scheme.surfaceVariant.withOpacity(0.5),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassCard(
      {required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final surface = scheme.surface;
    final overlayColor = isLight
        ? Colors.white.withOpacity(0.92)
        : Color.alphaBlend(
            scheme.primary.withOpacity(0.1),
            surface,
          ).withOpacity(0.96);
    final borderColor = isLight
        ? Colors.white.withOpacity(0.35)
        : scheme.primary.withOpacity(0.25);
    final shadows = isLight
        ? const [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 12),
              blurRadius: 24,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              offset: const Offset(0, 18),
              blurRadius: 40,
            ),
          ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: overlayColor,
            border: Border.all(color: borderColor),
            boxShadow: shadows,
          ),
          child: child,
        ),
      ),
    );
  }
}








