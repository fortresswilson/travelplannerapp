import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// StorageService — Firebase Storage for profile photos and activity images
/// Replaces Activity images TODO in add_activities_screen.dart
/// Replaces Member avatars TODO in trip_lobby_screen.dart
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Upload profile photo ────────────────────────────────────────────────
  Future<String> uploadProfilePhoto(File imageFile) async {
    final ref = _storage.ref('users/$_uid/profile.jpg');
    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ─── Upload activity photo ────────────────────────────────────────────────
  /// Replaces Activity images TODO in AddActivitiesScreen
  Future<String> uploadActivityPhoto({
    required String tripId,
    required String activityId,
    required File imageFile,
  }) async {
    final ref =
        _storage.ref('trips/$tripId/activities/$activityId/photo.jpg');
    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ─── Upload trip cover photo ──────────────────────────────────────────────
  Future<String> uploadTripCover({
    required String tripId,
    required File imageFile,
  }) async {
    final ref = _storage.ref('trips/$tripId/cover.jpg');
    final uploadTask = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ─── Delete a file ────────────────────────────────────────────────────────
  Future<void> deleteFile(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  }

  // ─── Get download URL (with fallback) ────────────────────────────────────
  Future<String?> getDownloadUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
