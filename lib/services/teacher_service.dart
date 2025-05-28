import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class TeacherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Öğretmenleri getir
  Future<List<Map<String, dynamic>>> getTeachers() async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmen rolüne sahip tüm kullanıcıları getir
      final QuerySnapshot teachersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      List<Map<String, dynamic>> teachers = [];

      for (var doc in teachersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final teacherId = doc.id;
        
        // Geçerli öğretmeni özel olarak işaretle
        final bool isCurrentTeacher = teacherId == currentTeacherId;
        
        teachers.add({
          'id': teacherId,
          'name': data['name']?.toString() ?? 'İsimsiz Öğretmen',
          'email': data['email']?.toString() ?? '',
          'isCurrentTeacher': isCurrentTeacher,
        });
      }

      return teachers;
    } catch (e) {
      throw Exception('Öğretmenler getirilirken hata: $e');
    }
  }

  // Öğretmenin öğrencilerini getir
  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmenle ilişkilendirilmiş öğrencileri getir
      QuerySnapshot studentsSnapshot = await _firestore
          .collection('teacher_students')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      List<Map<String, dynamic>> students = [];

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final studentId = data['studentId'] as String?;
        if (studentId == null) continue;

        // Öğrenci bilgilerini getir
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>?;
          if (studentData == null) continue;
          
          students.add({
            'id': studentId,
            'name': studentData['name']?.toString() ?? '',
            'email': studentData['email']?.toString() ?? '',
            'grade': data['grade']?.toString() ?? '',
            'lastActivity': studentData['lastLogin'] != null
                ? _formatTimestamp(studentData['lastLogin'] as Timestamp)
                : 'Bilinmiyor',
          });
        }
      }

      return students;
    } catch (e) {
      throw Exception('Öğrenciler getirilirken hata: $e');
    }
  }

  // Öğretmenin sınav ve ödevlerini getir
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmenin oluşturduğu sınavları getir
      QuerySnapshot examsSnapshot = await _firestore
          .collection('exams')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('dueDate', descending: false)
          .get();

      // Öğretmenin oluşturduğu ödevleri getir
      QuerySnapshot homeworksSnapshot = await _firestore
          .collection('homeworks')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('dueDate', descending: false)
          .get();

      List<Map<String, dynamic>> tasks = [];

      // Sınavları listeye ekle
      for (var doc in examsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Atanan öğrenci sayısını ve bilgilerini ekle
        final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
        final completedStudents = List<String>.from(data['completedStudents'] ?? []);
        
        // Öğrenci isimlerini getir (ilk 3 öğrenci)
        final studentNames = await _getStudentNamesPreview(assignedStudents);
        
        tasks.add({
          'id': doc.id,
          'title': data['title'] ?? 'İsimsiz Sınav',
          'dueDate': data['dueDate'] != null
              ? _formatTimestamp(data['dueDate'] as Timestamp)
              : 'Tarih yok',
          'type': 'exam',
          'assignedStudentCount': assignedStudents.length,
          'completedStudentCount': completedStudents.length,
          'studentNames': studentNames,
          'assignedStudents': assignedStudents,
        });
      }

      // Ödevleri listeye ekle
      for (var doc in homeworksSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Atanan öğrenci sayısını ve bilgilerini ekle
        final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
        final completedStudents = List<String>.from(data['completedStudents'] ?? []);
        
        // Öğrenci isimlerini getir (ilk 3 öğrenci)
        final studentNames = await _getStudentNamesPreview(assignedStudents);
        
        tasks.add({
          'id': doc.id,
          'title': data['title'] ?? 'İsimsiz Ödev',
          'dueDate': data['dueDate'] != null
              ? _formatTimestamp(data['dueDate'] as Timestamp)
              : 'Tarih yok',
          'type': 'homework',
          'assignedStudentCount': assignedStudents.length,
          'completedStudentCount': completedStudents.length,
          'studentNames': studentNames,
          'assignedStudents': assignedStudents,
        });
      }

      // Son teslim tarihine göre sırala
      tasks.sort((a, b) => a['dueDate'].compareTo(b['dueDate']));

      return tasks;
    } catch (e) {
      throw Exception('Görevler getirilirken hata: $e');
    }
  }
  
  // Belirli öğrencilerin isimlerini getir (ilk 3 öğrenci ve toplam sayı)
  Future<String> _getStudentNamesPreview(List<String> studentIds) async {
    if (studentIds.isEmpty) return 'Öğrenci atanmamış';
    
    try {
      List<String> names = [];
      
      // İlk 3 öğrencinin bilgilerini getir
      for (int i = 0; i < min(3, studentIds.length); i++) {
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(studentIds[i])
            .get();
            
        if (studentDoc.exists) {
          final data = studentDoc.data() as Map<String, dynamic>?;
          if (data != null && data['name'] != null) {
            names.add(data['name'] as String);
          }
        }
      }
      
      if (names.isEmpty) return 'Öğrenci adı alınamadı';
      
      // İlk 3 öğrenci + daha fazla varsa belirt
      if (studentIds.length <= 3) {
        return names.join(', ');
      } else {
        return '${names.join(', ')} ve ${studentIds.length - 3} öğrenci daha';
      }
    } catch (e) {
      return 'Öğrenci bilgileri alınamadı';
    }
  }
  
  // Bir ödevin veya sınavın tamamlanma durumunu görmek için
  Future<Map<String, dynamic>> getTaskCompletionStatus(String taskId, String taskType) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Koleksiyon adını belirle
      final collectionName = taskType == 'exam' ? 'exams' : 'homeworks';
      
      // Görevi getir
      DocumentSnapshot taskDoc = await _firestore
          .collection(collectionName)
          .doc(taskId)
          .get();
          
      if (!taskDoc.exists) {
        throw Exception('Görev bulunamadı');
      }
      
      final data = taskDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Görev verisi bulunamadı');
      }
      
      if (data['teacherId'] != teacherId) {
        throw Exception('Bu görevi görüntüleme yetkiniz yok');
      }
      
      // Atanan ve tamamlayan öğrencileri al
      final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
      final completedStudents = List<String>.from(data['completedStudents'] ?? []);
      
      // Öğrenci bilgilerini getir
      List<Map<String, dynamic>> assignedStudentDetails = [];
      for (String studentId in assignedStudents) {
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();
            
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>?;
          if (studentData != null) {
            assignedStudentDetails.add({
              'id': studentId,
              'name': studentData['name']?.toString() ?? 'İsimsiz Öğrenci',
              'completed': completedStudents.contains(studentId),
            });
          }
        }
      }
      
      return {
        'totalAssigned': assignedStudents.length,
        'totalCompleted': completedStudents.length,
        'students': assignedStudentDetails,
      };
    } catch (e) {
      throw Exception('Görev tamamlama durumu alınamadı: $e');
    }
  }

  // Öğrenci ekle
  Future<void> addStudent(String email, String grade) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // E-posta ile öğrenciyi bul
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'student')
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('Bu e-posta adresine sahip öğrenci bulunamadı');
      }

      final studentDoc = userSnapshot.docs.first;
      final String studentId = studentDoc.id;
      final studentData = studentDoc.data() as Map<String, dynamic>;
      final String studentName = studentData['name'] ?? 'İsimsiz Öğrenci';

      // Öğretmen-öğrenci ilişkisini kontrol et
      QuerySnapshot existingRelation = await _firestore
          .collection('teacher_students')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingRelation.docs.isNotEmpty) {
        throw Exception('Bu öğrenci zaten eklenmiş');
      }

      // Öğretmen-öğrenci ilişkisini ekle
      await _firestore.collection('teacher_students').add({
        'teacherId': teacherId,
        'studentId': studentId,
        'grade': grade,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Öğrencinin sınıfını oluştur veya mevcut sınıfa ekle
      // Önce öğretmenin grade için sınıfı var mı kontrol edelim
      QuerySnapshot existingClassSnapshot = await _firestore
          .collection('classes')
          .where('grade', isEqualTo: grade)
          .where('teacherIds', arrayContains: teacherId)
          .limit(1)
          .get();
      
      String classId;
      
      if (existingClassSnapshot.docs.isEmpty) {
        // Sınıf yoksa yeni sınıf oluştur
        DocumentReference classRef = await _firestore.collection('classes').add({
          'name': '$grade Sınıfı',
          'description': '$grade sınıfı öğrencileri',
          'grade': grade,
          'teacherIds': [teacherId],
          'studentIds': [studentId],
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': teacherId,
          'lastUpdatedBy': teacherId,
        });
        
        classId = classRef.id;
        
        // Sınıf sohbeti oluştur
        await _firestore.collection('class_chats').doc(classId).set({
          'classId': classId,
          'className': '$grade Sınıfı',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageText': 'Sınıf oluşturuldu',
          'lastMessageSender': studentName,
          'unreadCount': 0,
        });
        
      } else {
        // Sınıf varsa öğrenciyi sınıfa ekle
        DocumentSnapshot classDoc = existingClassSnapshot.docs.first;
        classId = classDoc.id;
        
        final classData = classDoc.data() as Map<String, dynamic>;
        List<String> studentIds = List<String>.from(classData['studentIds'] ?? []);
        
        if (!studentIds.contains(studentId)) {
          studentIds.add(studentId);
          await _firestore.collection('classes').doc(classId).update({
            'studentIds': studentIds,
            'lastUpdatedBy': teacherId,
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Öğrenci sil
  Future<void> removeStudent(String studentId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmen-öğrenci ilişkisini bul
      QuerySnapshot relation = await _firestore
          .collection('teacher_students')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (relation.docs.isEmpty) {
        throw Exception('Bu öğrenci size ait değil');
      }

      // İlişkiyi sil
      await _firestore.collection('teacher_students').doc(relation.docs.first.id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Sınıfları getir
  Future<List<Map<String, dynamic>>> getClasses() async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmenin erişimi olan sınıfları getir (teacherIds içerisinde olanlar)
      QuerySnapshot classesSnapshot = await _firestore
          .collection('classes')
          .where('teacherIds', arrayContains: currentTeacherId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> classes = [];

      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final studentIds = List<String>.from(data['studentIds'] ?? []);
        final teacherIds = List<String>.from(data['teacherIds'] ?? []);
        
        // Sınıf sahibi mi?
        final createdBy = data['createdBy'] as String?;
        final isCreator = (createdBy == currentTeacherId);
        
        classes.add({
          'id': doc.id,
          'name': data['name']?.toString() ?? '',
          'description': data['description']?.toString() ?? '',
          'studentCount': studentIds.length,
          'teacherCount': teacherIds.length,
          'isCreator': isCreator,
          'createdAt': _formatTimestamp(data['createdAt'] as Timestamp? ?? Timestamp.now()),
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
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfa erişim yetkiniz yok');
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

      final studentIds = List<String>.from(data['studentIds'] ?? []);
      List<Map<String, dynamic>> students = [];

      // Öğrenci bilgilerini getir
      for (String studentId in studentIds) {
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>?;
          if (studentData == null) continue;
          
          students.add({
            'id': studentId,
            'name': studentData['name']?.toString() ?? '',
            'email': studentData['email']?.toString() ?? '',
          });
        }
      }

      // Öğretmen bilgilerini de ekleyelim
      List<Map<String, dynamic>> teachers = [];
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      
      for (String teacherId in teacherIds) {
        DocumentSnapshot teacherDoc = await _firestore
            .collection('users')
            .doc(teacherId)
            .get();

        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() as Map<String, dynamic>?;
          if (teacherData == null) continue;
          
          teachers.add({
            'id': teacherId,
            'name': teacherData['name']?.toString() ?? '',
            'email': teacherData['email']?.toString() ?? '',
            'isCurrentTeacher': teacherId == currentTeacherId,
          });
        }
      }

      return {
        'id': classDoc.id,
        'name': data['name']?.toString() ?? '',
        'description': data['description']?.toString() ?? '',
        'createdAt': _formatTimestamp(data['createdAt'] as Timestamp? ?? Timestamp.now()),
        'students': students,
        'teachers': teachers,
        'createdBy': data['createdBy']?.toString() ?? '',
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
  
  // Öğretmenin sınıfa erişim yetkisini kontrol et - yeni güvenilir metot
  Future<bool> hasClassAccess(String classId) async {
    try {
      final String? currentTeacherId = getCurrentUserId();
      if (currentTeacherId == null || currentTeacherId.isEmpty) {
        print('[YETKİ HATASI]: Kullanıcı oturumu bulunamadı - classId: $classId');
        return false;
      }
      
      // Sınıfı getir
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();
          
      // Sınıf bulunamadı
      if (!classDoc.exists) {
        print('[YETKİ HATASI]: Sınıf bulunamadı - classId: $classId, teacherId: $currentTeacherId');
        return false;
      }
      
      // Sınıf verisi boş
      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        print('[YETKİ HATASI]: Sınıf verisi bulunamadı - classId: $classId, teacherId: $currentTeacherId');
        return false;
      }
      
      // Öğretmen ID'sini kontrol et, eski yöntem (geriye dönük uyumluluk)
      if (data.containsKey('teacherId') && data['teacherId'] == currentTeacherId) {
        return true;
      }
      
      // Öğretmenler listesini kontrol et
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      final hasAccess = teacherIds.contains(currentTeacherId);
      
      // Erişim yok - loglayalım
      if (!hasAccess) {
        print('[YETKİ HATASI]: Erişim reddedildi - classId: $classId, teacherId: $currentTeacherId, teacherIds: $teacherIds');
      }
      
      return hasAccess;
    } catch (e) {
      print('[YETKİ HATASI] - EXCEPTION: $e');
      return false;
    }
  }
  
  // Sınıfı var olup olmadığını kontrol et
  Future<bool> checkClassExists(String classId) async {
    try {
      if (classId.isEmpty) {
        return false;
      }
      
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();
          
      return classDoc.exists;
    } catch (e) {
      print('checkClassExists hatası: $e');
      return false;
    }
  }

  // Daha güvenli sınıf detayı getirme (yeni yapı) - hata vermek yerine durumu belirten bir bilgi döndürür
  Future<Map<String, dynamic>> getClassDetailSafe(String classId) async {
    try {
      if (classId.isEmpty) {
        return {
          'error': 'Geçersiz sınıf ID\'si',
          'exists': false,
          'hasAccess': false,
          'students': [],
          'teachers': []
        };
      }
      
      final String? currentTeacherId = getCurrentUserId();
      if (currentTeacherId == null || currentTeacherId.isEmpty) {
        return {
          'error': 'Kullanıcı oturumu bulunamadı',
          'exists': false,
          'hasAccess': false,
          'students': [],
          'teachers': []
        };
      }

      // Sınıfı getir
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        return {
          'error': 'Sınıf bulunamadı',
          'exists': false,
          'hasAccess': false,
          'students': [],
          'teachers': []
        };
      }

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        return {
          'error': 'Sınıf verisi bulunamadı',
          'exists': false,
          'hasAccess': false,
          'students': [],
          'teachers': []
        };
      }

      // Öğretmen yetkisini kontrol et - basitleştirilmiş
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      final bool hasAccess = teacherIds.contains(currentTeacherId);
      if (!hasAccess) {
        print('[YETKİ HATASI - getClassDetailSafe]: Erişim reddedildi - classId: $classId, teacherId: $currentTeacherId, teacherIds: $teacherIds');
      }
      
      // Öğrenci bilgilerini getir
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      List<Map<String, dynamic>> students = [];
      
      for (String studentId in studentIds) {
        try {
          DocumentSnapshot studentDoc = await _firestore
              .collection('users')
              .doc(studentId)
              .get();
              
          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>?;
            if (studentData != null) {
              students.add({
                'id': studentId,
                'name': studentData['name']?.toString() ?? 'İsimsiz Öğrenci',
                'email': studentData['email']?.toString() ?? '',
              });
            }
          }
        } catch (e) {
          print('Öğrenci bilgisi getirme hatası: $e');
          // Hata durumunda döngüye devam et
        }
      }
      
      // Öğretmen bilgilerini getir
      List<Map<String, dynamic>> teachers = [];
      for (String teacherId in teacherIds) {
        try {
          DocumentSnapshot teacherDoc = await _firestore
              .collection('users')
              .doc(teacherId)
              .get();
              
          if (teacherDoc.exists) {
            final teacherData = teacherDoc.data() as Map<String, dynamic>?;
            if (teacherData != null) {
              teachers.add({
                'id': teacherId,
                'name': teacherData['name']?.toString() ?? 'İsimsiz Öğretmen',
                'email': teacherData['email']?.toString() ?? '',
                'isCurrentTeacher': teacherId == currentTeacherId,
              });
            }
          }
        } catch (e) {
          print('Öğretmen bilgisi getirme hatası: $e');
          // Hata durumunda döngüye devam et
        }
      }

      // Sınıfı oluşturan kişi bilgisi (opsiyonel)
      String creatorName = "Bilinmiyor";
      final createdBy = data['createdBy'] as String?;
      if (createdBy != null && createdBy.isNotEmpty) {
        try {
          DocumentSnapshot creatorDoc = await _firestore
              .collection('users')
              .doc(createdBy)
              .get();
              
          if (creatorDoc.exists) {
            final creatorData = creatorDoc.data() as Map<String, dynamic>?;
            if (creatorData != null) {
              creatorName = creatorData['name']?.toString() ?? 'Bilinmiyor';
            }
          }
        } catch (e) {
          print('Oluşturan bilgisi getirme hatası: $e');
        }
      }
      
      return {
        'exists': true,
        'hasAccess': hasAccess,
        'id': classDoc.id,
        'name': data['name']?.toString() ?? 'İsimsiz Sınıf',
        'description': data['description']?.toString() ?? '',
        'students': students,
        'teachers': teachers,
        'studentCount': studentIds.length,
        'teacherCount': teacherIds.length,
        'createdAt': _formatTimestamp(data['createdAt'] as Timestamp? ?? Timestamp.now()),
        'createdBy': createdBy ?? '',
        'creatorName': creatorName,
        'teacherIds': teacherIds,
      };
    } catch (e) {
      print('getClassDetailSafe hatası: $e');
      return {
        'exists': false,
        'hasAccess': false,
        'error': 'Sınıf detayı getirilirken hata: $e',
        'students': [],
        'teachers': []
      };
    }
  }

  // Sınıfı öğrenciler ve öğretmenlerle birlikte oluştur
  Future<String> createClassWithStudentsAndTeachers(
    String name, 
    String description, 
    List<String> studentIds,
    List<String> teacherIds
  ) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğrenci listesi boşsa hata döndür
      if (studentIds.isEmpty) {
        throw Exception('En az bir öğrenci seçmelisiniz');
      }
      
      // Öğretmen listesi boşsa hata döndür
      if (teacherIds.isEmpty) {
        throw Exception('En az bir öğretmen seçmelisiniz');
      }
      
      // Mevcut öğretmenin listede olup olmadığını kontrol et
      if (!teacherIds.contains(currentTeacherId)) {
        teacherIds.add(currentTeacherId); // Mevcut öğretmeni listeye ekle
      }

      // Sınıfı oluştur - artık teacherId yok, sadece teacherIds listesi var
      DocumentReference classRef = await _firestore.collection('classes').add({
        'name': name,
        'description': description,
        'teacherIds': teacherIds, // Tüm öğretmenler
        'studentIds': studentIds,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentTeacherId // Kim oluşturdu bilgisi için (opsiyonel)
      });

      return classRef.id;
    } catch (e) {
      throw Exception('Sınıf oluşturulurken hata: $e');
    }
  }

  // Sınıf oluştur - basitleştirilmiş versiyon
  Future<String> createClass(String name, String description) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Sınıfı oluştur - yeni yapıyla
      DocumentReference classRef = await _firestore.collection('classes').add({
        'name': name,
        'description': description,
        'teacherIds': [currentTeacherId], // Sadece mevcut öğretmen
        'studentIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentTeacherId // Kim oluşturdu bilgisi için (opsiyonel)
      });

      return classRef.id;
    } catch (e) {
      throw Exception('Sınıf oluşturulurken hata: $e');
    }
  }

  // Sınıfı öğrencilerle birlikte oluştur
  Future<String> createClassWithStudents(String name, String description, List<String> studentIds) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğrenci listesi boşsa hata döndür
      if (studentIds.isEmpty) {
        throw Exception('En az bir öğrenci seçmelisiniz');
      }

      // Sınıfı oluştur - yeni yapıyla
      DocumentReference classRef = await _firestore.collection('classes').add({
        'name': name,
        'description': description,
        'teacherIds': [currentTeacherId], // Sadece mevcut öğretmen
        'studentIds': studentIds,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentTeacherId // Kim oluşturdu bilgisi için (opsiyonel)
      });

      return classRef.id;
    } catch (e) {
      throw Exception('Sınıf oluşturulurken hata: $e');
    }
  }

  // Sınıfa öğrenci ekle
  Future<void> addStudentToClass(String classId, String studentId) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfta işlem yapma yetkiniz yok');
      }

      // Öğrencinin öğretmenle ilişkisini kontrol et
      QuerySnapshot relation = await _firestore
          .collection('teacher_students')
          .where('teacherId', isEqualTo: currentTeacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (relation.docs.isEmpty) {
        throw Exception('Bu öğrenci size ait değil');
      }

      // Sınıfı getir (yetki kontrolü sonrası güvenli)
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Öğrenciyi sınıfa ekle
      List<String> studentIds = List<String>.from(data['studentIds'] ?? []);
      if (studentIds.contains(studentId)) {
        throw Exception('Bu öğrenci zaten sınıfa eklenmiş');
      }
      
      studentIds.add(studentId);
      
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': studentIds,
      });
    } catch (e) {
      throw Exception('Öğrenci sınıfa eklenirken hata: $e');
    }
  }

  // Sınıftan öğrenci çıkar
  Future<void> removeStudentFromClass(String classId, String studentId) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfta işlem yapma yetkiniz yok');
      }

      // Sınıfı getir (yetki kontrolü sonrası güvenli)
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Öğrenciyi sınıftan çıkar
      List<String> studentIds = List<String>.from(data['studentIds'] ?? []);
      if (!studentIds.contains(studentId)) {
        throw Exception('Bu öğrenci sınıfta değil');
      }
      
      studentIds.remove(studentId);
      
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': studentIds,
      });
    } catch (e) {
      throw Exception('Öğrenci sınıftan çıkarılırken hata: $e');
    }
  }

  // Sınıfa öğretmen ekle
  Future<void> addTeacherToClass(String classId, String teacherId) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfta işlem yapma yetkiniz yok');
      }
      
      // Eklenecek öğretmenin gerçekten öğretmen olduğunu kontrol et
      DocumentSnapshot teacherDoc = await _firestore
          .collection('users')
          .doc(teacherId)
          .get();
          
      if (!teacherDoc.exists) {
        throw Exception('Öğretmen bulunamadı');
      }
      
      final teacherData = teacherDoc.data() as Map<String, dynamic>?;
      if (teacherData == null || teacherData['role'] != 'teacher') {
        throw Exception('Bu kullanıcı bir öğretmen değil');
      }

      // Sınıfı getir (yetki kontrolü sonrası güvenli)
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Öğretmeni sınıfa ekle
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      if (teacherIds.contains(teacherId)) {
        throw Exception('Bu öğretmen zaten sınıfa eklenmiş');
      }
      
      teacherIds.add(teacherId);
      
      await _firestore.collection('classes').doc(classId).update({
        'teacherIds': teacherIds,
      });
    } catch (e) {
      throw Exception('Öğretmen sınıfa eklenirken hata: $e');
    }
  }

  // Sınıftan öğretmen çıkar
  Future<void> removeTeacherFromClass(String classId, String teacherId) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfta işlem yapma yetkiniz yok');
      }

      // Sınıfı getir (yetki kontrolü sonrası güvenli)
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }
      
      // Öğretmeni sınıftan çıkar
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      if (!teacherIds.contains(teacherId)) {
        throw Exception('Bu öğretmen sınıfta değil');
      }
      
      // Sınıfta her zaman en az bir öğretmen kalmalı
      if (teacherIds.length <= 1) {
        throw Exception('Sınıfta en az bir öğretmen kalmalıdır');
      }
      
      // Kendi kendini çıkarmaya çalışıyorsa uyar
      if (currentTeacherId == teacherId) {
        throw Exception('Kendinizi sınıftan çıkaramazsınız. Önce başka bir öğretmene yetki vermelisiniz.');
      }
      
      teacherIds.remove(teacherId);
      
      await _firestore.collection('classes').doc(classId).update({
        'teacherIds': teacherIds,
      });
    } catch (e) {
      throw Exception('Öğretmen sınıftan çıkarılırken hata: $e');
    }
  }

  // Öğretmenin cevaplanmamış sorularını getir
  Future<List<Map<String, dynamic>>> getQuestions() async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Öğretmene ait soruları getir
      QuerySnapshot questionsSnapshot = await _firestore
          .collection('questions')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> questions = [];

      for (var doc in questionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Öğrenci bilgilerini getir
        DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(data['studentId'] as String)
            .get();
        
        String studentName = 'Bilinmeyen Öğrenci';
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>?;
          if (studentData != null && studentData['name'] != null) {
            studentName = studentData['name'] as String;
          }
        }
        
        questions.add({
          'id': doc.id,
          'title': data['title'] ?? 'İsimsiz Soru',
          'content': data['content'] ?? '',
          'studentName': studentName,
          'studentId': data['studentId'] ?? '',
          'imageUrl': data['imageUrl'],
          'date': data['createdAt'] != null
              ? _formatTimestamp(data['createdAt'] as Timestamp)
              : 'Zaman bilgisi yok',
          'status': data['answered'] == true ? 'answered' : 'pending',
          'answer': data['answer'],
          'answerDate': data['answerDate'] != null
              ? _formatTimestamp(data['answerDate'] as Timestamp)
              : null,
        });
      }

      return questions;
    } catch (e) {
      throw Exception('Sorular getirilirken hata: $e');
    }
  }

  // Soruyu yanıtla
  Future<void> answerQuestion(String questionId, String answer) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Soruyu kontrol et
      DocumentSnapshot questionDoc = await _firestore
          .collection('questions')
          .doc(questionId)
          .get();

      if (!questionDoc.exists) {
        throw Exception('Soru bulunamadı');
      }

      final questionData = questionDoc.data() as Map<String, dynamic>;
      if (questionData['teacherId'] != teacherId) {
        throw Exception('Bu soruyu yanıtlama yetkiniz yok');
      }

      // Soruyu yanıtla
      await _firestore.collection('questions').doc(questionId).update({
        'answer': answer,
        'answered': true,
        'answerDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Soru yanıtlanırken hata: $e');
    }
  }

  // Sınıfı güncelle
  Future<void> updateClass(String classId, String name, String description) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfı düzenleme yetkiniz yok');
      }

      // Sınıfı güncelle
      await _firestore.collection('classes').doc(classId).update({
        'name': name,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': currentTeacherId,
      });
    } catch (e) {
      throw Exception('Sınıf güncellenirken hata: $e');
    }
  }

  // Sınıfı sil
  Future<void> deleteClass(String classId) async {
    try {
      final String currentTeacherId = _auth.currentUser?.uid ?? '';
      if (currentTeacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Yetki kontrolü - yeni güvenilir metot
      final bool hasAccess = await hasClassAccess(classId);
      if (!hasAccess) {
        throw Exception('Bu sınıfı silme yetkiniz yok');
      }

      // Sınıfı getir (yetki kontrolü sonrası güvenli)
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      final data = classDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Öğrenci ve öğretmen sayısını kontrol et
      final studentIds = List<String>.from(data['studentIds'] ?? []);
      if (studentIds.isNotEmpty) {
        throw Exception('Sınıfı silmeden önce tüm öğrencileri çıkarmalısınız');
      }
      
      final teacherIds = List<String>.from(data['teacherIds'] ?? []);
      if (teacherIds.length > 1) {
        throw Exception('Sınıfı silmeden önce diğer öğretmenleri çıkarmalısınız');
      }

      // Sınıfı sil
      await _firestore.collection('classes').doc(classId).delete();
    } catch (e) {
      throw Exception('Sınıf silinirken hata: $e');
    }
  }

  // Ödev sil
  Future<void> deleteHomework(String homeworkId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
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

      final data = homeworkDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Ödev verisi bulunamadı');
      }

      if (data['teacherId'] != teacherId) {
        throw Exception('Bu ödevi silme yetkiniz yok');
      }

      // Ödevi sil
      await _firestore.collection('homeworks').doc(homeworkId).delete();
    } catch (e) {
      throw Exception('Ödev silinirken hata: $e');
    }
  }
  
  // Sınav sil
  Future<void> deleteExam(String examId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
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

      final data = examDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Sınav verisi bulunamadı');
      }

      if (data['teacherId'] != teacherId) {
        throw Exception('Bu sınavı silme yetkiniz yok');
      }

      // Sınavı sil
      await _firestore.collection('exams').doc(examId).delete();
    } catch (e) {
      throw Exception('Sınav silinirken hata: $e');
    }
  }

  // Timestamp formatını düzenle
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

  // Öğrencinin ödev istatistiklerini getir
  Future<Map<String, dynamic>> getStudentHomeworkStats(String studentId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmenin tüm ödevlerini getir
      QuerySnapshot homeworksSnapshot = await _firestore
          .collection('homeworks')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      // Bu öğrenciye atanan ödevleri say
      int totalCount = 0;
      List<String> assignedHomeworkIds = [];
      
      for (var doc in homeworksSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
        
        if (assignedStudents.contains(studentId)) {
          totalCount++;
          assignedHomeworkIds.add(doc.id);
        }
      }
      
      // Öğrencinin tamamladığı ödevleri say
      int completedCount = 0;
      
      if (assignedHomeworkIds.isNotEmpty) {
        QuerySnapshot submissionsSnapshot = await _firestore
            .collection('homework_submissions')
            .where('studentId', isEqualTo: studentId)
            .get();
            
        // Tamamlanmış ödev ID'lerini topla
        Set<String> completedHomeworkIds = {};
        for (var doc in submissionsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final homeworkId = data['homeworkId'] as String?;
          
          if (homeworkId != null && assignedHomeworkIds.contains(homeworkId)) {
            completedHomeworkIds.add(homeworkId);
          }
        }
        
        completedCount = completedHomeworkIds.length;
      }
      
      return {
        'totalCount': totalCount,
        'completedCount': completedCount,
        'pendingCount': totalCount - completedCount,
      };
    } catch (e) {
      print('getStudentHomeworkStats hatası: $e');
      // Hata durumunda varsayılan değer döndür
      return {
        'totalCount': 0,
        'completedCount': 0,
        'pendingCount': 0,
      };
    }
  }
  
  // Öğrencinin sınav istatistiklerini getir
  Future<Map<String, dynamic>> getStudentExamStats(String studentId) async {
    try {
      final String teacherId = _auth.currentUser?.uid ?? '';
      if (teacherId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Öğretmenin tüm sınavlarını getir
      QuerySnapshot examsSnapshot = await _firestore
          .collection('exams')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      // Bu öğrenciye atanan sınavları say
      int totalCount = 0;
      List<String> assignedExamIds = [];
      
      for (var doc in examsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final assignedStudents = List<String>.from(data['assignedStudents'] ?? []);
        
        if (assignedStudents.contains(studentId)) {
          totalCount++;
          assignedExamIds.add(doc.id);
        }
      }
      
      // Öğrencinin tamamladığı sınavları say
      int completedCount = 0;
      
      if (assignedExamIds.isNotEmpty) {
        QuerySnapshot submissionsSnapshot = await _firestore
            .collection('exam_submissions')
            .where('studentId', isEqualTo: studentId)
            .get();
            
        // Tamamlanmış sınav ID'lerini topla
        Set<String> completedExamIds = {};
        for (var doc in submissionsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final examId = data['examId'] as String?;
          
          if (examId != null && assignedExamIds.contains(examId)) {
            completedExamIds.add(examId);
          }
        }
        
        completedCount = completedExamIds.length;
      }
      
      return {
        'totalCount': totalCount,
        'completedCount': completedCount,
        'pendingCount': totalCount - completedCount,
      };
    } catch (e) {
      print('getStudentExamStats hatası: $e');
      // Hata durumunda varsayılan değer döndür
      return {
        'totalCount': 0,
        'completedCount': 0,
        'pendingCount': 0,
      };
    }
  }
} 
