import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wafaaptc/config.dart';
import 'package:wafaaptc/screens/admin_screen.dart';
import 'package:wafaaptc/screens/home_screen.dart';
import 'package:wafaaptc/screens/login_screen.dart';
import 'package:wafaaptc/screens/month_history_screen.dart';
import 'package:wafaaptc/screens/scan_screen.dart';

void main() {
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1C4E80);
    const lightBackground = Color(0xFFF4F6FB);
    const darkBackground = Color(0xFF0B121C);

    ThemeData buildTheme(Brightness brightness) {
      final isLight = brightness == Brightness.light;
      final scaffoldBackground = isLight ? lightBackground : darkBackground;
      final baseScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );

      final scheme = baseScheme.copyWith(
        primary: isLight ? baseScheme.primary : const Color(0xFF5C9CFF),
        onPrimary: isLight ? baseScheme.onPrimary : const Color(0xFF041326),
        surface: isLight ? Colors.white : const Color(0xFF151F2D),
        onSurface: isLight ? const Color(0xFF172135) : const Color(0xFFE4EBF7),
        onSurfaceVariant:
            isLight ? const Color(0xFF4D5A72) : const Color(0xFFB8C4D7),
        outline:
            isLight ? const Color(0xFFD5DBE7) : const Color(0xFF2F3C50),
        secondaryContainer:
            isLight ? const Color(0xFFDCE7FF) : const Color(0xFF233146),
        onSecondaryContainer:
            isLight ? const Color(0xFF152947) : const Color(0xFFC9D5EA),
        surfaceTint: isLight ? Colors.white : const Color(0xFF151F2D),
      );

      final surface = scheme.surface;
      final mutedSurface = isLight
          ? Colors.white
          : Color.alphaBlend(Colors.white.withValues(alpha: 0.04), surface);
      final elevatedSurface = isLight
          ? Colors.white
          : Color.alphaBlend(Colors.white.withValues(alpha: 0.08), surface);

      final base = ThemeData(
        colorScheme: scheme,
        brightness: brightness,
        useMaterial3: true,
        scaffoldBackgroundColor: scaffoldBackground,
        canvasColor: surface,
        cardColor: mutedSurface,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: scheme.onSurface),
          systemOverlayStyle:
              isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isLight
              ? scheme.inverseSurface.withValues(alpha: 0.92)
              : elevatedSurface,
          actionTextColor: scheme.primary,
        ),
        cardTheme: CardThemeData(
          color: mutedSurface,
          surfaceTintColor: Colors.transparent,
          elevation: isLight ? 2 : 1,
          shadowColor: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: mutedSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: scheme.outline.withValues(alpha: isLight ? 0.35 : 0.5),
          space: 1,
          thickness: 1,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: scheme.onSurfaceVariant,
          textColor: scheme.onSurface,
          tileColor: mutedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isLight ? Colors.white : elevatedSurface,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: isLight ? 0.35 : 0.6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(width: 1.4, color: scheme.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.8)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: mutedSurface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: mutedSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.outline.withValues(alpha: isLight ? 0.4 : 0.6),
          ),
          checkColor: WidgetStateProperty.all(scheme.onPrimary),
        ),
      );

      final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

      return base.copyWith(
        textTheme: textTheme,
        snackBarTheme: base.snackBarTheme.copyWith(
          contentTextStyle: textTheme.bodyMedium?.copyWith(
            color: isLight ? scheme.onInverseSurface : scheme.onSurface,
          ),
        ),
      );
    }

    return MaterialApp(
      title: arabicAppTitle,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/scan': (_) => const ScanScreen(),
        '/history-month': (_) => const MonthHistoryScreen(),
        '/admin': (_) => const AdminScreen(),
      },
    );
  }
}
