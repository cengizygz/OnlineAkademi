import 'package:cloud_firestore/cloud_firestore.dart';

class PoolQuestion {
  final String id;
  final String creatorId; // Soruyu oluşturan öğrenci ID'si
  final String questionText;
  final List<String> options; // A, B, C, D şıkları
  final String correctAnswer; // "A", "B", "C", "D" gibi
  final String subject; // Ders
  final String topic; // Konu
  final DateTime createdAt;
  final bool isApproved;
  final bool isSolved;
  final String? solverStudentId; // Çözen öğrenci ID'si (eğer çözüldüyse)
  final String? solutionText; // Çözüm açıklaması
  final String? solutionFileUrl; // Çözüm dosyası URL'i

  PoolQuestion({
    required this.id,
    required this.creatorId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.subject,
    required this.topic,
    required this.createdAt,
    required this.isApproved,
    required this.isSolved,
    this.solverStudentId,
    this.solutionText,
    this.solutionFileUrl,
  });

  // Firestore'dan veri almak için factory constructor
  factory PoolQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PoolQuestion(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      subject: data['subject'] ?? '',
      topic: data['topic'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isApproved: data['isApproved'] ?? false,
      isSolved: data['isSolved'] ?? false,
      solverStudentId: data['solverStudentId'],
      solutionText: data['solutionText'],
      solutionFileUrl: data['solutionFileUrl'],
    );
  }

  // Firestore'a veri kaydetmek için map
  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'questionText': questionText,
      'options': options,
      'correctAnswer': correctAnswer,
      'subject': subject,
      'topic': topic,
      'createdAt': Timestamp.fromDate(createdAt),
      'isApproved': isApproved,
      'isSolved': isSolved,
      'solverStudentId': solverStudentId,
      'solutionText': solutionText,
      'solutionFileUrl': solutionFileUrl,
    };
  }
} 