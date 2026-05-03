import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AuthService — wraps FirebaseAuth for TropicaGuide
/// Replaces all TODO stubs in sign_in_screen.dart and sign_up_screen.dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Current user stream ────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─── Email / Password Sign In ───────────────────────────────────────────
  /// Replaces _handleEmailSignIn stub in SignInScreen
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ─── Email / Password Sign Up ───────────────────────────────────────────
  /// Replaces _handleSignUp stub in SignUpScreen
  /// Also creates Firestore user profile doc
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Update display name on Auth profile
    await cred.user!.updateDisplayName(name.trim());

    // Create Firestore user doc
    await _db.doc('users/${cred.user!.uid}').set({
      'uid': cred.user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'tripIds': [],
    });

    return cred;
  }

  // ─── Google Sign In ─────────────────────────────────────────────────────
  /// Replaces _handleGoogleSignIn stub in SignInScreen
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Create user doc if first time
    final userDoc = await _db.doc('users/${cred.user!.uid}').get();
    if (!userDoc.exists) {
      await _db.doc('users/${cred.user!.uid}').set({
        'uid': cred.user!.uid,
        'name': cred.user!.displayName ?? '',
        'email': cred.user!.email ?? '',
        'photoUrl': cred.user!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'tripIds': [],
      });
    }

    return cred;
  }

  // ─── Password Reset ─────────────────────────────────────────────────────
  /// Replaces _handleForgotPassword stub in SignInScreen
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Sign Out ───────────────────────────────────────────────────────────
  /// Replaces _handleSignOut stub in TripLobbyScreen
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
