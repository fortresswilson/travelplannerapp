import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/sign_in_screen.dart';
import 'screens/trip_lobby_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TropicaGuideApp());
}

class TropicaGuideApp extends StatelessWidget {
  const TropicaGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TropicaGuide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Auth gate — shows TripLobby if logged in, SignIn if not
      home: const _AuthGate(),
    );
  }
}

/// AuthGate — listens to Firebase auth state and routes accordingly
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        // Logged in → Trip Lobby
        if (snapshot.hasData && snapshot.data != null) {
          return const TripLobbyScreen();
        }
        // Not logged in → Sign In
        return const SignInScreen();
      },
    );
  }
}
