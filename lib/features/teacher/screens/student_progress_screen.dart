import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:math_app/services/homework_service.dart';
import 'package:math_app/services/teacher_service.dart';
import 'package:math_app/services/student_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:math_app/features/profile/screens/student_question_pool_screen.dart';

class StudentProgressScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  
  const StudentProgressScreen({
    super.key, 
    required this.studentId, 
    required this.studentName
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  final HomeworkService _homeworkService = HomeworkService();
  final ExamService _examService = ExamService();
  final TeacherService _teacherService = TeacherService();
  final StudentService _studentService = StudentService();
  
  bool _isLoading = true;
  String _errorMessage = '';
  
  // İstatistik verileri
  List<Map<String, dynamic>> _homeworkScores = [];
  List<Map<String, dynamic>> _examScores = [];
  Map<String, dynamic>? _studentData;
  
  // Analiz verileri
  int _totalHomeworks = 0;
  int _completedHomeworks = 0;
  int _totalExams = 0;
  int _completedExams = 0;
  double _averageHomeworkScore = 0;
  double _averageExamScore = 0;
  double _overallProgress = 0;
  
  // Performans grafiği verileri
  List<FlSpot> _homeworkPerformance = [];
  List<FlSpot> _examPerformance = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Ödev puanlarını getir
      _homeworkScores = await _homeworkService.getStudentHomeworkScores(widget.studentId);
      
      // Sınav puanlarını getir
      _examScores = await _examService.getStudentExamScores(widget.studentId);
      
      // Öğrenci verilerini getir
      _studentData = await _studentService.getStudentDetails(widget.studentId);
      
      // Toplam ödev ve sınav sayısını getir
      final homeworkStats = await _teacherService.getStudentHomeworkStats(widget.studentId);
      _totalHomeworks = homeworkStats['totalCount'] as int;
      _completedHomeworks = homeworkStats['completedCount'] as int;
      
      final examStats = await _teacherService.getStudentExamStats(widget.studentId);
      _totalExams = examStats['totalCount'] as int;
      _completedExams = examStats['completedCount'] as int;
      
      // Ortalamaları hesapla
      _calculateAverages();
      
      // Grafik verilerini hazırla
      _prepareChartData();
      
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
  
  void _calculateAverages() {
    // Ödev ortalaması
    if (_homeworkScores.isNotEmpty) {
      double totalScore = 0;
      for (var score in _homeworkScores) {
        totalScore += score['percentage'] as double;
      }
      _averageHomeworkScore = totalScore / _homeworkScores.length;
    }
    
    // Sınav ortalaması
    if (_examScores.isNotEmpty) {
      double totalScore = 0;
      for (var score in _examScores) {
        totalScore += score['percentage'] as double;
      }
      _averageExamScore = totalScore / _examScores.length;
    }
    
    // Genel ilerleme - ödev ve sınavların eşit ağırlıklı ortalaması
    if (_homeworkScores.isNotEmpty || _examScores.isNotEmpty) {
      double homeworkWeight = _homeworkScores.isNotEmpty ? 0.5 : 0;
      double examWeight = _examScores.isNotEmpty ? 0.5 : 0;
      
      if (_homeworkScores.isEmpty) {
        examWeight = 1.0;
      } else if (_examScores.isEmpty) {
        homeworkWeight = 1.0;
      }
      
      _overallProgress = (_averageHomeworkScore * homeworkWeight) + (_averageExamScore * examWeight);
    }
  }
  
  void _prepareChartData() {
    // Ödev performans grafiği
    _homeworkPerformance = [];
    for (int i = 0; i < _homeworkScores.length; i++) {
      _homeworkPerformance.add(FlSpot(
        i.toDouble(), 
        (_homeworkScores[i]['percentage'] as double) / 100
      ));
    }
    
    // Sınav performans grafiği
    _examPerformance = [];
    for (int i = 0; i < _examScores.length; i++) {
      _examPerformance.add(FlSpot(
        i.toDouble(), 
        (_examScores[i]['percentage'] as double) / 100
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - İlerleme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Liderlik Tablosu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StudentQuestionPoolScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                          onPressed: _loadData,
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentCard(),
            const SizedBox(height: 16),
            _buildOverallProgressCard(),
            const SizedBox(height: 16),
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            if (_homeworkPerformance.isNotEmpty || _examPerformance.isNotEmpty) ...[
              _buildPerformanceCard(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.assignment),
                    label: const Text('Ödevler'),
                    onPressed: () {
                      Navigator.pushNamed(
                        context, 
                        AppConstants.routeStudentHomeworkList,
                        arguments: {
                          'studentId': widget.studentId,
                          'studentName': widget.studentName,
                        }
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.quiz),
                    label: const Text('Sınavlar'),
                    onPressed: () {
                      Navigator.pushNamed(
                        context, 
                        AppConstants.routeStudentExamList,
                        arguments: {
                          'studentId': widget.studentId,
                          'studentName': widget.studentName,
                        }
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.question_answer),
              label: const Text('Öğrenci Soruları'),
              onPressed: () {
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeStudentQuestions,
                  arguments: {
                    'studentId': widget.studentId,
                    'studentName': widget.studentName,
                  }
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudentCard() {
    if (_studentData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Öğrenci verisi bulunamadı'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studentData!['name'] ?? 'İsimsiz Öğrenci',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _studentData!['email'] ?? 'E-posta yok',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Sınıf: ${_studentData!['grade'] ?? 'Belirtilmemiş'}',
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildOverallProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genel İlerleme',
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
                      '${_overallProgress.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getProgressColor(_overallProgress),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Genel Başarı',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Ödev başarı göstergesi
                if (_homeworkScores.isNotEmpty) 
                  _buildProgressIndicator(
                    'Ödev', 
                    _averageHomeworkScore, 
                    Icons.assignment
                  ),
                // Sınav başarı göstergesi
                if (_examScores.isNotEmpty) 
                  _buildProgressIndicator(
                    'Sınav', 
                    _averageExamScore, 
                    Icons.quiz
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _overallProgress / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(_overallProgress)),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator(String label, double percentage, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(percentage)),
                strokeWidth: 6,
              ),
            ),
            Icon(icon, color: _getProgressColor(percentage)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$label: ${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getProgressColor(percentage),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Görev İstatistikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Ödevler',
                  '$_completedHomeworks/$_totalHomeworks',
                  _totalHomeworks > 0 
                      ? (_completedHomeworks / _totalHomeworks) * 100 
                      : 0,
                  Icons.assignment
                ),
                _buildStatItem(
                  'Sınavlar',
                  '$_completedExams/$_totalExams',
                  _totalExams > 0 
                      ? (_completedExams / _totalExams) * 100 
                      : 0,
                  Icons.quiz
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, double percentage, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getCompletionColor(percentage)),
                strokeWidth: 6,
              ),
            ),
            Column(
              children: [
                Icon(icon, color: _getCompletionColor(percentage)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getCompletionColor(percentage),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'Tamamlama: ${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performans Grafiği',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              (value.toInt() + 1).toString(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: _getMaxX(),
                  minY: 0,
                  maxY: 1,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white.withOpacity(0.8),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          final value = barSpot.y * 100;
                          
                          String title = '';
                          if (barSpot.barIndex == 0 && index < _homeworkScores.length) {
                            title = _homeworkScores[index]['homeworkTitle'];
                          } else if (barSpot.barIndex == 1 && index < _examScores.length) {
                            title = _examScores[index]['examTitle'];
                          }
                          
                          return LineTooltipItem(
                            '$title\n${value.toStringAsFixed(1)}%',
                            TextStyle(
                              color: barSpot.barIndex == 0 ? Colors.blue : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    if (_homeworkPerformance.isNotEmpty)
                      LineChartBarData(
                        spots: _homeworkPerformance,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.1),
                        ),
                      ),
                    if (_examPerformance.isNotEmpty)
                      LineChartBarData(
                        spots: _examPerformance,
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.red.withOpacity(0.1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_homeworkPerformance.isNotEmpty)
                  _buildLegendItem('Ödev Performansı', Colors.blue),
                if (_homeworkPerformance.isNotEmpty && _examPerformance.isNotEmpty)
                  const SizedBox(width: 16),
                if (_examPerformance.isNotEmpty)
                  _buildLegendItem('Sınav Performansı', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
  
  double _getMaxX() {
    final homeworkLength = _homeworkPerformance.length - 1.0;
    final examLength = _examPerformance.length - 1.0;
    
    if (homeworkLength <= 0 && examLength <= 0) return 5;
    return homeworkLength > examLength ? homeworkLength : examLength;
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage >= 85) {
      return Colors.green;
    } else if (percentage >= 70) {
      return Colors.blue;
    } else if (percentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  Color _getCompletionColor(double percentage) {
    if (percentage >= 90) {
      return Colors.green;
    } else if (percentage >= 70) {
      return Colors.blue;
    } else if (percentage >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
} 