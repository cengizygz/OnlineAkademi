## Genel Bilgi

* **Proje Adı:** Özel Ders Mobil Uygulaması
* **Amaç:** Öğretmenin öğrencileriyle sınav, ödev ve iletişimi kolayca yönetmesi
* **Platform:** Flutter (iOS & Android)
* **Roller:** Öğretmen, Öğrenci

---

## Yapıldı Özellikler

| Özellik                | Açıklama                                                |
| ---------------------- | ------------------------------------------------------- |
| Giriş / Kayıt          | Email ile kayıt ve giriş ekranı tamamlandı              |
| Öğretmen Paneli        | Öğrencileri görme, görevler ekleme arayüzü oluşturuldu  |
| Öğrenci Paneli         | Ödev/sınav durumu, öğretmen notları arayüzü oluşturuldu |
| Sınav Ekleme / Yükleme | Öğretmenin sınav oluşturma, öğrencinin görüntüleme ekranları tamamlandı |
| Ödev Takibi            | Ödev ekleme ve öğrenci teslim ekranları tamamlandı      |
| Soru Sorma             | Öğrencinin öğretmene soru sorma ekranı tamamlandı       |
| Profil Sayfası         | Kullanıcı bilgileri düzenleme ekranı tamamlandı         |

## Yapılacak Özellikler

| Özellik                | Açıklama                                                |
| ---------------------- | ------------------------------------------------------- |
| Cevaplama Modülü       | Öğretmenin cevap verme ekranı                           |
| Duyuru Gönderme        | Öğretmenin tüm öğrencilere kısa mesaj göndermesi        |
| Takvim / Ders Planı    | Ders tarihlerini belirleyip öğrencilere gösterme        |
| Not Takibi ve Grafik   | Öğrenciye verilen notları grafikle gösterme             |
| Basit Mesajlaşma       | Öğrenci - öğretmen arası yazışma                        |
| Bildirimler            | Ödev/sınav/cevap olduğunda uyarı (Firebase)             |
| Canlı Ders Linki       | Zoom/Meet bağlantısı paylaşma                           |

---

## Teknik Yapı

* **Flutter:** Mobil uygulama için
* **Firebase:** Auth, Firestore, Storage, Cloud Messaging
* **State Management:** Riverpod veya Provider

---

## Tamamlanan Teknik Yapılar

1. **Ana Yapı:**
   - Proje klasör yapısı: features, core, assets
   - Rota sistemi: AppRoutes sınıfı ile tüm yönlendirmeler
   - Tema ayarları: AppTheme ile standart stil tanımları
   - Sabitler: AppConstants ile route ve rol tanımları

2. **Arayüz Bileşenleri:**
   - Auth: Giriş ve kayıt ekranları
   - Öğretmen: Ana ekran, sınav oluşturma, ödev oluşturma
   - Öğrenci: Ana ekran, sınav görüntüleme, ödev görüntüleme, soru sorma
   - Profil: Kullanıcı profil sayfası

3. **Tamamlanmış Kullanıcı Ekranları:**
   - LoginScreen: E-posta ve şifre ile giriş
   - RegisterScreen: Yeni hesap oluşturma ve rol seçimi
   - TeacherHomeScreen: Öğrenci listesi, görev listesi, takvim sekmeleri
   - StudentHomeScreen: Görevler, sorular, takvim sekmeleri
   - ExamCreateScreen: Çoktan seçmeli sınav hazırlama
   - ExamViewScreen: Öğrencinin sınavı görüntüleme/cevaplama
   - HomeworkCreateScreen: Görev bazlı ödev oluşturma
   - HomeworkViewScreen: Görevlerin tamamlanma durumunu işaretleme
   - AskQuestionScreen: Öğrencinin soru sorabilmesi
   - ProfileScreen: Kullanıcı bilgilerini düzenleme

---

## Notlar ve Sonraki Adımlar

* Firebase entegrasyonu yapılacak (Auth, Firestore, Storage, Cloud Messaging)
* State management için Riverpod entegrasyonu
* Eksik ekranların tamamlanması (cevaplama, mesajlaşma)
* Bildirim sistemi
* Performans iyileştirmeleri
* Test yazımı

---

## Nasıl Çalıştırılır

1. Flutter'ı yükleyin ve projeyi klonlayın
2. Bağımlılıkları yükleyin: `flutter pub get`
3. Uygulamayı çalıştırın: `flutter run`

**Test kullanıcıları:**
- Öğretmen: teacher@example.com / 123456
- Öğrenci: student@example.com / 123456

Not: Firebase entegrasyonu yapılana kadar gerçek veri kaydı yapılmamaktadır. Tüm veriler örnek verilerdir.







## 📌 Amaç
Bu sistem; öğrencilerin test tipi sorular hazırlayıp havuza ekleyebildiği, diğer öğrencilerin bu soruları yalnızca bir kez çözebildiği, doğru çözüldüğünde puan kazanabildiği ve çözümün soru sahibine iletildiği bir etkileşimli öğrenme platformudur. Öğretmen onayı ile yayınlanan sorular yalnızca ilk doğru çözüme açık olacak şekilde çalışır.

---

## 👥 Hedef Kullanıcılar
- Öğrenciler
- Öğretmenler / Moderatörler

---

## 🔁 Akış Özeti
1. Öğrenci test sorusu oluşturur.
2. Öğretmen/moderatör soruyu onaylar.
3. Soru havuza düşer, öğrenciler tarafından çözülmeye hazır hale gelir.
4. İlk doğru çözen öğrenci puan kazanır, dosya yükleyebilir ve açıklama bırakabilir.
5. Soru çözüldüğünde havuzdan kalkar.
6. Soru sahibi öğrenciye çözüm, açıklama ve dosya otomatik olarak iletilir.

---

## 🧩 Özellikler

### 🔹 1. Soru Oluşturma
- Soru metni
- 4 adet çoktan seçmeli şık (A, B, C, D)
- Doğru şık seçimi
- Ders ve konu seçimi
- “Gönder” butonuna basıldığında sistem, soruyu moderasyona gönderir

### 🔹 2. Öğretmen Onayı
- “Bekleyen Sorular” paneli
- Soru ön izlemesi
- Onayla / Reddet seçenekleri
- Onaylanan sorular havuza düşer

### 🔹 3. Soru Çözme
- Öğrenci, sadece **bir kez** çözebilir
- Cevap seçimi sonrası:
  - Açıklama yazabilir (isteğe bağlı)
  - Dosya yükleyebilir (PDF/JPG vb.)

### 🔹 4. Puanlama ve Bildirimler
- İlk doğru çözen öğrenciye puan (örn: +10)
- Soruyu soran öğrenciye:
  - Doğru cevap
  - Açıklama
  - Çözüm dosyası
- Soru havuzdan kalkar


## 📱 Flutter UI Akış

### 👨‍🎓 Öğrenci Ekranları
- Soru oluşturma formu
- Soru çözme ekranı (şıklar, dosya ve açıklama alanı)
- Bildirim: “Sorun çözüldü!”

### 👨‍🏫 Öğretmen Paneli
- Bekleyen sorular listesi
- Soru detayına bak / Onayla / Reddet

---

## 🧪 Test Senaryoları
- [ ] Öğrenci boş alan bırakmadan soru oluşturabiliyor mu?
- [ ] Öğretmen onaylamadan soru çözülebiliyor mu? (olmamalı)
- [ ] Aynı kullanıcı aynı soruyu iki kez çözebiliyor mu? (olmamalı)
- [ ] Dosya ve açıklama doğru şekilde yüklenip görüntüleniyor mu?
- [ ] Sorunun çözülmesi sonrası doğru öğrenciye puan gidiyor mu?
- [ ] Soru çözüldükten sonra havuzdan otomatik kalkıyor mu?

---

## ⚙️ Teknik Notlar
- Dosya yüklemek için Firebase Storage veya başka bir bulut servis önerilir
- Gerçek zamanlı güncellemeler için Firebase veya socket kullanımı düşünülebilir
- Soru çözüldüğünde push bildirimi ile öğrenci bilgilendirme yapılabilir

---

## 🏁 Versiyon 1.0 Hedefleri
- Soru oluşturma & onay sistemi
- İlk doğru çözüm üzerinden puanlama
- Çözüm dosyası + açıklama gönderme
- Soru çözüm sonrası havuzdan kalkma

---

