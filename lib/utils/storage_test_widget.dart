import 'package:flutter/material.dart';
import 'package:math_app/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Storage bağlantısını test etmek için kullanılan widget
class StorageTestWidget extends StatefulWidget {
  const StorageTestWidget({super.key});

  @override
  State<StorageTestWidget> createState() => _StorageTestWidgetState();
}

class _StorageTestWidgetState extends State<StorageTestWidget> {
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool? _testResult;
  String _errorMessage = '';
  String _detailedErrorInfo = '';

  Future<void> _testStorageConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
      _errorMessage = '';
      _detailedErrorInfo = '';
    });

    // Kullanıcı oturum açmış mı kontrol et
    if (_auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _testResult = false;
        _errorMessage = 'Kullanıcı oturumu yok. Önce giriş yapmalısınız.';
        _detailedErrorInfo = 'Firebase Storage kuralları kimlik doğrulaması gerektirir. '
            'Firebase Storage\'a dosya yükleyebilmek için önce bir kullanıcı olarak giriş yapmalısınız.';
      });
      return;
    }

    try {
      final result = await _storageService.testStorageConnection();
      
      setState(() {
        _testResult = result;
        _isLoading = false;
        
        if (!result) {
          _errorMessage = 'Firebase Storage bağlantısı kurulamadı.';
          _detailedErrorInfo = 'Bu hata genellikle Firebase Storage kuralları ile ilgili sorunlardan kaynaklanır. '
              'Lütfen Firebase konsolunda Storage kurallarınızı kontrol edin.';
        }
      });
    } catch (e) {
      String errorDetail = '';
      
      if (e.toString().contains('unauthorized') || e.toString().contains('permission-denied')) {
        errorDetail = 'Bu hata, Firebase Storage kurallarında yetkilendirme sorunu olduğunu gösterir. '
            'Firebase konsolundan Storage > Rules bölümünü kontrol edin ve kuralları güncelleyin.';
      } else if (e.toString().contains('not-found')) {
        errorDetail = 'Bu hata, dosyanın veya klasörün bulunamadığını gösterir. '
            'Firebase Storage klasör yapısını kontrol edin.';
      } else if (e.toString().contains('network')) {
        errorDetail = 'Bu hata, internet bağlantısı sorunu olduğunu gösterir. '
            'İnternet bağlantınızı kontrol edin.';
      } else {
        errorDetail = 'Firebase Storage hizmetine erişimde bir sorun var. '
            'Firebase projenizin ayarlarını kontrol edin.';
      }
      
      setState(() {
        _errorMessage = e.toString();
        _detailedErrorInfo = errorDetail;
        _testResult = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Firebase Storage Bağlantı Testi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) 
              const CircularProgressIndicator()
            else if (_testResult != null)
              Icon(
                _testResult! ? Icons.check_circle : Icons.error,
                color: _testResult! ? Colors.green : Colors.red,
                size: 48,
              ),
            const SizedBox(height: 16),
            Text(
              _testResult == null
                ? 'Test henüz çalıştırılmadı'
                : _testResult!
                  ? 'Firebase Storage bağlantısı başarılı'
                  : 'Firebase Storage bağlantısı başarısız',
              style: TextStyle(
                color: _testResult == null
                  ? Colors.grey
                  : _testResult!
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hata Detayı:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                    if (_detailedErrorInfo.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Çözüm Önerisi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _detailedErrorInfo,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testStorageConnection,
              child: const Text('Bağlantıyı Test Et'),
            ),
          ],
        ),
      ),
    );
  }
} 