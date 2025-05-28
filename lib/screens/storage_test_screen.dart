import 'package:flutter/material.dart';
import 'package:math_app/utils/storage_test_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageTestScreen extends StatelessWidget {
  const StorageTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final bool isUserLoggedIn = auth.currentUser != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Storage Test'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Firebase Storage Bağlantı Testi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu sayfa, uygulamanızın Firebase Storage\'a bağlanabildiğini doğrulamak için kullanılır. Eğer test başarısız olursa, Firebase konsolundaki ayarlarınızı kontrol edin.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              // Kimlik doğrulama durumu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUserLoggedIn ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUserLoggedIn ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUserLoggedIn ? Icons.check_circle : Icons.error,
                      color: isUserLoggedIn ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kimlik Doğrulama Durumu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isUserLoggedIn ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isUserLoggedIn 
                              ? 'Oturum açmış kullanıcı: ${auth.currentUser?.email ?? "Bilinmiyor"}'
                              : 'Oturum açılmamış! Dosya işlemleri için önce giriş yapın.',
                            style: TextStyle(
                              color: isUserLoggedIn ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const StorageTestWidget(),
              const SizedBox(height: 24),
              const Text(
                'Sorun giderme adımları:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildTroubleshootingStep(
                '1. Firebase konsolunda Storage aktivasyonunu kontrol edin',
                'Firebase Storage etkinleştirilmiş olmalıdır.',
              ),
              _buildTroubleshootingStep(
                '2. Storage izinlerini kontrol edin',
                'Firebase konsolunda Storage > Rules bölümünden izinlerin aşağıdaki gibi olup olmadığını kontrol edin:\n\nallow read, write: if request.auth != null;',
              ),
              _buildTroubleshootingStep(
                '3. Kimlik doğrulama durumunu kontrol edin',
                'Uygulamada giriş yapmış bir kullanıcı olmalıdır.',
              ),
              _buildTroubleshootingStep(
                '4. İnternet bağlantısını kontrol edin',
                'İnternet bağlantısının aktif olduğundan emin olun.',
              ),
              _buildTroubleshootingStep(
                '5. Firebase konsolunda Storage izinleri',
                'Firebase konsolundan Storage kurallarını güncelleyin:\n\nrules_version = \'2\';\nservice firebase.storage {\n  match /b/{bucket}/o {\n    match /files/{allPaths=**} {\n      allow read, write: if request.auth != null;\n    }\n  }\n}',
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTroubleshootingStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(description),
        ],
      ),
    );
  }
} 