import 'package:flutter/material.dart';
import 'package:math_app/models/question_pool.dart';
import 'package:math_app/services/question_pool_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:math_app/core/constants/app_constants.dart';

class QuestionPoolScreen extends StatefulWidget {
  const QuestionPoolScreen({super.key});

  @override
  State<QuestionPoolScreen> createState() => _QuestionPoolScreenState();
}

class _QuestionPoolScreenState extends State<QuestionPoolScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuestionPoolService _questionPoolService = QuestionPoolService();
  
  // Veriler
  List<PoolQuestion> _availableQuestions = [];
  List<PoolQuestion> _myQuestions = [];
  List<PoolQuestion> _mySolvedQuestions = [];
  
  // Yükleme durumları
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final availableQuestions = await _questionPoolService.getAvailableQuestions();
      final myQuestions = await _questionPoolService.getMyQuestions();
      final mySolvedQuestions = await _questionPoolService.getMySolvedQuestions();
      
      if (mounted) {
        setState(() {
          _availableQuestions = availableQuestions;
          _myQuestions = myQuestions;
          _mySolvedQuestions = mySolvedQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yüklenirken hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToCreateQuestion() {
    Navigator.pushNamed(context, AppConstants.routeQuestionCreate).then((_) {
      // Geri döndüğünde veriyi yenile
      _loadData();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soru Havuzu'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Çözülebilir Sorular'),
            Tab(text: 'Sorularım'),
            Tab(text: 'Çözdüğüm Sorular'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
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
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Çözülebilir sorular
                    _buildAvailableQuestionsTab(),
                    
                    // Benim sorularım
                    _buildMyQuestionsTab(),
                    
                    // Çözdüğüm sorular
                    _buildMySolvedQuestionsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateQuestion,
        tooltip: 'Soru Oluştur',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // Çözülebilir sorular sekmesi
  Widget _buildAvailableQuestionsTab() {
    if (_availableQuestions.isEmpty) {
      return const Center(
        child: Text(
          'Şu anda çözülebilir soru bulunmuyor. Yeni sorular eklendiğinde burada görünecek.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _availableQuestions.length,
      itemBuilder: (context, index) {
        final question = _availableQuestions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showSolveDialog(question),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${question.subject} / ${question.topic}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Şıkları görmek ve soruyu çözmek için tıklayın',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Sorularım sekmesi
  Widget _buildMyQuestionsTab() {
    if (_myQuestions.isEmpty) {
      return const Center(
        child: Text(
          'Henüz soru oluşturmadınız. Yeni soru eklemek için sağ alttaki + butonuna tıklayın.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _myQuestions.length,
      itemBuilder: (context, index) {
        final question = _myQuestions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showQuestionDetailsDialog(question),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.questionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(question),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${question.subject} / ${question.topic}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (question.isSolved && question.solutionText != null) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Çözüm:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            question.solutionText!,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Çözdüğüm sorular sekmesi
  Widget _buildMySolvedQuestionsTab() {
    if (_mySolvedQuestions.isEmpty) {
      return const Center(
        child: Text(
          'Henüz hiç soru çözmediniz. İlk sekmeye geçip soruları çözebilirsiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _mySolvedQuestions.length,
      itemBuilder: (context, index) {
        final question = _mySolvedQuestions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showQuestionDetailsDialog(question),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${question.subject} / ${question.topic}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Doğru Çözüldü',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Durum etiketi
  Widget _buildStatusChip(PoolQuestion question) {
    if (question.isSolved) {
      return const Chip(
        label: Text('Çözüldü'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else if (question.isApproved) {
      return const Chip(
        label: Text('Onaylandı'),
        backgroundColor: Colors.blue,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else {
      return const Chip(
        label: Text('Onay Bekliyor'),
        backgroundColor: Colors.orange,
        labelStyle: TextStyle(color: Colors.white),
      );
    }
  }
  
  // Soru detaylarını göster
  void _showQuestionDetailsDialog(PoolQuestion question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soru Detayları'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.questionText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Şıklar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(4, (index) {
                final letter = String.fromCharCode(65 + index); // A, B, C, D
                final isCorrect = letter == question.correctAnswer;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCorrect ? Colors.green : Colors.grey.shade300,
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: TextStyle(
                            fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: isCorrect ? Colors.green : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Ders: ${question.subject}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Konu: ${question.topic}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (question.isSolved) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Çözüm:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (question.solutionText != null && question.solutionText!.isNotEmpty)
                  Text(question.solutionText!),
                if (question.solutionFileUrl != null && question.solutionFileUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download),
                    label: const Text('Çözüm Dosyasını İndir'),
                    onPressed: () {
                      // Dosya indirme işlemi - URL tarayıcıda açılabilir
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dosya URL: ${question.solutionFileUrl}'),
                          action: SnackBarAction(
                            label: 'Tamam',
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                  ),
                ]
              ],
            ],
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
  
  // Soruyu çözme diyalogu
  void _showSolveDialog(PoolQuestion question) {
    String selectedAnswer = '';
    String solutionText = '';
    File? solutionFile;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Soruyu Çöz'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    question.questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Şıklar:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(4, (index) {
                    final letter = String.fromCharCode(65 + index); // A, B, C, D
                    return RadioListTile<String>(
                      title: Text(question.options[index]),
                      value: letter,
                      groupValue: selectedAnswer,
                      onChanged: (value) {
                        setState(() {
                          selectedAnswer = value!;
                        });
                      },
                    );
                  }),
                  if (selectedAnswer.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Çözüm Açıklaması (opsiyonel):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Çözümünüzü açıklayın...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        solutionText = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Çözüm Dosyası (opsiyonel):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (solutionFile == null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Dosya Seç'),
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles();
                            if (result != null) {
                              setState(() {
                                solutionFile = File(result.files.single.path!);
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Dosya seçilirken hata: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Seçilen: ${solutionFile!.path.split('/').last}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                solutionFile = null;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              if (selectedAnswer.isNotEmpty)
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          setState(() {
                            _isSubmitting = true;
                          });
                          try {
                            final isCorrect = await _questionPoolService.solveQuestion(
                              questionId: question.id,
                              selectedAnswer: selectedAnswer,
                              solutionText: solutionText.isNotEmpty ? solutionText : null,
                              solutionFile: solutionFile,
                            );
                            
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            
                            if (isCorrect) {
                              // Doğru cevaplandı
                              _showSuccessDialog();
                              // Veriyi yeniden yükle
                              _loadData();
                            } else {
                              // Yanlış cevaplandı
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Yanlış cevap! Lütfen tekrar deneyin.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bir hata oluştu: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Çözümü Gönder'),
                ),
            ],
          );
        },
      ),
    );
  }
  
  // Başarılı çözüm diyalogu
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Tebrikler!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Soruyu doğru cevapladınız ve 10 puan kazandınız!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Çözümünüz soruyu oluşturan öğrenciye iletildi.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Harika!'),
          ),
        ],
      ),
    );
  }
} 