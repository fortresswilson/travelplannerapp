import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/activity_model.dart';

/// OptimizerService — local scoring engine + Cloud Function trigger
/// Replaces _runOptimizer, _loadScores, _loadBudget TODOs in OptimizerBudgetScreen
///
/// Scoring formula (must-solve requirement):
///   score = (voteWeight * 35) + (distanceWeight * 25) + (budgetWeight * 25) + (popularityWeight * 15)
class OptimizerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ─── Run optimizer via Cloud Function ────────────────────────────────────
  /// Replaces _runOptimizer TODO in OptimizerBudgetScreen
  /// Returns list of activities with updated scores + reorder reason strings
  Future<List<ScoredResult>> runOptimizer(String tripId) async {
    final callable = _functions.httpsCallable('optimizeItinerary');
    final result = await callable.call({'tripId': tripId});

    final data = List<Map<String, dynamic>>.from(result.data['activities']);
    return data.map((item) => ScoredResult.fromMap(item)).toList();
  }

  // ─── Local scoring fallback (runs without Cloud Function) ────────────────
  /// Used when offline or for instant preview — same logic as Cloud Function
  List<ActivityModel> scoreLocally({
    required List<ActivityModel> activities,
    required double budgetTotal,
    required double budgetSpent,
  }) {
    final budgetRemaining = budgetTotal - budgetSpent;

    for (final act in activities) {
      // Distance score: closer = higher (max 25 pts)
      final distScore = _normalizeInverse(act.distanceKm, 0, 20) * 25;

      // Budget score: cheaper relative to remaining = higher (max 25 pts)
      final budgetScore = budgetRemaining > 0
          ? ((1 - (act.cost / budgetRemaining).clamp(0, 1)) * 25)
          : 0.0;

      // Vote score: from votes sub-collection (pre-loaded, max 35 pts)
      final voteScore = act.voteScore.clamp(0, 35).toDouble();

      // Popularity score: static, max 15 pts
      final popScore = act.popularityScore.clamp(0, 15).toDouble();

      final total =
          (distScore + budgetScore + voteScore + popScore).round().clamp(0, 100);

      act.computedScore = total;
      act.scoreReason =
          'Votes ${voteScore.toInt()}/35 • Distance ${distScore.toInt()}/25 • Budget ${budgetScore.toInt()}/25 • Popularity ${popScore.toInt()}/15';
    }

    activities.sort((a, b) => b.computedScore.compareTo(a.computedScore));
    return activities;
  }

  // ─── Save scores back to Firestore ───────────────────────────────────────
  Future<void> saveScores(
      String tripId, List<ActivityModel> activities) async {
    final batch = _db.batch();
    for (final act in activities) {
      final ref = _db.doc('trips/$tripId/activities/${act.id}');
      batch.update(ref, {
        'score': act.computedScore,
        'scoreReason': act.scoreReason,
        'order': activities.indexOf(act),
      });
    }
    await batch.commit();
  }

  // ─── Real-time scored activities stream ──────────────────────────────────
  /// Replaces _loadScores TODO in OptimizerBudgetScreen
  Stream<List<ActivityModel>> scoredActivitiesStream(String tripId) {
    return _db
        .collection('trips/$tripId/activities')
        .orderBy('score', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList());
  }

  // ─── Budget stream ────────────────────────────────────────────────────────
  /// Replaces _loadBudget TODO in OptimizerBudgetScreen
  Stream<Map<String, double>> budgetStream(String tripId) {
    return _db.doc('trips/$tripId').snapshots().map((snap) {
      if (!snap.exists) return {};
      return {
        'budgetTotal': (snap['budgetTotal'] as num?)?.toDouble() ?? 0,
        'budgetSpent': (snap['budgetSpent'] as num?)?.toDouble() ?? 0,
      };
    });
  }

  // ─── Helper ──────────────────────────────────────────────────────────────
  double _normalizeInverse(double value, double min, double max) {
    if (max == min) return 1;
    return 1 - ((value - min) / (max - min)).clamp(0.0, 1.0);
  }
}

/// Result from Cloud Function optimizer
class ScoredResult {
  final String activityId;
  final int score;
  final String reason;
  final int newOrder;

  const ScoredResult({
    required this.activityId,
    required this.score,
    required this.reason,
    required this.newOrder,
  });

  factory ScoredResult.fromMap(Map<String, dynamic> map) {
    return ScoredResult(
      activityId: map['activityId'] as String,
      score: (map['score'] as num).toInt(),
      reason: map['reason'] as String? ?? '',
      newOrder: (map['order'] as num).toInt(),
    );
  }
}
