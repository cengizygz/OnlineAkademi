# Firebase Storage Sorunları ve Çözüm Kılavuzu

## Sorun Tespiti

Uygulamada dosya yükleme işlemleri sırasında aşağıdaki hata mesajlarıyla karşılaşılıyor:

```
E/StorageException: Object does not exist at location.
E/StorageException: Code: -13010 HttpResult: 404
E/StorageException: The server has terminated the upload session
I/flutter: Firebase Storage bağlantı testi başarısız: [firebase_storage/unauthorized] User is not authorized to perform the desired action.
```

Bu hata, Firebase Storage'da yetkilendirme kuralları veya referans yollarıyla ilgili sorunlardan kaynaklanmaktadır.

## Çözüm Adımları

### 1. Öncelikle Kimlik Doğrulama (Authentication) Kontrolü

1. Uygulamada bir kullanıcı olarak giriş yaptığınızdan emin olun
2. Giriş yapmadıysanız, önce oturum açın
3. Test ekranında giriş durumunuz görüntülenir
4. Firebase kuralları `request.auth != null` kontrolü yaptığı için oturum açık olmalıdır

### 2. Firebase Konsolu'nda Storage Kurallarını Güncelleme

Firebase console'a gidin (https://console.firebase.google.com/) ve projenizin Storage > Rules kısmında aşağıdaki kuralları kullanın:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Tüm dosya yükleme ve okuma işlemlerine izin ver
    match /files/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Ödevler için dosya izinleri
    match /homework_{homeworkId}_{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Öğretmenler için dosya izinleri
    match /teacher_homework_{homeworkId}_{teacherId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == teacherId;
    }
  }
}
```

### 3. Firebase Storage Bucket'ı Yapılandırma

1. Firebase konsolunda Storage kısmına gidin
2. Henüz başlatılmadıysa, "Get Started" butonuna tıklayarak Storage'ı başlatın
3. Bucket konumunu seçin (genellikle size en yakın bölge)
4. İlk olarak "Start in test mode" seçeneğini seçerek test yapılmasını sağlayın
5. Test işlemlerinden sonra yukarıdaki güvenlik kurallarını kullanın

### 4. "Unauthorized" Hatası için Özel Çözüm

Bu hata genellikle aşağıdaki durumlarda oluşur:

1. Kullanıcı oturum açmamışken dosya yükleme işlemi yapılmaya çalışılıyor
2. Firebase Storage kurallarınız, dosya yolunuzla uyumlu değil
3. Storage kuralları güncellenmiş ancak güncellemeler henüz uygulanmamış

Çözüm:

1. Storage Test Ekranı'nı açın (`/storage-test` rotası)
2. Kimlik doğrulama durumunuzu kontrol edin - oturum açık olmalıdır
3. "Bağlantıyı Test Et" butonuna tıklayın ve sonucu görün
4. Hata devam ediyorsa:
   - Firebase konsolunu açın
   - Storage > Rules kısmına gidin
   - Kuralları yukarıdaki gibi güncelleyin
   - **"Publish"** butonuna tıklayın (Bu adım çok önemli!)
   - Kuralların yayınlanması için 1-2 dakika bekleyin
5. Testi tekrar çalıştırın

### 5. Internet İzinlerini Kontrol Etme

Android Manifest dosyasında internet izinlerinin tanımlandığından emin olun:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 6. Firebase Storage Yollarını Doğru Kullanma

Uygulamada kullanılan dosya yollarının Firebase kurallarıyla uyumlu olduğundan emin olun:

1. `files/{klasör}/{dosya}` şeklinde yollar kullanılmalıdır
2. Özel karakterler (`#`, `$`, `.`, `[`, `]`, `/`) dosya yollarında sorun yaratabilir
3. Dosya yüklerken bu karakterlerin temizlendiğinden emin olun

### 7. Sorun Devam Ederse

Sorun hâlâ devam ediyorsa aşağıdaki adımları deneyin:

1. Firebase projesi ayarlarını kontrol edin (Firebase console > Project settings)
2. SHA-1 ve SHA-256 parmak izlerinin doğru ayarlandığından emin olun
3. google-services.json dosyasını güncelleyin
4. Emülatör veya cihazla test yaparken internet bağlantısının çalıştığından emin olun
5. Firebase konsolunda Storage > Usage bölümünde aktivite olup olmadığını kontrol edin
6. Firebase Authentication > Usage bölümünde kullanıcı oturumlarını kontrol edin

## Yardımcı Kaynaklar

- [Firebase Storage Dokümantasyonu](https://firebase.google.com/docs/storage)
- [Firebase Storage Güvenlik Kuralları](https://firebase.google.com/docs/storage/security/get-started)
- [Firebase Storage Flutter Entegrasyonu](https://firebase.flutter.dev/docs/storage/overview/) 