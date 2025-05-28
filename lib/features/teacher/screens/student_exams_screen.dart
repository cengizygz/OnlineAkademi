import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/exam_service.dart';

class StudentExamsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  
  const StudentExamsScreen({
    super.key, 
    required this.studentId, 
    required this.studentName
  });

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> with SingleTickerProviderStateMixin {
  final ExamService _examService = ExamService();
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Sınav verileri
  List<Map<String, dynamic>> _studentExams = [];
  List<Map<String, dynamic>> _examScores = [];
  
  // Tab Controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Sınav gönderilerini getir
      _studentExams = await _examService.getStudentSubmittedExams(widget.studentId);
      
      // Puanları getir
      _examScores = await _examService.getStudentExamScores(widget.studentId);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Veriler yüklenirken hata: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - Sınavları'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tamamlanan Sınavlar'),
            Tab(text: 'Puanlar'),
          ],
        ),
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
                          onPressed: _loadData,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExamsTab(),
                    _buildScoresTab(),
                  ],
                ),
    );
  }
  
  Widget _buildExamsTab() {
    if (_studentExams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Öğrenci henüz sınav tamamlamamış',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _studentExams.length,
        itemBuilder: (context, index) {
          final exam = _studentExams[index];
          return _buildExamItem(exam);
        },
      ),
    );
  }
  
  Widget _buildScoresTab() {
    if (_examScores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz puanlanmış sınav bulunmuyor',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Genel başarı yüzdesini hesapla
    double totalPercentage = 0;
    for (var score in _examScores) {
      totalPercentage += score['percentage'] as double;
    }
    final averagePercentage = totalPercentage / _examScores.length;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Genel başarı kartı
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Genel Başarı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${averagePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(averagePercentage),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ortalama Başarı',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_examScores.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Değerlendirilen Sınav',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: averagePercentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(averagePercentage)),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Puan detayları
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Sınav Puanları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Puan listesi
          ...List.generate(_examScores.length, (index) {
            final score = _examScores[index];
            return _buildScoreItem(score);
          }),
        ],
      ),
    );
  }
  
  Widget _buildExamItem(Map<String, dynamic> exam) {
    final bool isGraded = exam['graded'] ?? false;
    final int score = exam['score'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGraded 
              ? _getScoreColor(score.toDouble()) 
              : Colors.grey,
          child: Icon(
            isGraded ? Icons.assignment_turned_in : Icons.assignment,
            color: Colors.white,
          ),
        ),
        title: Text((exam['examTitle'] ?? exam['examName'] ?? 'İsimsiz Sınav').toString()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Teslim: ${_formatTimestamp(exam['submittedAt'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                isGraded
                    ? Row(
                        children: [
                          Icon(Icons.grade, size: 14, color: _getScoreColor(score.toDouble())),
                          const SizedBox(width: 4),
                          Text(
                            'Puan: $score/100',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(score.toDouble()),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.pending, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Değerlendirilmedi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                const SizedBox(width: 8),
                Text(
                  'Doğru: ${(exam['correctCount'] ?? 0).toString()}/${(exam['questionCount'] ?? 0).toString()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: () {
            // Sınav detaylarını görüntüle
            Navigator.pushNamed(
              context,
              AppConstants.routeExamSubmissionReview,
              arguments: {
                'examId': exam['examId'],
                'studentId': widget.studentId,
              },
            ).then((value) {
              if (value == true) {
                _loadData();
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isGraded 
                ? Colors.blue 
                : Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Text(
            isGraded ? 'Görüntüle' : 'Değerlendir',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        onTap: () {
          // Sınav detaylarını görüntüle
          Navigator.pushNamed(
            context,
            AppConstants.routeExamSubmissionReview,
            arguments: {
              'examId': exam['examId'],
              'studentId': widget.studentId,
            },
          ).then((value) {
            if (value == true) {
              _loadData();
            }
          });
        },
      ),
    );
  }
  
  Widget _buildScoreItem(Map<String, dynamic> score) {
    final percentage = (score['percentage'] ?? 0.0) as double;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getScoreColor(percentage).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text((score['examTitle'] ?? score['examName'] ?? 'İsimsiz Sınav').toString()),
            subtitle: Text(
              'Değerlendiren: ${(score['gradedBy'] ?? score['gradedByName'] ?? 'Bilinmiyor').toString()} • ${_formatTimestamp(score['gradedAt'] ?? score['examDate'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: CircleAvatar(
              backgroundColor: _getScoreColor(percentage),
              child: Text(
                '${score['score'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(double score) {
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
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Tarih bilinmiyor';
    
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
} 