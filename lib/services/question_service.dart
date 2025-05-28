import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Öğrencinin soru havuzu puanlarını ve sıralamayı getir
  Future<Map<String, dynamic>> getStudentQuestionPoolPoints() async {
    try {
      final String currentUserId = _auth.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      print('Liderlik tablosu için veri toplanıyor...');
      print('Mevcut kullanıcı ID: $currentUserId');

      // Tüm öğrencilerin puanlarını getir
      final QuerySnapshot studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      print('Toplam öğrenci sayısı: ${studentsSnapshot.docs.length}');

      List<Map<String, dynamic>> allPoints = [];
      
      // Her öğrenci için puanları ve çözdüğü soru adedini hesapla
      for (var doc in studentsSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        print('\nÖğrenci kontrol ediliyor:');
        print('Öğrenci ID: $userId');
        print('Öğrenci adı: ${userData['name']}');
        print('Mevcut points değeri: ${userData['points']}');
        
        // Öğrencinin çözdüğü soruları getir
        final QuerySnapshot solvedQuestionsSnapshot = await _firestore
            .collection('solvedQuestions')
            .where('userId', isEqualTo: userId)
            .get();

        print('Çözülen soru sayısı: ${solvedQuestionsSnapshot.docs.length}');

        int totalPoints = 0;
        int solvedCount = solvedQuestionsSnapshot.docs.length;
        
        // Her çözülen soru için puanları topla
        for (var questionDoc in solvedQuestionsSnapshot.docs) {
          final questionData = questionDoc.data() as Map<String, dynamic>;
          final points = questionData['points'] as int? ?? 0;
          totalPoints += points;
          print('Soru puanı: $points, Toplam puan: $totalPoints');
        }

        print('Hesaplanan toplam puan: $totalPoints');

        // Eğer kullanıcının points veya solvedCount alanı yoksa veya null ise, güncelle
        if (!userData.containsKey('points') || userData['points'] == null ||
            !userData.containsKey('solvedCount') || userData['solvedCount'] == null) {
          print('Kullanıcı verileri güncelleniyor...');
          await _firestore.collection('users').doc(userId).update({
            'points': totalPoints,
            'solvedCount': solvedCount,
          });
          print('Kullanıcı verileri güncellendi');
        }

        // Sadece puanı 0'dan büyük olan öğrencileri listeye ekle
        if (totalPoints > 0) {
          print('Öğrenci listeye ekleniyor (puanı > 0)');
          allPoints.add({
            'userId': userId,
            'name': userData['name'] ?? 'İsimsiz Kullanıcı',
            'points': totalPoints,
            'solvedCount': solvedCount,
            'profilePicture': userData['profilePicture'] ?? '',
          });
        } else {
          print('Öğrenci listeye eklenmedi (puanı = 0)');
        }
      }

      print('\nLiderlik tablosu sonuçları:');
      print('Toplam öğrenci sayısı: ${allPoints.length}');

      // Puanlara göre sırala (yüksekten düşüğe)
      allPoints.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

      // Mevcut kullanıcının puanlarını bul
      final currentUserPoints = allPoints.firstWhere(
        (points) => points['userId'] == currentUserId,
        orElse: () => {'points': 0, 'solvedCount': 0},
      );

      print('Mevcut kullanıcı puanları: $currentUserPoints');

      return {
        'allPoints': allPoints,
        'userPoints': currentUserPoints,
      };
    } catch (e) {
      print('Soru havuzu puanları alınırken hata: $e');
      rethrow;
    }
  }

  // Öğrencinin soru havuzu puanını güncelle
  Future<void> updateStudentQuestionPoolPoints(String userId, int points) async {
    try {
      await _firestore.collection('solvedQuestions').add({
        'userId': userId,
        'points': points,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Soru havuzu puanı güncellenirken hata: $e');
      rethrow;
    }
  }
} 