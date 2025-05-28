import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/homework_service.dart';
import 'package:math_app/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class HomeworkViewScreen extends StatefulWidget {
  final String? homeworkId;
  
  const HomeworkViewScreen({super.key, this.homeworkId});

  @override
  State<HomeworkViewScreen> createState() => _HomeworkViewScreenState();
}

class _HomeworkViewScreenState extends State<HomeworkViewScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  
  // Ödev verisi
  Map<String, dynamic>? _homework;
  List<bool> _completedTasks = [];
  
  // Dosya yükleme için
  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // Servis
  final HomeworkService _homeworkService = HomeworkService();
  final StorageService _storageService = StorageService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Öğretmen tarafından yüklenen dosyaları kontrol et
  List<String> _existingFiles = [];
  
  // Öğrencinin önceden yüklediği dosyaları kontrol et
  List<String> _studentSubmittedFiles = [];
  
  @override
  void initState() {
    super.initState();
    // Argümanların düzgün bir şekilde alınmasını sağlamak için kısa bir gecikme
    Future.delayed(Duration.zero, () {
      _resolveHomeworkId();
    });
  }
  
  void _resolveHomeworkId() {
    final args = ModalRoute.of(context)?.settings.arguments;
    
    String? homeworkId;
    
    // Widget üzerinden gelen ID
    if (widget.homeworkId != null && widget.homeworkId!.isNotEmpty) {
      homeworkId = widget.homeworkId;
      print('HomeworkID from widget: $homeworkId');
    } 
    // Route üzerinden gelen string ID
    else if (args is String) {
      homeworkId = args;
      print('HomeworkID from route (String): $homeworkId');
    }
    // Route üzerinden gelen map ID
    else if (args is Map<String, dynamic> && args.containsKey('id')) {
      homeworkId = args['id']?.toString();
      print('HomeworkID from route (Map): $homeworkId');
    }
    
    if (homeworkId != null && homeworkId.isNotEmpty) {
      _loadHomework(homeworkId);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ödev ID\'si bulunamadı veya geçersiz';
      });
    }
  }
  
  Future<void> _loadHomework(String homeworkId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Değişiklik: homeworkId parametresi artık fonksiyona geçiriliyor
      if (homeworkId.isEmpty) {
        throw Exception('Geçerli bir ödev ID\'si bulunamadı. Lütfen ödevler listesine dönün ve tekrar deneyin.');
      }
      
      _homework = await _homeworkService.getHomework(homeworkId);
      
      // Ödevin doğru yüklendiğinden emin olalım
      if (_homework == null) {
        throw Exception('Ödev bulunamadı veya yüklenemedi.');
      }
      
      // Tüm görevleri başlangıçta tamamlanmamış olarak işaretleyelim
      final tasks = _homework!['tasks'] as List<dynamic>;
      _completedTasks = List.generate(tasks.length, (index) => false);

      // Öğretmen tarafından yüklenen dosyaları kontrol et
      if (_homework!.containsKey('fileUrls')) {
        setState(() {
          _existingFiles = List<String>.from(_homework!['fileUrls'] ?? []);
        });
      }
      
      // Öğrenci daha önce bu ödevi tamamladıysa, durumunu kontrol et
      final studentId = _homeworkService.getCurrentUserId();
      if (_homework!.containsKey('studentSubmissions')) {
        final submissions = _homework!['studentSubmissions'] as List<dynamic>?;
        if (submissions != null) {
          for (var submission in submissions) {
            if (submission['studentId'] == studentId) {
              // Öğrencinin tamamladığı görevleri işaretle
              if (submission.containsKey('completedTasks')) {
                final completedTasksList = submission['completedTasks'] as List<dynamic>;
                for (int i = 0; i < completedTasksList.length; i++) {
                  final taskData = completedTasksList[i];
                  if (i < _completedTasks.length && taskData['isCompleted'] == true) {
                    _completedTasks[i] = true;
                  }
                }
              }
              
              // Öğrencinin yüklediği dosyaları ekle
              if (submission.containsKey('fileUrls')) {
                setState(() {
                  _studentSubmittedFiles = List<String>.from(submission['fileUrls'] ?? []);
                });
              }
              break;
            }
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ödev yüklenirken hata: $e';
      });
      
      // Hata log
      print('Ödev yükleme hatası: $e | ID: $homeworkId');
    }
  }
  
  void _toggleTaskCompletion(int index) {
    setState(() {
      _completedTasks[index] = !_completedTasks[index];
    });
  }
  
  // Add a method to reload the current homework
  void _reloadHomework() {
    _resolveHomeworkId();
  }
  
  bool get _allTasksCompleted => !_completedTasks.contains(false);

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
  
  void _submitHomework() {
    if (!_allTasksCompleted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tüm görevler tamamlanmadı'),
          content: const Text('Bazı görevler tamamlanmamış görünüyor. Yine de ödevi göndermek istiyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _processSubmission();
              },
              child: const Text('Gönder'),
            ),
          ],
        ),
      );
    } else {
      _processSubmission();
    }
  }
  
  Future<void> _processSubmission() async {
    if (_homework == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev bilgileri yüklenemedi, lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final homeworkId = widget.homeworkId;
    if (homeworkId == null || homeworkId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev ID bulunamadı, lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    
    try {
      // Tamamlanan görevleri hazırla
      final tasks = _homework!['tasks'] as List<dynamic>;
      List<Map<String, dynamic>> completedTasks = [];
      
      for (int i = 0; i < tasks.length; i++) {
        completedTasks.add({
          'id': tasks[i]['id'],
          'description': tasks[i]['description'],
          'isCompleted': _completedTasks[i],
        });
      }
      
      // Erişim ve atama kontrolü
      if (!(_homework!['assignedStudents'] as List<dynamic>).contains(_homeworkService.getCurrentUserId())) {
        throw Exception('Bu ödeve erişim yetkiniz yok. Lütfen öğretmeninizle iletişime geçin.');
      }
      
      // Ödev gönderilme zaten tamamlanmış mı kontrol et
      if ((_homework!['completedStudents'] as List<dynamic>).contains(_homeworkService.getCurrentUserId())) {
        throw Exception('Bu ödevi zaten tamamladınız. Tekrar gönderemezsiniz.');
      }
      
      // Dosya yükleme işlemi
      List<String> fileUrls = [];
      
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
          
          // Dosyaları storage servisini kullanarak yükle
          List<Map<String, dynamic>> filesToUpload = _selectedFiles
              .where((file) => file.path != null)
              .map((file) => {'path': file.path!})
              .toList();
              
          // Dosya yollarını hazırla - basit, geçerli bir yol kullan
          final studentId = _homeworkService.getCurrentUserId() ?? 'unknown';
          final destination = 'homework_${homeworkId}_${studentId}';
          
          // Dosyaları yükle ve ilerleme durumunu güncelle
          fileUrls = await _storageService.uploadMultipleFiles(
            files: filesToUpload,
            basePath: destination,
            onProgress: (progress) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          );
        } catch (e) {
          print('Dosya yükleme hatası: $e');
          throw Exception('Dosya yüklenirken hata oluştu: ${e.toString()}');
        } finally {
          setState(() {
            _isUploading = false;
          });
        }
      }
      
      // Ödevi gönder
      await _homeworkService.submitHomework(
        homeworkId,
        completedTasks,
        fileUrls.isNotEmpty ? fileUrls : null,
      );
      
      if (!mounted) return;
      
      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev başarıyla gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Geri dön
      Navigator.pop(context, true); // true değerini döndürerek veri değişikliğini belirt
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Ödev gönderilirken hata: $e';
      });
      
      // Hata log
      print('Ödev gönderme hatası: $e | ID: $homeworkId');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Eğer route argümanlarından gelen homeworkId değeri yoksa ve widget'a geçilen homewordId de null ise
    // Yol argümanlarından almaya çalış
    final widgetHomeworkId = widget.homeworkId;
    
    if (widgetHomeworkId == null) {
      // Route argümanlarını kontrol et, belki oradan gelebilir
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        // Argümanın bir string olduğunu varsayalım - bu ID olmalı
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeworkViewScreen(homeworkId: args),
            ),
          );
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_homework != null ? _homework!['title'] : 'Ödev'),
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
                          onPressed: _reloadHomework,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _homework == null
                  ? const Center(child: Text('Ödev bulunamadı'))
                  : SingleChildScrollView(
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
                                    _homework!['title'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _homework!['description'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Son Tarih: ${_formatDate(_homework!['dueDate'])}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (_homework!['tasks'] as List).length,
                            itemBuilder: (context, index) {
                              return _buildTaskItem(index);
                            },
                          ),
                          const SizedBox(height: 24),
                          // Öğretmen tarafından yüklenen dosyaları göster
                          if (_existingFiles.isNotEmpty) ...[
                            const Text(
                              'Öğretmen Tarafından Yüklenen Dosyalar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _existingFiles.length,
                              itemBuilder: (context, index) {
                                final fileName = _existingFiles[index].split('/').last;
                                final extension = fileName.split('.').last;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
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
                                      icon: const Icon(Icons.download, color: Colors.blue),
                                      onPressed: () => _downloadFile(_existingFiles[index], fileName),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Öğrencinin önceden yüklediği dosyaları göster
                          if (_studentSubmittedFiles.isNotEmpty) ...[
                            const Text(
                              'Daha Önce Yüklediğiniz Dosyalar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _studentSubmittedFiles.length,
                              itemBuilder: (context, index) {
                                final fileName = _studentSubmittedFiles[index].split('/').last;
                                final extension = fileName.split('.').last;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      _getFileIcon(extension),
                                      color: Colors.green,
                                    ),
                                    title: Text(
                                      fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.download, color: Colors.blue),
                                      onPressed: () => _downloadFile(_studentSubmittedFiles[index], fileName),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
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
                                    onPressed: _isSubmitting ? null : _pickFiles,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Dosya Seç'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  if (_selectedFiles.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Seçilen Dosyalar:',
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
                                          onPressed: _isSubmitting ? null : () => _removeFile(index),
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
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitHomework,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Ödevi Gönder',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
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
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildTaskItem(int index) {
    final tasks = _homework!['tasks'] as List<Map<String, dynamic>>;
    final task = tasks[index];
    final isCompleted = _completedTasks[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: Text(
          task['description'],
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        value: isCompleted,
        onChanged: (value) => _toggleTaskCompletion(index),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Colors.green,
      ),
    );
  }
  
  // Dosyayı indirme fonksiyonu
  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      // Uzantı kontrolü
      String name = fileName;
      if (!name.contains('.')) {
        // URL'den uzantıyı al
        final ext = fileUrl.split('?').first.split('.').last;
        name = '[32m$name.$ext[0m';
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await StorageService.downloadAndOpenFile(fileUrl, name);
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya başarıyla indirildi ve açıldı.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya indirilemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }
} 