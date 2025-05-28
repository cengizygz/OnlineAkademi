import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeworkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Ödev oluştur
  Future<String> createHomework({
    required String title,
    required String description,
    required DateTime dueDate,
    required List<Map<String, dynamic>> tasks,
    List<String>? assignedStudents,
    List<String>? fileUrls,
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

      // Firestore'a ödev oluştur
      DocumentReference docRef = await _firestore.collection('homeworks').add({
        'teacherId': teacherId,
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'tasks': tasks,
        'assignedStudents': students,
        'completedStudents': [],
        'fileUrls': fileUrls ?? [],
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Ödev oluşturulurken hata: $e');
    }
  }

  // Ödev detayını getir
  Future<Map<String, dynamic>> getHomework(String homeworkId) async {
    try {
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();

      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }

      final data = homeworkDoc.data() as Map<String, dynamic>;
      return {
        'id': homeworkId,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'dueDate': data['dueDate'] != null 
            ? (data['dueDate'] as Timestamp).toDate() 
            : DateTime.now(),
        'tasks': List<Map<String, dynamic>>.from(data['tasks'] ?? []),
        'assignedStudents': List<String>.from(data['assignedStudents'] ?? []),
        'completedStudents': List<String>.from(data['completedStudents'] ?? []),
        'fileUrls': List<String>.from(data['fileUrls'] ?? []),
      };
    } catch (e) {
      throw Exception('Ödev getirilirken hata: $e');
    }
  }

  // Ödevi güncelle
  Future<void> updateHomework({
    required String homeworkId,
    String? title,
    String? description,
    DateTime? dueDate,
    List<Map<String, dynamic>>? tasks,
    List<String>? assignedStudents,
    List<String>? fileUrls,
  }) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Ödevin bu öğretmene ait olduğunu doğrula
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();

      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }

      final data = homeworkDoc.data() as Map<String, dynamic>;
      if (data['teacherId'] != teacherId) {
        throw Exception('Bu ödevi düzenleme yetkiniz yok');
      }

      // Güncellenecek alanları belirle
      Map<String, dynamic> updates = {};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
      if (tasks != null) updates['tasks'] = tasks;
      if (assignedStudents != null) updates['assignedStudents'] = assignedStudents;
      if (fileUrls != null) updates['fileUrls'] = fileUrls;

      // Ödevi güncelle
      await _firestore.collection('homeworks').doc(homeworkId).update(updates);
    } catch (e) {
      throw Exception('Ödev güncellenirken hata: $e');
    }
  }

  // Ödevi sil
  Future<void> deleteHomework(String homeworkId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Ödevin bu öğretmene ait olduğunu doğrula
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();

      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }

      final data = homeworkDoc.data() as Map<String, dynamic>;
      if (data['teacherId'] != teacherId) {
        throw Exception('Bu ödevi silme yetkiniz yok');
      }

      // Ödevi sil
      await _firestore.collection('homeworks').doc(homeworkId).delete();
    } catch (e) {
      throw Exception('Ödev silinirken hata: $e');
    }
  }

  // Ödev cevaplarını kaydet (öğrenci tarafı)
  Future<void> submitHomework(
    String homeworkId, 
    List<Map<String, dynamic>> completedTasks,
    List<String>? fileUrls,
  ) async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Ödevi kontrol et
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();

      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }

      final homeworkData = homeworkDoc.data() as Map<String, dynamic>;
      
      // Öğrencinin bu ödeve atandığını kontrol et
      final assignedStudents = List<String>.from(homeworkData['assignedStudents'] ?? []);
      if (!assignedStudents.contains(studentId)) {
        throw Exception('Bu ödeve erişim yetkiniz yok');
      }

      // Öğrencinin daha önce ödevi tamamlamadığından emin ol
      final completedStudents = List<String>.from(homeworkData['completedStudents'] ?? []);
      if (completedStudents.contains(studentId)) {
        throw Exception('Bu ödevi zaten tamamladınız');
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

      // Ödev cevaplarını kaydet
      await _firestore.collection('homework_submissions').add({
        'homeworkId': homeworkId,
        'homeworkTitle': homeworkData['title'] ?? 'İsimsiz Ödev',
        'studentId': studentId,
        'studentName': studentName,
        'completedTasks': completedTasks,
        'fileUrls': fileUrls ?? [],
        'submittedAt': FieldValue.serverTimestamp(),
        'graded': false,
        'score': 0,
        'feedback': '',
        'gradedBy': '',
        'gradedAt': null,
      });

      // Öğrenciyi tamamlayanlar listesine ekle
      await _firestore.collection('homeworks').doc(homeworkId).update({
        'completedStudents': FieldValue.arrayUnion([studentId]),
      });

      return;
    } catch (e) {
      throw Exception('Ödev gönderilirken hata: $e');
    }
  }
  
  // Bir ödevi tamamlayan öğrencilerin listesini getir (öğretmen tarafı)
  Future<List<Map<String, dynamic>>> getHomeworkSubmissions(String homeworkId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Ödevin bu öğretmene ait olduğunu doğrula
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();
          
      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }
      
      final homeworkData = homeworkDoc.data() as Map<String, dynamic>?;
      if (homeworkData == null) {
        throw Exception('Ödev verisi bulunamadı');
      }
      
      if (homeworkData['teacherId'] != teacherId) {
        throw Exception('Bu ödeve erişim yetkiniz yok');
      }
      
      // Bu ödeve ait cevapları getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('homework_submissions')
          .where('homeworkId', isEqualTo: homeworkId)
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
          'completedTasks': List<Map<String, dynamic>>.from(data['completedTasks'] ?? []),
          'fileUrls': List<String>.from(data['fileUrls'] ?? []),
        });
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Ödev cevapları getirilirken hata: $e');
    }
  }
  
  // Bir öğrencinin ödev cevaplarını getir
  Future<Map<String, dynamic>> getStudentHomeworkSubmission(String homeworkId, String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Ödevi getir
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();
          
      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }
      
      final homeworkData = homeworkDoc.data() as Map<String, dynamic>?;
      if (homeworkData == null) {
        throw Exception('Ödev verisi bulunamadı');
      }
      
      // Öğretmen veya ilgili öğrenci mi kontrol et
      bool hasAccess = false;
      if (userId == homeworkData['teacherId'] || userId == studentId) {
        hasAccess = true;
      }
      
      if (!hasAccess) {
        throw Exception('Bu ödev cevaplarına erişim yetkiniz yok');
      }
      
      // Öğrencinin cevaplarını getir
      QuerySnapshot submissionSnapshot = await _firestore
          .collection('homework_submissions')
          .where('homeworkId', isEqualTo: homeworkId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
          
      if (submissionSnapshot.docs.isEmpty) {
        throw Exception('Öğrenci ödevi henüz tamamlamamış');
      }
      
      final submissionData = submissionSnapshot.docs.first.data() as Map<String, dynamic>;
      final submissionId = submissionSnapshot.docs.first.id;
      
      // Ödevin görevlerini getir
      final tasks = List<Map<String, dynamic>>.from(homeworkData['tasks'] ?? []);
      
      // Öğretmen tarafından yüklenen dosyaları içerecek şekilde ödev verisini hazırla
      final Map<String, dynamic> homeworkDataClean = {
        'id': homeworkId,
        'title': homeworkData['title'] ?? '',
        'description': homeworkData['description'] ?? '',
        'dueDate': homeworkData['dueDate'],
        'fileUrls': List<String>.from(homeworkData['fileUrls'] ?? []),
        'teacherId': homeworkData['teacherId'],
      };
      
      return {
        'id': submissionId,
        'homeworkId': homeworkId,
        'homeworkTitle': homeworkData['title'] ?? '',
        'studentId': studentId,
        'studentName': submissionData['studentName'] ?? 'İsimsiz Öğrenci',
        'submittedAt': submissionData['submittedAt'] ?? Timestamp.now(),
        'graded': submissionData['graded'] ?? false,
        'score': submissionData['score'] ?? 0,
        'feedback': submissionData['feedback'] ?? '',
        'completedTasks': List<Map<String, dynamic>>.from(submissionData['completedTasks'] ?? []),
        'fileUrls': List<String>.from(submissionData['fileUrls'] ?? []),
        'tasks': tasks,
        'homeworkData': homeworkDataClean, // Öğretmenin yüklediği dosyalar için ödev verisini ekle
      };
    } catch (e) {
      throw Exception('Öğrenci ödev cevapları getirilirken hata: $e');
    }
  }
  
  // Ödev cevaplarını puanla (öğretmen tarafı)
  Future<void> gradeHomework(String submissionId, int score, String feedback) async {
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
          .collection('homework_submissions')
          .doc(submissionId)
          .get();
          
      if (!submissionDoc.exists) {
        throw Exception('Ödev cevabı bulunamadı');
      }
      
      final submissionData = submissionDoc.data() as Map<String, dynamic>?;
      if (submissionData == null) {
        throw Exception('Ödev cevabı verisi bulunamadı');
      }
      
      final homeworkId = submissionData['homeworkId'] as String?;
      if (homeworkId == null) {
        throw Exception('Ödev ID\'si bulunamadı');
      }
      
      // Ödevin bu öğretmene ait olduğunu doğrula
      DocumentSnapshot homeworkDoc = await _firestore
          .collection('homeworks')
          .doc(homeworkId)
          .get();
          
      if (!homeworkDoc.exists) {
        throw Exception('Ödev bulunamadı');
      }
      
      final homeworkData = homeworkDoc.data() as Map<String, dynamic>?;
      if (homeworkData == null) {
        throw Exception('Ödev verisi bulunamadı');
      }
      
      if (homeworkData['teacherId'] != teacherId) {
        throw Exception('Bu ödevi puanlama yetkiniz yok');
      }
      
      // Submission'ı güncelle
      await _firestore.collection('homework_submissions').doc(submissionId).update({
        'graded': true,
        'score': score,
        'feedback': feedback,
        'gradedBy': teacherId,
        'gradedByName': teacherName,
        'gradedAt': FieldValue.serverTimestamp(),
      });
      
      // Öğrenci bilgisini al
      final studentId = submissionData['studentId'] as String?;
      if (studentId == null) {
        throw Exception('Öğrenci ID\'si bulunamadı');
      }
      
      // Öğrencinin ödev kayıtlarına ekle (öğrenci profili için)
      await _firestore.collection('student_homework_scores').add({
        'studentId': studentId,
        'homeworkId': homeworkId,
        'submissionId': submissionId,
        'homeworkTitle': submissionData['homeworkTitle'] ?? 'İsimsiz Ödev',
        'score': score,
        'maxScore': 100, // Maksimum puan varsayılan olarak 100
        'gradedBy': teacherId,
        'gradedByName': teacherName,
        'gradedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      throw Exception('Ödev puanlanırken hata: $e');
    }
  }
  
  // Öğrencinin ödev puanlarını getir (profili için)
  Future<List<Map<String, dynamic>>> getStudentHomeworkScores(String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmen veya ilgili öğrenci olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;
      
      bool hasAccess = userId == studentId || userRole == 'teacher';
      
      if (!hasAccess) {
        throw Exception('Bu puanlara erişim yetkiniz yok');
      }
      
      // Öğrencinin ödev puanlarını getir
      QuerySnapshot scoresSnapshot = await _firestore
          .collection('student_homework_scores')
          .where('studentId', isEqualTo: studentId)
          .orderBy('gradedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> scores = [];
      
      for (var doc in scoresSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        scores.add({
          'id': doc.id,
          'homeworkId': data['homeworkId'] ?? '',
          'submissionId': data['submissionId'] ?? '',
          'homeworkTitle': data['homeworkTitle'] ?? 'İsimsiz Ödev',
          'score': data['score'] ?? 0,
          'maxScore': data['maxScore'] ?? 100,
          'gradedBy': data['gradedByName'] ?? 'İsimsiz Öğretmen',
          'gradedAt': data['gradedAt'] ?? Timestamp.now(),
          'percentage': (data['score'] ?? 0) / (data['maxScore'] ?? 100) * 100,
        });
      }
      
      return scores;
    } catch (e) {
      throw Exception('Öğrenci ödev puanları getirilirken hata: $e');
    }
  }

  // Mevcut kullanıcının ID'sini getir
  String? getCurrentUserId() {
    try {
      return _auth.currentUser?.uid;
    } catch (e) {
      print('getCurrentUserId hatası: $e');
      return null;
    }
  }

  // Öğrencinin tamamladığı ödevleri getir
  Future<List<Map<String, dynamic>>> getCurrentStudentSubmittedHomeworks() async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğrencinin gönderdiği ödevleri getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('homework_submissions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> submissions = [];
      
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final homeworkId = data['homeworkId'] as String;
        
        try {
          // İlgili ödev bilgilerini getir
          DocumentSnapshot homeworkDoc = await _firestore
              .collection('homeworks')
              .doc(homeworkId)
              .get();
              
          if (homeworkDoc.exists) {
            final homeworkData = homeworkDoc.data() as Map<String, dynamic>;
            
            submissions.add({
              'id': doc.id,
              'homeworkId': homeworkId,
              'homeworkTitle': homeworkData['title'] ?? 'İsimsiz Ödev',
              'submittedAt': data['submittedAt'],
              'graded': data['graded'] ?? false,
              'score': data['score'] ?? 0,
              'feedback': data['feedback'] ?? '',
              'fileUrls': List<String>.from(data['fileUrls'] ?? []),
              'teacherFileUrls': List<String>.from(homeworkData['fileUrls'] ?? []),
            });
          }
        } catch (e) {
          print('Ödev bilgisi alınırken hata: $e');
          // Hata durumunda bu ödevi atla
        }
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Öğrenci ödevleri getirilirken hata: $e');
    }
  }

  // Bir öğrencinin tamamladığı ödevleri getir - öğretmen tarafı
  Future<List<Map<String, dynamic>>> getStudentSubmittedHomeworks(String studentId) async {
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
      
      // Öğrencinin gönderdiği ödevleri getir
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('homework_submissions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .get();
          
      List<Map<String, dynamic>> submissions = [];
      
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final homeworkId = data['homeworkId'] as String;
        
        try {
          // İlgili ödev bilgilerini getir
          DocumentSnapshot homeworkDoc = await _firestore
              .collection('homeworks')
              .doc(homeworkId)
              .get();
              
          if (homeworkDoc.exists) {
            submissions.add({
              'id': doc.id,
              'homeworkId': homeworkId,
              'homeworkTitle': data['homeworkTitle'] ?? 'İsimsiz Ödev',
              'submittedAt': data['submittedAt'],
              'graded': data['graded'] ?? false,
              'score': data['score'] ?? 0,
              'feedback': data['feedback'] ?? '',
              'fileUrls': List<String>.from(data['fileUrls'] ?? []),
              'completedTasks': List<Map<String, dynamic>>.from(data['completedTasks'] ?? []),
            });
          }
        } catch (e) {
          print('Ödev bilgisi alınırken hata: $e');
          // Hata olsa bile çalışmaya devam et
        }
      }
      
      return submissions;
    } catch (e) {
      throw Exception('Öğrenci ödevleri getirilirken hata: $e');
    }
  }
} 