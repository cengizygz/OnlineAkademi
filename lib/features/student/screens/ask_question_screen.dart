import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/student_service.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _questionController = TextEditingController();
  bool _isLoading = false;
  bool _hasImage = false;
  String? _imageUrl;
  String _errorMessage = '';
  
  // StudentService ekle
  final StudentService _studentService = StudentService();

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Firebase'e soruyu kaydet
        await _studentService.addQuestion(
          _titleController.text.trim(),
          _questionController.text.trim(),
          _imageUrl
        );

        if (!mounted) return;

        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorunuz başarıyla gönderildi'),
            backgroundColor: Colors.green,
          ),
        );

        // Öğrenci paneline geri dön ve veri yenileme bilgisi gönder
        Navigator.pop(context, true);
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Soru gönderilirken hata oluştu: $e';
        });
      }
    }
  }

  void _pickImage() {
    // Resim seçme işlemi - Firebase Storage entegrasyonu sonrası yapılacak
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resim ekleme özelliği Firebase entegrasyonu sonrası aktif olacak'),
      ),
    );

    // Simülasyon için
    setState(() {
      _hasImage = true;
      // Gerçek uygulamada buraya resim seçme ve yükleme kodu gelecek
      // _imageUrl = 'firebase_storage_url';
    });
  }

  void _removeImage() {
    setState(() {
      _hasImage = false;
      _imageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Sor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Soru Başlığı',
                        hintText: 'Örn: Türev formülünü anlamadım',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir başlık girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Sorunuz',
                        hintText: 'Sorunuzu detaylı bir şekilde açıklayın',
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen sorunuzu girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Resim Ekle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sorunuzla ilgili bir resim ekleyebilirsiniz (isteğe bağlı)',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_hasImage) ...[
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('Örnek Resim (simülasyon)'),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text('Resim Ekle'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitQuestion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Soruyu Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 