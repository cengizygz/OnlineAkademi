import 'package:flutter/material.dart';
import 'package:math_app/services/question_pool_service.dart';

class QuestionCreateScreen extends StatefulWidget {
  const QuestionCreateScreen({super.key});

  @override
  State<QuestionCreateScreen> createState() => _QuestionCreateScreenState();
}

class _QuestionCreateScreenState extends State<QuestionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final QuestionPoolService _questionService = QuestionPoolService();
  
  // Form alanları
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4, (_) => TextEditingController(),
  );
  String _selectedCorrectAnswer = 'A';
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Seçenek indeksi -> Harf dönüşümü
  String _getOptionLetter(int index) {
    return String.fromCharCode(65 + index); // A, B, C, D
  }
  
  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _subjectController.dispose();
    _topicController.dispose();
    super.dispose();
  }
  
  Future<void> _submitQuestion() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        // Şıkları listeye dönüştür
        final options = _optionControllers.map((c) => c.text.trim()).toList();
        
        // Soruyu oluştur
        await _questionService.createQuestion(
          questionText: _questionController.text.trim(),
          options: options,
          correctAnswer: _selectedCorrectAnswer,
          subject: _subjectController.text.trim(),
          topic: _topicController.text.trim(),
        );
        
        if (!mounted) return;
        
        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorunuz başarıyla gönderildi! Öğretmen onayı sonrası havuza eklenecektir.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Formu temizle
        _clearForm();
        
        // Önceki sayfaya dön
        Navigator.pop(context, true); // true: veri güncellendi
        
      } catch (e) {
        setState(() {
          _errorMessage = 'Soru gönderilirken hata oluştu: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _clearForm() {
    _questionController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    _subjectController.clear();
    _topicController.clear();
    setState(() {
      _selectedCorrectAnswer = 'A';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bilgi kartı
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Nasıl Çalışır?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Oluşturduğunuz soru öğretmen onayından sonra soru havuzuna eklenir. '
                        'İlk doğru çözen öğrencinin çözümü size iletilir ve öğrenci puan kazanır.',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Soru metni
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Soru Metni',
                  hintText: 'Sorunuzu buraya yazın',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen bir soru yazın';
                  }
                  if (value.length < 10) {
                    return 'Soru en az 10 karakter olmalı';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Şıklar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              
              // Şıklar
              const SizedBox(height: 8),
              ...List.generate(4, (index) {
                final letter = _getOptionLetter(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Şık etiketi
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedCorrectAnswer == letter 
                              ? Colors.green 
                              : Colors.grey.shade300,
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedCorrectAnswer == letter
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Şık içeriği
                      Expanded(
                        child: TextFormField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            hintText: '$letter şıkkı',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '$letter şıkkı boş olamaz';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // Doğru cevap seçici
                      Radio<String>(
                        value: letter,
                        groupValue: _selectedCorrectAnswer,
                        onChanged: (value) {
                          setState(() {
                            _selectedCorrectAnswer = value!;
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Doğru Cevap:'),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCorrectAnswer,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Ders ve konu
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Ders',
                        hintText: 'Örn: Matematik',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ders adı gerekli';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'Konu',
                        hintText: 'Örn: Trigonometri',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Konu adı gerekli';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              // Hata mesajı
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Gönder butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitQuestion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Soruyu Gönder',
                          style: TextStyle(fontSize: 16),
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