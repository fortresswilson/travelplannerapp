import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { upcoming, active, past }

class TripModel {
  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double budgetTotal;
  final double budgetSpent;
  final String ownerId;
  final List<String> memberIds;
  final String inviteCode;
  final TripStatus status;
  final DateTime? createdAt;

  const TripModel({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budgetTotal,
    required this.budgetSpent,
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    required this.status,
    this.createdAt,
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripModel(
      id: doc.id,
      name: data['name'] ?? '',
      destination: data['destination'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      budgetTotal: (data['budgetTotal'] as num?)?.toDouble() ?? 0,
      budgetSpent: (data['budgetSpent'] as num?)?.toDouble() ?? 0,
      ownerId: data['ownerId'] ?? '',
      memberIds: List<String>.from(data['members'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static TripStatus _parseStatus(String? s) {
    switch (s) {
      case 'active': return TripStatus.active;
      case 'past':   return TripStatus.past;
      default:       return TripStatus.upcoming;
    }
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'destination': destination,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'budgetTotal': budgetTotal,
    'budgetSpent': budgetSpent,
    'ownerId': ownerId,
    'members': memberIds,
    'inviteCode': inviteCode,
    'status': status.name,
  };
}
