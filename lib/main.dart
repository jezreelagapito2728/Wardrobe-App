import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'screens/settings_page.dart';
import 'screens/edit_profile_page.dart';
import 'package:flutter/services.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Color(0xFFD09D64),
          secondary: Color(0xFF6E5A3F),
          background: Color(0xFFF4EAE0),
        ),
        scaffoldBackgroundColor: Color(0xFFF4EAE0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4F2D20),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,            // stops the color shifting on scroll
          surfaceTintColor: Colors.transparent, // stops Material 3 tinting the bar
          centerTitle: false,
          toolbarHeight: kToolbarHeight,        // standard 56 on every screen
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Color(0xFF4F2D20),  // same as backgroundColor
            statusBarIconBrightness: Brightness.light, // Android icons
            statusBarBrightness: Brightness.dark,      // iOS icons
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6E5A3F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            elevation: 5,
          ),
        ),
        fontFamily: 'Montserrat',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          labelStyle: TextStyle(color: Color(0xFFD09D64)),
          prefixIconColor: Colors.grey.shade600,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color(0xFFD09D64), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red.shade700, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),

      // ✅ Set this instead of initialRoute
      home: const _AuthGate(),

      // ✅ Define named routes
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldAutoLogin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomePage();
        }
        return const LandingPage();
      },
    );
  }
}
