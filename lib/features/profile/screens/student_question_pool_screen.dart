import 'package:flutter/material.dart';
import 'package:math_app/services/question_service.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentQuestionPoolScreen extends StatefulWidget {
  const StudentQuestionPoolScreen({super.key});

  @override
  State<StudentQuestionPoolScreen> createState() => _StudentQuestionPoolScreenState();
}

class _StudentQuestionPoolScreenState extends State<StudentQuestionPoolScreen> {
  final QuestionService _questionService = QuestionService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPoints = [];
  Map<String, dynamic>? _userPoints;
  int _userRank = 0;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    try {
      final data = await _questionService.getStudentQuestionPoolPoints();
      final allPoints = data['allPoints'] as List<Map<String, dynamic>>;
      final userPoints = data['userPoints'] as Map<String, dynamic>;
      int rank = 1;
      for (var p in allPoints) {
        if (p['userId'] == userPoints['userId']) break;
        rank++;
      }
      setState(() {
        _allPoints = allPoints;
        _userPoints = userPoints;
        _userRank = rank;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Puanlar yüklenirken hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Havuzu Sıralaması'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userPoints != null) ...[
                    Card(
                      color: Colors.blue[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          backgroundImage: (_userPoints!['profilePicture'] != null && (_userPoints!['profilePicture'] as String).isNotEmpty)
                              ? NetworkImage(_userPoints!['profilePicture'])
                              : null,
                          child: (_userPoints!['profilePicture'] == null || (_userPoints!['profilePicture'] as String).isEmpty)
                              ? Text(
                                  '$_userRank',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          _userPoints!['name'] ?? 'İsimsiz Kullanıcı',
                          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Puanınız: ${_userPoints!['points']}  |  Çözdüğünüz Soru: ${_userPoints!['solvedCount']}'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'İlk 10',
                    style: GoogleFonts.notoSerif(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allPoints.length > 10 ? 10 : _allPoints.length,
                      itemBuilder: (context, index) {
                        final p = _allPoints[index];
                        final isCurrentUser = _userPoints != null && p['userId'] == _userPoints!['userId'];
                        return Card(
                          color: isCurrentUser ? Colors.blue[100] : null,
                          child: ListTile(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.blue,
                                        backgroundImage: (p['profilePicture'] != null && (p['profilePicture'] as String).isNotEmpty)
                                            ? NetworkImage(p['profilePicture'])
                                            : null,
                                        child: (p['profilePicture'] == null || (p['profilePicture'] as String).isEmpty)
                                            ? Icon(Icons.person, color: Colors.white, size: 28)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(p['name'] ?? 'İsimsiz Kullanıcı')),
                                    ],
                                  ),
                                  content: Text('Çözdüğü Soru Adedi: ${p['solvedCount']}'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Kapat'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: index < 3 ? Colors.amber : Colors.grey[300],
                              backgroundImage: (p['profilePicture'] != null && (p['profilePicture'] as String).isNotEmpty)
                                  ? NetworkImage(p['profilePicture'])
                                  : null,
                              child: (p['profilePicture'] == null || (p['profilePicture'] as String).isEmpty)
                                  ? Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: index < 3 ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              p['name'] ?? 'İsimsiz Kullanıcı',
                              style: GoogleFonts.notoSerif(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                            ),
                            subtitle: Text('Çözdüğü: ${p['solvedCount']}'),
                            trailing: Text(
                              '${p['points']} Puan',
                              style: GoogleFonts.notoSerif(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 