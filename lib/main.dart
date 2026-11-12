import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/onboarding_page.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'screens/settings_page.dart';
import 'screens/edit_profile_page.dart';
import 'package:flutter/services.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DigitalClosetApp());
}

class DigitalClosetApp extends StatelessWidget {
  const DigitalClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wardrobe AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: forestInk,
          secondary: softSage,
          surface: linen,
          onPrimary: linen,
          onSecondary: forestInk,
          onSurface: forestInk,
          surfaceContainerHighest: linen,
          onSurfaceVariant: forestInk,
        ),
        scaffoldBackgroundColor: linen,
        appBarTheme: AppBarTheme(
          backgroundColor: linen,
          foregroundColor: forestInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          toolbarHeight: kToolbarHeight,
          titleTextStyle: TextStyle(
            color: forestInk,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: linen,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: forestInk,
            foregroundColor: linen,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: forestInk,
            side: BorderSide(color: softSage, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: forestInk,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: linen,
          hintStyle: TextStyle(color: forestInk.withValues(alpha: 0.4)),
          labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.7)),
          prefixIconColor: softSage,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: forestInk, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade700, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
        cardTheme: CardThemeData(
          color: linen,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: softSage.withValues(alpha: 0.2)),
          ),
          shadowColor: forestInk.withValues(alpha: 0.05),
        ),
        dividerTheme: DividerThemeData(
          color: softSage.withValues(alpha: 0.3),
          thickness: 1,
        ),
        fontFamily: 'Montserrat',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // ✅ Set onboarding as initial route
      home: const _AuthGate(),

      // ✅ Define named routes
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/landing': (context) => const LandingPage(),
        '/home':
            (context) => StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasData && snapshot.data != null) {
                  return const HomePage();
                } else {
                  return const LoginPage();
                }
              },
            ),
        '/settings': (context) => const SettingsPage(),
        '/edit-profile': (context) => const EditProfilePage(),
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<bool> _shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    return rememberMe && FirebaseAuth.instance.currentUser != null;
  }

  Future<bool> _shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_complete') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowOnboarding(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: linen,
            body: Center(
              child: CircularProgressIndicator(
                color: forestInk,
              ),
            ),
          );
        }

        final showOnboarding = snapshot.data ?? true;

        if (showOnboarding) {
          return const OnboardingPage();
        }

        return FutureBuilder<bool>(
          future: _shouldAutoLogin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: linen,
                body: Center(
                  child: CircularProgressIndicator(
                    color: forestInk,
                  ),
                ),
              );
            }
            if (snapshot.data == true) {
              return const HomePage();
            }
            return const LandingPage();
          },
        );
      },
    );
  }
}
