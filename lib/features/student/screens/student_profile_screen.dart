import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/student_service.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentViewProfileScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentViewProfileScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentViewProfileScreen> createState() => _StudentViewProfileScreenState();
}

class _StudentViewProfileScreenState extends State<StudentViewProfileScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _studentProfile = {};
  List<Map<String, dynamic>> _examScores = [];

  // Servis
  final StudentService _studentService = StudentService();
  final ExamService _examService = ExamService();

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  // Öğrenci profilini yükle
  Future<void> _loadStudentProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Profil bilgilerini getir
      final profile = await _studentService.getStudentProfile(widget.studentId);
      
      // Sınav puanlarını getir
      final examScores = await _examService.getStudentExamScores(widget.studentId);
      
      // Sınav istatistiklerini hesapla
      double totalScore = 0;
      int totalExams = examScores.length;
      
      for (var score in examScores) {
        totalScore += score['score'] as int;
      }
      
      double averageScore = totalExams > 0 ? totalScore / totalExams : 0;
      
      // Profil verisine sınav istatistiklerini ekle
      profile['examStats'] = {
        'average': averageScore.toStringAsFixed(1),
        'count': totalExams,
      };
      
      setState(() {
        _studentProfile = profile;
        _examScores = examScores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} Profili'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildPerformanceStats(),
          const SizedBox(height: 24),
          _buildExamScores(),
          const SizedBox(height: 24),
          _buildAttendance(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                _studentProfile['name']?.substring(0, 1) ?? '?',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _studentProfile['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _studentProfile['email'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.school, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Sınıf: ${_studentProfile['grade'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (_studentProfile['className'] != null && _studentProfile['className'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.class_, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Grup: ${_studentProfile['className']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Katılma: ${_studentProfile['joinDate'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceStats() {
    final homeworkStats = _studentProfile['homeworkStats'] ?? {'completed': 0, 'total': 0};
    final examStats = _studentProfile['examStats'] ?? {'average': '0', 'count': 0};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performans Özeti',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Ödevler',
                        '${homeworkStats['completed']}/${homeworkStats['total']}',
                        Icons.assignment,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatCard(
                        'Sınav Ortalaması',
                        '${examStats['average']}',
                        Icons.quiz,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Girilen Sınav Sayısı: ${examStats['count']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExamScores() {
    if (_examScores.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sınav Sonuçları',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Henüz değerlendirilmiş sınav bulunmamaktadır',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sınav Sonuçları',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var score in _examScores)
                  _buildExamScoreItem(score),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildExamScoreItem(Map<String, dynamic> score) {
    final int scoreValue = score['score'] as int;
    final gradedAt = score['gradedAt'] as Timestamp?;
    final double percentage = score['percentage'] as double? ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  score['examTitle'] as String? ?? 'İsimsiz Sınav',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(scoreValue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$scoreValue/${score['maxScore']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Değerlendiren: ${score['gradedBy']}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          if (gradedAt != null)
            Text(
              'Değerlendirme: ${_formatTimestamp(gradedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(scoreValue)),
          ),
          const Divider(height: 24),
        ],
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
  
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
  
  Widget _buildAttendance() {
    final attendance = _studentProfile['attendance'] ?? {'present': 0, 'absent': 0, 'late': 0};
    final total = attendance['present'] + attendance['absent'] + attendance['late'];
    final presentPercent = total > 0 ? (attendance['present'] / total * 100).toStringAsFixed(1) : '0';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Derse Katılım',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Katılım Oranı: %$presentPercent',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: total > 0 ? attendance['present'] / total : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttendanceItem('Katıldı', attendance['present'].toString(), Colors.green),
                    _buildAttendanceItem('Katılmadı', attendance['absent'].toString(), Colors.red),
                    _buildAttendanceItem('Geç Kaldı', attendance['late'].toString(), Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttendanceItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final recentQuestions = List<Map<String, dynamic>>.from(
        _studentProfile['recentQuestions'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Son Sorular',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (recentQuestions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz soru yok'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentQuestions.length,
            itemBuilder: (context, index) {
              final question = recentQuestions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.question_answer,
                    color: AppColors.accent,
                  ),
                  title: Text(question['title']),
                  subtitle: Text('${question['createdAt']}'),
                  trailing: Chip(
                    label: Text(
                      question['status'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: question['status'] == 'Cevaplandı'
                        ? Colors.green
                        : Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                  onTap: () {
                    // Soru detayına git
                    Navigator.pushNamed(
                      context,
                      AppConstants.routeQuestionDetail,
                      arguments: question['id'],
                    );
                  },
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.routeStudentQuestions,
                    arguments: {
                      'studentId': widget.studentId,
                      'studentName': widget.studentName,
                    },
                  );
                },
                icon: const Icon(Icons.question_answer),
                label: const Text('Tüm Soruları Görüntüle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 