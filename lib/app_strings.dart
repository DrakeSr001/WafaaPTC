
// Place this file at: lib/app_strings.dart
// Centralized, Unicode-safe Arabic strings for your Flutter app.
// Use these constants instead of hard-coded text in widgets.

class AppStrings {
  // App titles
  static const String arabicAppTitle =
      '\u0645\u0631\u0643\u0632\u0020\u0627\u0644\u0639\u0644\u0627\u062C\u0020\u0627\u0644\u0637\u0628\u064A\u0639\u064A\u0020\u002D\u0020\u0641\u0631\u0639\u0020\u0627\u0644\u0648\u0641\u0627\u0621\u0020\u0648\u0627\u0644\u0623\u0645\u0644';

  static const String welcome =
      '\u0645\u0631\u062D\u0628\u0627\u0020\u0628\u0643\u0645'; // مرحبا بكم

  // Common buttons
  static const String login = '\u062A\u0633\u062C\u064A\u0644\u0020\u0627\u0644\u062F\u062E\u0648\u0644'; // تسجيل الدخول
  static const String logout = '\u062A\u0633\u062C\u064A\u0644\u0020\u0627\u0644\u062E\u0631\u0648\u062C'; // تسجيل الخروج
  static const String scanQr = '\u0645\u0633\u062D\u0020\u0631\u0645\u0632\u0020\u0627\u0644\u0020\u0627\u0633\u062A\u062C\u0627\u0628\u0629'; // مسح رمز الاستجابة

  // Errors
  static const String networkError = '\u062D\u062F\u062B\u062A\u0020\u0645\u0634\u0643\u0644\u0629\u0020\u0641\u064A\u0020\u0627\u0644\u0634\u0628\u0643\u0629'; // حدثت مشكلة في الشبكة
  static const String unknownError = '\u062D\u062F\u062B\u062E\u0637\u0623\u0020\u063A\u064A\u0631\u0020\u0645\u0639\u0631\u0648\u0641'; // حدث خطأ غير معروف

  // Helper: numbers/dates could be added as needed
}

// Example usage in a widget:
// import 'package:google_fonts/google_fonts.dart';
// import 'app_strings.dart';
//
// Text(
//   AppStrings.welcome,
//   textAlign: TextAlign.center,
//   textDirection: TextDirection.rtl,
//   style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w500),
// );
