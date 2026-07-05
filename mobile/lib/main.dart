import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api.dart';
import 'senegal_data.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/terms_screen.dart';

// Palette Gologui — tirée du logo (singe orange sur vert sapin)
const gologuiTeal = Color(0xFF0B4F47);
const gologuiTealLight = Color(0xFF35B79E); // accent en mode sombre
const gologuiOrange = Color(0xFFF49D37);
const gologuiCream = Color(0xFFF7ECD4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await Senegal.load();
  await Api.init();
  runApp(const GologuiApp());
}

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: gologuiTeal,
    brightness: brightness,
    primary: dark ? gologuiTealLight : gologuiTeal,
    secondary: gologuiOrange,
    surface: dark ? const Color(0xFF161A19) : Colors.white,
  );
  final borderColor = dark ? const Color(0xFF2A2F2D) : const Color(0xFFE9E9E4);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1110) : const Color(0xFFFAFAF7),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0E1110) : const Color(0xFFFAFAF7),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: dark ? const Color(0xFF06211D) : Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: borderColor),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      filled: true,
      fillColor: scheme.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      elevation: 0,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(color: borderColor),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    ),
  );
}

class GologuiApp extends StatelessWidget {
  const GologuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gologui',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system, // s'adapte au réglage du téléphone
      home: !Api.isLoggedIn
          ? const LoginScreen()
          : (((Api.currentUser?['firstName'] as String?)?.isNotEmpty ?? false)
              ? (Api.currentUser?['acceptedTermsAt'] != null
                  ? const HomeScreen()
                  : const TermsScreen())
              : const CompleteProfileScreen()),
    );
  }
}
