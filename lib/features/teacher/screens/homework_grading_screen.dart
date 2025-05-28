import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/homework_service.dart';
import 'package:math_app/services/storage_service.dart';

class HomeworkGradingScreen extends StatefulWidget {
  final String homeworkId;
  
  const HomeworkGradingScreen({super.key, required this.homeworkId});

  @override
  State<HomeworkGradingScreen> createState() => _HomeworkGradingScreenState();
}

class _HomeworkGradingScreenState extends State<HomeworkGradingScreen> {
  final HomeworkService _homeworkService = HomeworkService();
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Ödev verileri
  Map<String, dynamic>? _homeworkData;
  List<Map<String, dynamic>> _submissions = [];
  
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
      // Ödev bilgilerini getir
      _homeworkData = await _homeworkService.getHomework(widget.homeworkId);
      
      // Ödev gönderilerini getir
      _submissions = await _homeworkService.getHomeworkSubmissions(widget.homeworkId);
      
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
        title: Text(_homeworkData != null ? 'Ödev: ${_homeworkData!['title']}' : 'Ödev Değerlendirme'),
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
    if (_homeworkData == null) {
      return const Center(child: Text('Ödev bilgisi bulunamadı'));
    }
    
    return Column(
      children: [
        _buildHomeworkInfo(),
        const Divider(),
        if (_submissions.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz ödev gönderisi bulunmuyor',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ödev Son Tarihi: ${_formatDate(_homeworkData!['dueDate'])}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_homeworkData!['assignedStudents'].length} öğrenciye atandı',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  final submission = _submissions[index];
                  return _buildSubmissionItem(submission);
                },
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildHomeworkInfo() {
    if (_homeworkData == null) return const SizedBox.shrink();
    
    final dueDate = _homeworkData!['dueDate'];
    final isOverdue = dueDate.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _homeworkData!['title'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _homeworkData!['description'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Son Tarih: ${_formatDate(_homeworkData!['dueDate'])}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.grey,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverdue ? Colors.red : Colors.green,
                    ),
                  ),
                  child: Text(
                    isOverdue ? 'Süresi Doldu' : 'Aktif',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Atanan: ${_homeworkData!['assignedStudents'].length} öğrenci',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Tamamlayan: ${_homeworkData!['completedStudents'].length} öğrenci',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (_homeworkData!['fileUrls'] != null && (_homeworkData!['fileUrls'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Dosyalar: ${(_homeworkData!['fileUrls'] as List).length} adet',
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Dosyaları Görüntüle', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      // Dosyaları görüntüleme diyaloğu
                      _showFilesDialog(_homeworkData!['fileUrls'] as List<String>);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmissionItem(Map<String, dynamic> submission) {
    // Puanlama durumuna göre renk
    final Color statusColor = submission['graded'] 
        ? Colors.green 
        : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            submission['graded'] ? Icons.grading : Icons.pending_actions,
            color: statusColor,
          ),
        ),
        title: Text(submission['studentName']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Teslim: ${_formatTimestamp(submission['submittedAt'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                submission['graded'] 
                    ? Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Puan: ${submission['score']}/100',
                            style: const TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.pending, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Değerlendirilmedi',
                            style: TextStyle(
                              fontSize: 12, 
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                const Spacer(),
                Text(
                  'Dosya: ${(submission['fileUrls'] as List).length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  'Görev: ${(submission['completedTasks'] as List).length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: () {
            // Ödev değerlendirme sayfasına yönlendir
            Navigator.pushNamed(
              context,
              AppConstants.routeHomeworkSubmissionReview,
              arguments: {
                'homeworkId': widget.homeworkId,
                'studentId': submission['studentId'],
              },
            ).then((value) {
              // Sayfa dönüşünde verileri yenile
              if (value == true) {
                _loadData();
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(40, 36),
          ),
          child: Text(
            submission['graded'] ? 'Görüntüle' : 'Değerlendir',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        onTap: () {
          // Ödev değerlendirme sayfasına yönlendir
          Navigator.pushNamed(
            context,
            AppConstants.routeHomeworkSubmissionReview,
            arguments: {
              'homeworkId': widget.homeworkId,
              'studentId': submission['studentId'],
            },
          ).then((value) {
            // Sayfa dönüşünde verileri yenile
            if (value == true) {
              _loadData();
            }
          });
        },
      ),
    );
  }
  
  void _showFilesDialog(List<String> fileUrls) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödev Dosyaları'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fileUrls.length,
            itemBuilder: (context, index) {
              final fileName = fileUrls[index].split('/').last;
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
              
              return ListTile(
                leading: Icon(fileIcon, color: Colors.blue),
                title: Text(fileName),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    // Dosya indirme işlemi
                    Navigator.pop(context);
                    _showFileDownloadDialog(fileUrls[index], fileName);
                  },
                ),
                onTap: () {
                  // Dosya görüntüleme
                  Navigator.pop(context);
                  _showFileDownloadDialog(fileUrls[index], fileName);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
  
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
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Tarih bilinmiyor';
    
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 