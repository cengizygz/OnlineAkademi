import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/exam_service.dart';

class ExamViewScreen extends StatefulWidget {
  final String? examId;
  
  const ExamViewScreen({super.key, this.examId});

  @override
  State<ExamViewScreen> createState() => _ExamViewScreenState();
}

class _ExamViewScreenState extends State<ExamViewScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  String? _resolvedExamId;
  
  // Sınav verisi
  Map<String, dynamic>? _exam;
  
  // Öğrencinin cevapları - başlangıçta boş
  final Map<String, String> _studentAnswers = {};
  
  // Servis
  final ExamService _examService = ExamService();
  
  @override
  void initState() {
    super.initState();
    // Sınav ID'sini almak için biraz gecikelim
    // Bu, argümanların düzgün bir şekilde alınmasını sağlar
    Future.delayed(Duration.zero, () {
      _resolveExamId();
    });
  }
  
  void _resolveExamId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    
    String? examId;
    
    // Widget üzerinden gelen ID
    if (widget.examId != null && widget.examId!.isNotEmpty) {
      examId = widget.examId;
      print('ExamID from widget: $examId');
    } 
    // Route üzerinden gelen string ID
    else if (args is String) {
      examId = args;
      print('ExamID from route (String): $examId');
    }
    // Route üzerinden gelen map ID
    else if (args is Map<String, dynamic> && args.containsKey('id')) {
      examId = args['id']?.toString();
      print('ExamID from route (Map): $examId');
    }
    
    setState(() {
      _resolvedExamId = examId;
    });
    
    if (examId != null && examId.isNotEmpty) {
      _loadExam(examId);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sınav ID\'si bulunamadı veya geçersiz';
      });
    }
  }
  
  Future<void> _loadExam(String examId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      print('Sınav yükleniyor: $examId');
      
      _exam = await _examService.getExam(examId);
      
      print('Sınav başarıyla yüklendi: ${_exam?['title']}');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Sınav yükleme hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sınav yüklenirken hata: $e';
      });
    }
  }
  
  Future<void> _submitExam() async {
    // Sınav yüklenmemişse çıkış yap
    if (_exam == null || _resolvedExamId == null) {
      return;
    }
    
    final questions = _exam!['questions'] as List<Map<String, dynamic>>;
    
    // Tüm soruların cevaplanıp cevaplanmadığını kontrol et
    bool allAnswered = true;
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionId = question['id'] ?? 'q_$i';
      if (!_studentAnswers.containsKey(questionId) || _studentAnswers[questionId]!.isEmpty) {
        allAnswered = false;
        break;
      }
    }
    
    if (!allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm soruları cevaplayın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    
    try {
      // Cevapları Firebase'e gönder
      List<String> answers = [];
      
      print('Öğrenci cevapları hazırlanıyor:');
      // Doğru sırada cevapları ekle
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];
        final questionId = question['id'] ?? 'q_$i';
        final answer = _studentAnswers[questionId] ?? '';
        
        print('Soru ${i+1} (ID: $questionId):');
        print('- Soru: ${question['question']}');
        print('- Seçilen cevap: $answer');
        if (question.containsKey('correctAnswer')) {
          print('- Doğru cevap: ${question['correctAnswer']}');
        }
        
        answers.add(answer);
      }
      print('Gönderilecek cevaplar: $answers');
      
      await _examService.submitExamAnswers(_resolvedExamId!, answers);
      
      // Otomatik puanlama yap
      try {
        final studentId = _examService.getCurrentUserId();
        await _examService.autoGradeExam(_resolvedExamId!, studentId);
      } catch (e) {
        print('Otomatik puanlama hatası: $e');
        // Otomatik puanlama başarısız olsa bile devam et
      }
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sınav başarıyla gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Geri dön
      Navigator.pop(context, true); // true değerini döndürerek veri değişikliğini belirt
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Sınav gönderilirken hata: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_exam != null ? _exam!['title'] : 'Sınav'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_resolvedExamId != null)
                          Text(
                            'Sınav ID: $_resolvedExamId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _resolvedExamId != null 
                              ? _loadExam(_resolvedExamId!) 
                              : _resolveExamId(),
                          child: const Text('Tekrar Dene'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Geri Dön'),
                        ),
                      ],
                    ),
                  ),
                )
              : _exam == null
                  ? const Center(child: Text('Sınav bulunamadı'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _exam!['title'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _exam!['description'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Son Tarih: ${_formatDate(_exam!['dueDate'])}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Sorular',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (_exam!['questions'] as List).length,
                            itemBuilder: (context, index) {
                              final question = (_exam!['questions'] as List)[index] as Map<String, dynamic>;
                              return _buildQuestionCard(question, index);
                            },
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitExam,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Sınavı Gönder',
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
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    // Unique ID oluştur
    final String questionId = question['id'] ?? 'q_$index';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soru ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (question['question'] != null && (question['question'] as String).trim().isNotEmpty) ...[
              Text(
                question['question'],
                style: const TextStyle(fontSize: 16),
              ),
            ] else ...[
              // imageUrl güvenli kontrol
              if (((question['imageUrl'] ?? '').toString()).isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    (question['imageUrl'] ?? '').toString(),
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bu soru görsel tabanlıdır.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ] else ...[
                const Text(
                  'Soru metni veya görseli bulunamadı.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
                ),
              ],
            ],
            const SizedBox(height: 16),
            ...['A', 'B', 'C', 'D'].map((option) {
              final options = question['options'] as Map<String, dynamic>;
              return _buildOptionTile(questionId, option, options[option]);
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionTile(String questionId, String option, String optionText) {
    final isSelected = _studentAnswers[questionId] == option;
    
    return RadioListTile<String>(
      title: Text(optionText),
      value: option,
      groupValue: _studentAnswers[questionId],
      onChanged: (value) {
        setState(() {
          _studentAnswers[questionId] = value!;
        });
      },
      activeColor: Colors.blue,
      selected: isSelected,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
} 