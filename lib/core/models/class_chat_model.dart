import 'package:cloud_firestore/cloud_firestore.dart';

class ClassChatModel {
  final String id;
  final String classId;
  final String className;
  final int unreadCount;
  final Timestamp lastMessageTime;
  final String lastMessageText;
  final String lastMessageSender;

  ClassChatModel({
    required this.id,
    required this.classId,
    required this.className,
    this.unreadCount = 0,
    required this.lastMessageTime,
    this.lastMessageText = '',
    this.lastMessageSender = '',
  });

  // From Firestore
  factory ClassChatModel.fromFirestore(DocumentSnapshot doc, {String? className}) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassChatModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      className: className ?? data['className'] ?? '',
      unreadCount: data['unreadCount'] ?? 0,
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      lastMessageText: data['lastMessageText'] ?? '',
      lastMessageSender: data['lastMessageSender'] ?? '',
    );
  }

  // Create from class data
  factory ClassChatModel.fromClassData(Map<String, dynamic> classData) {
    return ClassChatModel(
      id: classData['id'] ?? '',
      classId: classData['id'] ?? '',
      className: classData['name'] ?? 'İsimsiz Sınıf',
      unreadCount: 0,
      lastMessageTime: Timestamp.now(),
      lastMessageText: 'Henüz mesaj yok',
      lastMessageSender: '',
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'className': className,
      'unreadCount': unreadCount,
      'lastMessageTime': lastMessageTime,
      'lastMessageText': lastMessageText,
      'lastMessageSender': lastMessageSender,
    };
  }
} 