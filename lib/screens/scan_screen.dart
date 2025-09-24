import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_client.dart';

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
    // ignore: avoid_print
    print('scan raw: $raw');
    // ignore: avoid_print
    print('scan normalized code: ${code ?? 'null'}');
    if (code == null) {
      setState(() => _status = 'Invalid QR. Try again.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR. Please scan the kiosk code.')),
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Submitting...';
    });

    try {
      final api = ApiClient();
      final res = await api.scanAttendance(code);
      if (!mounted) return;
      setState(() => _status = 'Success: ${res['action']} at ${res['at']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorded ${res['action']}')),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      var message = 'Failed: invalid/expired code or network';
      if (e is DioException) {
        final data = e.response?.data;
        final status = e.response?.statusCode;
        final statusLabel = status != null ? ' ($status)' : '';
        if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
          message = 'Failed$statusLabel: ${data['message']}';
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = 'Failed$statusLabel: ${e.message!}';
        } else if (status != null) {
          message = 'Failed ($status)';
        }
        // ignore: avoid_print
        print('scanAttendance dio error: status=${e.response?.statusCode?.toString() ?? '-'} data=${e.response?.data?.toString() ?? '-'}');
      } else {
        // ignore: avoid_print
        print('scanAttendance unexpected error: $e');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Kiosk QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final b = capture.barcodes.firstOrNull;
              final raw = b?.rawValue;
              if (raw != null) _handleCode(raw);
            },
          ),
          if (_busy || _status != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: Text(
                  _status ?? '',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
