import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/exam_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ExamCreateScreen extends StatefulWidget {
  final String? examId;
  final String examType;
  
  const ExamCreateScreen({
    super.key, 
    this.examId,
    this.examType = 'normal',
  });

  @override
  State<ExamCreateScreen> createState() => _ExamCreateScreenState();
}

class _ExamCreateScreenState extends State<ExamCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final List<File?> _questionImages = [];
  final List<TextEditingController> _optionAControllers = [];
  final List<TextEditingController> _optionBControllers = [];
  final List<TextEditingController> _optionCControllers = [];
  final List<TextEditingController> _optionDControllers = [];
  final List<String> _correctAnswers = [];
  bool _isLoading = false;
  bool _isEditMode = false;
  String _errorMessage = '';
  
  // Servis
  final ExamService _examService = ExamService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    
    if (widget.examId != null) {
      _isEditMode = true;
      _loadExamData();
    } else {
      _addQuestion(); // İlk soruyu ekleyelim
    }
  }

  // Resim seçme fonksiyonu
  Future<void> _pickImage(int questionIndex) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (_questionImages.length <= questionIndex) {
            _questionImages.add(File(image.path));
          } else {
            _questionImages[questionIndex] = File(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim seçilirken hata: $e')),
      );
    }
  }

  // Sınav verilerini yükle (düzenleme modu için)
  Future<void> _loadExamData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final examData = await _examService.getExam(widget.examId!);
      
      // Form alanlarını doldur
      _titleController.text = examData['title'];
      _descriptionController.text = examData['description'];
      _dueDate = examData['dueDate'];
      
      // Soruları yükle
      final questions = examData['questions'] as List<Map<String, dynamic>>;
      
      if (questions.isNotEmpty) {
        for (var question in questions) {
          // Resim URL'sini yükle
          if (question['imageUrl'] != null) {
            // TODO: Resmi URL'den yükle
            _questionImages.add(null); // Şimdilik null olarak bırak
          } else {
            _questionImages.add(null);
          }
          
          final options = question['options'] as Map<String, dynamic>;
          _optionAControllers.add(TextEditingController(text: options['A']));
          _optionBControllers.add(TextEditingController(text: options['B']));
          _optionCControllers.add(TextEditingController(text: options['C']));
          _optionDControllers.add(TextEditingController(text: options['D']));
          
          _correctAnswers.add(question['correctAnswer']);
        }
      } else {
        // Eğer hiç soru yoksa, bir tane boş soru ekle
        _addQuestion();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sınav yüklenirken hata: $e';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _optionAControllers) {
      controller.dispose();
    }
    for (var controller in _optionBControllers) {
      controller.dispose();
    }
    for (var controller in _optionCControllers) {
      controller.dispose();
    }
    for (var controller in _optionDControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questionImages.add(null);
      _optionAControllers.add(TextEditingController());
      _optionBControllers.add(TextEditingController());
      _optionCControllers.add(TextEditingController());
      _optionDControllers.add(TextEditingController());
      _correctAnswers.add('A'); // Varsayılan doğru cevap
    });
  }

  void _removeQuestion(int index) {
    if (_questionImages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir soru olmalıdır')),
      );
      return;
    }

    setState(() {
      _optionAControllers[index].dispose();
      _optionBControllers[index].dispose();
      _optionCControllers[index].dispose();
      _optionDControllers[index].dispose();
      
      _questionImages.removeAt(index);
      _optionAControllers.removeAt(index);
      _optionBControllers.removeAt(index);
      _optionCControllers.removeAt(index);
      _optionDControllers.removeAt(index);
      _correctAnswers.removeAt(index);
    });
  }

  // Resim yükleme fonksiyonu
  Future<String?> _uploadImage(File imageFile, int questionIndex) async {
    try {
      final String fileName = 'exam_questions/${DateTime.now().millisecondsSinceEpoch}_$questionIndex.jpg';
      final Reference storageRef = _storage.ref().child(fileName);
      
      // Resmi yükle
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot taskSnapshot = await uploadTask;
      
      // Yüklenen resmin URL'sini al
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim yüklenirken hata: $e')),
      );
      return null;
    }
  }

  Future<void> _saveExam() async {
    if (widget.examType == 'deneme') {
      // Deneme sınavı için resim kontrolü
      for (var image in _questionImages) {
        if (image == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen tüm sorular için resim ekleyin')),
          );
          return;
        }
      }
    }

    setState(() {
      _errorMessage = '';
    });
    
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Soruları Firestore formatına dönüştür
        List<Map<String, dynamic>> questions = [];
        
        for (int i = 0; i < _questionImages.length; i++) {
          String? imageUrl;
          if (_questionImages[i] != null) {
            imageUrl = await _uploadImage(_questionImages[i]!, i);
            if (imageUrl == null) {
              throw Exception('Resim yüklenemedi');
            }
          }

          Map<String, dynamic> questionData = {
            'imageUrl': imageUrl,
            'options': {
              'A': _optionAControllers[i].text,
              'B': _optionBControllers[i].text,
              'C': _optionCControllers[i].text,
              'D': _optionDControllers[i].text,
            },
            'correctAnswer': _correctAnswers[i],
          };
          
          questions.add(questionData);
        }
        
        if (_isEditMode) {
          await _examService.updateExam(
            examId: widget.examId!,
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: _dueDate,
            questions: questions,
            examType: widget.examType,
          );
        } else {
          await _examService.createExam(
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: _dueDate,
            questions: questions,
            examType: widget.examType,
          );
        }
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.examType == 'deneme'
              ? 'Deneme sınavı başarıyla ${_isEditMode ? 'güncellendi' : 'oluşturuldu'}'
              : 'Sınav başarıyla ${_isEditMode ? 'güncellendi' : 'oluşturuldu'}'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examType == 'deneme' 
          ? (_isEditMode ? 'Deneme Sınavını Düzenle' : 'Deneme Sınavı Oluştur')
          : (_isEditMode ? 'Sınavı Düzenle' : 'Sınav Oluştur')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveExam,
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
                      ),
                    ),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: widget.examType == 'deneme' 
                        ? 'Deneme Sınavı Başlığı'
                        : 'Sınav Başlığı',
                      hintText: widget.examType == 'deneme'
                        ? 'Örn: 2024 TYT Deneme Sınavı'
                        : 'Örn: Limit ve Türev Sınavı',
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
                      hintText: 'Öğrencilerinize sınav ile ilgili açıklamalar',
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
                          hintText: 'Sınavın son teslim tarihi',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sorular',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._questionImages.isEmpty
                      ? [
                          const Center(
                            child: Text('Henüz soru yok'),
                          )
                        ]
                      : List.generate(_questionImages.length, (index) {
                          return _buildQuestionCard(index);
                        }),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Soru Ekle'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestionCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Soru ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Resim seçme alanı (her sınav türü için)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soru Resmi:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(index),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _questionImages[index] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _questionImages[index]!,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Resim eklemek için tıklayın'),
                                ],
                              ),
                      ),
                    ),
                    if (_questionImages[index] != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _questionImages[index] = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(index),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Resim Ekle / Değiştir'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOptionField(index, 'A', _optionAControllers[index]),
            const SizedBox(height: 8),
            _buildOptionField(index, 'B', _optionBControllers[index]),
            const SizedBox(height: 8),
            _buildOptionField(index, 'C', _optionCControllers[index]),
            const SizedBox(height: 8),
            _buildOptionField(index, 'D', _optionDControllers[index]),
            const SizedBox(height: 16),
            const Text(
              'Doğru Cevap:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildCorrectAnswerSelection(index),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionField(int questionIndex, String option, TextEditingController controller) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _correctAnswers[questionIndex] == option ? Colors.blue : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              option,
              style: TextStyle(
                color: _correctAnswers[questionIndex] == option ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '$option seçeneği',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lütfen $option seçeneğini girin';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCorrectAnswerSelection(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['A', 'B', 'C', 'D'].map((option) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _correctAnswers[index] = option;
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _correctAnswers[index] == option ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  color: _correctAnswers[index] == option ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
} 