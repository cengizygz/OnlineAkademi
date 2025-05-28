import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:math_app/services/auth_service.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:math_app/services/question_service.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_app/features/profile/screens/student_question_pool_screen.dart';

class StudentSelfProfileScreen extends StatefulWidget {
  const StudentSelfProfileScreen({super.key});

  @override
  State<StudentSelfProfileScreen> createState() => _StudentSelfProfileScreenState();
}

class _StudentSelfProfileScreenState extends State<StudentSelfProfileScreen> {
  final AuthService _authService = AuthService();
  final ExamService _examService = ExamService();
  final QuestionService _questionService = QuestionService();
  bool _isLoading = false;
  bool _isEditing = false;
  String? _profilePictureUrl;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _examScores = [];
  List<Map<String, dynamic>> _questionPoolPoints = [];
  int _userRank = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      // Kullanıcı bilgilerini yükle
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
          _profilePictureUrl = userData['profilePicture'] as String?;
        });
      }

      // Sınav notlarını yükle
      final examScores = await _examService.getStudentExamScores(_authService.currentUser!.uid);
      
      // Soru havuzu puanlarını ve sıralamayı yükle
      final questionPoolData = await _questionService.getStudentQuestionPoolPoints();
      final allPoints = questionPoolData['allPoints'] as List<Map<String, dynamic>>;
      final userPoints = questionPoolData['userPoints'] as Map<String, dynamic>;
      
      // Kullanıcının sıralamasını bul
      int rank = 1;
      for (var points in allPoints) {
        if (points['userId'] == _authService.currentUser!.uid) {
          break;
        }
        rank++;
      }

      setState(() {
        _examScores = examScores;
        _questionPoolPoints = allPoints;
        _userRank = rank;
      });
    } catch (e) {
      print('Veriler yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isLoading = true);
        
        final File imageFile = File(image.path);
        final String downloadUrl = await _authService.uploadProfilePicture(imageFile);
        
        setState(() {
          _profilePictureUrl = downloadUrl;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _authService.updateProfile(
        name: _userData?['name'] ?? '',
        phoneNumber: _userData?['phoneNumber'] ?? '',
        profilePicture: _profilePictureUrl,
      );
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil güncellenirken hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildExamScoresList() {
    if (_examScores.isEmpty) {
      return Center(
        child: Text(
          'Henüz sınav notu bulunmuyor',
          style: GoogleFonts.notoSerif(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _examScores.length,
      itemBuilder: (context, index) {
        final exam = _examScores[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              exam['examName'] ?? 'İsimsiz Sınav',
              style: GoogleFonts.notoSerif(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Tarih: ${(exam['examDate'] as Timestamp).toDate().toString().split(' ')[0]}',
              style: GoogleFonts.notoSerif(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Text(
              '${exam['score']} Puan',
              style: GoogleFonts.notoSerif(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionPoolRanking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Soru Havuzu Sıralaması',
            style: GoogleFonts.notoSerif(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sıralama',
                      style: GoogleFonts.notoSerif(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Puan',
                      style: GoogleFonts.notoSerif(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                ...List.generate(
                  _questionPoolPoints.length > 10 ? 10 : _questionPoolPoints.length,
                  (index) {
                    final points = _questionPoolPoints[index];
                    final isCurrentUser = points['userId'] == _authService.currentUser!.uid;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Colors.blue.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: index < 3 ? Colors.amber : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.notoSerif(
                                      color: index < 3 ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                points['name'] ?? 'İsimsiz Kullanıcı',
                                style: GoogleFonts.notoSerif(
                                  fontSize: 14,
                                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${points['points']} Puan',
                            style: GoogleFonts.notoSerif(
                              fontSize: 14,
                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentUser ? Colors.blue : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_userRank > 10) ...[
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_userRank',
                                  style: GoogleFonts.notoSerif(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _userData?['name'] ?? 'İsimsiz Kullanıcı',
                              style: GoogleFonts.notoSerif(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_questionPoolPoints.firstWhere((p) => p['userId'] == _authService.currentUser!.uid)['points']} Puan',
                          style: GoogleFonts.notoSerif(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.notoSerif(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            tooltip: _isEditing ? 'Kaydet' : 'Düzenle',
            onPressed: _isEditing ? _saveProfile : _toggleEdit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profil Fotoğrafı ve Güncelle Butonu (EN ÜSTE ALINDI)
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          child: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: _profilePictureUrl!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person, size: 60, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: _pickAndUploadImage,
                          child: const Text(
                            'Fotoğrafı Güncelle',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Kullanıcı Bilgileri
                  if (_userData != null) ...[
                    Text(
                      _userData!['name'] ?? 'İsimsiz Kullanıcı',
                      style: GoogleFonts.notoSerif(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // E-posta (readonly)
                    TextFormField(
                      initialValue: _userData!['email'] ?? '',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Telefon (edit mode)
                    TextFormField(
                      initialValue: _userData!['phoneNumber'] ?? '',
                      readOnly: !_isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        _userData!['phoneNumber'] = val;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Şifre Sıfırla Butonu
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          if (_userData!['email'] != null && _userData!['email'].toString().isNotEmpty) {
                            await _authService.sendPasswordResetEmail(_userData!['email']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi.'), backgroundColor: Colors.blue),
                            );
                          }
                        },
                        icon: const Icon(Icons.lock_reset, color: Colors.blue),
                        label: const Text('Şifre Sıfırla', style: TextStyle(color: Colors.blue)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userData!['role'] == AppConstants.roleStudent ? 'Öğrenci' : 'Öğretmen',
                      style: GoogleFonts.notoSerif(
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Sınav Notları
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sınav Notlarım',
                      style: GoogleFonts.notoSerif(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildExamScoresList(),
                  
                  const SizedBox(height: 24),
                  
                  // Soru Havuzu Sıralaması
                  _buildQuestionPoolRanking(),
                  
                  const SizedBox(height: 32),
                  
                  // Çıkış Yap Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _authService.signOut();
                          if (!mounted) return;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppConstants.routeLogin,
                            (route) => false,
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Çıkış yapılırken hata oluştu: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ÇIKIŞ YAP',
                        style: GoogleFonts.notoSerif(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 