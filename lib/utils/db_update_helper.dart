import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase'deki sınıf yapısını güncellemek için kullanılan yardımcı metotlar
class DbUpdateHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Tüm sınıfları yeni yapıya günceller
  /// NOT: Bu metodu sadece bir kez çağırın!
  Future<void> updateAllClassesToNewStructure() async {
    try {
      // Tüm sınıfları getir
      QuerySnapshot classesSnapshot = await _firestore
          .collection('classes')
          .get();
          
      print('Toplam ${classesSnapshot.docs.length} sınıf güncelleniyor...');
      
      int success = 0;
      int error = 0;
      
      // Her bir sınıfı güncelle
      for (var doc in classesSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            print('HATA: Sınıf verisi boş - ID: ${doc.id}');
            error++;
            continue;
          }
          
          // teacherId var mı?
          final teacherId = data['teacherId'] as String?;
          if (teacherId == null || teacherId.isEmpty) {
            print('HATA: teacherId bulunamadı - ID: ${doc.id}');
            error++;
            continue;
          }
          
          // teacherIds zaten var mı?
          if (data.containsKey('teacherIds') && data['teacherIds'] is List) {
            // Zaten güncel yapıda, sadece createdBy ekleyelim
            if (!data.containsKey('createdBy')) {
              await _firestore.collection('classes').doc(doc.id).update({
                'createdBy': teacherId,
              });
              print('createdBy eklendi - ID: ${doc.id}');
            }
            success++;
            continue;
          }
          
          // Yeni teacherIds listesi oluştur ve güncelle
          await _firestore.collection('classes').doc(doc.id).update({
            'teacherIds': [teacherId],
            'createdBy': teacherId,
          });
          
          print('Güncellendi - ID: ${doc.id}, teacherId: $teacherId');
          success++;
        } catch (e) {
          print('HATA: Sınıf güncellenemedi - ID: ${doc.id}, hata: $e');
          error++;
        }
      }
      
      print('Güncelleme tamamlandı: $success başarılı, $error hatalı');
    } catch (e) {
      print('Güncelleme işlemi başarısız: $e');
    }
  }
} 