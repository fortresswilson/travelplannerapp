import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, system, vote }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? ts;
  final MessageType type;
  final Map<String, int> reactions;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.ts,
    required this.type,
    required this.reactions,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? 'Unknown',
      text: d['text'] ?? '',
      ts: (d['ts'] as Timestamp?)?.toDate(),
      type: _parseType(d['type']),
      reactions: Map<String, int>.from(d['reactions'] ?? {}),
    );
  }

  static MessageType _parseType(String? s) {
    switch (s) {
      case 'system': return MessageType.system;
      case 'vote': return MessageType.vote;
      default: return MessageType.text;
    }
  }
}
