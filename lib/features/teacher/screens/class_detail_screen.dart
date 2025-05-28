import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/teacher_service.dart';
import 'package:math_app/features/profile/screens/student_question_pool_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;

  const ClassDetailScreen({
    super.key,
    required this.classId,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _classDetail = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _availableStudents = [];
  bool _isAddingStudent = false;

  // Servis
  final TeacherService _teacherService = TeacherService();

  @override
  void initState() {
    super.initState();
    _loadClassDetail();
  }

  // Sınıf detayını yükle
  Future<void> _loadClassDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Kullanıcının öğretmen olduğunu doğrulama ekleyelim
      final String? currentUserId = _teacherService.getCurrentUserId();
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }
      
      // Sınıfın var olduğunu kontrol et
      bool classExists = await _teacherService.checkClassExists(widget.classId);
      if (!classExists) {
        throw Exception('Sınıf bulunamadı');
      }
      
      // Daha yumuşak bir erişim kontrolü ekleyelim
      // Sınıf sahibi değilse bile, eğer öğretmense görüntüleyebilir
      final classDetail = await _teacherService.getClassDetailSafe(widget.classId);
      
      if (classDetail['error'] != null) {
        throw Exception(classDetail['error']);
      }
      
      setState(() {
        _classDetail = classDetail;
        _students = List<Map<String, dynamic>>.from(classDetail['students'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      // Hata mesajını log'a yazalım
      print('Sınıf detayı yükleme hatası: $e');
    }
  }

  // Mevcut öğrencileri yükle
  Future<void> _loadAvailableStudents() async {
    try {
      final students = await _teacherService.getStudents();
      
      // Sınıfta olmayan öğrencileri filtrele
      final currentStudentIds = _students.map((s) => s['id'] as String).toList();
      final availableStudents = students.where(
        (student) => !currentStudentIds.contains(student['id'])
      ).toList();
      
      setState(() {
        _availableStudents = availableStudents;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğrenciler yüklenirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Öğrenci ekle
  Future<void> _addStudentToClass(String studentId) async {
    setState(() {
      _isAddingStudent = true;
    });

    try {
      await _teacherService.addStudentToClass(widget.classId, studentId);
      
      // Yenile
      await _loadClassDetail();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Öğrenci sınıfa eklendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğrenci eklenirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAddingStudent = false;
      });
    }
  }

  // Öğrenci çıkar
  Future<void> _removeStudentFromClass(String studentId) async {
    try {
      await _teacherService.removeStudentFromClass(widget.classId, studentId);
      
      // Yenile
      await _loadClassDetail();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Öğrenci sınıftan çıkarıldı'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğrenci çıkarılırken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Öğrenci ekle diyalogu
  void _showAddStudentDialog() async {
    await _loadAvailableStudents();
    
    if (_availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eklenebilecek öğrenci bulunmuyor'),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenci Ekle'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableStudents.length,
            itemBuilder: (context, index) {
              final student = _availableStudents[index];
              return ListTile(
                title: Text(student['name']),
                subtitle: Text(student['email']),
                onTap: _isAddingStudent
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _addStudentToClass(student['id']);
                      },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sınıf sahibi mi kontrolü
    final bool isOwner = _classDetail['isOwner'] == true;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_classDetail['name'] ?? 'Sınıf Detayı'),
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
          // Sadece sınıf sahibi için ek seçenekleri göster
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showClassOptions,
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
                          onPressed: _loadClassDetail,
                          child: const Text('Tekrar Dene'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Geri Dön'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
      // Sadece sınıf sahibi için öğrenci ekleme butonunu göster
      floatingActionButton: isOwner ? FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _classDetail['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _classDetail['description'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text('Oluşturulma: ${_classDetail['createdAt'] ?? ''}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16),
                      const SizedBox(width: 8),
                      Text('Öğrenci sayısı: ${_students.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildChatCard(),
          const SizedBox(height: 16),
          const Text(
            'Öğrenciler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _students.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Henüz öğrenci yok'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(student['name'].substring(0, 1)),
                        ),
                        title: Text(student['name']),
                        subtitle: Text(student['email']),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          _showStudentOptions(student);
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildChatCard() {
    return Card(
      color: AppColors.primary.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppConstants.routeClassChat,
            arguments: {
              'classId': widget.classId,
              'className': _classDetail['name'] ?? 'Sınıf',
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.chat, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sınıf Sohbeti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Öğrenciler ve diğer öğretmenlerle mesajlaş',
                      style: TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
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
                  'studentName': student['name'],
                },
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
                  'studentName': student['name'],
                },
              );
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
            leading: const Icon(Icons.remove_circle, color: Colors.red),
            title: const Text('Sınıftan Çıkar', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Öğrenciyi Çıkar'),
                  content: Text('${student['name']} adlı öğrenciyi sınıftan çıkarmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Çıkar'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                await _removeStudentFromClass(student['id']);
              }
            },
          ),
        ],
      ),
    );
  }

  // Sınıf için ek seçenekleri göster
  void _showClassOptions() {
    // Sınıf sahibi mi kontrolü
    final bool isOwner = _classDetail['isOwner'] == true;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sadece sahibi ise düzenleme ve silme işlemlerini göster
          if (isOwner) ...[
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Sınıfı Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _showEditClassDialog();
              },
            ),
          ],
          // Tüm öğretmenler ödev/sınav atayabilir
          ListTile(
            leading: const Icon(Icons.assignment, color: Colors.green),
            title: const Text('Ödev Ata'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeHomeworkCreate,
                arguments: {'classId': widget.classId},
              ).then((value) {
                if (value == true) {
                  _loadClassDetail();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz, color: Colors.purple),
            title: const Text('Sınav Ata'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context, 
                AppConstants.routeExamCreate,
                arguments: {'classId': widget.classId},
              ).then((value) {
                if (value == true) {
                  _loadClassDetail();
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Colors.orange),
            title: const Text('Toplu E-posta Gönder'),
            onTap: () {
              Navigator.pop(context);
              _showSendBulkEmailDialog();
            },
          ),
          // Sadece sahibi ise silme işlemini göster
          if (isOwner) ...[
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Sınıfı Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteClassDialog();
              },
            ),
          ],
        ],
      ),
    );
  }

  // Sınıfı düzenleme diyaloğu
  void _showEditClassDialog() {
    final nameController = TextEditingController(text: _classDetail['name']);
    final descriptionController = TextEditingController(text: _classDetail['description']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınıfı Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Sınıf Adı',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
              ),
              maxLines: 3,
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
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Sınıfı güncelle
                await _teacherService.updateClass(
                  widget.classId,
                  nameController.text,
                  descriptionController.text,
                );
                
                // Yenile
                await _loadClassDetail();
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sınıf güncellendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sınıf güncellenirken hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // Toplu e-posta gönder
  void _showSendBulkEmailDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu E-posta Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu mesaj sınıftaki tüm öğrencilere gönderilecektir.'),
            const SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Konu',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Mesaj',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
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
            onPressed: () {
              Navigator.pop(context);
              
              // E-posta gönder (Şimdilik sadece göstermelik)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu özellik yakında eklenecektir'),
                ),
              );
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
  
  // Sınıfı sil
  void _showDeleteClassDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınıfı Sil'),
        content: Text('${_classDetail['name']} sınıfını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _teacherService.deleteClass(widget.classId);
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sınıf silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                Navigator.pop(context, true); // Ana sayfaya geri dön ve yenile
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sınıf silinirken hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
} 