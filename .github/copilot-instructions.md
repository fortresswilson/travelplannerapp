# TropicaGuide AI Agent Guide

- `lib/main.dart` is the app entrypoint. It initializes Firebase with `DefaultFirebaseOptions.currentPlatform` and then renders a MaterialApp whose `home` is `_AuthGate`.
- `_AuthGate` listens to `FirebaseAuth.instance.authStateChanges()` and routes to `TripLobbyScreen` when signed in, or `SignInScreen` when signed out.

## Architecture

- `lib/screens/` contains the UI pages and local state. Navigation is explicit via `Navigator.push`, `pushReplacement`, and modal bottom sheets.
- `lib/services/` contains Firebase wrappers. Each service is responsible for one domain:
  - `AuthService` handles sign-in, sign-up, Google auth, reset password, and sign-out.
  - `TripService` handles Firestore trip CRUD, invite code join flow, trip streams, and budget updates.
  - `ChatService` handles Firestore chat messages, vote streams, and Firebase Cloud Messaging token/topic setup.
  - `UserService` handles user profile streams, profile updates, and member lookup.
  - `StorageService` handles Firebase Storage uploads for trip/activity photos.
  - `OptimizerService` wraps Firestore activity streams and Cloud Functions calls for itinerary scoring.
- `lib/models/` defines Firestore shapes for trips, activities, users, and messages.

## Important patterns

- Most screens currently use mock UI data and contain `TODO` comments for Firebase wiring. Search for `TODO (Backend)` or `Firebase hooks` in `lib/screens/`.
- Service methods are usually created to replace those stubs. For example, `SignInScreen._handleEmailSignIn()` should use `AuthService.signInWithEmail(...)`.
- There is no dependency injection framework; screens instantiate service classes directly, e.g. `final _authService = AuthService();` in `SignInScreen`.
- Real-time data is expected to use Firestore snapshots and streams. Example: `TripService.tripsStream()` returns `collection('trips').where('members', arrayContains: uid).snapshots()`.

## Build / test workflow

- Install dependencies: `flutter pub get`
- Run the app: `flutter run`
- Run tests: `flutter test` or `flutter test test/widget_test.dart`
- Analyze: `flutter analyze`

## Project-specific notes

- Firebase is already configured for platforms in `lib/firebase_options.dart`. Do not edit that file manually after FlutterFire setup.
- The app uses generated Firebase config and platform-specific assets under `ios/Runner/GoogleService-Info.plist` and `android/app/google-services.json`.
- Keep UI logic in `lib/screens/` and backend contract code in `lib/services/`.
- Use existing Firestore field names and collection patterns from service classes, such as `trips/{tripId}/activities`, `trips/{tripId}/messages`, and `users/{uid}`.

## When editing

- Preserve current navigation flow: SignIn → TripLobby → Create/Join Trip → Itinerary → Chat/Voting.
- Wire backend logic by replacing mock delays and placeholder data with service calls, rather than reworking the screen structure unnecessarily.
- Follow the `flutter_lints` rules configured in `analysis_options.yaml`.
