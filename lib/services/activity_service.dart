import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_model.dart';

/// ActivityService — Firestore CRUD for trip activities
/// Replaces all TODO stubs in itinerary_view_screen.dart and add_activities_screen.dart
class ActivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── Real-time stream of activities (ordered by score) ───────────────────
  /// Replaces _loadActivities TODO in ItineraryViewScreen
  Stream<List<ActivityModel>> activitiesStream(String tripId) {
    return _db
        .collection('trips/$tripId/activities')
        .orderBy('score', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList());
  }

  // ─── Stream filtered by day ──────────────────────────────────────────────
  Stream<List<ActivityModel>> activitiesByDayStream(
      String tripId, int dayIndex) {
    return _db
        .collection('trips/$tripId/activities')
        .where('dayIndex', isEqualTo: dayIndex)
        .orderBy('score', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList());
  }

  // ─── Add an activity ─────────────────────────────────────────────────────
  /// Replaces _addActivity TODO in AddActivitiesScreen and ItineraryViewScreen
  Future<String> addActivity({
    required String tripId,
    required String title,
    required String emoji,
    required String category,
    required int dayIndex,
    required String startTime,
    required String endTime,
    required double cost,
    required double distanceKm,
    String? note,
  }) async {
    final docRef = await _db.collection('trips/$tripId/activities').add({
      'title': title.trim(),
      'emoji': emoji,
      'category': category,
      'dayIndex': dayIndex,
      'startTime': startTime,
      'endTime': endTime,
      'cost': cost,
      'distanceKm': distanceKm,
      'note': note ?? '',
      'done': false,
      'score': 0, // scored by Cloud Function after adding
      'addedBy': _uid,
      'status': 'pending_vote',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Trigger budget recalc
    await _updateBudgetSpent(tripId);

    return docRef.id;
  }

  // ─── Toggle done ─────────────────────────────────────────────────────────
  /// Replaces _toggleActivityDone TODO in ItineraryViewScreen
  Future<void> toggleDone(String tripId, String activityId, bool currentDone) async {
    await _db
        .doc('trips/$tripId/activities/$activityId')
        .update({'done': !currentDone});
  }

  // ─── Delete activity ─────────────────────────────────────────────────────
  /// Replaces _deleteActivity TODO in ItineraryViewScreen
  Future<void> deleteActivity(String tripId, String activityId) async {
    await _db.doc('trips/$tripId/activities/$activityId').delete();
    await _updateBudgetSpent(tripId);
  }

  // ─── Reorder activities (batch update order field) ───────────────────────
  /// Replaces _onReorder TODO in ItineraryViewScreen
  Future<void> reorderActivities(
      String tripId, List<ActivityModel> reorderedList) async {
    final batch = _db.batch();
    for (int i = 0; i < reorderedList.length; i++) {
      final ref = _db.doc('trips/$tripId/activities/${reorderedList[i].id}');
      batch.update(ref, {'order': i});
    }
    await batch.commit();
  }

  // ─── Update activity score ────────────────────────────────────────────────
  Future<void> updateScore(
      String tripId, String activityId, int score) async {
    await _db
        .doc('trips/$tripId/activities/$activityId')
        .update({'score': score});
  }

  // ─── Private: recalculate budget spent ──────────────────────────────────
  Future<void> _updateBudgetSpent(String tripId) async {
    final snap = await _db.collection('trips/$tripId/activities').get();
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc['cost'] as num?)?.toDouble() ?? 0;
    }
    await _db.doc('trips/$tripId').update({'budgetSpent': total});
  }
}
