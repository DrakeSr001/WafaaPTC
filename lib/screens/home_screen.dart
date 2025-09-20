import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/pending_scan.dart';
import '../services/token_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan failed (expired or invalid code).')),
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
          'U.Oï¿½Uï¿½Oï¿½ O\u0015U,O1U,O\u0015Oï¿½ O\u0015U,Oï¿½O"USO1US - O\u0015U,U^U?O\u0015Oï¿½ U^ O\u0015U,Oï¿½U.U,',
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
                    label: const Text('Scan Kiosk'),
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
