import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String classId;
  final String senderId;
  final String senderName;
  final String content;
  final Timestamp timestamp;
  final bool isTeacher;

  ChatMessageModel({
    required this.id,
    required this.classId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isTeacher,
  });

  // From Firestore
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isTeacher: data['isTeacher'] ?? false,
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp,
      'isTeacher': isTeacher,
    };
  }
} 