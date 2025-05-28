import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/models/chat_message_model.dart';
import 'package:math_app/core/models/class_chat_model.dart';
import 'package:math_app/services/teacher_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TeacherService _teacherService = TeacherService();

  // Kullanıcının erişimi olan tüm sınıf sohbetlerini getir
  Future<List<ClassChatModel>> getAccessibleClassChats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcı bilgilerini getir
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        throw Exception('Kullanıcı verisi bulunamadı');
      }

      String userRole = userData['role']?.toString() ?? '';

      List<ClassChatModel> classChats = [];

      // Öğretmen ise
      if (userRole == AppConstants.roleTeacher) {
        // Erişimi olan sınıfları getir
        final classes = await _teacherService.getClasses();
        
        for (var classData in classes) {
          // En son mesajı bul
          final lastMessage = await _getLastMessageForClass(classData['id']);
          
          ClassChatModel chatModel;
          if (lastMessage != null) {
            chatModel = ClassChatModel(
              id: classData['id'],
              classId: classData['id'],
              className: classData['name'],
              lastMessageTime: lastMessage.timestamp,
              lastMessageText: lastMessage.content,
              lastMessageSender: lastMessage.senderName,
            );
          } else {
            chatModel = ClassChatModel.fromClassData(classData);
          }
          
          classChats.add(chatModel);
        }
      }
      // Öğrenci ise
      else if (userRole == AppConstants.roleStudent) {
        // Öğrencinin dahil olduğu sınıfları bulma
        QuerySnapshot classesSnapshot = await _firestore
            .collection('classes')
            .where('studentIds', arrayContains: user.uid)
            .get();
            
        for (var doc in classesSnapshot.docs) {
          final classData = doc.data() as Map<String, dynamic>;
          final classId = doc.id;
          final className = classData['name'] ?? 'İsimsiz Sınıf';
          
          // En son mesajı bul
          final lastMessage = await _getLastMessageForClass(classId);
          
          ClassChatModel chatModel;
          if (lastMessage != null) {
            chatModel = ClassChatModel(
              id: classId,
              classId: classId,
              className: className,
              lastMessageTime: lastMessage.timestamp,
              lastMessageText: lastMessage.content,
              lastMessageSender: lastMessage.senderName,
            );
          } else {
            chatModel = ClassChatModel(
              id: classId,
              classId: classId,
              className: className,
              lastMessageTime: Timestamp.now(),
              lastMessageText: 'Henüz mesaj yok',
              lastMessageSender: '',
            );
          }
          
          classChats.add(chatModel);
        }
      }

      // Son mesaj zamanına göre sırala (en yeniler önce)
      classChats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      return classChats;
    } catch (e) {
      throw Exception('Sınıf sohbetleri getirilirken hata: $e');
    }
  }

  // Bir sınıf için en son mesajı getir
  Future<ChatMessageModel?> _getLastMessageForClass(String classId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('class_messages')
          .where('classId', isEqualTo: classId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
          
      if (messagesSnapshot.docs.isEmpty) {
        return null;
      }
      
      return ChatMessageModel.fromFirestore(messagesSnapshot.docs.first);
    } catch (e) {
      print('Son mesaj alınırken hata: $e');
      return null;
    }
  }

  // Sınıf mesajlarını getir
  Stream<List<ChatMessageModel>> getClassMessages(String classId) {
    return _firestore
        .collection('class_messages')
        .where('classId', isEqualTo: classId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc))
              .toList();
        });
  }

  // Mesaj gönder
  Future<void> sendMessage(String classId, String content) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      // Kullanıcı bilgilerini getir
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) {
        throw Exception('Kullanıcı verisi bulunamadı');
      }

      String userRole = userData['role']?.toString() ?? '';
      String userName = userData['name']?.toString() ?? 'İsimsiz Kullanıcı';

      // Sınıfı kontrol et
      DocumentSnapshot classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Sınıf bulunamadı');
      }

      final classData = classDoc.data() as Map<String, dynamic>?;
      if (classData == null) {
        throw Exception('Sınıf verisi bulunamadı');
      }

      // Kullanıcının yetkisini kontrol et
      bool hasAccess = false;
      
      if (userRole == AppConstants.roleTeacher) {
        // Öğretmenler listesini kontrol et
        final teacherIds = List<String>.from(classData['teacherIds'] ?? []);
        hasAccess = teacherIds.contains(user.uid);
      } else if (userRole == AppConstants.roleStudent) {
        // Öğrenciler listesini kontrol et
        final studentIds = List<String>.from(classData['studentIds'] ?? []);
        hasAccess = studentIds.contains(user.uid);
      }
      
      if (!hasAccess) {
        throw Exception('Bu sınıfa mesaj gönderme yetkiniz yok');
      }

      // Mesajı ekle
      final messageRef = await _firestore.collection('class_messages').add({
        'classId': classId,
        'senderId': user.uid,
        'senderName': userName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isTeacher': userRole == AppConstants.roleTeacher,
      });
      
      // Sınıf bilgisini al
      String className = classData['name'] ?? 'İsimsiz Sınıf';
      
      // class_chats koleksiyonunu güncelle veya oluştur
      DocumentReference classChatRef = _firestore.collection('class_chats').doc(classId);
      DocumentSnapshot classChatSnapshot = await classChatRef.get();
      
      if (classChatSnapshot.exists) {
        // Güncelle
        await classChatRef.update({
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageText': content,
          'lastMessageSender': userName,
        });
      } else {
        // Oluştur
        await classChatRef.set({
          'classId': classId,
          'className': className,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageText': content,
          'lastMessageSender': userName,
          'unreadCount': 0,
        });
      }
      
      return;
    } catch (e) {
      throw Exception('Mesaj gönderilirken hata: $e');
    }
  }

  // Yardımcı fonksiyonlar
  String formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  
  // Mevcut kullanıcının ID'sini al
  String getCurrentUserId() {
    final user = _auth.currentUser;
    return user?.uid ?? '';
  }
} 