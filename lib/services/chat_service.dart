import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/message_model.dart';

/// ChatService — Firestore real-time chat + FCM notifications
/// Replaces all TODO stubs in chat_voting_screen.dart
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  String get _uid => _auth.currentUser!.uid;
  String get _displayName =>
      _auth.currentUser?.displayName ?? 'Traveler';

  // ─── Real-time message stream ────────────────────────────────────────────
  /// Replaces _loadMessages TODO in ChatVotingScreen
  Stream<List<MessageModel>> messagesStream(String tripId) {
    return _db
        .collection('trips/$tripId/messages')
        .orderBy('ts', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // ─── Send a text message ─────────────────────────────────────────────────
  /// Replaces _sendMessage TODO in ChatVotingScreen
  Future<void> sendMessage({
    required String tripId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    await _db.collection('trips/$tripId/messages').add({
      'senderId': _uid,
      'senderName': _displayName,
      'text': text.trim(),
      'ts': FieldValue.serverTimestamp(),
      'type': 'text',
      'reactions': {},
    });
  }

  // ─── Add reaction to a message ──────────────────────────────────────────
  Future<void> addReaction({
    required String tripId,
    required String messageId,
    required String emoji,
  }) async {
    final ref = _db.doc('trips/$tripId/messages/$messageId');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final reactions = Map<String, int>.from(snap['reactions'] ?? {});
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      tx.update(ref, {'reactions': reactions});
    });
  }

  // ─── Cast a vote on an activity ──────────────────────────────────────────
  /// Replaces _castVote TODO in ChatVotingScreen
  Future<void> castVote({
    required String tripId,
    required String activityId,
    required String voteEmoji, // '✅' '❌' '🤔'
  }) async {
    await _db.doc('trips/$tripId/votes/$activityId').set({
      'votes.$_uid': voteEmoji,
    }, SetOptions(merge: true));

    // Send system message announcing the vote
    await _db.collection('trips/$tripId/messages').add({
      'senderId': 'system',
      'senderName': 'TropicaGuide',
      'text': '$_displayName voted $voteEmoji on an activity!',
      'ts': FieldValue.serverTimestamp(),
      'type': 'system',
      'reactions': {},
    });
  }

  // ─── Stream vote counts for an activity ─────────────────────────────────
  Stream<Map<String, int>> voteCountStream(
      String tripId, String activityId) {
    return _db
        .doc('trips/$tripId/votes/$activityId')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return {};
      final votes = Map<String, String>.from(snap['votes'] ?? {});
      final counts = <String, int>{};
      for (final v in votes.values) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ─── FCM setup ───────────────────────────────────────────────────────────
  /// Call once from main.dart after Firebase.initializeApp()
  Future<void> setupFCM(String tripId) async {
    await _fcm.requestPermission();
    final token = await _fcm.getToken();
    if (token != null) {
      // Save FCM token to user doc so backend can target this device
      await _db.doc('users/$_uid').update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }

    // Subscribe to trip-specific topic for group notifications
    await _fcm.subscribeToTopic('trip_$tripId');
  }

  // ─── Typing indicator (Realtime DB pattern via Firestore) ────────────────
  Future<void> setTyping(String tripId, bool isTyping) async {
    await _db.doc('trips/$tripId/typing/$_uid').set({
      'name': _displayName,
      'isTyping': isTyping,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> typingUsersStream(String tripId) {
    return _db
        .collection('trips/$tripId/typing')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != _uid)
            .map((doc) => doc['name'] as String)
            .toList());
  }
}
