import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:math_app/core/theme/app_theme.dart';

class QuestionDetailScreen extends StatefulWidget {
  final String questionId;
  
  const QuestionDetailScreen({Key? key, required this.questionId}) : super(key: key);

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _questionData;
  
  @override
  void initState() {
    super.initState();
    _loadQuestionData();
  }
  
  Future<void> _loadQuestionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Soru detaylarını Firestore'dan getir
      DocumentSnapshot questionDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.questionId)
          .get();
      
      if (!questionDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Soru bulunamadı';
        });
        return;
      }
      
      final data = questionDoc.data() as Map<String, dynamic>;
      
      // Öğrenci ID kontrolü
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (data['studentId'] != currentUserId) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bu soruyu görüntüleme yetkiniz yok';
        });
        return;
      }
      
      // Öğretmen bilgilerini getir
      String teacherName = '';
      if (data['teacherId'] != null) {
        DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['teacherId'] as String)
            .get();
            
        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() as Map<String, dynamic>?;
          if (teacherData != null && teacherData['name'] != null) {
            teacherName = teacherData['name'] as String;
          }
        }
      }
      
      setState(() {
        _questionData = {
          ...data,
          'id': widget.questionId,
          'teacherName': teacherName,
          'formattedDate': _formatTimestamp(data['createdAt'] as Timestamp),
          'formattedAnswerDate': data['answerDate'] != null 
              ? _formatTimestamp(data['answerDate'] as Timestamp) 
              : null,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Soru yüklenirken hata oluştu: $e';
      });
    }
  }
  
  // Timestamp formatını düzenle
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
        title: Text(_questionData != null ? _questionData!['title'] : 'Soru Detayı'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildQuestionDetails(),
    );
  }
  
  Widget _buildQuestionDetails() {
    if (_questionData == null) {
      return const Center(child: Text('Soru bilgileri bulunamadı'));
    }
    
    final bool isAnswered = _questionData!['answered'] == true;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _questionData!['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(_questionData!['formattedDate']),
                    ],
                  ),
                  if (_questionData!['teacherName'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 4),
                        Text('Öğretmen: ${_questionData!["teacherName"]}'),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  const Text(
                    'Sorunuz:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_questionData!['content']),
                  if (_questionData!['imageUrl'] != null && _questionData!['imageUrl'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ekli Görsel:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Görsel burada gösterilecek'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isAnswered) ...[
            Card(
              elevation: 2,
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Yanıt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_questionData!['formattedAnswerDate'] != null)
                          Text(_questionData!['formattedAnswerDate']!),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_questionData!['answer']),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              elevation: 2,
              color: Colors.orange[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Sorunuz henüz yanıtlanmadı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 