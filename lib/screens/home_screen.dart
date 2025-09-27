import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/device_id.dart';
import '../services/pending_scan.dart';
import '../services/token_storage.dart';
import '../utils/attendance_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _deviceId;
  bool _loadingDevice = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    if (kIsWeb) {
      Future.microtask(_handlePendingScan);
    }
  }

  Future<void> _loadDeviceId() async {
    final id = await ensureDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = id;
        _loadingDevice = false;
      });
    }
  }

  String _scanErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      if (data is Map && data['message'] is String) {
        final raw = (data['message'] as String).trim();
        switch (raw) {
          case 'daily_limit_reached':
            return 'Attendance already captured today.';
          case 'invalid':
          case 'expired':
            return 'Invalid or expired QR code.';
          default:
            final code = status?.toString() ?? 'error';
            return 'Scan failed ($code): $raw';
        }
      }
    }
    return 'Scan failed. Please try again.';
  }

  Future<void> _handlePendingScan() async {
    final code = PendingScan.readFromUrl();
    if (code == null) return;
    await Future.delayed(const Duration(milliseconds: 250));
    final api = ApiClient();
    try {
      final res = await api.scanAttendance(code);
      if (!mounted) return;
      await showAttendanceDialog(
        context,
        actionLabel: res['action'] as String? ?? 'Recorded',
        happenedAtIso: res['at'] as String?,
      );
    } catch (err) {
      if (!mounted) return;
      final msg = _scanErrorMessage(err);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final surfaceGradientColors = isLight
        ? const [Color(0xFFE9F1FF), Color(0xFFF9FBFF)]
        : [
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.16), scheme.surface),
            theme.scaffoldBackgroundColor,
          ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: theme.textTheme.labelLarge,
            ),
            Text(
              arabicAppTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: surfaceGradientColors,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            children: [
              _HeroBanner(deviceId: _deviceId),
              const SizedBox(height: 24),
              Text(
                'Quick actions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _QuickActionCard(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan & Record',
                    subtitle: 'Scan QR code to Log IN or OUT.',
                    color: theme.colorScheme.primary,
                    onTap: () => Navigator.pushNamed(context, '/scan'),
                  ),
                  _QuickActionCard(
                    icon: Icons.calendar_month,
                    title: 'Attendance history',
                    subtitle: 'Browse your monthly entries and exports.',
                    color: theme.colorScheme.secondary,
                    onTap: () => Navigator.pushNamed(context, '/history-month'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _DeviceIdPanel(
                deviceId: _deviceId,
                loading: _loadingDevice,
                onCopy: () async {
                  final id = _deviceId;
                  if (id == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: id));
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Device ID copied.')),
                  );
                },
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: isLight ? 0.08 : 0.24),
                  ),
                  boxShadow: isLight
                      ? const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tips_and_updates,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Pro tip: keep your device ID private. If you change phones, ask an admin to grant access for the new device.',
                        style: theme.textTheme.bodyMedium,
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
  }
}

class _HeroBanner extends StatelessWidget {
  final String? deviceId;
  const _HeroBanner({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    // Keep your gradients
    final gradientColors = isLight
        ? [scheme.primary, scheme.primaryContainer]
        : [
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.20), scheme.surface),
            Color.alphaBlend(scheme.primaryContainer.withValues(alpha: 0.12), scheme.surface),
          ];

    // ✅ Choose text color based on the banner's perceived brightness
    // (in dark mode, use onSurface; in light mode, keep onPrimary for strong contrast)
    final bannerBgProbe = gradientColors.last;
    final bgBrightness = ThemeData.estimateBrightnessForColor(bannerBgProbe);
    final Color textColor = (bgBrightness == Brightness.dark)
        ? scheme.onSurface  // light text for dark bg (Material sets this to near-white in dark theme)
        : scheme.onPrimary; // dark text for light primary bg

    final id = deviceId;
    final idPrefix = id?.substring(0, id.length >= 8 ? 8 : id.length);
    final deviceSnippet = idPrefix == null
        ? 'Preparing your verified device ID...'
        : 'Device linked - $idPrefix...';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isLight ? Colors.black26 : Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 420;

          final heroText = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today is ${DateFormat('EEEE, MMM d').format(DateTime.now())}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log your attendance with confidence.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                deviceSnippet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.90),
                ),
              ),
            ],
          );

          final logoCard = Container(
            decoration: BoxDecoration(
              // Slight translucent overlay that adapts to textColor choice
              color: textColor.withValues(alpha: isLight ? 0.18 : 0.20),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: EdgeInsets.all(isWide ? 18 : 12),
            child: Image.asset(
              'images/gameya.png',
              height: isWide ? 96 : 72,
              fit: BoxFit.contain,
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heroText),
                const SizedBox(width: 24),
                logoCard,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.centerRight, child: logoCard),
              const SizedBox(height: 16),
              heroText,
            ],
          );
        },
      ),
    );
  }
}


class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final surface = scheme.surface;
    final shadowColor =
        isLight ? color.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.6);
    final highlight = color.withValues(alpha: isLight ? 0.16 : 0.22);
    final cardElevation = isLight ? 6.0 : 2.0;
    final isWide = MediaQuery.of(context).size.width > 720;

    return SizedBox(
      width: isWide ? 300 : double.infinity,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        elevation: cardElevation,
        shadowColor: shadowColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: highlight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceIdPanel extends StatelessWidget {
  final String? deviceId;
  final bool loading;
  final Future<void> Function() onCopy;

  const _DeviceIdPanel({
    required this.deviceId,
    required this.loading,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final surface = theme.cardColor;
    final borderColor = scheme.outline.withValues(alpha: isLight ? 0.08 : 0.24);
    final shadow = isLight
        ? const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: shadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your trusted device',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (loading)
                  Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Generating a secure identifier...'),
                    ],
                  )
                else
                  SelectableText(
                    deviceId ?? '-',
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Keep this ID private. Admins can clear it when you upgrade your device.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: loading || deviceId == null ? null : onCopy,
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy ID'),
                    ),
                    TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Need to change phones?'),
                          content: const Text(
                            'Ask an admin to release this ID. They can then approve your new device instantly.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('View instructions'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}












