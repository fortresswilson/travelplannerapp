import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String title;
  final String emoji;
  final String category;
  final int dayIndex;
  final String startTime;
  final String endTime;
  final double cost;
  final double distanceKm;
  final String note;
  final bool done;
  final int score;
  final String addedBy;
  final String status; // 'pending_vote' | 'approved' | 'rejected'
  final DateTime? createdAt;

  // Mutable fields set by optimizer
  int voteScore;
  int popularityScore;
  int computedScore;
  String scoreReason;

  ActivityModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.cost,
    required this.distanceKm,
    required this.note,
    required this.done,
    required this.score,
    required this.addedBy,
    required this.status,
    this.createdAt,
    this.voteScore = 0,
    this.popularityScore = 10,
    this.computedScore = 0,
    this.scoreReason = '',
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      title: d['title'] ?? '',
      emoji: d['emoji'] ?? '📍',
      category: d['category'] ?? 'Other',
      dayIndex: (d['dayIndex'] as num?)?.toInt() ?? 0,
      startTime: d['startTime'] ?? '09:00',
      endTime: d['endTime'] ?? '10:00',
      cost: (d['cost'] as num?)?.toDouble() ?? 0,
      distanceKm: (d['distanceKm'] as num?)?.toDouble() ?? 0,
      note: d['note'] ?? '',
      done: d['done'] ?? false,
      score: (d['score'] as num?)?.toInt() ?? 0,
      addedBy: d['addedBy'] ?? '',
      status: d['status'] ?? 'pending_vote',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      voteScore: (d['voteScore'] as num?)?.toInt() ?? 0,
      popularityScore: (d['popularityScore'] as num?)?.toInt() ?? 10,
      computedScore: (d['score'] as num?)?.toInt() ?? 0,
      scoreReason: d['scoreReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'emoji': emoji,
    'category': category,
    'dayIndex': dayIndex,
    'startTime': startTime,
    'endTime': endTime,
    'cost': cost,
    'distanceKm': distanceKm,
    'note': note,
    'done': done,
    'score': score,
    'addedBy': addedBy,
    'status': status,
  };
}
