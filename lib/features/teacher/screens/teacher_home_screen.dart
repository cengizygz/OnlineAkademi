import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/teacher_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_app/features/profile/screens/student_question_pool_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Veri listeleri
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _classes = [];
  
  // Servis
  final TeacherService _teacherService = TeacherService();
  
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
        // Öğrencileri getir
        final students = await _teacherService.getStudents();
        setState(() {
          _students = students;
          _isLoading = false;
        });
      } else if (_selectedIndex == 1) {
        // Görevleri getir
        final tasks = await _teacherService.getTasks();
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      } else if (_selectedIndex == 2) {
        // Soruları getir
        final questions = await _teacherService.getQuestions();
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      } else if (_selectedIndex == 3) {
        // Sınıfları getir
        final classes = await _teacherService.getClasses();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğretmen Paneli'),
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
        type: BottomNavigationBarType.fixed, // Fixed type for more than 3 items
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white.withOpacity(0.7),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Öğrencilerim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Görevler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.question_answer),
            label: 'Sorular',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Sınıflar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: 'Soru Havuzu',
          ),
        ],
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 3) ? FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {
          if (_selectedIndex == 0) {
            _showAddStudentDialog();
          } else if (_selectedIndex == 1) {
            _showAddTaskOptions();
          } else if (_selectedIndex == 3) {
            Navigator.pushNamed(context, AppConstants.routeTeacherAddClass).then((value) {
              // Sayfa dönüşünde verileri yenile
              if (value == true) {
                _loadData();
              }
            });
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildStudentsTab();
      case 1:
        return _buildTasksTab();
      case 2:
        return _buildQuestionsTab();
      case 3:
        return _buildClassesTab();
      case 4:
        return _buildQuestionPoolTab();
      default:
        return _buildStudentsTab();
    }
  }

  Widget _buildStudentsTab() {
    if (_students.isEmpty) {
      return const Center(
        child: Text(
          'Henüz öğrenciniz bulunmuyor',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(student['name'].substring(0, 1)),
              ),
              title: Text(student['name']),
              subtitle: Text('${student['grade']} • Son aktivite: ${student['lastActivity']}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showStudentOptions(student);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Text(
          'Henüz görev bulunmuyor',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    // Ödevleri ve sınavları ayır
    final homeworks = _tasks.where((task) => task['type'] == 'homework').toList();
    final exams = _tasks.where((task) => task['type'] == 'exam').toList();
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment),
                    SizedBox(width: 8),
                    Text('Ödevler'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz),
                    SizedBox(width: 8),
                    Text('Sınavlar'),
                  ],
                ),
              ),
            ],
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[600],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Ödevler Tab
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: homeworks.isEmpty
                      ? const Center(child: Text('Henüz ödev bulunmuyor'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: homeworks.length,
                          itemBuilder: (context, index) {
                            final task = homeworks[index];
                            return _buildTaskItem(task);
                          },
                        ),
                ),
                
                // Sınavlar Tab
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: exams.isEmpty
                      ? const Center(child: Text('Henüz sınav bulunmuyor'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: exams.length,
                          itemBuilder: (context, index) {
                            final task = exams[index];
                            return _buildTaskItem(task);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Tekrarlanan task item widget'ını ayrı bir metoda çıkaralım
  Widget _buildTaskItem(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          task['type'] == 'exam' ? Icons.quiz : Icons.assignment,
          color: task['type'] == 'exam' ? Colors.red : Colors.blue,
        ),
        title: Text(task['title']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son tarih: ${task['dueDate']}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${task['assignedStudentCount'] ?? 0} öğrenci (${task['completedStudentCount'] ?? 0} tamamlandı)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            if (task['studentNames'] != null) ...[
              const SizedBox(height: 2),
              Text(
                task['studentNames'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showTaskOptions(task);
          },
        ),
        onTap: () {
          _showTaskDetails(task);
        },
      ),
    );
  }

  Widget _buildQuestionsTab() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'Henüz öğrencilerden gelen soru bulunmuyor',
          style: TextStyle(fontSize: 16),
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
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: question['status'] == 'answered' 
                    ? Colors.green 
                    : Colors.orange,
                child: Icon(
                  question['status'] == 'answered' 
                      ? Icons.check 
                      : Icons.help,
                  color: Colors.white,
                ),
              ),
              title: Text(
                question['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Öğrenci: ${question['studentName']}'),
                  Text(
                    'Tarih: ${_formatDate(question['createdAt'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppConstants.routeQuestionDetail,
                  arguments: question['id'],
                ).then((value) {
                  // Sayfa dönüşünde verileri yenile
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

  Widget _buildClassesTab() {
    if (_classes.isEmpty) {
      return const Center(
        child: Text(
          'Henüz sınıf bulunmuyor',
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
              leading: Icon(
                Icons.class_,
                color: Colors.blue,
              ),
              title: Text(classItem['name']),
              subtitle: Text('Öğrenci sayısı: ${classItem['studentCount']}'),
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
                      // Sınıf detayına git (klasik davranış)
                      Navigator.pushNamed(context, AppConstants.routeClassDetail, arguments: classItem['id']);
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
            'Öğrencilerin oluşturduğu soruları onaylayabilir ve\nonların birbirlerinden öğrenmesine yardımcı olabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.checklist),
            label: const Text('Onay Bekleyen Sorular'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.routeQuestionApproval);
            },
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final _emailController = TextEditingController();
    final _gradeController = TextEditingController();
    bool _isAdding = false;
    String _errorMessage = '';
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Öğrenci Ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Öğrenci E-posta',
                    hintText: 'ornek@ogrenci.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _gradeController,
                  decoration: const InputDecoration(
                    labelText: 'Sınıf',
                    hintText: '10. Sınıf',
                  ),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: _isAdding ? null : () async {
                  if (_emailController.text.isEmpty) {
                    setDialogState(() {
                      _errorMessage = 'E-posta adresi gerekli';
                    });
                    return;
                  }
                  
                  if (_gradeController.text.isEmpty) {
                    setDialogState(() {
                      _errorMessage = 'Sınıf bilgisi gerekli';
                    });
                    return;
                  }
                  
                  setDialogState(() {
                    _isAdding = true;
                    _errorMessage = '';
                  });
                  
                  try {
                    await _teacherService.addStudent(
                      _emailController.text.trim(),
                      _gradeController.text.trim(),
                    );
                    
                    Navigator.pop(context);
                    
                    // Öğrenci listesini yenile
                    _loadData();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Öğrenci başarıyla eklendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    setDialogState(() {
                      _isAdding = false;
                      _errorMessage = e.toString();
                    });
                  }
                },
                child: _isAdding
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Ekle'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.quiz, color: Colors.red),
            title: const Text('Normal Sınav Ekle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeExamCreate,
                arguments: {'examType': 'normal'},
              ).then((value) {
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined, color: Colors.purple),
            title: const Text('Deneme Sınavı Ekle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeExamCreate,
                arguments: {'examType': 'deneme'},
              ).then((value) {
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.blue),
            title: const Text('Ödev Ekle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.routeHomeworkCreate).then((value) {
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  void _showStudentOptions(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profili Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeStudentProfile, 
                arguments: {
                  'studentId': student['id'],
                  'studentName': student['name']
                }
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: const Text('Soruları Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeStudentQuestions, 
                arguments: {
                  'studentId': student['id'],
                  'studentName': student['name']
                }
              ).then((value) {
                // Sorular güncellendiğinde verileri yenile
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Mesaj Gönder'),
            onTap: () {
              Navigator.pop(context);
              // Mesaj gönderme ekranı - İlerde eklenecek
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu özellik yakında eklenecek'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Ödevleri Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              // Öğrencinin ödevlerini görüntüleme sayfasına yönlendir
              Navigator.pushNamed(
                context, 
                AppConstants.routeStudentHomeworkList, 
                arguments: {
                  'studentId': student['id'],
                  'studentName': student['name']
                }
              ).then((value) {
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('Sınavları Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              // Öğrencinin sınavlarını görüntüleme sayfasına yönlendir
              Navigator.pushNamed(
                context, 
                AppConstants.routeStudentExamList, 
                arguments: {
                  'studentId': student['id'],
                  'studentName': student['name']
                }
              ).then((value) {
                if (value == true) {
                  _loadData();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_chart),
            title: const Text('İlerleme Durumu'),
            onTap: () {
              Navigator.pop(context);
              // İlerleme durumu ekranına yönlendir
              Navigator.pushNamed(
                context, 
                AppConstants.routeStudentProgress, 
                arguments: {
                  'studentId': student['id'],
                  'studentName': student['name']
                }
              );
            },
          ),
        ],
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
                    'Öğrenci: ${question["studentName"]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tarih: ${question["date"]}'),
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
                  if (question['imageUrl'] != null && question['imageUrl'].toString().isNotEmpty) ...[
                    const Text(
                      'Ekli Görsel:',
                      style: TextStyle(
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
                    const SizedBox(height: 16),
                  ],
                  if (isAnswered) ...[
                    const Text(
                      'Yanıtınız:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(question['answer']),
                    if (question['answerDate'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Yanıt tarihi: ${question["answerDate"]}'),
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
                            await _teacherService.answerQuestion(
                              question['id'],
                              _answerController.text.trim(),
                            );
                            
                            if (!mounted) return;
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Yanıtınız kaydedildi'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            
                            Navigator.of(dialogContext).pop();
                            _loadData();
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

  void _showTaskDetails(Map<String, dynamic> task) {
    // Görev detaylarını göster
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FutureBuilder<Map<String, dynamic>>(
          future: _teacherService.getTaskCompletionStatus(task['id'], task['type']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: Text(task['title'])),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(task['title'])),
                body: Center(
                  child: Text(
                    'Bilgiler yüklenirken hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            
            final completionData = snapshot.data!;
            final students = List<Map<String, dynamic>>.from(completionData['students']);
            
            return Scaffold(
              appBar: AppBar(title: Text(task['title'])),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text('Son Tarih: ${task['dueDate']}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${completionData['totalCompleted']}/${completionData['totalAssigned']} öğrenci tamamladı',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Öğrenci Durumları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: student['completed'] ? Colors.green : Colors.grey,
                            child: Icon(
                              student['completed'] ? Icons.check : Icons.hourglass_empty,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(student['name']),
                          subtitle: Text(
                            student['completed'] ? 'Tamamlandı' : 'Bekliyor',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              // Öğrenci profilini göster
                              Navigator.pushNamed(
                                context,
                                AppConstants.routeStudentProfile,
                                arguments: {
                                  'studentId': student['id'],
                                  'studentName': student['name'],
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  void _showTaskOptions(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              task['type'] == 'exam' ? Icons.quiz : Icons.assignment,
              color: task['type'] == 'exam' ? Colors.red : Colors.blue,
            ),
            title: Text(task['title']),
            subtitle: Text('Son tarih: ${task['dueDate']}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Detayları Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              _showTaskDetails(task);
            },
          ),
          if (task['type'] == 'exam')
            ListTile(
              leading: const Icon(Icons.grading, color: Colors.orange),
              title: const Text('Sınav Değerlendirme'),
              onTap: () {
                Navigator.pop(context);
                // Sınav değerlendirme sayfasına yönlendir
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeExamGrading,
                  arguments: task['id'],
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              },
            )
          else if (task['type'] == 'homework')
            ListTile(
              leading: const Icon(Icons.grading, color: Colors.green),
              title: const Text('Ödev Değerlendirme'),
              onTap: () {
                Navigator.pop(context);
                // Ödev değerlendirme sayfasına yönlendir
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeHomeworkGrading,
                  arguments: task['id'],
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              },
            ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Tamamlayan Öğrenciler'),
            subtitle: Text('${task['completedStudentCount']}/${task['assignedStudentCount']} öğrenci'),
            onTap: () {
              Navigator.pop(context);
              if (task['type'] == 'exam') {
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeExamGrading,
                  arguments: task['id'],
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              } else {
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeHomeworkGrading,
                  arguments: task['id'],
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Düzenle'),
            onTap: () {
              Navigator.pop(context);
              // Düzenleme sayfasına yönlendir
              if (task['type'] == 'exam') {
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeExamCreate,
                  arguments: {'examId': task['id']},
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              } else {
                Navigator.pushNamed(
                  context, 
                  AppConstants.routeHomeworkCreate,
                  arguments: {'homeworkId': task['id']},
                ).then((value) {
                  if (value == true) {
                    _loadData();
                  }
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Sil', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteTask(task);
            },
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteTask(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görev Silme'),
        content: Text('${task['title']} görevini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                if (task['type'] == 'exam') {
                  // Sınav sil
                  await _teacherService.deleteExam(task['id']);
                } else {
                  // Ödev sil
                  await _teacherService.deleteHomework(task['id']);
                }
                
                // Listeyi yenile
                _loadData();
                
                // Başarı mesajı göster
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Görev başarıyla silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                
                // Hata mesajı göster
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Görev silinirken hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Tarih formatı
  String _formatDate(dynamic date) {
    if (date == null) {
      return 'Belirtilmemiş';
    }
    
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else {
      return 'Geçersiz tarih';
    }
  }
} 