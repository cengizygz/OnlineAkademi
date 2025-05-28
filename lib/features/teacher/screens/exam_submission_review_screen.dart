import 'package:flutter/material.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSubmissionReviewScreen extends StatefulWidget {
  final String examId;
  final String studentId;
  
  const ExamSubmissionReviewScreen({
    super.key, 
    required this.examId, 
    required this.studentId
  });

  @override
  State<ExamSubmissionReviewScreen> createState() => _ExamSubmissionReviewScreenState();
}

class _ExamSubmissionReviewScreenState extends State<ExamSubmissionReviewScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  Map<String, dynamic>? _submissionData;
  
  // Puanlama için
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSubmissionData();
  }
  
  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSubmissionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Öğrenci cevaplarını getir
      _submissionData = await _examService.getStudentExamSubmission(
        widget.examId, 
        widget.studentId
      );
      
      final questions = _submissionData!['questions'] as List<Map<String, dynamic>>;
      final answers = _submissionData!['answers'] as List<String>;
      
      // Öğrenci sonuçlarını ve doğru cevapları analiz et
      int correctAnswers = _calculateCorrectAnswers(questions, answers);
      int totalQuestions = questions.length;
      int calculatedScore = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
      
      print('Öğrenci cevapları analiz edildi:');
      print('Doğru sayısı: $correctAnswers / $totalQuestions');
      print('Hesaplanan puan: $calculatedScore');
      
      // Eğer zaten puanlanmışsa, mevcut puanı ve geri bildirimi yükle
      if (_submissionData!['graded']) {
        _scoreController.text = _submissionData!['score'].toString();
        _feedbackController.text = _submissionData!['feedback'];
        
        print('Mevcut puan: ${_submissionData!['score']}');
        if (_submissionData!.containsKey('isAutoGraded') && _submissionData!['isAutoGraded'] == true) {
          print('Bu sınav otomatik olarak puanlanmış');
        }
      } else {
        // Otomatik puanlama sonucunu öner
        _scoreController.text = calculatedScore.toString();
        _feedbackController.text = 'Otomatik hesaplanan puan: $calculatedScore/100\nDoğru cevap sayısı: $correctAnswers/$totalQuestions\n\nÖğretmen notları:';
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  int _calculateCorrectAnswers(List<Map<String, dynamic>> questions, List<String> answers) {
    int correctAnswers = 0;
    int totalQuestions = questions.length;
      
    for (int i = 0; i < totalQuestions; i++) {
      if (i < answers.length) {
        final question = questions[i];
        final studentAnswer = answers[i];
        
        if (studentAnswer.isEmpty) {
          print('Soru ${i+1}: Cevap verilmemiş');
          continue; // Boş cevap, atla
        }
        
        // Doğru cevabı al
        String correctAnswer = question['correctAnswer'] ?? '';
        if (correctAnswer.isEmpty) {
          print('Soru ${i+1}: Doğru cevap tanımlanmamış');
          continue; // Doğru cevap tanımlanmamış, atla
        }
        
        print('Soru ${i+1}: "${question['question'] ?? ''}"');
        print('- Öğrenci cevabı: "$studentAnswer"');
        print('- Doğru cevap: "$correctAnswer"');
        
        bool isCorrect = false;
        
        // Öğrenci A, B, C, D formatında cevap verdi
        // Doğru cevabın formatını kontrol et ve karşılaştır
        if (studentAnswer == correctAnswer) {
          // Direk eşleşme
          isCorrect = true;
          print('- Eşleşme: Doğrudan eşleşme');
        } else if (correctAnswer.length > 1 && ['A', 'B', 'C', 'D'].contains(studentAnswer)) {
          // Şıkların içeriklerini kontrol et
          final options = question['options'] as Map<String, dynamic>?;
          if (options != null) {
            final optionContent = options[studentAnswer];
            print('- Şık içeriği kontrol ediliyor: $studentAnswer = $optionContent');
            if (optionContent == correctAnswer) {
              isCorrect = true;
              print('- Eşleşme: Şık içeriği doğru cevapla eşleşiyor');
            }
          }
        } else if (correctAnswer.length == 1 && ['A', 'B', 'C', 'D'].contains(correctAnswer)) {
          // Ters durum kontrolü
          final options = question['options'] as Map<String, dynamic>?;
          if (options != null) {
            final optionContent = options[correctAnswer];
            print('- Ters eşleşme kontrol ediliyor: $correctAnswer = $optionContent');
            if (optionContent == studentAnswer) {
              isCorrect = true;
              print('- Eşleşme: Doğru cevap şıkkının içeriği öğrenci cevabıyla eşleşiyor');
            }
          }
        }
        
        print('- Sonuç: ${isCorrect ? "DOĞRU" : "YANLIŞ"}');
        
        if (isCorrect) {
          correctAnswers++;
        }
      }
    }
    
    return correctAnswers;
  }
  
  Future<void> _saveGrade() async {
    // Boş veya negatif puan kontrolü
    final scoreText = _scoreController.text.trim();
    if (scoreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir puan girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final score = int.tryParse(scoreText) ?? 0;
    if (score < 0 || score > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 0-100 arası bir puan girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _examService.gradeExam(
        _submissionData!['id'],
        score,
        _feedbackController.text.trim(),
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puan başarıyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Geri dönerken, puanlama sayfasının kendini güncellemesi için true dön
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Puan kaydedilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_submissionData != null ? '${_submissionData!['examTitle']} - Değerlendirme' : 'Sınav Değerlendirme'),
        actions: [
          if (_submissionData != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveGrade,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
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
                        ElevatedButton(
                          onPressed: _loadSubmissionData,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_submissionData == null) {
      return const Center(child: Text('Sınav verisi bulunamadı'));
    }
    
    final questions = _submissionData!['questions'] as List<Map<String, dynamic>>;
    final answers = _submissionData!['answers'] as List<String>;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentInfo(),
          const Divider(height: 32),
          _buildGradingSection(),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Cevaplar (${answers.length}/${questions.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              String studentAnswer = index < answers.length ? answers[index] : '';
              return _buildQuestionAnswerItem(question, studentAnswer, index);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildStudentInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _submissionData!['studentName'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Teslim Tarihi: ${_formatTimestamp(_submissionData!['submittedAt'] as Timestamp)}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            if (_submissionData!['graded'])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grade, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Mevcut Puan: ${_submissionData!['score']}/100',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_submissionData!.containsKey('isAutoGraded') && _submissionData!['isAutoGraded'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Otomatik puanlanmış',
                            style: TextStyle(
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGradingSection() {
    final questions = _submissionData!['questions'] as List<Map<String, dynamic>>;
    final answers = _submissionData!['answers'] as List<String>;
    final int correctAnswers = _calculateCorrectAnswers(questions, answers);
    final int totalQuestions = questions.length;
    final int calculatedScore = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
    
    final bool isGraded = _submissionData!['graded'] ?? false;
    final bool isAutoGraded = _submissionData!['isAutoGraded'] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Değerlendirme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            if (!isGraded)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Otomatik Değerlendirme',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Doğru cevap sayısı: $correctAnswers / $totalQuestions'),
                    Text('Önerilen puan: $calculatedScore / 100'),
                    const Text(
                      'Not: Otomatik değerlendirme sonucu kaydetmeden önce değiştirilebilir.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
            if (isGraded && isAutoGraded)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Otomatik Puanlanmış',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Doğru cevap sayısı: $correctAnswers / $totalQuestions'),
                    const Text(
                      'Not: Öğretmen puanı tekrar gözden geçirebilir ve değiştirebilir.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 8),
            TextFormField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: 'Puan (0-100)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.score),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Geri Bildirim (Öğrenciye Notlar)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.feedback),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGrade,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isGraded ? 'Değerlendirmeyi Güncelle' : 'Değerlendirmeyi Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuestionAnswerItem(Map<String, dynamic> question, String studentAnswer, int index) {
    final correctAnswer = question['correctAnswer'] ?? '';
    final options = question['options'] as Map<String, dynamic>?;
    
    // Öğrencinin cevabı doğru mu kontrol et
    bool isCorrect = false;
    
    if (studentAnswer == correctAnswer) {
      isCorrect = true;
    } else if (correctAnswer.length > 1 && ['A', 'B', 'C', 'D'].contains(studentAnswer)) {
      if (options != null) {
        final optionContent = options[studentAnswer];
        if (optionContent == correctAnswer) {
          isCorrect = true;
        }
      }
    } else if (correctAnswer.length == 1 && ['A', 'B', 'C', 'D'].contains(correctAnswer)) {
      if (options != null) {
        final optionContent = options[correctAnswer];
        if (optionContent == studentAnswer) {
          isCorrect = true;
        }
      }
    }
    
    // Öğrenci cevabının görsel temsilini hazırla
    String displayStudentAnswer = studentAnswer;
    String displayStudentAnswerContent = '';
    
    if (studentAnswer.isEmpty) {
      displayStudentAnswer = 'Cevap verilmemiş';
    } else if (['A', 'B', 'C', 'D'].contains(studentAnswer) && options != null) {
      // Şık seçildi, içeriğini de göster
      displayStudentAnswerContent = options[studentAnswer] ?? '';
    }
    
    // Doğru cevabın görsel temsilini hazırla
    String displayCorrectAnswer = correctAnswer;
    String displayCorrectAnswerContent = '';
    
    if (correctAnswer.isEmpty) {
      displayCorrectAnswer = 'Belirtilmemiş';
    } else if (['A', 'B', 'C', 'D'].contains(correctAnswer) && options != null) {
      // Şık belirtilmiş, içeriğini de göster
      displayCorrectAnswerContent = options[correctAnswer] ?? '';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isCorrect ? Colors.green[50] : (studentAnswer.isEmpty ? Colors.grey[100] : Colors.red[50]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Soru ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (studentAnswer.isNotEmpty)
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                if (studentAnswer.isNotEmpty)
                  const SizedBox(width: 4),
                Text(
                  studentAnswer.isEmpty ? 'Cevaplanmadı' : (isCorrect ? 'Doğru' : 'Yanlış'),
                  style: TextStyle(
                    color: studentAnswer.isEmpty ? Colors.grey : (isCorrect ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question['question'] ?? 'Soru metnine ulaşılamadı',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Seçenekler:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (options != null)
              ...['A', 'B', 'C', 'D'].map((option) {
                final optionText = options[option] ?? '';
                bool isStudentAnswer = studentAnswer == option;
                bool isCorrectOption = false;
                
                if (correctAnswer == option) {
                  isCorrectOption = true;
                } else if (correctAnswer.length > 1 && options[option] == correctAnswer) {
                  isCorrectOption = true;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$option: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: Text(optionText),
                      ),
                      if (isStudentAnswer)
                        Icon(
                          Icons.person,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 18,
                        ),
                      if (isCorrectOption)
                        const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 18,
                        ),
                    ],
                  ),
                );
              }).toList(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Öğrencinin Cevabı: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  displayStudentAnswer,
                  style: TextStyle(
                    color: studentAnswer.isEmpty ? Colors.grey : (isCorrect ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (displayStudentAnswerContent.isNotEmpty)
                  Text(
                    ' ($displayStudentAnswerContent)',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Doğru Cevap: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  displayCorrectAnswer,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (displayCorrectAnswerContent.isNotEmpty)
                  Text(
                    ' ($displayCorrectAnswerContent)',
                    style: const TextStyle(
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 