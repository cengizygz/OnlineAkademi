import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/student_service.dart';
import 'package:math_app/features/profile/screens/student_question_pool_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showCompletedTasks = false;
  
  // Veri listeleri
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _classes = [];
  
  // Servis
  final StudentService _studentService = StudentService();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // Verileri yükle
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      if (_selectedIndex == 0) {
        // Görevleri getir
        final tasks = await _studentService.getTasks();
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      } else if (_selectedIndex == 1) {
        // Soruları getir
        final questions = await _studentService.getQuestions();
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      } else if (_selectedIndex == 2) {
        // Sınıfları getir
        final classes = await _studentService.getClasses();
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Veri yüklenirken hata: $e';
        _isLoading = false;
      });
    }
  }

  // Toggle showing completed tasks
  void _toggleCompletedTasks() {
    setState(() {
      _showCompletedTasks = !_showCompletedTasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Paneli'),
        automaticallyImplyLeading: false,
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
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.routeProfile);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _loadData(); // Sekme değiştiğinde verileri yükle
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white.withOpacity(0.7),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Görevlerim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.question_answer),
            label: 'Sorularım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Sınıfım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Takvim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: 'Soru Havuzu',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: () {
                Navigator.pushNamed(context, AppConstants.routeAskQuestion).then((value) {
                  // Sayfa dönüşünde verileri yenile
                  if (value == true) {
                    _loadData();
                  }
                });
              },
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _selectedIndex == 4
              ? FloatingActionButton(
                  backgroundColor: AppColors.accent,
                  onPressed: () {
                    Navigator.pushNamed(context, AppConstants.routeQuestionPool);
                  },
                  child: const Icon(Icons.quiz, color: Colors.white),
                )
              : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildTasksTab();
      case 1:
        return _buildQuestionsTab();
      case 2:
        return _buildClassesTab();
      case 3:
        return _buildCalendarTab();
      case 4:
        return _buildQuestionPoolTab();
      default:
        return _buildTasksTab();
    }
  }

  Widget _buildTasksTab() {
    List<Map<String, dynamic>> pendingTasks = [];
    List<Map<String, dynamic>> completedTasks = [];
    
    // Görevleri tamamlanmış ve bekleyen olarak ayır
    for (var task in _tasks) {
      if (task['status'] == 'completed') {
        completedTasks.add(task);
      } else {
        pendingTasks.add(task);
      }
    }
    
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'Henüz göreviniz bulunmuyor',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    // Display the tasks based on the current view state
    final tasksToShow = _showCompletedTasks ? completedTasks : pendingTasks;
    final bool hasTasksToShow = tasksToShow.isNotEmpty;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Toggle button for switching between pending and completed tasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showCompletedTasks ? 'Tamamlanan Görevler' : 'Bekleyen Görevler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _showCompletedTasks ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                // Counter badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showCompletedTasks ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasksToShow.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle button
                ElevatedButton.icon(
                  onPressed: _toggleCompletedTasks,
                  icon: Icon(_showCompletedTasks 
                      ? Icons.assignment : Icons.assignment_turned_in),
                  label: Text(_showCompletedTasks 
                      ? 'Bekleyen Görevler' : 'Tamamlananlar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showCompletedTasks 
                        ? Colors.blue : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Task list
          Expanded(
            child: hasTasksToShow
                ? ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: tasksToShow.length,
                    itemBuilder: (context, index) {
                      return _buildTaskItem(
                        tasksToShow[index], 
                        _showCompletedTasks
                      );
                    },
                  )
                : Center(
                    child: Text(
                      _showCompletedTasks
                          ? 'Henüz tamamlanan göreviniz yok'
                          : 'Bekleyen göreviniz yok',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskItem(Map<String, dynamic> task, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          task['type'] == 'exam' ? Icons.quiz : Icons.assignment,
          color: isCompleted ? Colors.green : (task['type'] == 'exam' ? Colors.red : Colors.blue),
        ),
        title: Text(
          task['title'],
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Text('Son tarih: ${task['dueDate']}'),
        trailing: isCompleted 
            ? const Icon(Icons.check_circle, color: Colors.green)
            : _buildTaskStatus(task['status']),
        onTap: () {
          // Görev detayına git
          if (task['type'] == 'exam') {
            print('Sınava yönlendiriliyor. ID: ${task['id']}');
            Navigator.pushNamed(
              context, 
              AppConstants.routeExamView, 
              arguments: task['id']
            ).then((value) {
              if (value == true) {
                _loadData();
              }
            });
          } else {
            Navigator.pushNamed(
              context, 
              AppConstants.routeHomeworkView, 
              arguments: task['id']
            ).then((value) {
              if (value == true) {
                _loadData();
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildTaskStatus(String status) {
    if (status == 'completed') {
      return Chip(
        label: const Text('Tamamlandı'),
        backgroundColor: Colors.green,
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );
    } else {
      return Chip(
        label: const Text('Bekliyor'),
        backgroundColor: Colors.orange,
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );
    }
  }

  Widget _buildQuestionsTab() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Henüz soru sormadınız',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppConstants.routeAskQuestion).then((value) {
                  // Sayfa dönüşünde verileri yenile
                  if (value == true) {
                    _loadData();
                  }
                });
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Yeni Soru Sor'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.question_mark, color: Colors.purple),
              title: Text(question['title']),
              subtitle: Text('Sorulma zamanı: ${question['date']}'),
              trailing: _buildQuestionStatus(question['status']),
              onTap: () {
                // Soru detayına git
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeQuestionDetail, 
                  arguments: question['id']
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionStatus(String status) {
    if (status == 'answered') {
      return Chip(
        label: const Text('Yanıtlandı'),
        backgroundColor: Colors.green,
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );
    } else {
      return Chip(
        label: const Text('Bekliyor'),
        backgroundColor: Colors.orange,
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );
    }
  }

  Widget _buildClassesTab() {
    if (_classes.isEmpty) {
      return const Center(
        child: Text(
          'Henüz katıldığınız sınıf bulunmuyor',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final classItem = _classes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(
                Icons.class_,
                color: Colors.indigo,
              ),
              title: Text(classItem['name']),
              subtitle: Text('Öğretmen: ${classItem['teacherName']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    onPressed: () {
                      // Doğrudan sınıf sohbetine git
                      Navigator.pushNamed(
                        context,
                        AppConstants.routeClassChat,
                        arguments: {
                          'classId': classItem['id'],
                          'className': classItem['name'],
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      // Sınıf detay ekranına git (klasik davranış)
                      Navigator.pushNamed(
                        context,
                        AppConstants.routeClassDetail,
                        arguments: classItem['id'],
                      ).then((_) => _loadData()); // Dönüşte yenile
                    },
                  ),
                ],
              ),
              onTap: () {
                // Doğrudan sınıf sohbetine git
                Navigator.pushNamed(
                  context,
                  AppConstants.routeClassChat,
                  arguments: {
                    'classId': classItem['id'],
                    'className': classItem['name'],
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarTab() {
    // Takvim görünümü - şimdilik basit bir mesaj
    return const Center(
      child: Text(
        'Takvim yakında eklenecek',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  // Soru havuzu sekmesi
  Widget _buildQuestionPoolTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.quiz,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Soru Havuzu',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bu özellik, öğrencilerin test soruları oluşturup\ndiğer öğrencilerin çözmesine olanak tanır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.quiz),
            label: const Text('Soru Havuzuna Git'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.routeQuestionPool);
            },
          ),
        ],
      ),
    );
  }
} 