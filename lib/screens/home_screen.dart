import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../config.dart';
import '../services/pending_scan.dart';
import '../services/token_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future.microtask(_handlePendingScan);
    }
  }

  Future<void> _handlePendingScan() async {
    final code = PendingScan.readFromUrl();
    if (code == null) return;
    await Future.delayed(const Duration(milliseconds: 250));
    final api = ApiClient();
    try {
      final res = await api.scanAttendance(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned: ${res['action']} at ${res['at']}')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          arabicAppTitle,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 500.0),
            child: Center(
              child: Opacity(
                opacity: 1,
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tap the button to scan the kiosk QR.',
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/scan'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/history-month'),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('History by Month'),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
