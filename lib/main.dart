import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/trip_lobby_screen.dart';
import 'screens/create_join_trip_screen.dart';
import 'screens/itinerary_view_screen.dart';
import 'screens/add_activities_screen.dart';
import 'screens/chat_voting_screen.dart';
import 'screens/optimizer_and_budget_optimizer_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/settings_and_preferences_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style — transparent so wave headers bleed through
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // TODO: Uncomment when Backend Lead wires Firebase
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

      // ── Entry point ──
      home: const SignInScreen(),

      // ── Named route table ──
      // Screens that take no required args can use named routes directly.
      // Screens with required args (tripId, destination, etc.) are pushed
      // with MaterialPageRoute + constructor params — see each screen file.
      routes: {
        '/signin':    (ctx) => const SignInScreen(),
        '/signup':    (ctx) => const SignUpScreen(),
        '/lobby':     (ctx) => const TripLobbyScreen(),
        '/profile':   (ctx) => const UserProfileScreen(),
        '/settings':  (ctx) => const SettingsAndPreferencesScreen(),

        // Screens below require args — navigate via MaterialPageRoute in code.
        // These named routes use default/demo params and are useful for
        // quick dev testing only.
        '/itinerary': (ctx) => const ItineraryViewScreen(),
        '/chat':      (ctx) => const ChatVotingScreen(),
        '/optimizer': (ctx) => const OptimizerBudgetScreen(),

        // CreateJoinTripScreen requires a TripMode — pushed directly in code.
        // '/create-trip' and '/join-trip' are handled by TripLobbyScreen.
      },

      // ── Route generator (for screens that need arguments) ──
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/itinerary':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ItineraryViewScreen(
                tripId: args?['tripId'] ?? 't1',
                destination: args?['destination'] ?? 'Bali, Indonesia',
              ),
            );

          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatVotingScreen(
                tripId: args?['tripId'] ?? 't1',
                tripDestination: args?['destination'] ?? 'Bali, Indonesia',
              ),
            );

          case '/optimizer':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => OptimizerBudgetScreen(
                tripId: args?['tripId'] ?? 't1',
                destination: args?['destination'] ?? 'Bali, Indonesia',
              ),
            );

          case '/add-activities':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => AddActivitiesScreen(
                tripId: args?['tripId'] ?? 't1',
                tripDestination: args?['destination'] ?? 'Bali, Indonesia',
              ),
            );

          case '/create-trip':
            return MaterialPageRoute(
              builder: (_) =>
                  const CreateJoinTripScreen(mode: TripMode.create),
            );

          case '/join-trip':
            return MaterialPageRoute(
              builder: (_) =>
                  const CreateJoinTripScreen(mode: TripMode.join),
            );

          default:
            return null; // fall through to routes table or 404
        }
      },
    );
  }
}
