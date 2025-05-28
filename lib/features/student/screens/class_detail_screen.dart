import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/services/student_service.dart';

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

  // Servis
  final StudentService _studentService = StudentService();

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
      // Alternatif olarak güvenli yöntemi deneyelim
      final classDetail = await _studentService.getClassDetailSafe(widget.classId);
      
      // Sınıf var mı?
      if (classDetail['exists'] != true) {
        setState(() {
          _errorMessage = classDetail['error'] ?? 'Sınıf bilgileri yüklenemedi';
          _isLoading = false;
        });
        return;
      }
      
      // Erişim izni var mı?
      if (classDetail['hasAccess'] != true) {
        setState(() {
          _errorMessage = 'Bu sınıfa erişim izniniz yok. Lütfen öğretmeninizle iletişime geçin.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _classDetail = classDetail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sınıf detayları yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
      
      // Hatayı log'a yazalım
      print('Sınıf detayı yükleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classDetail['name'] ?? 'Sınıf Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppConstants.routeClassChat,
                arguments: {
                  'classId': widget.classId,
                  'className': _classDetail['name'] ?? 'Sınıf',
                },
              );
            },
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
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClassCard(),
          const SizedBox(height: 24),
          _buildChatCard(),
          const SizedBox(height: 24),
          _buildStudentCount(),
        ],
      ),
    );
  }

  Widget _buildClassCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.class_, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
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
                      const SizedBox(height: 4),
                      Text(
                        'Öğretmen: ${_classDetail['teacherName'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_classDetail['description'] != null && 
                _classDetail['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _classDetail['description'],
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
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
                      'Öğretmen ve arkadaşlarınla mesajlaş',
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

  Widget _buildStudentCount() {
    final List<Map<String, dynamic>> students = List<Map<String, dynamic>>.from(_classDetail['students'] ?? []);
    
    return GestureDetector(
      onTap: () {
        _showClassmatesDialog(students);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.people, size: 24, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sınıf Arkadaşları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_classDetail['studentCount'] ?? 0} öğrenci',
                      style: TextStyle(
                        color: Colors.grey[700],
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
  
  // Sınıf arkadaşları diyaloğunu göster
  void _showClassmatesDialog(List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Sınıf Arkadaşlarım'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: students.isEmpty
            ? const Center(child: Text('Bu sınıfta başka öğrenci bulunmuyor'))
            : ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final isCurrentStudent = student['isCurrentStudent'] == true;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrentStudent ? AppColors.accent : Colors.blue,
                      child: Text(
                        student['name']?.substring(0, 1).toUpperCase() ?? '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      '${student['name']}${isCurrentStudent ? ' (Sen)' : ''}',
                    ),
                    subtitle: student['email'] != null && student['email'].toString().isNotEmpty
                      ? Text(student['email'])
                      : null,
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
} 