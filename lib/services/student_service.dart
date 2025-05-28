import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Öğrencinin görevlerini getir (sınavlar ve ödevler)
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      print('StudentService: Görevler getiriliyor, öğrenci ID: $studentId');

      // Öğrencinin öğretmenlerini bul
      QuerySnapshot teacherRelations = await _firestore
          .collection('teacher_students')
          .where('studentId', isEqualTo: studentId)
          .get();

      List<String> teacherIds = [];
      
      for (var doc in teacherRelations.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['teacherId'] is String) {
          teacherIds.add(data['teacherId'] as String);
        }
      }

      print('StudentService: Bulunan öğretmen sayısı: ${teacherIds.length}');
      
      List<Map<String, dynamic>> tasks = [];

      // Her bir öğretmenin verdiği sınavları getir
      for (String teacherId in teacherIds) {
        print('StudentService: Öğretmen için sınavlar alınıyor: $teacherId');
        
        QuerySnapshot examsSnapshot = await _firestore
            .collection('exams')
            .where('teacherId', isEqualTo: teacherId)
            .where('assignedStudents', arrayContains: studentId)
            .get();

        print('StudentService: Bulunan sınav sayısı: ${examsSnapshot.docs.length}');
        
        for (var doc in examsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          print('StudentService: Sınav işleniyor: ${doc.id} - ${data['title']}');
          
          // Öğrencinin bu sınava katılım durumunu kontrol et
          String status = 'pending';
          if (data['completedStudents'] != null) {
            List<dynamic> completedStudents = data['completedStudents'] as List<dynamic>;
            if (completedStudents.contains(studentId)) {
              status = 'completed';
            }
          }
          
          tasks.add({
            'id': doc.id,
            'title': data['title']?.toString() ?? 'İsimsiz Sınav',
            'dueDate': data['dueDate'] != null
                ? _formatTimestamp(data['dueDate'] as Timestamp)
                : 'Tarih yok',
            'type': 'exam',
            'status': status,
          });
        }

        // Her bir öğretmenin verdiği ödevleri getir
        QuerySnapshot homeworksSnapshot = await _firestore
            .collection('homeworks')
            .where('teacherId', isEqualTo: teacherId)
            .where('assignedStudents', arrayContains: studentId)
            .get();

        for (var doc in homeworksSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          // Öğrencinin bu ödevi tamamlama durumunu kontrol et
          String status = 'pending';
          if (data['completedStudents'] != null) {
            List<dynamic> completedStudents = data['completedStudents'] as List<dynamic>;
            if (completedStudents.contains(studentId)) {
              status = 'completed';
            }
          }
          
          tasks.add({
            'id': doc.id,
            'title': data['title']?.toString() ?? 'İsimsiz Ödev',
            'dueDate': data['dueDate'] != null
                ? _formatTimestamp(data['dueDate'] as Timestamp)
                : 'Tarih yok',
            'type': 'homework',
            'status': status,
          });
        }
      }

      // Son teslim tarihine göre sırala
      tasks.sort((a, b) => a['dueDate'].compareTo(b['dueDate']));

      return tasks;
    } catch (e) {
      throw Exception('Görevler getirilirken hata: $e');
    }
  }

  // Öğrencinin sınıflarını getir
  Future<List<Map<String, dynamic>>> getClasses() async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğrencinin dahil olduğu sınıfları getir
      QuerySnapshot classesSnapshot = await _firestore
          .collection('classes')
          .where('studentIds', arrayContains: studentId)
          .get();

      List<Map<String, dynamic>> classes = [];

      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        // Öğretmen bilgisini getir - yeni yapıya uygun olarak
        String teacherName = 'Bilinmiyor';
        
        // teacherIds listesinden ilk öğretmeni kullanalım
        final teacherIds = List<String>.from(data['teacherIds'] ?? []);
        if (teacherIds.isNotEmpty) {
          final mainTeacherId = teacherIds[0];
          
          DocumentSnapshot teacherDoc = await _firestore
              .collection('users')
              .doc(mainTeacherId)
              .get();
          
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>?;
            if (teacherData != null) {
              teacherName = teacherData['name']?.toString() ?? 'Bilinmiyor';
            }
          }
        }
        
        // Sınıf seviyesini de ekleyelim
        String grade = data['grade']?.toString() ?? '';
        String classNameDisplay = data['name']?.toString() ?? '';
        
        // Eğer sınıf ismi grade ile başlamıyorsa ve grade bilgisi varsa ekleyelim
        if (grade.isNotEmpty && !classNameDisplay.contains(grade)) {
          classNameDisplay = '$classNameDisplay ($grade)';
        }
        
        classes.add({
          'id': doc.id,
          'name': classNameDisplay,
          'grade': grade,
          'teacherName': teacherName,
          'description': data['description']?.toString() ?? '',
        });
      }

      return classes;
    } catch (e) {
      throw Exception('Sınıflar getirilirken hata: $e');
    }
  }

  // Sınıf detayını getir
  Future<Map<String, dynamic>> getClassDetail(String classId) async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınıfı getir
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Sınıf bulunamadı');
      }

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Öğrencinin bu sınıfa dahil olup olmadığını kontrol et
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      if (!studentIds.contains(studentId)) {
        throw Exception('Bu sınıfa erişim izniniz yok');
      }

      // Öğretmen bilgisini getir - yeni yapıya uygun olarak
      String teacherName = 'Bilinmiyor';
      String teacherId = '';
        
      // teacherIds listesinden ilk öğretmeni kullanalım
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      if (teacherIds.isNotEmpty) {
        teacherId = teacherIds[0];
        
        DocumentSnapshot teacherDoc = await _firestore
            .collection('users')
            .doc(teacherId)
            .get();
        
        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() as Map<String, dynamic>?;
          if (teacherData != null) {
            teacherName = teacherData['name']?.toString() ?? 'Bilinmiyor';
          }
        }
      }
      
      // Öğrenciler için isCurrentStudent ekleyelim
      List<Map<String, dynamic>> students = [];
      for (String id in studentIds) {
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(id)
            .get();
            
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>?;
          if (studentData != null) {
            students.add({
              'id': id,
              'name': studentData['name']?.toString() ?? 'İsimsiz Öğrenci',
              'email': studentData['email']?.toString() ?? '',
              'isCurrentStudent': id == studentId,
            });
          }
        }
      }
      
      // Sınıf seviyesini de ekleyelim
      String grade = data['grade']?.toString() ?? '';
      String classNameDisplay = data['name']?.toString() ?? '';
      
      // Eğer sınıf ismi grade ile başlamıyorsa ve grade bilgisi varsa ekleyelim
      if (grade.isNotEmpty && !classNameDisplay.contains(grade)) {
        classNameDisplay = '$classNameDisplay ($grade)';
      }
      
      return {
        'id': classDoc.id,
        'name': classNameDisplay,
        'grade': grade,
        'description': data['description']?.toString() ?? '',
        'teacherName': teacherName,
        'teacherId': teacherId,
        'studentCount': studentIds.length,
        'students': students,
        'createdAt': _formatTimestamp(data['createdAt'] as Timestamp? ?? Timestamp.now()),
      };
    } catch (e) {
      throw Exception('Sınıf detayı getirilirken hata: $e');
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

  // Daha güvenli sınıf detayı getirme - hata vermek yerine durumu belirten bir bilgi döndürür
  Future<Map<String, dynamic>> getClassDetailSafe(String classId) async {
    try {
      if (classId.isEmpty) {
        return {
          'exists': false,
          'hasAccess': false,
          'error': 'Geçersiz sınıf ID\'si',
          'students': []
        };
      }
      
      final String? studentId = getCurrentUserId();
      if (studentId == null || studentId.isEmpty) {
        return {
          'exists': false,
          'hasAccess': false,
          'error': 'Kullanıcı oturumu bulunamadı',
          'students': []
        };
      }

      // Sınıfı getir
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        return {
          'exists': false,
          'hasAccess': false,
          'error': 'Sınıf bulunamadı',
          'students': []
        };
      }

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        return {
          'exists': false,
          'hasAccess': false,
          'error': 'Sınıf verisi bulunamadı',
          'students': []
        };
      }

      // Öğrencinin bu sınıfa dahil olup olmadığını kontrol et
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      final bool hasAccess = studentIds.contains(studentId);
      
      // Öğretmen bilgisini getir - yeni yapıya uygun olarak
      String teacherName = 'Bilinmiyor';
      String teacherId = '';
        
      // teacherIds listesinden ilk öğretmeni kullanalım
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      if (teacherIds.isNotEmpty) {
        teacherId = teacherIds[0];
        
        try {
          DocumentSnapshot teacherDoc = await _firestore
              .collection('users')
              .doc(teacherId)
              .get();
          
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>?;
            if (teacherData != null) {
              teacherName = teacherData['name']?.toString() ?? 'Bilinmiyor';
            }
          }
        } catch (e) {
          print('Öğretmen bilgisi getirilemedi: $e');
        }
      }
      
      // Öğrencileri getir
      List<Map<String, dynamic>> students = [];
      
      for (String id in studentIds) {
        try {
          DocumentSnapshot studentDoc = await _firestore
              .collection('users')
              .doc(id)
              .get();
              
          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>?;
            if (studentData != null) {
              students.add({
                'id': id,
                'name': studentData['name']?.toString() ?? 'İsimsiz Öğrenci',
                'email': studentData['email']?.toString() ?? '',
                'isCurrentStudent': id == studentId,
              });
            }
          }
        } catch (e) {
          print('Öğrenci bilgisi getirilemedi: $e');
        }
      }
      
      // Sınıf seviyesini de ekleyelim
      String grade = data['grade']?.toString() ?? '';
      String classNameDisplay = data['name']?.toString() ?? '';
      
      // Eğer sınıf ismi grade ile başlamıyorsa ve grade bilgisi varsa ekleyelim
      if (grade.isNotEmpty && !classNameDisplay.contains(grade)) {
        classNameDisplay = '$classNameDisplay ($grade)';
      }
      
      return {
        'exists': true,
        'hasAccess': hasAccess,
        'id': classDoc.id,
        'name': classNameDisplay,
        'description': data['description']?.toString() ?? '',
        'teacherName': teacherName,
        'teacherId': teacherId,
        'grade': grade,
        'studentCount': studentIds.length,
        'students': students,
        'createdAt': data['createdAt'] != null
            ? _formatTimestamp(data['createdAt'] as Timestamp)
            : '',
      };
    } catch (e) {
      print('getClassDetailSafe hatası: $e');
      return {
        'exists': false,
        'hasAccess': false,
        'error': 'Sınıf detayı getirilirken hata: $e',
        'students': []
      };
    }
  }

  // Bir öğrencinin profilini getir (diğer öğrenciler için)
  Future<Map<String, dynamic>> getStudentProfile(String studentId) async {
    try {
      // Öğrenci bilgilerini getir
      DocumentSnapshot studentDoc = await _firestore
          .collection('users')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Öğrenci bulunamadı');
      }

      final data = studentDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Öğrenci verisi bulunamadı');
      }

      // Öğrenci sınıf bilgisini getir
      String grade = 'Bilinmiyor';
      String className = '';
      
      // Öğrencinin ilişkili olduğu sınıfları getir
      QuerySnapshot classesSnapshot = await _firestore
          .collection('classes')
          .where('studentIds', arrayContains: studentId)
          .get();
      
      if (classesSnapshot.docs.isNotEmpty) {
        final classData = classesSnapshot.docs.first.data() as Map<String, dynamic>?;
        if (classData != null) {
          grade = classData['grade']?.toString() ?? 'Bilinmiyor';
          className = classData['name']?.toString() ?? '';
        }
      }
      
      // Teacher-Student ilişkisinden grade bilgisini al (yedek yöntem)
      if (grade == 'Bilinmiyor') {
        QuerySnapshot teacherStudentSnapshot = await _firestore
            .collection('teacher_students')
            .where('studentId', isEqualTo: studentId)
            .get();
        
        if (teacherStudentSnapshot.docs.isNotEmpty) {
          final teacherStudentData = teacherStudentSnapshot.docs.first.data() as Map<String, dynamic>?;
          if (teacherStudentData != null && teacherStudentData['grade'] != null) {
            grade = teacherStudentData['grade'].toString();
          }
        }
      }

      // Öğrencinin sorularını getir
      QuerySnapshot questionsSnapshot = await _firestore
          .collection('questions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> recentQuestions = [];
      
      for (var doc in questionsSnapshot.docs) {
        final questionData = doc.data() as Map<String, dynamic>?;
        if (questionData == null) continue;
        
        recentQuestions.add({
          'id': doc.id,
          'title': questionData['title']?.toString() ?? '',
          'status': questionData['answered'] == true ? 'Cevaplandı' : 'Bekliyor',
          'createdAt': _formatTimestamp(questionData['createdAt'] as Timestamp? ?? Timestamp.now()),
        });
      }

      return {
        'id': studentId,
        'name': data['name']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'grade': grade,
        'className': className,
        'joinDate': _formatTimestamp(data['createdAt'] as Timestamp? ?? Timestamp.now()),
        'recentQuestions': recentQuestions,
      };
    } catch (e) {
      throw Exception('Öğrenci profili getirilirken hata: $e');
    }
  }

  // Öğrencinin sorularını getir
  Future<List<Map<String, dynamic>>> getQuestions({String? studentId}) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      // Kullanıcı rolünü al
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;
      final String targetStudentId = studentId ?? userId;
      bool hasAccess = userId == targetStudentId || userRole == 'teacher';
      if (!hasAccess) {
        throw Exception('Bu sorulara erişim yetkiniz yok');
      }
      // Öğrencinin sorduğu soruları getir
      QuerySnapshot questionsSnapshot = await _firestore
          .collection('questions')
          .where('studentId', isEqualTo: targetStudentId)
          .orderBy('createdAt', descending: true)
          .get();
      List<Map<String, dynamic>> questions = [];
      for (var doc in questionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        questions.add({
          'id': doc.id,
          'title': data['title'] ?? 'İsimsiz Soru',
          'date': data['createdAt'] != null
              ? _formatTimestamp(data['createdAt'] as Timestamp)
              : 'Zaman bilgisi yok',
          'status': data['answered'] == true ? 'answered' : 'pending',
        });
      }
      return questions;
    } catch (e) {
      throw Exception('Sorular getirilirken hata: $e');
    }
  }

  // Soru ekle
  Future<void> addQuestion(String title, String content, String? imageUrl) async {
    try {
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğrencinin öğretmen ilişkilerini getir
      QuerySnapshot teacherRelations = await _firestore
          .collection('teacher_students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (teacherRelations.docs.isEmpty) {
        throw Exception('Henüz bir öğretmeniniz yok');
      }

      String teacherId = (teacherRelations.docs.first.data() 
          as Map<String, dynamic>)['teacherId'] as String;

      // Yeni soru oluştur
      await _firestore.collection('questions').add({
        'studentId': studentId,
        'teacherId': teacherId,
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'answered': false,
        'answer': null,
        'answerDate': null,
      });
    } catch (e) {
      throw Exception('Soru eklenirken hata: $e');
    }
  }

  // Tarih formatını düzenle
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} dakika önce';
      }
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Bir öğrencinin detaylarını getir (öğretmen tarafı)
  Future<Map<String, dynamic>> getStudentDetails(String studentId) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmen rolünü kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;
      
      // Sadece öğretmenler veya öğrencinin kendisi erişebilir
      if (userRole != 'teacher' && userId != studentId) {
        throw Exception('Bu bilgilere erişim yetkiniz yok');
      }
      
      // Öğrenci bilgilerini getir
      DocumentSnapshot studentDoc = await _firestore
          .collection('users')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Öğrenci bulunamadı');
      }

      final data = studentDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Öğrenci verisi bulunamadı');
      }
      
      // Öğrenci sınıf bilgisini getir
      String grade = 'Bilinmiyor';
      String className = '';
      
      // Öğrencinin ilişkili olduğu sınıfları getir
      QuerySnapshot classesSnapshot = await _firestore
          .collection('classes')
          .where('studentIds', arrayContains: studentId)
          .get();
      
      if (classesSnapshot.docs.isNotEmpty) {
        final classData = classesSnapshot.docs.first.data() as Map<String, dynamic>?;
        if (classData != null) {
          grade = classData['grade']?.toString() ?? 'Bilinmiyor';
          className = classData['name']?.toString() ?? '';
        }
      }
      
      // Öğrencinin ödev ve sınav istatistiklerini getir
      Map<String, dynamic> homeworkStats = {
        'completed': 0,
        'total': 0,
      };
      
      Map<String, dynamic> examStats = {
        'average': '0',
        'count': 0,
      };
      
      try {
        // Ödev sayılarını getir
        QuerySnapshot homeworkSubmissionsSnapshot = await _firestore
            .collection('homework_submissions')
            .where('studentId', isEqualTo: studentId)
            .get();
        
        homeworkStats['completed'] = homeworkSubmissionsSnapshot.docs.length;
        
        // Sınav puanlarını getir
        QuerySnapshot examScoresSnapshot = await _firestore
            .collection('student_exam_scores')
            .where('studentId', isEqualTo: studentId)
            .get();
        
        examStats['count'] = examScoresSnapshot.docs.length;
        
        if (examScoresSnapshot.docs.isNotEmpty) {
          double totalScore = 0;
          for (var doc in examScoresSnapshot.docs) {
            final examData = doc.data() as Map<String, dynamic>;
            totalScore += (examData['score'] as num?) ?? 0;
          }
          
          double averageScore = totalScore / examScoresSnapshot.docs.length;
          examStats['average'] = averageScore.toStringAsFixed(1);
        }
      } catch (e) {
        print('Öğrenci istatistikleri getirilemedi: $e');
      }
      
      return {
        'id': studentId,
        'name': data['name']?.toString() ?? 'İsimsiz Öğrenci',
        'email': data['email']?.toString() ?? '',
        'phone': data['phone']?.toString() ?? '',
        'grade': grade,
        'className': className,
        'joinDate': data['createdAt'] != null
            ? _formatTimestamp(data['createdAt'] as Timestamp)
            : 'Bilinmiyor',
        'lastLogin': data['lastLogin'] != null
            ? _formatTimestamp(data['lastLogin'] as Timestamp)
            : 'Bilinmiyor',
        'homeworkStats': homeworkStats,
        'examStats': examStats,
      };
    } catch (e) {
      throw Exception('Öğrenci detayları getirilirken hata: $e');
    }
  }
} 