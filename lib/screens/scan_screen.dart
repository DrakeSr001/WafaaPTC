import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_client.dart';
import '../utils/attendance_dialog.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _busy = false;
  String? _status;

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Session expired. Please sign in again and rescan.';
      }
      if (data is Map && data['message'] is String) {
        final raw = (data['message'] as String).trim();
        switch (raw) {
          case 'daily_limit_reached':
            return 'Scan blocked: already checked out today.';
          case 'min_session_time':
            return 'Scan blocked: please wait 10 minutes between check-in and check-out.';
          case 'invalid':
          case 'expired':
            return 'Scan failed: invalid or expired code.';
          default:
            final code = status != null ? ' ($status)' : '';
            return 'Scan failed$code: $raw';
        }
      }
      if (status != null) {
        return 'Scan failed ($status).';
      }
    }
    return 'Scan failed: invalid/expired code or network.';
  }

  String? _extractCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (!trimmed.contains('://') && !trimmed.contains('?')) {
      return trimmed.length >= 10 ? trimmed : null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final queryCode = uri.queryParameters['code'];
      if (queryCode != null && queryCode.trim().length >= 10) {
        return queryCode.trim();
      }

      if (uri.fragment.isNotEmpty) {
        final frag = uri.fragment;
        final qIndex = frag.indexOf('?');
        if (qIndex != -1) {
          try {
            final fragParams = Uri.splitQueryString(frag.substring(qIndex + 1));
            final fragCode = fragParams['code'];
            if (fragCode != null && fragCode.trim().length >= 10) {
              return fragCode.trim();
            }
          } catch (_) {
            // ignore malformed fragments
          }
        }
      }
    }

    if (trimmed.startsWith('?')) {
      try {
        final params = Uri.splitQueryString(trimmed.substring(1));
        final queryCode = params['code'];
        if (queryCode != null && queryCode.trim().length >= 10) {
          return queryCode.trim();
        }
      } catch (_) {
        // ignore
      }
    }

    return null;
  }

  Future<void> _handleCode(String raw) async {
    if (_busy) return;
    final code = _extractCode(raw);
    if (code == null) {
      setState(() => _status = 'Invalid QR. Try again.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR. Please scan the kiosk code.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Sending to server...';
    });

    try {
      final api = ApiClient();
      final res = await api.scanAttendance(code);
      if (!mounted) return;
      setState(() => _status = 'Success: ${res['action']} at ${res['at']}');
      await showAttendanceDialog(
        context,
        actionLabel: res['action'] as String? ?? 'Recorded',
        happenedAtIso: res['at'] as String?,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      final message = _errorMessage(e);
      if (mounted) {
        setState(() => _status = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom > 0
        ? media.viewPadding.bottom
        : media.padding.bottom;
    final bottomSafePadding = bottomInset + 32;
    final width = media.size.width;
    final instructionScale = width < 360
        ? 0.9
        : width > 720
            ? 1.1
            : 1.0;
    final instructionsStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white70,
      fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * instructionScale,
      height: 1.35,
    );
    final statusStyle = theme.textTheme.titleSmall?.copyWith(
      color: Colors.white,
      fontSize: (theme.textTheme.titleSmall?.fontSize ?? 16) * instructionScale,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance QR'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue;
              if (raw != null) _handleCode(raw);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafePadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Align the kiosk QR within the frame. We'll submit it automatically.",
                    textAlign: TextAlign.center,
                    style: instructionsStyle,
                  ),
                  const SizedBox(height: 12),
                  if (_status != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _status!,
                        key: ValueKey(_status),
                        textAlign: TextAlign.center,
                        style: statusStyle,
                      ),
                    ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


