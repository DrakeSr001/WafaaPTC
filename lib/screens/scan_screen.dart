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
              content: Text('Invalid QR. Please scan the kiosk code.')),
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Sending to server�';
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
      var message = 'Failed: invalid/expired code or network';
      if (e is DioException) {
        final data = e.response?.data;
        final status = e.response?.statusCode;
        final statusLabel = status != null ? ' ($status)' : '';
        if (data is Map &&
            data['message'] is String &&
            (data['message'] as String).isNotEmpty) {
          message = 'Failed$statusLabel: ${data['message']}';
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = 'Failed$statusLabel: ${e.message!}';
        } else if (status != null) {
          message = 'Failed ($status)';
        }
      }
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.72)
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Align the kiosk QR within the frame. We�ll submit it automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  if (_status != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _status!,
                        key: ValueKey(_status),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
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
