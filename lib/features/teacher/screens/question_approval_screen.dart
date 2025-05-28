import 'package:flutter/material.dart';
import 'package:math_app/models/question_pool.dart';
import 'package:math_app/services/question_pool_service.dart';

class QuestionApprovalScreen extends StatefulWidget {
  const QuestionApprovalScreen({super.key});

  @override
  State<QuestionApprovalScreen> createState() => _QuestionApprovalScreenState();
}

class _QuestionApprovalScreenState extends State<QuestionApprovalScreen> {
  final QuestionPoolService _questionPoolService = QuestionPoolService();
  
  List<PoolQuestion> _pendingQuestions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, bool> _processingQuestions = {};
  
  @override
  void initState() {
    super.initState();
    _loadPendingQuestions();
  }
  
  Future<void> _loadPendingQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final questions = await _questionPoolService.getPendingQuestions();
      
      if (mounted) {
        setState(() {
          _pendingQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Onay bekleyen sorular yüklenirken hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _approveQuestion(PoolQuestion question, bool isApproved) async {
    // İşlem başladığında ilgili soru için yükleniyor durumunu ayarla
    setState(() {
      _processingQuestions[question.id] = true;
    });
    
    try {
      await _questionPoolService.approveQuestion(question.id, isApproved);
      
      if (mounted) {
        // Başarılı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved
                ? 'Soru başarıyla onaylandı ve havuza eklendi!'
                : 'Soru reddedildi.'),
            backgroundColor: isApproved ? Colors.green : Colors.orange,
          ),
        );
        
        // Listeyi güncelle - onaylanan/reddedilen soruyu kaldır
        setState(() {
          _pendingQuestions.removeWhere((q) => q.id == question.id);
          _processingQuestions.remove(question.id);
        });
      }
    } catch (e) {
      if (mounted) {
        // Hata mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem sırasında hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _processingQuestions.remove(question.id);
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Onayları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingQuestions,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
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
                        onPressed: _loadPendingQuestions,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _pendingQuestions.isEmpty
                  ? const Center(
                      child: Text(
                        'Şu anda onay bekleyen soru bulunmuyor.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _pendingQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _pendingQuestions[index];
                        final isProcessing = _processingQuestions[question.id] ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Soru metni
                                Text(
                                  question.questionText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Şıklar
                                const Text(
                                  'Şıklar:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...List.generate(4, (i) {
                                  final letter = String.fromCharCode(65 + i); // A, B, C, D
                                  final isCorrect = letter == question.correctAnswer;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isCorrect ? Colors.green : Colors.grey.shade300,
                                          ),
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isCorrect ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            question.options[i],
                                            style: TextStyle(
                                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                              color: isCorrect ? Colors.green : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                
                                const SizedBox(height: 8),
                                Text(
                                  'Ders: ${question.subject}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Konu: ${question.topic}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isProcessing)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else ...[
                                      // Reddet butonu
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        label: const Text('Reddet'),
                                        onPressed: () => _approveQuestion(question, false),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Onayla butonu
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check),
                                        label: const Text('Onayla'),
                                        onPressed: () => _approveQuestion(question, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
} 