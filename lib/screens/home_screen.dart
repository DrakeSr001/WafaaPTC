import 'package:flutter/material.dart';
import '../services/token_storage.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await TokenStorage.clear();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مركز العلاج الطبيعي - الوفاء و الأمل',
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
                  width: 300, // Adjust width as needed
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
                    onPressed: () => _logout(context),
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
