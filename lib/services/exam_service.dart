import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sınav oluştur
  Future<String> createExam({
    required String title,
    required String description,
    required DateTime dueDate,
    required List<Map<String, dynamic>> questions,
    List<String>? assignedStudents,
    String examType = 'normal', // normal veya deneme
  }) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmenin öğrencilerini getir
      QuerySnapshot studentRelations = await _firestore
          .collection('teacher_students')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      // Öğrenci ID'lerini al
      List<String> studentIds = [];
      for (var doc in studentRelations.docs) {
        final data = doc.data() as Map<String, dynamic>;
        studentIds.add(data['studentId'] as String);
      }

      // Belirli öğrenciler atanmışsa onları kullan, yoksa tüm öğrencileri kullan
      final List<String> students = assignedStudents ?? studentIds;

      // Firestore'a sınav oluştur
      DocumentReference docRef = await _firestore.collection('exams').add({
        'teacherId': teacherId,
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'questions': questions,
        'assignedStudents': students,
        'completedStudents': [],
        'examType': examType, // normal veya deneme
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Sınav oluşturulurken hata: $e');
    }
  }

  // Sınavı gönder
  Future<void> submitExam({
    required String examId,
    required List<String> answers,
  }) async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınav verilerini getir
      final examDoc = await _firestore.collection('exams').doc(examId).get();
      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }

      final examData = examDoc.data() as Map<String, dynamic>;
      final questions = examData['questions'] as List<dynamic>;

      // Cevapları kontrol et
      if (answers.length != questions.length) {
        throw Exception('Cevap sayısı soru sayısı ile eşleşmiyor');
      }

      // Sınav gönderimini kaydet
      await _firestore.collection('exam_submissions').add({
        'examId': examId,
        'studentId': studentId,
        'answers': answers,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, graded
      });

      // Sınavın tamamlanan öğrenciler listesini güncelle
      await _firestore.collection('exams').doc(examId).update({
        'completedStudents': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      throw Exception('Sınav gönderilirken hata: $e');
    }
  }

  // Sınav detayını getir
  Future<Map<String, dynamic>> getExam(String examId) async {
    try {
      print('ExamService: getExam çağrıldı, ID: $examId');
      
      if (examId.isEmpty) {
        throw Exception('Geçersiz sınav ID\'si: ID boş');
      }
      
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();

      print('ExamService: Firestore sorgusu tamamlandı, belge var mı? ${examDoc.exists}');

      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı (ID: $examId)');
      }

      final data = examDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınav verisi bulunamadı (ID: $examId)');
      }
      
      // Sınavın öğrenciye atanıp atanmadığını kontrol et
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isNotEmpty) {
        final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
        if (!assignedStudents.contains(studentId)) {
          print('ExamService: Öğrenci bu sınava atanmamış: $studentId');
        }
      }
      
      print('ExamService: Sınav başarıyla getirildi - ${data['title']}');
      
      final questions = data['questions'] ?? [];
      
      print('ExamService: Soru sayısı: ${questions.length}');

      return {
        'id': examId,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'dueDate': data['dueDate'] != null 
            ? (data['dueDate'] as Timestamp).toDate() 
            : DateTime.now(),
        'questions': List<Map<String, dynamic>>.from(data['questions'] ?? []),
        'assignedStudents': List<String>.from(data['assignedStudents'] ?? []),
        'completedStudents': List<String>.from(data['completedStudents'] ?? []),
      };
    } catch (e) {
      print('ExamService: Sınav getirme hatası: $e');
      throw Exception('Sınav getirilirken hata: $e');
    }
  }

  // Sınavı güncelle
  Future<void> updateExam({
    required String examId,
    String? title,
    String? description,
    DateTime? dueDate,
    List<Map<String, dynamic>>? questions,
    List<String>? assignedStudents,
    String? examType,
  }) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınavın bu öğretmene ait olduğunu doğrula
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();

      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }

      final data = examDoc.data() as Map<String, dynamic>;
      if (data['teacherId'] != teacherId) {
        throw Exception('Bu sınavı düzenleme yetkiniz yok');
      }

      // Güncellenecek alanları belirle
      Map<String, dynamic> updates = {};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
      if (questions != null) updates['questions'] = questions;
      if (assignedStudents != null) updates['assignedStudents'] = assignedStudents;
      if (examType != null) updates['examType'] = examType;

      // Sınavı güncelle
      await _firestore.collection('exams').doc(examId).update(updates);
    } catch (e) {
      throw Exception('Sınav güncellenirken hata: $e');
    }
  }

  // Sınavı sil
  Future<void> deleteExam(String examId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınavın bu öğretmene ait olduğunu doğrula
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();

      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }

      final data = examDoc.data() as Map<String, dynamic>;
      if (data['teacherId'] != teacherId) {
        throw Exception('Bu sınavı silme yetkiniz yok');
      }

      // Sınavı sil
      await _firestore.collection('exams').doc(examId).delete();
    } catch (e) {
      throw Exception('Sınav silinirken hata: $e');
    }
  }

  // Sınav cevaplarını kaydet (öğrenci tarafı)
  Future<void> submitExamAnswers(String examId, List<String> answers) async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınavı kontrol et
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();

      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }

      final examData = examDoc.data() as Map<String, dynamic>;
      final examTitle = examData['title'] ?? 'İsimsiz Sınav';
      
      // Öğrencinin bu sınava atandığını kontrol et
      final assignedStudents = List<String>.from(examData['assignedStudents'] ?? []);
      if (!assignedStudents.contains(studentId)) {
        throw Exception('Bu sınava erişim yetkiniz yok');
      }

      // Öğrencinin daha önce sınavı tamamlamadığından emin ol
      final completedStudents = List<String>.from(examData['completedStudents'] ?? []);
      if (completedStudents.contains(studentId)) {
        throw Exception('Bu sınavı zaten tamamladınız');
      }

      // Kullanıcı adını al
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(studentId).get();
      String studentName = 'İsimsiz Öğrenci';
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['name'] != null) {
          studentName = userData['name'];
        }
      }

      // Sınav cevaplarını kaydet
      final submissionDoc = await _firestore.collection('exam_submissions').add({
        'examId': examId,
        'examTitle': examTitle,
        'studentId': studentId,
        'studentName': studentName,
        'answers': answers,
        'submittedAt': FieldValue.serverTimestamp(),
        'graded': false,
        'score': 0,
        'feedback': '',
        'gradedBy': '',
        'gradedAt': null,
      });

      // Öğrenciyi tamamlayanlar listesine ekle
      await _firestore.collection('exams').doc(examId).update({
        'completedStudents': FieldValue.arrayUnion([studentId]),
      });

      return;
    } catch (e) {
      throw Exception('Sınav cevapları gönderilirken hata: $e');
    }
  }
  
  // Bir sınavı tamamlayan öğrencilerin listesini getir (öğretmen tarafı)
  Future<List<Map<String, dynamic>>> getExamSubmissions(String examId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Sınavın bu öğretmene ait olduğunu doğrula
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();
          
      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }
      
      final examData = examDoc.data() as Map<String, dynamic>?;
      if (examData == null) {
        throw Exception('Sınav verisi bulunamadı');
      }
      
      if (examData['teacherId'] != teacherId) {
        throw Exception('Bu sınava erişim yetkiniz yok');
      }
      
      // Bu sınava ait cevapları getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('exam_submissions')
          .where('examId', isEqualTo: examId)
          .get();
      
      List<Map<String, dynamic>> submissions = [];
      
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        submissions.add({
          'id': doc.id,
          'studentId': data['studentId'] ?? '',
          'studentName': data['studentName'] ?? 'İsimsiz Öğrenci',
          'submittedAt': data['submittedAt'] ?? Timestamp.now(),
          'graded': data['graded'] ?? false,
          'score': data['score'] ?? 0,
          'answers': List<String>.from(data['answers'] ?? []),
        });
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Sınav cevapları getirilirken hata: $e');
    }
  }
  
  // Bir öğrencinin sınav cevaplarını getir
  Future<Map<String, dynamic>> getStudentExamSubmission(String examId, String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Sınavı getir
      DocumentSnapshot examDoc = await _firestore
          .collection('exams')
          .doc(examId)
          .get();
          
      if (!examDoc.exists) {
        throw Exception('Sınav bulunamadı');
      }
      
      final examData = examDoc.data() as Map<String, dynamic>?;
      if (examData == null) {
        throw Exception('Sınav verisi bulunamadı');
      }
      
      // Öğretmen veya ilgili öğrenci mi kontrol et
      bool hasAccess = false;
      if (userId == examData['teacherId'] || userId == studentId) {
        hasAccess = true;
      }
      
      if (!hasAccess) {
        throw Exception('Bu sınav cevaplarına erişim yetkiniz yok');
      }
      
      // Öğrencinin cevaplarını getir
      QuerySnapshot submissionSnapshot = await _firestore
          .collection('exam_submissions')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
          
      if (submissionSnapshot.docs.isEmpty) {
        throw Exception('Öğrenci sınavı henüz tamamlamamış');
      }
      
      final submissionData = submissionSnapshot.docs.first.data() as Map<String, dynamic>;
      final submissionId = submissionSnapshot.docs.first.id;
      
      // Sınavın doğru cevaplarını getir
      final questions = List<Map<String, dynamic>>.from(examData['questions'] ?? []);
      
      return {
        'id': submissionId,
        'examId': examId,
        'examTitle': examData['title'] ?? '',
        'studentId': studentId,
        'studentName': submissionData['studentName'] ?? 'İsimsiz Öğrenci',
        'submittedAt': submissionData['submittedAt'] ?? Timestamp.now(),
        'graded': submissionData['graded'] ?? false,
        'score': submissionData['score'] ?? 0,
        'feedback': submissionData['feedback'] ?? '',
        'answers': List<String>.from(submissionData['answers'] ?? []),
        'questions': questions,
      };
    } catch (e) {
      throw Exception('Öğrenci sınav cevapları getirilirken hata: $e');
    }
  }
  
  // Sınav cevaplarını puanla (öğretmen tarafı)
  Future<void> gradeExam(String submissionId, int score, String feedback, {bool isAutoGraded = false}) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmen adını al
      DocumentSnapshot teacherDoc = await _firestore.collection('users').doc(teacherId).get();
      String teacherName = 'İsimsiz Öğretmen';
      if (teacherDoc.exists) {
        final userData = teacherDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['name'] != null) {
          teacherName = userData['name'];
        }
      }
      
      // Submission'ı getir
      DocumentSnapshot submissionDoc = await _firestore
          .collection('exam_submissions')
          .doc(submissionId)
          .get();
          
      if (!submissionDoc.exists) {
        throw Exception('Sınav cevabı bulunamadı');
      }
      
      final submissionData = submissionDoc.data() as Map<String, dynamic>?;
      if (submissionData == null) {
        throw Exception('Sınav cevabı verisi bulunamadı');
      }
      
      final examId = submissionData['examId'] as String?;
      if (examId == null) {
        throw Exception('Sınav ID\'si bulunamadı');
      }
      
      // Otomatik değilse, öğretmenin bu sınava erişim hakkını doğrula
      if (!isAutoGraded) {
        // Sınavın bu öğretmene ait olduğunu doğrula
        DocumentSnapshot examDoc = await _firestore
            .collection('exams')
            .doc(examId)
            .get();
            
        if (!examDoc.exists) {
          throw Exception('Sınav bulunamadı');
        }
        
        final examData = examDoc.data() as Map<String, dynamic>?;
        if (examData == null) {
          throw Exception('Sınav verisi bulunamadı');
        }
        
        if (examData['teacherId'] != teacherId) {
          throw Exception('Bu sınavı puanlama yetkiniz yok');
        }
      }
      
      // Submission'ı güncelle
      await _firestore.collection('exam_submissions').doc(submissionId).update({
        'graded': true,
        'score': score,
        'feedback': feedback,
        'gradedBy': teacherId,
        'gradedByName': teacherName,
        'gradedAt': FieldValue.serverTimestamp(),
        'isAutoGraded': isAutoGraded,
      });
      
      // Öğrenci bilgisini al
      final studentId = submissionData['studentId'] as String?;
      if (studentId == null) {
        throw Exception('Öğrenci ID\'si bulunamadı');
      }
      
      // Öğrencinin sınav kayıtlarına ekle (öğrenci profili için)
      await _firestore.collection('student_exam_scores').add({
        'studentId': studentId,
        'examId': examId,
        'submissionId': submissionId,
        'examTitle': submissionData['examTitle'] ?? 'İsimsiz Sınav',
        'score': score,
        'maxScore': 100, // Maksimum puan varsayılan olarak 100
        'gradedBy': teacherId,
        'gradedByName': teacherName,
        'gradedAt': FieldValue.serverTimestamp(),
        'isAutoGraded': isAutoGraded,
      });
      
    } catch (e) {
      throw Exception('Sınav puanlanırken hata: $e');
    }
  }
  
  // Sınavı otomatik olarak puanla
  Future<void> autoGradeExam(String examId, String studentId) async {
    try {
      // Öğrencinin cevaplarını getir
      final submission = await getStudentExamSubmission(examId, studentId);
      
      if (submission['graded']) {
        // Zaten puanlandırılmış, otomatik puanlama yapma
        return;
      }
      
      final questions = submission['questions'] as List<Map<String, dynamic>>;
      final answers = submission['answers'] as List<String>;
      
      print('Otomatik puanlama başlatılıyor...');
      print('Soru sayısı: ${questions.length}, Cevap sayısı: ${answers.length}');
      
      // Doğru cevapların sayısını hesapla
      int correctAnswers = 0;
      int totalQuestions = questions.length;
      
      for (int i = 0; i < totalQuestions; i++) {
        if (i < answers.length) {
          final question = questions[i];
          final studentAnswer = answers[i];
          
          // Doğru cevabı al
          String correctAnswer = question['correctAnswer'] ?? '';
          
          print('Soru ${i+1}: "${question['question'] ?? ''}"');
          print('- Doğru cevap: "$correctAnswer"');
          print('- Öğrenci cevabı: "$studentAnswer"');
          
          bool isCorrect = false;
          
          // Öğrenci muhtemelen A, B, C, D formatında cevap verdi
          // Doğru cevabın formatını kontrol et ve karşılaştır
          if (studentAnswer == correctAnswer) {
            // Direk eşleşme
            isCorrect = true;
          } else if (correctAnswer.length > 1 && ['A', 'B', 'C', 'D'].contains(studentAnswer)) {
            // Eğer doğru cevap şıkkın içeriği ise ve öğrenci A, B, C, D ile cevap verdiyse
            // Şıkların içeriklerini kontrol et
            final options = question['options'] as Map<String, dynamic>?;
            if (options != null) {
              final optionContent = options[studentAnswer];
              if (optionContent == correctAnswer) {
                isCorrect = true;
              }
            }
          } else if (correctAnswer.length == 1 && ['A', 'B', 'C', 'D'].contains(correctAnswer)) {
            // Eğer doğru cevap A, B, C, D formatında ise ve öğrenci içerik ile cevap verdiyse
            // Bu durum pek olası değil ama kontrol edelim
            final options = question['options'] as Map<String, dynamic>?;
            if (options != null) {
              final optionContent = options[correctAnswer];
              if (optionContent == studentAnswer) {
                isCorrect = true;
              }
            }
          }
          
          print('- Eşleşiyor mu?: $isCorrect');
          
          if (isCorrect) {
            correctAnswers++;
          }
        }
      }
      
      // Puanı hesapla (100 üzerinden)
      int score = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
      
      print('Doğru cevap sayısı: $correctAnswers / $totalQuestions');
      print('Hesaplanan puan: $score');
      
      // Geri bildirim oluştur
      String feedback = 'Otomatik puanlama: $correctAnswers/$totalQuestions doğru cevap.';
      
      // Puanla
      await gradeExam(
        submission['id'],
        score,
        feedback,
        isAutoGraded: true,
      );
      
    } catch (e) {
      print('Otomatik puanlama hatası: $e');
      // Otomatik puanlama başarısız olsa bile uygulama çalışmaya devam etsin
    }
  }
  
  // Öğrencinin sınav notlarını getir (profili için)
  Future<List<Map<String, dynamic>>> getStudentExamScores(String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      // Kullanıcı rolünü al
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;
      debugPrint('getStudentExamScores: userId=$userId, userRole=$userRole, studentId=$studentId');
      // Öğrenci veya öğretmen erişebilsin
      bool hasAccess = userId == studentId || userRole == 'teacher';
      if (!hasAccess) {
        throw Exception('Bu puanlara erişim yetkiniz yok');
      }
      
      // Öğrencinin sınav puanlarını getir
      QuerySnapshot scoresSnapshot = await _firestore
          .collection('student_exam_scores')
          .where('studentId', isEqualTo: studentId)
          .orderBy('gradedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> scores = [];
      
      for (var doc in scoresSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        scores.add({
          'id': doc.id,
          'examId': data['examId'] ?? '',
          'submissionId': data['submissionId'] ?? '',
          'examName': data['examTitle'] ?? 'İsimsiz Sınav',
          'score': data['score'] ?? 0,
          'maxScore': data['maxScore'] ?? 100,
          'gradedBy': data['gradedByName'] ?? 'İsimsiz Öğretmen',
          'examDate': data['gradedAt'] ?? Timestamp.now(),
          'totalQuestions': data['maxScore'] ?? 100,
          'correctAnswers': ((data['score'] ?? 0) / (data['maxScore'] ?? 100) * (data['maxScore'] ?? 100)).round(),
          'percentage': (data['score'] ?? 0) / (data['maxScore'] ?? 100) * 100,
        });
      }
      
      return scores;
    } catch (e) {
      throw Exception('Öğrenci sınav puanları getirilirken hata: $e');
    }
  }

  // Mevcut kullanıcının ID'sini getir
  String getCurrentUserId() {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      return userId;
    } catch (e) {
      print('getCurrentUserId hatası: $e');
      throw Exception('Kullanıcı ID\'si alınamadı: $e');
    }
  }
  
  // Bir öğrencinin tamamladığı sınavları getir - öğretmen tarafı
  Future<List<Map<String, dynamic>>> getStudentSubmittedExams(String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmenin rolünü kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;
      
      // Sadece öğretmenler erişebilir
      if (userRole != 'teacher') {
        throw Exception('Bu bilgilere erişim yetkiniz yok');
      }
      
      // Öğrencinin gönderdiği sınavları getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('exam_submissions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> submissions = [];
      
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final examId = data['examId'] as String;
        
        try {
          // İlgili sınav bilgilerini getir
          DocumentSnapshot examDoc = await _firestore
              .collection('exams')
              .doc(examId)
              .get();
              
          if (examDoc.exists) {
            submissions.add({
              'id': doc.id,
              'examId': examId,
              'examTitle': data['examTitle'] ?? 'İsimsiz Sınav',
              'submittedAt': data['submittedAt'],
              'graded': data['graded'] ?? false,
              'score': data['score'] ?? 0,
              'feedback': data['feedback'] ?? '',
              'answers': List<String>.from(data['answers'] ?? []),
            });
          }
        } catch (e) {
          print('Sınav bilgisi alınırken hata: $e');
          // Hata olsa bile çalışmaya devam et
        }
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Öğrenci sınavları getirilirken hata: $e');
    }
  }
  
  // Mevcut öğrencinin tamamladığı sınavları getir
  Future<List<Map<String, dynamic>>> getCurrentStudentSubmittedExams() async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğrencinin gönderdiği sınavları getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('exam_submissions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> submissions = [];
      
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final examId = data['examId'] as String;
        
        try {
          // İlgili sınav bilgilerini getir
          DocumentSnapshot examDoc = await _firestore
              .collection('exams')
              .doc(examId)
              .get();
              
          if (examDoc.exists) {
            final examData = examDoc.data() as Map<String, dynamic>;
            
            submissions.add({
              'id': doc.id,
              'examId': examId,
              'examTitle': examData['title'] ?? 'İsimsiz Sınav',
              'submittedAt': data['submittedAt'],
              'graded': data['graded'] ?? false,
              'score': data['score'] ?? 0,
              'feedback': data['feedback'] ?? '',
            });
          }
        } catch (e) {
          print('Sınav bilgisi alınırken hata: $e');
          // Hata durumunda bu sınavı atla
        }
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Öğrenci sınavları getirilirken hata: $e');
    }
  }
} 