import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';

/// TripService — all Firestore operations for trips
/// Replaces all TODO stubs in trip_lobby_screen.dart and create_join_trip_screen.dart
class TripService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Generate invite code ────────────────────────────────────────────────
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Create a new trip ───────────────────────────────────────────────────
  /// Replaces Create TODO in CreateJoinTripScreen._handleSubmit
  Future<String> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetTotal,
  }) async {
    final inviteCode = _generateInviteCode();

    final docRef = await _db.collection('trips').add({
      'name': name.trim(),
      'destination': destination.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budgetTotal': budgetTotal,
      'budgetSpent': 0.0,
      'ownerId': _uid,
      'members': [_uid],
      'inviteCode': inviteCode,
      'status': 'upcoming',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add trip reference to user doc
    await _db.doc('users/$_uid').update({
      'tripIds': FieldValue.arrayUnion([docRef.id]),
    });

    return docRef.id;
  }

  // ─── Join a trip via invite code ─────────────────────────────────────────
  /// Replaces Join TODO in CreateJoinTripScreen._handleSubmit
  Future<String> joinTrip(String inviteCode) async {
    final query = await _db
        .collection('trips')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No trip found with that invite code.');
    }

    final tripDoc = query.docs.first;
    final tripId = tripDoc.id;
    final members = List<String>.from(tripDoc['members'] ?? []);

    if (members.contains(_uid)) {
      return tripId; // already a member — just navigate
    }

    // Add user to trip members
    await _db.doc('trips/$tripId').update({
      'members': FieldValue.arrayUnion([_uid]),
    });

    // Add trip to user profile
    await _db.doc('users/$_uid').update({
      'tripIds': FieldValue.arrayUnion([tripId]),
    });

    return tripId;
  }

  // ─── Real-time stream of user's trips ────────────────────────────────────
  /// Replaces _loadTrips TODO in TripLobbyScreen
  Stream<List<TripModel>> tripsStream() {
    return _db
        .collection('trips')
        .where('members', arrayContains: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TripModel.fromFirestore(doc))
            .toList());
  }

  // ─── Get single trip ─────────────────────────────────────────────────────
  Future<TripModel?> getTrip(String tripId) async {
    final doc = await _db.doc('trips/$tripId').get();
    if (!doc.exists) return null;
    return TripModel.fromFirestore(doc);
  }

  // ─── Update budget spent ─────────────────────────────────────────────────
  /// Called by OptimizerBudgetScreen._saveBudgetTotal
  Future<void> updateBudget(String tripId, double budgetTotal) async {
    await _db.doc('trips/$tripId').update({'budgetTotal': budgetTotal});
  }

  // ─── Recalculate budget spent from activities ────────────────────────────
  Future<void> recalculateBudgetSpent(String tripId) async {
    final activitiesSnap =
        await _db.collection('trips/$tripId/activities').get();
    double total = 0;
    for (final doc in activitiesSnap.docs) {
      total += (doc['cost'] as num?)?.toDouble() ?? 0;
    }
    await _db.doc('trips/$tripId').update({'budgetSpent': total});
  }

  // ─── Delete a trip ───────────────────────────────────────────────────────
  Future<void> deleteTrip(String tripId) async {
    await _db.doc('trips/$tripId').delete();
    await _db.doc('users/$_uid').update({
      'tripIds': FieldValue.arrayRemove([tripId]),
    });
  }
}
