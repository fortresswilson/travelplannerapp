import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

/// UserService — Firestore user profile operations
/// Replaces TODOs in user_profile_screen.dart
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Real-time user profile stream ──────────────────────────────────────
  Stream<UserModel?> profileStream() {
    return _db.doc('users/$_uid').snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  // ─── Get user by ID (for member avatars in trip lobby) ───────────────────
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.doc('users/$uid').get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ─── Update profile ──────────────────────────────────────────────────────
  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _db.doc('users/$_uid').update(updates);

    // Also update Firebase Auth display name
    if (name != null) {
      await _auth.currentUser?.updateDisplayName(name.trim());
    }
    if (photoUrl != null) {
      await _auth.currentUser?.updatePhotoURL(photoUrl);
    }
  }

  // ─── Get multiple users (for trip member list) ───────────────────────────
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final futures = uids.map((uid) => getUser(uid));
    final results = await Future.wait(futures);
    return results.whereType<UserModel>().toList();
  }
}
