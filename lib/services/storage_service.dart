import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Tekli dosya yükleme işlemi
  Future<String> uploadFile({
    required String filePath,
    required String destination,
    Function(double)? onProgress,
  }) async {
    try {
      // Dosya yolunu kontrol et
      if (!File(filePath).existsSync()) {
        throw Exception('Dosya bulunamadı: $filePath');
      }
      
      // Geçerli bir destination yolu oluştur
      final fileName = path.basename(filePath);
      final sanitizedDestination = destination.replaceAll(RegExp(r'[#$.\[\]/]'), '_');
      final fullPath = 'files/$sanitizedDestination/$fileName';
      
      final ref = _storage.ref(fullPath);
      
      // Yükleme işlemini başlat
      final uploadTask = ref.putFile(
        File(filePath),
        SettableMetadata(
          contentType: _getContentType(filePath),
          customMetadata: {'uploaded_at': DateTime.now().toIso8601String()},
        ),
      );
      
      // İlerleme durumunu takip et
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          // Çok sık çağrı yapmayalım
          if (progress % 0.05 < 0.01) {
            onProgress(progress);
          }
        }, onError: (e) {
          debugPrint('Upload dinleme hatası: $e');
        });
      }
      
      // Yüklemeyi bekle
      final snapshot = await uploadTask;
      
      // URL'i al ve döndür
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('Firebase yükleme hatası: ${e.code} - ${e.message}');
      throw Exception('Dosya yüklenirken Firebase hatası: ${e.message}');
    } catch (e) {
      debugPrint('Dosya yükleme hatası: $e');
      throw Exception('Dosya yüklenirken bir hata oluştu: $e');
    }
  }
  
  /// Çoklu dosya yükleme işlemi
  Future<List<String>> uploadMultipleFiles({
    required List<Map<String, dynamic>> files,
    required String basePath,
    Function(double)? onProgress,
  }) async {
    try {
      if (files.isEmpty) return [];
      
      // Dosya sayısını kontrol et
      for (final file in files) {
        final filePath = file['path'] as String;
        if (!File(filePath).existsSync()) {
          throw Exception('Dosya bulunamadı: $filePath');
        }
      }
      
      // Her bir dosya için uploadFile metodunu çalıştırma ve total progress takip etme
      List<String> fileUrls = [];
      int totalFiles = files.length;
      double totalProgress = 0.0;
      
      // Basepath'i temizle
      String sanitizedBasePath = basePath.replaceAll(RegExp(r'[#$.\[\]/]'), '_');
      
      for (int i = 0; i < files.length; i++) {
        try {
          final file = files[i];
          final filePath = file['path'] as String;
          
          // Her dosya için benzersiz bir dosya yolu oluştur
          final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
          final destination = '$sanitizedBasePath/${uniqueId.substring(uniqueId.length - 6)}';
          
          final fileUrl = await uploadFile(
            filePath: filePath, 
            destination: destination,
            onProgress: (fileProgress) {
              totalProgress = (i / totalFiles) + (fileProgress / totalFiles);
              if (onProgress != null) {
                onProgress(totalProgress);
              }
            }
          );
          
          fileUrls.add(fileUrl);
        } catch (e) {
          debugPrint('Dosya ${i+1} yükleme hatası: $e');
          // Devam et ve diğer dosyaları yüklemeyi dene
        }
      }
      
      if (fileUrls.isEmpty && files.isNotEmpty) {
        throw Exception('Hiçbir dosya yüklenemedi');
      }
      
      return fileUrls;
    } catch (e) {
      debugPrint('Çoklu dosya yükleme hatası: $e');
      throw Exception('Dosyalar yüklenirken bir hata oluştu: $e');
    }
  }
  
  /// Dosya silme işlemi
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      debugPrint('Firebase dosya silme hatası: ${e.code} - ${e.message}');
      if (e.code == 'object-not-found') {
        debugPrint('Silinecek dosya zaten yok');
        return; // Dosya zaten yoksa hata fırlatma
      }
      throw Exception('Dosya silinirken Firebase hatası: ${e.message}');
    } catch (e) {
      debugPrint('Dosya silme hatası: $e');
      throw Exception('Dosya silinirken bir hata oluştu: $e');
    }
  }
  
  /// Çoklu dosya silme işlemi
  Future<void> deleteMultipleFiles(List<String> fileUrls) async {
    try {
      if (fileUrls.isEmpty) return;
      
      for (final url in fileUrls) {
        try {
          await deleteFile(url);
        } catch (e) {
          // Bir dosya silinemese bile diğerlerini silmeye devam et
          debugPrint('Dosya $url silme hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('Çoklu dosya silme hatası: $e');
      throw Exception('Dosyalar silinirken bir hata oluştu: $e');
    }
  }
  
  /// Dosya türüne göre content type belirle
  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream'; // Bilinmeyen dosya türü
    }
  }
  
  /// Firebase Storage bağlantısını test et
  Future<bool> testStorageConnection() async {
    try {
      // Oturum kontrolü yap
      if (_auth.currentUser == null) {
        debugPrint('Firebase Storage bağlantı testi: Kullanıcı oturumu yok');
        return false;
      }
      
      // Basit bir test dosyası yükle - rules.txt'deki kurallarla uyumlu olmalı
      final testData = Uint8List.fromList(utf8.encode('test data'));
      final testRef = _storage.ref('files/test/test_connection.txt');
      
      // Yüklemeyi dene
      final task = testRef.putData(testData);
      await task;
      
      // URL'i al
      final url = await testRef.getDownloadURL();
      
      // Dosyayı sil
      try {
        await testRef.delete();
      } catch (e) {
        // Silme hatası önemli değil
        debugPrint('Test dosyası silinirken hata: $e');
      }
      
      return true;
    } catch (e) {
      debugPrint('Firebase Storage bağlantı testi başarısız: $e');
      return false;
    }
  }

  /// Dosya indirme ve açma
  static Future<void> downloadAndOpenFile(String fileUrl, String fileName, {Function(double)? onProgress}) async {
    File? downloadedFile;
    try {
      debugPrint('Dosya indirme başladı: $fileUrl');
      debugPrint('Hedef dosya adı: $fileName');

      // URL kontrolü
      if (fileUrl.isEmpty) {
        throw Exception('Dosya URL\'i boş olamaz');
      }

      // Dosya adı kontrolü
      if (fileName.isEmpty) {
        // URL'den dosya adını çıkar
        final uri = Uri.parse(fileUrl);
        fileName = path.basename(uri.path);
        if (fileName.isEmpty) {
          fileName = 'indirilen_dosya_${DateTime.now().millisecondsSinceEpoch}';
        }
        debugPrint('URL\'den çıkarılan dosya adı: $fileName');
      }

      // İndirme dizinini al
      final dir = await getApplicationDocumentsDirectory();
      final savePath = path.join(dir.path, fileName);
      debugPrint('Dosya kaydedilecek yol: $savePath');

      // Eğer dosya zaten varsa sil
      downloadedFile = File(savePath);
      if (await downloadedFile.exists()) {
        debugPrint('Var olan dosya siliniyor: $savePath');
        await downloadedFile.delete();
      }

      // Dio yapılandırması
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      dio.options.followRedirects = true;
      dio.options.maxRedirects = 5;

      debugPrint('Dosya indirme işlemi başlıyor...');
      
      // Dosyayı indir
      final response = await dio.download(
        fileUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            debugPrint('İndirme ilerlemesi: ${(progress * 100).toStringAsFixed(1)}%');
            if (onProgress != null) {
              onProgress(progress);
            }
          }
        },
        deleteOnError: true,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Dosya indirme başarısız: HTTP ${response.statusCode}');
      }

      // İndirilen dosyanın varlığını kontrol et
      if (!await downloadedFile.exists()) {
        throw Exception('Dosya indirildi fakat kaydedilemedi: $savePath');
      }

      // Dosya boyutunu kontrol et
      final fileSize = await downloadedFile.length();
      debugPrint('İndirilen dosya boyutu: ${fileSize} bytes');
      
      if (fileSize == 0) {
        throw Exception('İndirilen dosya boş (0 bytes)');
      }

      debugPrint('Dosya başarıyla indirildi, açılmaya çalışılıyor...');
      
      // Dosyayı aç
      final result = await OpenFile.open(savePath);
      
      if (result.type != ResultType.done) {
        throw Exception('Dosya açılamadı: ${result.message}');
      }
      
      debugPrint('Dosya başarıyla açıldı');
    } catch (e) {
      debugPrint('Dosya indirme/açma hatası: $e');
      // Hata durumunda indirilen dosyayı temizle
      if (downloadedFile != null && await downloadedFile.exists()) {
        try {
          await downloadedFile.delete();
          debugPrint('Hata nedeniyle indirilen dosya silindi');
        } catch (deleteError) {
          debugPrint('Hatalı dosya silinirken hata: $deleteError');
        }
      }
      throw Exception('Dosya indirilemedi veya açılamadı: $e');
    }
  }
} 