import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = AppConstants.roleStudent;
  bool _isLoading = false;
  String _errorMessage = '';
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = '';
    });
    
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        print('Kayıt işlemi başlatılıyor...');
        // Firebase ile kayıt ol
        final UserCredential userCredential = await _authService.registerWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: "${_nameController.text.trim()} ${_surnameController.text.trim()}",
          role: _selectedRole,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        );
        
        if (!mounted) return;
        
        print('Kayıt başarılı, kullanıcı: ${userCredential.user?.uid}');
        
        // Kullanıcı başarıyla oluşturuldu mu kontrol et
        if (userCredential.user != null) {
          // Başarılı kayıt mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Giriş yapabilirsiniz.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Önce mevcut ekranı kapat ve giriş ekranına yönlendir
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppConstants.routeLogin, // Giriş ekranı route'u
            (route) => false, // Tüm önceki ekranları temizle
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kayıt oluşturuldu fakat oturum açılamadı. Lütfen giriş sayfasına gidin.';
          });
        }
      } on FirebaseAuthException catch (e) {
        print('Firebase Auth hatası: ${e.code} - ${e.message}');
        setState(() {
          _isLoading = false;
          // Hata mesajlarını Türkçeleştir
          switch (e.code) {
            case 'email-already-in-use':
              _errorMessage = 'Bu e-posta adresi zaten kullanımda';
              break;
            case 'invalid-email':
              _errorMessage = 'Geçersiz e-posta adresi';
              break;
            case 'operation-not-allowed':
              _errorMessage = 'E-posta/şifre hesapları etkin değil';
              break;
            case 'weak-password':
              _errorMessage = 'Şifre çok zayıf';
              break;
            case 'network-request-failed':
              _errorMessage = 'İnternet bağlantınızı kontrol edin';
              break;
            default:
              _errorMessage = 'Kayıt olurken bir hata oluştu: ${e.message}';
          }
        });
      } catch (e) {
        print('Beklenmeyen hata: $e');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bir hata oluştu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Yeni Bir Hesap Oluştur',
                            style: GoogleFonts.notoSerif(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Ad
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: TextFormField(
                                      controller: _nameController,
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ad',
                                        hintStyle: GoogleFonts.notoSerif(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ad alanı zorunludur';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Soyad
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: TextFormField(
                                      controller: _surnameController,
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Soyad',
                                        hintStyle: GoogleFonts.notoSerif(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Soyad alanı zorunludur';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // E-posta
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'E-posta',
                                        hintStyle: GoogleFonts.notoSerif(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        prefixIcon: const Icon(
                                          Icons.mail_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Lütfen e-posta adresinizi girin';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Geçerli bir e-posta adresi girin';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Telefon
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Telefon (İsteğe bağlı)',
                                        hintStyle: GoogleFonts.notoSerif(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                      ),
                                      validator: null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Şifre
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Şifre',
                                        hintStyle: GoogleFonts.notoSerif(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Lütfen şifrenizi girin';
                                        }
                                        if (value.length < 6) {
                                          return 'Şifre en az 6 karakter olmalıdır';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Rol Seçimi
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Text(
                                          'Hesap Türü',
                                          style: GoogleFonts.notoSerif(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: RadioListTile<String>(
                                              title: Text(
                                                'Öğrenci',
                                                style: GoogleFonts.notoSerif(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              value: AppConstants.roleStudent,
                                              groupValue: _selectedRole,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedRole = value!;
                                                });
                                              },
                                              activeColor: Colors.blue.shade300,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          Expanded(
                                            child: RadioListTile<String>(
                                              title: Text(
                                                'Öğretmen',
                                                style: GoogleFonts.notoSerif(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              value: AppConstants.roleTeacher,
                                              groupValue: _selectedRole,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedRole = value!;
                                                });
                                              },
                                              activeColor: Colors.blue.shade300,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Kayıt ol butonu
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: Colors.black),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          )
                                        : Text(
                                            'KAYIT OL',
                                            style: GoogleFonts.notoSerif(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Hesabınız var mı
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Zaten bir hesabım var',
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.black,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                      child: Text(
                                        'Giriş yap',
                                        style: GoogleFonts.notoSerif(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 