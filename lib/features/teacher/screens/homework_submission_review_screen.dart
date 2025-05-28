import 'package:flutter/material.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/homework_service.dart';
import 'package:math_app/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeworkSubmissionReviewScreen extends StatefulWidget {
  final String homeworkId;
  final String studentId;
  
  const HomeworkSubmissionReviewScreen({
    super.key, 
    required this.homeworkId, 
    required this.studentId
  });

  @override
  State<HomeworkSubmissionReviewScreen> createState() => _HomeworkSubmissionReviewScreenState();
}

class _HomeworkSubmissionReviewScreenState extends State<HomeworkSubmissionReviewScreen> {
  final HomeworkService _homeworkService = HomeworkService();
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  Map<String, dynamic>? _submissionData;
  
  // Puanlama için
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSubmissionData();
  }
  
  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSubmissionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Öğrenci cevaplarını getir
      _submissionData = await _homeworkService.getStudentHomeworkSubmission(
        widget.homeworkId, 
        widget.studentId
      );
      
      // Eğer zaten puanlanmışsa, mevcut puanı ve geri bildirimi yükle
      if (_submissionData!['graded']) {
        _scoreController.text = _submissionData!['score'].toString();
        _feedbackController.text = _submissionData!['feedback'];
      } else {
        // Varsayılan değerler
        _scoreController.text = '0';
        _feedbackController.text = '';
      }
      
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
  
  Future<void> _saveGrade() async {
    // Boş veya negatif puan kontrolü
    final scoreText = _scoreController.text.trim();
    if (scoreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir puan girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final score = int.tryParse(scoreText) ?? 0;
    if (score < 0 || score > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 0-100 arası bir puan girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      await _homeworkService.gradeHomework(
        _submissionData!['id'],
        score,
        _feedbackController.text.trim(),
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puan başarıyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Geri dönerken, puanlama sayfasının kendini güncellemesi için true dön
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Puan kaydedilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_submissionData != null ? '${_submissionData!['homeworkTitle']} - Değerlendirme' : 'Ödev Değerlendirme'),
        actions: [
          if (_submissionData != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveGrade,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.white),
              ),
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
                          onPressed: _loadSubmissionData,
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
    if (_submissionData == null) {
      return const Center(child: Text('Ödev verisi bulunamadı'));
    }
    
    final completedTasks = _submissionData!['completedTasks'] as List<Map<String, dynamic>>;
    final fileUrls = _submissionData!['fileUrls'] as List<String>? ?? [];
    
    // Ödev bilgilerini al - öğretmenin yüklediği dosyaları görmek için
    Map<String, dynamic>? homeworkData;
    List<String> teacherFileUrls = [];
    
    if (_submissionData!.containsKey('homeworkData') && _submissionData!['homeworkData'] != null) {
      homeworkData = _submissionData!['homeworkData'] as Map<String, dynamic>;
      if (homeworkData.containsKey('fileUrls')) {
        teacherFileUrls = List<String>.from(homeworkData['fileUrls'] ?? []);
      }
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentInfo(),
          const Divider(height: 32),
          _buildGradingSection(),
          const Divider(height: 32),
          
          // Öğretmenin yüklediği dosyaları göster
          if (teacherFileUrls.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Öğretmen Tarafından Yüklenen Dosyalar (${teacherFileUrls.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: teacherFileUrls.length,
              itemBuilder: (context, index) {
                return _buildFileItem(teacherFileUrls[index], index, isTeacherFile: true);
              },
            ),
            const Divider(height: 32),
          ],
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tamamlanan Görevler (${completedTasks.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskItem(completedTasks[index], index);
            },
          ),
          if (fileUrls.isNotEmpty) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Öğrenci Tarafından Yüklenen Dosyalar (${fileUrls.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fileUrls.length,
              itemBuilder: (context, index) {
                return _buildFileItem(fileUrls[index], index, isTeacherFile: false);
              },
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStudentInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _submissionData!['studentName'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Teslim Tarihi: ${_formatTimestamp(_submissionData!['submittedAt'] as Timestamp)}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            if (_submissionData!['graded'])
              Row(
                children: [
                  const Icon(Icons.grade, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Mevcut Puan: ${_submissionData!['score']}/100',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGradingSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Değerlendirme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: 'Puan (0-100)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.score),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Geri Bildirim (Öğrenciye Notlar)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.feedback),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGrade,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Değerlendirmeyi Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTaskItem(Map<String, dynamic> task, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Görev ${index + 1}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task['description'] ?? 'Açıklama yok',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Öğrenci Cevabı:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task['answer'] ?? 'Cevap verilmemiş',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileItem(String fileUrl, int index, {bool isTeacherFile = false}) {
    final fileName = fileUrl.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    
    // Dosya tipine göre icon belirle
    IconData fileIcon;
    switch (extension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        fileIcon = Icons.image;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = Icons.table_chart;
        break;
      case 'ppt':
      case 'pptx':
        fileIcon = Icons.slideshow;
        break;
      case 'txt':
        fileIcon = Icons.text_snippet;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isTeacherFile ? Colors.blue.shade300 : Colors.green.shade300,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(fileIcon, color: isTeacherFile ? Colors.blue : Colors.green, size: 36),
        title: Text(
          fileName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTeacherFile ? Colors.blue.shade700 : Colors.green.shade700,
          ),
        ),
        subtitle: Text(
          isTeacherFile ? 'Öğretmen dosyası' : 'Öğrenci dosyası',
          style: TextStyle(
            color: isTeacherFile ? Colors.blue.shade400 : Colors.green.shade400,
          ),
        ),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('İndir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isTeacherFile ? Colors.blue : Colors.green,
          ),
          onPressed: () => _showFileDownloadDialog(fileUrl, fileName),
        ),
        onTap: () => _showFileDownloadDialog(fileUrl, fileName),
      ),
    );
  }
  
  // Dosyayı indirme diyaloğu
  void _showFileDownloadDialog(String fileUrl, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      await StorageService.downloadAndOpenFile(fileUrl, fileName);
      
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosya başarıyla indirildi ve açıldı.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya indirilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 