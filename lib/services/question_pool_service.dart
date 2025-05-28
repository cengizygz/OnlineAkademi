import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:math_app/models/question_pool.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class QuestionPoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kullanıcının ID'sini al
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Yeni soru oluştur
  Future<void> createQuestion({
    required String questionText,
    required List<String> options,
    required String correctAnswer, // "A", "B", "C", "D"
    required String subject,
    required String topic,
  }) async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Önce kullanıcının öğrenci rolüne sahip olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;

      if (userRole != 'student') {
        throw Exception('Yalnızca öğrenciler soru oluşturabilir');
      }

      // Soruyu Firestore'a ekle
      await _firestore.collection('questionPool').add({
        'creatorId': currentUserId,
        'questionText': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'subject': subject,
        'topic': topic,
        'createdAt': Timestamp.now(),
        'isApproved': false,
        'isSolved': false,
        'solverStudentId': null,
        'solutionText': null,
        'solutionFileUrl': null,
      });
    } catch (e) {
      print('Soru oluşturma hatası: $e');
      throw Exception('Soru oluşturulamadı: $e');
    }
  }

  // Öğretmen için onay bekleyen soruları getir
  Future<List<PoolQuestion>> getPendingQuestions() async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının öğretmen rolüne sahip olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;

      if (userRole != 'teacher') {
        throw Exception('Bu işlem için öğretmen yetkisi gereklidir');
      }

      // Onay bekleyen soruları al
      QuerySnapshot querySnapshot = await _firestore
          .collection('questionPool')
          .where('isApproved', isEqualTo: false)
          .where('isSolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PoolQuestion.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Onay bekleyen soruları getirme hatası: $e');
      throw Exception('Onay bekleyen sorular alınamadı: $e');
    }
  }

  // Soruyu onayla veya reddet
  Future<void> approveQuestion(String questionId, bool isApproved) async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının öğretmen rolüne sahip olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;

      if (userRole != 'teacher') {
        throw Exception('Bu işlem için öğretmen yetkisi gereklidir');
      }

      // Soruyu güncelle
      await _firestore.collection('questionPool').doc(questionId).update({
        'isApproved': isApproved,
        // Reddedilirse soru havuzdan kaldırılacak mı? Bu bir tercih meselesi.
        // Eğer reddedilen sorular saklanacaksa, ayrı bir rejected alanı eklenebilir.
      });
    } catch (e) {
      print('Soru onaylama hatası: $e');
      throw Exception('Soru onaylanamadı: $e');
    }
  }

  // Onaylanmış ve çözülmemiş soruları getir (öğrenciler için)
  Future<List<PoolQuestion>> getAvailableQuestions() async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının öğrenci olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;

      if (userRole != 'student') {
        throw Exception('Bu özellik yalnızca öğrenciler içindir');
      }

      // Onaylanmış, çözülmemiş ve kendisinin oluşturmadığı soruları al
      QuerySnapshot querySnapshot = await _firestore
          .collection('questionPool')
          .where('isApproved', isEqualTo: true)
          .where('isSolved', isEqualTo: false)
          .where('creatorId', isNotEqualTo: currentUserId)
          .orderBy('creatorId') // where kullanıldığı için bu alan zorunlu
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PoolQuestion.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Kullanılabilir soruları getirme hatası: $e');
      throw Exception('Kullanılabilir sorular alınamadı: $e');
    }
  }

  // Soruyu çöz
  Future<bool> solveQuestion({
    required String questionId,
    required String selectedAnswer, // "A", "B", "C", "D"
    String? solutionText,
    File? solutionFile,
  }) async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının öğrenci olduğunu kontrol et
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userRole = userData?['role'] as String?;

      if (userRole != 'student') {
        throw Exception('Bu özellik yalnızca öğrenciler içindir');
      }

      // Soruyu al
      DocumentSnapshot questionDoc = await _firestore.collection('questionPool').doc(questionId).get();
      if (!questionDoc.exists) {
        throw Exception('Soru bulunamadı');
      }

      final questionData = questionDoc.data() as Map<String, dynamic>;
      
      // Soru zaten çözülmüş mü kontrol et
      if (questionData['isSolved'] == true) {
        throw Exception('Bu soru zaten çözülmüş');
      }

      // Cevap doğru mu?
      final correctAnswer = questionData['correctAnswer'];
      final isCorrect = selectedAnswer == correctAnswer;

      // Dosya yükleme
      String? fileUrl;
      if (isCorrect && solutionFile != null) {
        final fileName = path.basename(solutionFile.path);
        final destination = 'question_solutions/$questionId/$fileName';
        
        final ref = _storage.ref(destination);
        await ref.putFile(solutionFile);
        fileUrl = await ref.getDownloadURL();
      }

      // Eğer cevap doğruysa, soruyu çözülmüş olarak işaretle
      if (isCorrect) {
        await _firestore.collection('questionPool').doc(questionId).update({
          'isSolved': true,
          'solverStudentId': currentUserId,
          'solutionText': solutionText,
          'solutionFileUrl': fileUrl,
        });

        // Puan eklemesi
        await _addPointsToStudent(currentUserId, 10); // 10 puan ekle

        // Soru sahibine bildirim gönder
        await _notifyQuestionCreator(questionData['creatorId'], questionId);
      }

      return isCorrect;
    } catch (e) {
      print('Soru çözme hatası: $e');
      throw Exception('Soru çözülemedi: $e');
    }
  }

  // Öğrenciye puan ekle
  Future<void> _addPointsToStudent(String studentId, int points) async {
    try {
      // Öğrencinin mevcut puanını al
      DocumentSnapshot studentDoc = await _firestore.collection('users').doc(studentId).get();
      final studentData = studentDoc.data() as Map<String, dynamic>?;
      final currentPoints = studentData?['points'] as int? ?? 0;

      // Yeni puanı users koleksiyonunda güncelle
      await _firestore.collection('users').doc(studentId).update({
        'points': currentPoints + points,
      });

      // Aynı zamanda solvedQuestions koleksiyonuna da ekle
      await _firestore.collection('solvedQuestions').add({
        'userId': studentId,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'question_pool', // Soru havuzundan kazanılan puan olduğunu belirt
      });
    } catch (e) {
      print('Puan ekleme hatası: $e');
      throw Exception('Puan eklenirken hata oluştu: $e');
    }
  }

  // Soru sahibine bildirim gönder
  Future<void> _notifyQuestionCreator(String creatorId, String questionId) async {
    try {
      // Bildirim olarak kaydet
      await _firestore.collection('notifications').add({
        'userId': creatorId,
        'title': 'Sorunuz çözüldü!',
        'message': 'Havuza eklediğiniz soru başarıyla çözüldü. Çözümü görüntülemek için tıklayın.',
        'type': 'question_solved',
        'relatedId': questionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Burada Firebase Cloud Messaging ile anlık bildirim de gönderilebilir
    } catch (e) {
      print('Bildirim gönderme hatası: $e');
    }
  }

  // Öğrenci kendi oluşturduğu soruları ve çözümleri görebilir
  Future<List<PoolQuestion>> getMyQuestions() async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının oluşturduğu soruları al
      QuerySnapshot querySnapshot = await _firestore
          .collection('questionPool')
          .where('creatorId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PoolQuestion.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Kullanıcı sorularını getirme hatası: $e');
      throw Exception('Kullanıcı soruları alınamadı: $e');
    }
  }

  // Öğrenci çözdüğü soruları görebilir
  Future<List<PoolQuestion>> getMySolvedQuestions() async {
    try {
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcının çözdüğü soruları al
      QuerySnapshot querySnapshot = await _firestore
          .collection('questionPool')
          .where('solverStudentId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PoolQuestion.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Çözülen soruları getirme hatası: $e');
      throw Exception('Çözülen sorular alınamadı: $e');
    }
  }
} 