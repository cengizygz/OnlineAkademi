import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/homework_service.dart';

class StudentHomeworksScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  
  const StudentHomeworksScreen({
    super.key, 
    required this.studentId, 
    required this.studentName
  });

  @override
  State<StudentHomeworksScreen> createState() => _StudentHomeworksScreenState();
}

class _StudentHomeworksScreenState extends State<StudentHomeworksScreen> with SingleTickerProviderStateMixin {
  final HomeworkService _homeworkService = HomeworkService();
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Ödev verileri
  List<Map<String, dynamic>> _studentHomeworks = [];
  List<Map<String, dynamic>> _homeworkScores = [];
  
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
      // Ödev gönderilerini getir
      _studentHomeworks = await _homeworkService.getStudentSubmittedHomeworks(widget.studentId);
      
      // Puanları getir
      _homeworkScores = await _homeworkService.getStudentHomeworkScores(widget.studentId);
      
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
        title: Text('${widget.studentName} - Ödevleri'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tamamlanan Ödevler'),
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
                    _buildHomeworksTab(),
                    _buildScoresTab(),
                  ],
                ),
    );
  }
  
  Widget _buildHomeworksTab() {
    if (_studentHomeworks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Öğrenci henüz ödev tamamlamamış',
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
        itemCount: _studentHomeworks.length,
        itemBuilder: (context, index) {
          final homework = _studentHomeworks[index];
          return _buildHomeworkItem(homework);
        },
      ),
    );
  }
  
  Widget _buildScoresTab() {
    if (_homeworkScores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grade_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz puanlanmış ödev bulunmuyor',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Genel başarı yüzdesini hesapla
    double totalPercentage = 0;
    for (var score in _homeworkScores) {
      totalPercentage += score['percentage'] as double;
    }
    final averagePercentage = totalPercentage / _homeworkScores.length;
    
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
                            '${_homeworkScores.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Değerlendirilen Ödev',
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
              'Ödev Puanları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Puan listesi
          ...List.generate(_homeworkScores.length, (index) {
            final score = _homeworkScores[index];
            return _buildScoreItem(score);
          }),
        ],
      ),
    );
  }
  
  Widget _buildHomeworkItem(Map<String, dynamic> homework) {
    final bool isGraded = homework['graded'] ?? false;
    final int score = homework['score'] ?? 0;
    
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
        title: Text(homework['homeworkTitle']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Teslim: ${_formatTimestamp(homework['submittedAt'])}',
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
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: () {
            // Ödev detaylarını görüntüle
            Navigator.pushNamed(
              context,
              AppConstants.routeHomeworkSubmissionReview,
              arguments: {
                'homeworkId': homework['homeworkId'],
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
          // Ödev detaylarını görüntüle
          Navigator.pushNamed(
            context,
            AppConstants.routeHomeworkSubmissionReview,
            arguments: {
              'homeworkId': homework['homeworkId'],
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
    final percentage = score['percentage'] as double;
    
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
            title: Text(score['homeworkTitle']),
            subtitle: Text(
              'Değerlendiren: ${score['gradedBy']} • ${_formatTimestamp(score['gradedAt'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: CircleAvatar(
              backgroundColor: _getScoreColor(percentage),
              child: Text(
                '${score['score']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(percentage),
                      ),
                    ),
                    Text(
                      '${score['score']}/${score['maxScore']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(percentage)),
                    minHeight: 6,
                  ),
                ),
              ],
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