import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/homework_service.dart';
import 'package:math_app/services/teacher_service.dart';
import 'package:math_app/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class HomeworkCreateScreen extends StatefulWidget {
  final String? homeworkId;
  final String? classId;
  
  const HomeworkCreateScreen({super.key, this.homeworkId, this.classId});

  @override
  State<HomeworkCreateScreen> createState() => _HomeworkCreateScreenState();
}

class _HomeworkCreateScreenState extends State<HomeworkCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;
  bool _isEditMode = false;
  String _errorMessage = '';
  final List<TextEditingController> _taskControllers = [];
  
  // Öğrenci seçimi için
  List<Map<String, dynamic>> _students = [];
  List<String> _selectedStudentIds = [];
  bool _isLoadingStudents = false;
  
  // Dosya yükleme için
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  List<String> _existingFiles = [];
  
  // Servis
  final HomeworkService _homeworkService = HomeworkService();
  final TeacherService _teacherService = TeacherService();
  final StorageService _storageService = StorageService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.homeworkId != null) {
      _isEditMode = true;
      _loadHomeworkData();
    } else {
      _addTask(); // İlk görevi ekleyelim
      
      // Sınıfa göre öğrencileri yükle veya tüm öğrencileri getir
      if (widget.classId != null) {
        _loadClassStudents(widget.classId!);
      } else {
        _loadAllStudents();
      }
    }
  }
  
  // Tüm öğrencileri yükle
  Future<void> _loadAllStudents() async {
    setState(() {
      _isLoadingStudents = true;
    });
    
    try {
      final students = await _teacherService.getStudents();
      
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
        _errorMessage = 'Öğrenciler yüklenirken hata: $e';
      });
    }
  }
  
  // Belirli bir sınıfın öğrencilerini yükle
  Future<void> _loadClassStudents(String classId) async {
    setState(() {
      _isLoadingStudents = true;
    });
    
    try {
      final classDetail = await _teacherService.getClassDetailSafe(classId);
      final classStudents = List<Map<String, dynamic>>.from(classDetail['students'] ?? []);
      
      setState(() {
        _students = classStudents;
        // Varsayılan olarak sınıftaki tüm öğrencileri seç
        _selectedStudentIds = classStudents.map((s) => s['id'] as String).toList();
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
        _errorMessage = 'Sınıf öğrencileri yüklenirken hata: $e';
      });
    }
  }
  
  // Ödev verilerini yükle (düzenleme modu için)
  Future<void> _loadHomeworkData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final homeworkData = await _homeworkService.getHomework(widget.homeworkId!);
      
      // Form alanlarını doldur
      _titleController.text = homeworkData['title'];
      _descriptionController.text = homeworkData['description'];
      _dueDate = homeworkData['dueDate'];
      _selectedStudentIds = List<String>.from(homeworkData['assignedStudents']);
      
      // Mevcut dosyaları getir
      if (homeworkData.containsKey('fileUrls')) {
        _existingFiles = List<String>.from(homeworkData['fileUrls'] ?? []);
      }
      
      // Öğrencileri yükle
      await _loadAllStudents();
      
      // Görevleri yükle
      final tasks = homeworkData['tasks'] as List<Map<String, dynamic>>;
      
      if (tasks.isNotEmpty) {
        for (var task in tasks) {
          final taskController = TextEditingController(text: task['description']);
          _taskControllers.add(taskController);
        }
      } else {
        // Eğer hiç görev yoksa, bir tane boş görev ekle
        _addTask();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ödev yüklenirken hata: $e';
      });
    }
  }
  
  // Dosya seçimi
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      print('Dosya seçim hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Seçilen dosyayı kaldır
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }
  
  // Mevcut dosyayı kaldır
  void _removeExistingFile(int index) {
    setState(() {
      _existingFiles.removeAt(index);
    });
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _addTask() {
    setState(() {
      _taskControllers.add(TextEditingController());
    });
  }
  
  void _removeTask(int index) {
    if (_taskControllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir görev olmalıdır')),
      );
      return;
    }
    
    setState(() {
      _taskControllers[index].dispose();
      _taskControllers.removeAt(index);
    });
  }
  
  // Öğrenci seçimini değiştir
  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }
  
  // Öğrenci seçim diyaloğunu göster
  void _showStudentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenci Seç'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _isLoadingStudents
            ? const Center(child: CircularProgressIndicator())
            : _students.isEmpty
              ? const Center(child: Text('Öğrenci bulunamadı'))
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final isSelected = _selectedStudentIds.contains(student['id']);
                    
                    return CheckboxListTile(
                      title: Text(student['name']),
                      subtitle: Text(student['email']),
                      value: isSelected,
                      onChanged: (value) {
                        _toggleStudentSelection(student['id']);
                        setState(() {});
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveHomework() async {
    setState(() {
      _errorMessage = '';
    });
    
    if (_formKey.currentState?.validate() ?? false) {
      // Öğrenci seçilip seçilmediğini kontrol et
      if (_selectedStudentIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen en az bir öğrenci seçin'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Görevleri Firestore formatına dönüştür
        List<Map<String, dynamic>> tasks = [];
        
        for (int i = 0; i < _taskControllers.length; i++) {
          Map<String, dynamic> taskData = {
            'id': 'task_$i',
            'description': _taskControllers[i].text,
            'isCompleted': false,
          };
          
          tasks.add(taskData);
        }
        
        // Dosya yükleme işlemi
        List<String> fileUrls = List<String>.from(_existingFiles);
        
        if (_selectedFiles.isNotEmpty) {
          setState(() {
            _isUploading = true;
            _uploadProgress = 0.0;
          });
          
          try {
            // Önce storage bağlantısını test et
            final bool isStorageConnected = await _storageService.testStorageConnection();
            if (!isStorageConnected) {
              throw Exception('Firebase Storage bağlantısı kurulamadı. Lütfen internet bağlantınızı kontrol edin.');
            }
            
            // Dosyaları hazırla
            List<Map<String, dynamic>> filesToUpload = _selectedFiles
                .where((file) => file.path != null)
                .map((file) => {'path': file.path!})
                .toList();
                
            // Dosya yolunu oluştur - basit ve geçerli bir yol kullan
            final homeworkId = _isEditMode ? widget.homeworkId! : DateTime.now().millisecondsSinceEpoch.toString();
            final teacherId = _teacherService.getCurrentUserId() ?? 'unknown';
            final destination = 'teacher_homework_${homeworkId}_${teacherId}';
            
            // Dosyaları yükle
            List<String> newFileUrls = await _storageService.uploadMultipleFiles(
              files: filesToUpload,
              basePath: destination,
              onProgress: (progress) {
                setState(() {
                  _uploadProgress = progress;
                });
              }
            );
            
            // Yeni dosya URL'lerini ekle
            fileUrls.addAll(newFileUrls);
          } catch (e) {
            print('Dosya yükleme hatası: $e');
            throw Exception('Dosya yüklenirken hata oluştu: ${e.toString()}');
          } finally {
            setState(() {
              _isUploading = false;
            });
          }
        }
        
        if (_isEditMode) {
          // Ödevi güncelle
          await _homeworkService.updateHomework(
            homeworkId: widget.homeworkId!,
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: _dueDate,
            tasks: tasks,
            assignedStudents: _selectedStudentIds,
            fileUrls: fileUrls,
          );
          
          if (!mounted) return;
          
          // Başarılı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ödev başarıyla güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Yeni ödev oluştur
          final homeworkId = await _homeworkService.createHomework(
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: _dueDate,
            tasks: tasks,
            assignedStudents: _selectedStudentIds,
            fileUrls: fileUrls,
          );
          
          if (!mounted) return;
          
          // Başarılı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ödev başarıyla oluşturuldu'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Öğretmen paneline geri dön
        Navigator.pop(context, true); // true değerini döndürerek veri değişikliğini belirt
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }
  
  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Ödevi Düzenle' : 'Ödev Oluştur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveHomework,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Ödev Başlığı',
                      hintText: 'Örn: İntegral Problem Seti',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bir başlık girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Öğrencilerinize ödev ile ilgili açıklamalar',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Son Tarih',
                          hintText: 'Ödevin son teslim tarihi',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showStudentSelectionDialog,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Atanan Öğrenciler',
                        hintText: 'Öğrenci seçmek için dokunun',
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                      ),
                      child: Text(
                        _selectedStudentIds.isEmpty
                            ? 'Öğrenci seçilmedi'
                            : '${_selectedStudentIds.length} öğrenci seçildi',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Görevler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Görev listesi
                  ..._buildTaskWidgets(),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Görev Ekle'),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Dosya Yükleme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickFiles,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Dosya Seç'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (_existingFiles.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Mevcut Dosyalar:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              _existingFiles.length,
                              (index) {
                                final fileName = _existingFiles[index].split('/').last;
                                final extension = fileName.split('.').last;
                                
                                return ListTile(
                                  leading: Icon(
                                    _getFileIcon(extension),
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: _isLoading ? null : () => _removeExistingFile(index),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Yeni Seçilen Dosyalar:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              _selectedFiles.length,
                              (index) => ListTile(
                                leading: Icon(
                                  _getFileIcon(_selectedFiles[index].extension ?? ''),
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  _selectedFiles[index].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${(_selectedFiles[index].size / 1024).toStringAsFixed(2)} KB',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: _isLoading ? null : () => _removeFile(index),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Dosyalar yükleniyor... (${(_uploadProgress * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
  
  List<Widget> _buildTaskWidgets() {
    List<Widget> taskWidgets = [];
    
    for (int i = 0; i < _taskControllers.length; i++) {
      taskWidgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _taskControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Görev ${i + 1}',
                      hintText: 'Görev açıklaması',
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Görev açıklaması boş olamaz';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeTask(i),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return taskWidgets;
  }
} 