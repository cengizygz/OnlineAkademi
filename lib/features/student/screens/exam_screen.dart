import 'package:flutter/material.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  final String examType;

  const ExamScreen({
    super.key,
    required this.examId,
    this.examType = 'normal',
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _examData;
  int _currentQuestionIndex = 0;
  List<String> _answers = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExam();
  }

  Future<void> _loadExam() async {
    try {
      final examData = await _examService.getExam(widget.examId);
      setState(() {
        _examData = examData;
        _answers = List.filled(examData['questions'].length, '');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sınav yüklenirken hata: $e';
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < (_examData?['questions'].length ?? 0) - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitExam() async {
    if (_answers.contains('')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm soruları cevaplayın')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _examService.submitExam(
        examId: widget.examId,
        answers: _answers,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sınav başarıyla tamamlandı'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_examData == null) {
      return Scaffold(
        body: Center(
          child: Text(_errorMessage),
        ),
      );
    }

    final questions = _examData!['questions'] as List<dynamic>;
    final currentQuestion = questions[_currentQuestionIndex] as Map<String, dynamic>;
    final options = currentQuestion['options'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(_examData!['title']),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitExam,
            ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soru ${_currentQuestionIndex + 1}/${questions.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (currentQuestion['imageUrl'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: currentQuestion['imageUrl'],
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...['A', 'B', 'C', 'D'].map((option) {
                    final isSelected = _answers[_currentQuestionIndex] == option;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _selectAnswer(option),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.blue : Colors.grey[200],
                                ),
                                child: Center(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  options[option] ?? '',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Önceki'),
              ),
              ElevatedButton.icon(
                onPressed: _currentQuestionIndex < questions.length - 1
                    ? _nextQuestion
                    : _submitExam,
                icon: Icon(
                  _currentQuestionIndex < questions.length - 1
                      ? Icons.arrow_forward
                      : Icons.check,
                ),
                label: Text(
                  _currentQuestionIndex < questions.length - 1
                      ? 'Sonraki'
                      : 'Bitir',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 