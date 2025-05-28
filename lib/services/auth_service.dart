import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _lastLoginEmailKey = 'last_login_email';
  static const String _lastLoginPasswordKey = 'last_login_password';

  // Giriş durumunu izle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Son giriş bilgilerini kaydet
  Future<void> _saveLastLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLoginEmailKey, email);
    await prefs.setString(_lastLoginPasswordKey, password);
  }

  // Son giriş bilgilerini sil
  Future<void> _clearLastLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastLoginEmailKey);
    await prefs.remove(_lastLoginPasswordKey);
  }

  // Son giriş bilgilerini al
  Future<Map<String, String?>> getLastLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_lastLoginEmailKey),
      'password': prefs.getString(_lastLoginPasswordKey),
    };
  }

  // Profil fotoğrafı yükle
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-logged-in',
          message: 'Kullanıcı giriş yapmamış',
        );
      }

      final String userId = currentUser!.uid;
      final String fileName = 'profile_pictures/$userId.jpg';
      
      // Eski fotoğrafı sil (varsa)
      try {
        await _storage.ref().child(fileName).delete();
      } catch (e) {
        // Eski fotoğraf yoksa hata vermesini engelle
        print('Eski profil fotoğrafı silinemedi: $e');
      }

      // Yeni fotoğrafı yükle
      final uploadTask = await _storage.ref().child(fileName).putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Firestore'da profil fotoğrafı URL'sini güncelle
      await _firestore.collection('users').doc(userId).update({
        'profilePicture': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Profil fotoğrafı yüklenirken hata: $e');
      rethrow;
    }
  }

  // Email/şifre ile kayıt
  Future<UserCredential> registerWithEmailAndPassword({
    required String email, 
    required String password, 
    required String name,
    required String role,
    String? phoneNumber,
  }) async {
    UserCredential? userCredential;
    
    try {
      print('Kayıt işlemi başlatılıyor...');
      print('Email: $email, İsim: $name, Rol: $role');
      
      // Önce kullanıcıyı oluştur
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Kullanıcı oluşturulamadı',
        );
      }

      print('Firebase Auth kullanıcısı oluşturuldu: ${userCredential.user?.uid}');
      
      // Kullanıcı adını güncelle
      try {
        if (userCredential.user != null) {
          await userCredential.user!.updateDisplayName(name);
          print('Kullanıcı adı güncellendi: $name');
        }
      } catch (updateError) {
        print('Kullanıcı adı güncellenirken hata: $updateError');
        // Bu hata kritik değil, devam edebiliriz
      }
      
      // Firestore'a kullanıcı verilerini ekle
      try {
        if (userCredential.user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Kullanıcı bulunamadı',
          );
        }

        final String userId = userCredential.user!.uid;
        print('Kullanıcı ID: $userId');
        
        final userData = {
          'name': name,
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profilePicture': '',
          'phoneNumber': phoneNumber ?? '',
          'points': role == 'student' ? 0 : null,
          'solvedCount': role == 'student' ? 0 : null,
          'uid': userId,
        };
        
        print('Firestore\'a kayıt yapılıyor...');
        print('Kullanıcı verileri: $userData');
        
        // Firestore bağlantısını test et
        try {
          final testDoc = await _firestore.collection('users').doc('test').get();
          print('Firestore bağlantısı başarılı: ${testDoc.exists}');
        } catch (testError) {
          print('Firestore bağlantı testi başarısız: $testError');
          // Test başarısız olsa bile devam et, çünkü test dokümanı olmayabilir
        }
        
        // Kullanıcı verilerini kaydet
        await _firestore.collection('users').doc(userId).set(userData);
        print('Firestore kaydı başarılı');
        
        return userCredential;
      } catch (firestoreError) {
        print('Firestore hatası: $firestoreError');
        print('Hata detayı: ${firestoreError.toString()}');
        
        // Firestore hatası durumunda kullanıcıyı sil
        if (userCredential.user != null) {
          try {
            await userCredential.user!.delete();
            print('Firestore hatası nedeniyle kullanıcı silindi');
          } catch (deleteError) {
            print('Kullanıcı silinirken hata: $deleteError');
          }
        }
        
        throw FirebaseException(
          plugin: 'firestore',
          code: 'firestore-error',
          message: 'Kullanıcı bilgileri kaydedilemedi: $firestoreError',
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth hatası: ${e.code} - ${e.message}');
      // Eğer kullanıcı oluşturulduysa ama hata olduysa, kullanıcıyı sil
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
          print('Auth hatası nedeniyle kullanıcı silindi');
        } catch (deleteError) {
          print('Kullanıcı silinirken hata: $deleteError');
        }
      }
      rethrow;
    } catch (e) {
      print('Beklenmeyen hata: $e');
      print('Hata tipi: ${e.runtimeType}');
      // Eğer kullanıcı oluşturulduysa ama hata olduysa, kullanıcıyı sil
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
          print('Beklenmeyen hata nedeniyle kullanıcı silindi');
        } catch (deleteError) {
          print('Kullanıcı silinirken hata: $deleteError');
        }
      }
      throw FirebaseException(
        plugin: 'auth',
        code: 'unknown-error',
        message: 'Beklenmeyen bir hata oluştu: ${e.toString()}',
      );
    }
  }

  // Email/şifre ile giriş
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Giriş başarılıysa bilgileri kaydet
      await _saveLastLoginCredentials(email, password);
      
      // Son giriş zamanını güncelle
      if (result.user != null) {
        try {
          await _firestore.collection('users').doc(result.user!.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          print('Son giriş zamanı güncellenemedi: $updateError');
        }
      }
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Kullanıcı rolünü al
  Future<String> getUserRole() async {
    try {
      if (currentUser != null) {
        try {
          DocumentSnapshot doc = await _firestore
              .collection('users')
              .doc(currentUser!.uid)
              .get();
          
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['role'] as String? ?? AppConstants.roleStudent;
          }
        } catch (e) {
          print('Kullanıcı rolü alınırken hata: $e');
          // Firestore erişim hatası durumunda varsayılan rol döndür
          return AppConstants.roleStudent;
        }
      }
      
      return AppConstants.roleStudent;
    } catch (e) {
      print('Genel hata: $e');
      return AppConstants.roleStudent;
    }
  }

  // Kullanıcı bilgilerini getir
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (currentUser != null) {
        try {
          DocumentSnapshot doc = await _firestore
              .collection('users')
              .doc(currentUser!.uid)
              .get();
          
          if (doc.exists) {
            return doc.data() as Map<String, dynamic>?;
          } else {
            // Doküman yoksa varsayılan değerler döndür
            return {
              'email': currentUser?.email,
              'name': currentUser?.displayName ?? 'İsimsiz Kullanıcı',
              'role': AppConstants.roleStudent,
              'profilePicture': '',
              'phoneNumber': '',
            };
          }
        } catch (e) {
          print('Kullanıcı bilgileri alınırken hata: $e');
          // Hata durumunda en azından bazı temel bilgileri döndür
          return {
            'email': currentUser?.email,
            'name': currentUser?.displayName ?? 'İsimsiz Kullanıcı',
            'role': AppConstants.roleStudent,
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Genel hata: $e');
      return null;
    }
  }

  // Profil bilgilerini güncelle
  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? profilePicture,
  }) async {
    try {
      if (currentUser != null) {
        Map<String, dynamic> data = {};
        
        if (name != null && name.isNotEmpty) {
          data['name'] = name;
        }
        
        if (phoneNumber != null) {
          data['phoneNumber'] = phoneNumber;
        }
        
        if (profilePicture != null) {
          data['profilePicture'] = profilePicture;
        }
        
        if (data.isNotEmpty) {
          await _firestore
              .collection('users')
              .doc(currentUser!.uid)
              .update(data);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    try {
      await _clearLastLoginCredentials();
      return await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      return await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
} 