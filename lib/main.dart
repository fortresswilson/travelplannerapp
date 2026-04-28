import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/sign_in_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode (typical for mobile travel apps)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style — transparent so the wave header bleeds through
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // TODO: Add Firebase.initializeApp() here when Backend Lead wires Firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      // Initial route — Sign In is the entry point
      home: const SignInScreen(),
      // Route table (add screens as they are built)
      routes: {
        '/signin': (ctx) => const SignInScreen(),
        // '/lobby':  (ctx) => const TripLobbyScreen(),   // Next screen
        // '/signup': (ctx) => const SignUpScreen(),       // Companion screen
      },
    );
  }
}
