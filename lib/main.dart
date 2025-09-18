import 'package:flutter/material.dart';
import 'package:wafaaptc/screens/scan_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/month_history_screen.dart';
import 'screens/admin_screen.dart';

void main() {
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مركز العلاج الطبيعي - فرع الوفاء و الأمل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home' : (_) => const HomeScreen(),
        '/scan' : (_) => const ScanScreen(),
        '/history-month': (_) => const MonthHistoryScreen(), // ⬅️ add this
        '/admin': (_) => const AdminScreen(), // ⬅️ admin landing
      },
    );
  }
}
