import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_app/core/theme/app_theme.dart';

class StudentQuestionsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  
  const StudentQuestionsScreen({
    Key? key, 
    required this.studentId, 
    required this.studentName
  }) : super(key: key);

  @override
  State<StudentQuestionsScreen> createState() => _StudentQuestionsScreenState();
}

class _StudentQuestionsScreenState extends State<StudentQuestionsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Öğrencinin sorularını Firestore'dan getir
      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> questions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        questions.add({
          'id': doc.id,
          'title': data['title'] ?? 'İsimsiz Soru',
          'content': data['content'] ?? '',
          'createdAt': data['createdAt'] as Timestamp,
          'formattedDate': _formatTimestamp(data['createdAt'] as Timestamp),
          'status': data['answered'] == true ? 'answered' : 'pending',
          'answer': data['answer'],
          'answerDate': data['answerDate'],
          'formattedAnswerDate': data['answerDate'] != null 
              ? _formatTimestamp(data['answerDate'] as Timestamp) 
              : null,
        });
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sorular yüklenirken hata oluştu: $e';
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} dakika önce';
      }
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} Soruları'),
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
                          onPressed: _loadQuestions,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _questions.isEmpty
                  ? Center(
                      child: Text(
                        '${widget.studentName} henüz soru sormamış',
                        style: const TextStyle(fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadQuestions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: question['status'] == 'answered' ? Colors.green : Colors.orange,
                                child: Icon(
                                  question['status'] == 'answered' ? Icons.check : Icons.question_mark,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(question['title']),
                              subtitle: Text('Sorulma zamanı: ${question['formattedDate']}'),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                _showQuestionDetails(question);
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showQuestionDetails(Map<String, dynamic> question) {
    final bool isAnswered = question['status'] == 'answered';
    final _answerController = TextEditingController(
      text: isAnswered ? question['answer'] : '',
    );
    bool _isSubmitting = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(question['title']),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Öğrenci: ${widget.studentName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tarih: ${question["formattedDate"]}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Soru:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(question['content']),
                  const SizedBox(height: 16),
                  if (isAnswered) ...[
                    const Text(
                      'Yanıtınız:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(question['answer']),
                    if (question['formattedAnswerDate'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Yanıt tarihi: ${question["formattedAnswerDate"]}'),
                    ],
                  ] else ...[
                    const Text(
                      'Yanıtınız:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerController,
                      decoration: const InputDecoration(
                        hintText: 'Yanıtınızı buraya yazın',
                      ),
                      maxLines: 5,
                    ),
                    if (_isSubmitting) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Kapat'),
              ),
              if (!isAnswered)
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (_answerController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen bir yanıt girin'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          setDialogState(() {
                            _isSubmitting = true;
                          });
                          
                          try {
                            // Soruyu yanıtla
                            await FirebaseFirestore.instance
                                .collection('questions')
                                .doc(question['id'])
                                .update({
                              'answer': _answerController.text.trim(),
                              'answered': true,
                              'answerDate': FieldValue.serverTimestamp(),
                            });
                            
                            if (!mounted) return;
                            
                            // Başarı mesajı göster
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Yanıtınız kaydedildi'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            
                            Navigator.of(dialogContext).pop();
                            _loadQuestions(); // Soruları yeniden yükle
                          } catch (e) {
                            setDialogState(() {
                              _isSubmitting = false;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Yanıtı Gönder'),
                ),
            ],
          );
        },
      ),
    );
  }
} 