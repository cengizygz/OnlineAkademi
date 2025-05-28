import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamGradingScreen extends StatefulWidget {
  final String examId;
  
  const ExamGradingScreen({super.key, required this.examId});

  @override
  State<ExamGradingScreen> createState() => _ExamGradingScreenState();
}

class _ExamGradingScreenState extends State<ExamGradingScreen> {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _examData;
  List<Map<String, dynamic>> _submissions = [];
  
  @override
  void initState() {
    super.initState();
    _loadExamData();
  }
  
  Future<void> _loadExamData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Sınav verisini getir
      _examData = await _examService.getExam(widget.examId);
      
      // Öğrenci cevaplarını getir
      _submissions = await _examService.getExamSubmissions(widget.examId);
      
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_examData != null ? '${_examData!['title']} - Değerlendirme' : 'Sınav Değerlendirme'),
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
                          onPressed: _loadExamData,
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
    if (_examData == null) {
      return const Center(child: Text('Sınav verisi bulunamadı'));
    }
    
    final assignedCount = (_examData!['assignedStudents'] as List).length;
    final completedCount = (_examData!['completedStudents'] as List).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExamInfo(assignedCount, completedCount),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Öğrenci Cevapları (${_submissions.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _submissions.isEmpty
              ? const Center(child: Text('Henüz hiçbir öğrenci sınavı tamamlamamış'))
              : ListView.builder(
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    return _buildSubmissionItem(_submissions[index]);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildExamInfo(int assignedCount, int completedCount) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _examData!['title'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _examData!['description'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Son Tarih: ${_formatDate(_examData!['dueDate'])}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Öğrenci Durumu: $completedCount/$assignedCount tamamladı',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: assignedCount > 0 ? completedCount / assignedCount : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmissionItem(Map<String, dynamic> submission) {
    final bool isGraded = submission['graded'] ?? false;
    final int score = submission['score'] ?? 0;
    final submittedAt = submission['submittedAt'] as Timestamp?;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGraded ? Colors.green : Colors.orange,
          child: Icon(
            isGraded ? Icons.done : Icons.pending,
            color: Colors.white,
          ),
        ),
        title: Text(submission['studentName']),
        subtitle: Text(
          'Teslim: ${_formatTimestamp(submittedAt ?? Timestamp.now())}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGraded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(score),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$score/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppConstants.routeExamSubmissionReview,
                  arguments: {
                    'examId': widget.examId,
                    'studentId': submission['studentId'],
                  },
                ).then((value) {
                  if (value == true) {
                    _loadExamData();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isGraded ? Colors.blue : Colors.orange,
              ),
              child: Text(isGraded ? 'Gözden Geçir' : 'Değerlendir'),
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppConstants.routeExamSubmissionReview,
            arguments: {
              'examId': widget.examId,
              'studentId': submission['studentId'],
            },
          ).then((value) {
            if (value == true) {
              _loadExamData();
            }
          });
        },
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 85) {
      return Colors.green;
    } else if (score >= 70) {
      return Colors.blue;
    } else if (score >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
} 