import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    try {
      final credentials = await _authService.getLastLoginCredentials();
      if (credentials['email'] != null && credentials['password'] != null) {
        _emailController.text = credentials['email']!;
        _passwordController.text = credentials['password']!;
        // Otomatik giriş yap
        _login();
      }
    } catch (e) {
      print('Kayıtlı giriş bilgileri kontrol edilirken hata: $e');
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final UserCredential userCredential = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        if (userCredential.user != null) {
          // Kullanıcı rolüne göre yönlendirme
          final role = await _authService.getUserRole();
          if (role == AppConstants.roleTeacher) {
            Navigator.of(context).pushReplacementNamed(AppConstants.routeTeacherHome);
          } else {
            Navigator.of(context).pushReplacementNamed(AppConstants.routeStudentHome);
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          switch (e.code) {
            case 'user-not-found':
              _errorMessage = 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
              break;
            case 'wrong-password':
              _errorMessage = 'Hatalı şifre';
              break;
            case 'invalid-email':
              _errorMessage = 'Geçersiz e-posta adresi';
              break;
            case 'user-disabled':
              _errorMessage = 'Bu hesap devre dışı bırakılmış';
              break;
            case 'too-many-requests':
              _errorMessage = 'Çok fazla başarısız giriş denemesi. Lütfen daha sonra tekrar deneyin';
              break;
            default:
              _errorMessage = 'Giriş yapılırken bir hata oluştu: ${e.message}';
          }
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Beklenmeyen bir hata oluştu: $e';
        });
      }
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Şifre sıfırlama için lütfen e-posta adresinizi girin';
      });
      return;
    }
    
    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Şifre sıfırlama e-postası gönderilemedi: $e';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                // Logo - Card dışında
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
                            'Online Akademi Eğitim Paneline',
                            style: GoogleFonts.notoSerif(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Hoşgeldiniz',
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
                                          color: Colors.white54,
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
                                          color: Colors.white70,
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
                                          color: Colors.white54,
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
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            color: Colors.white70,
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
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    child: Text(
                                      'Şifremi Unuttum',
                                      style: GoogleFonts.notoSerif(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Giriş butonu
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
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
                                            'GİRİŞ YAP',
                                            style: GoogleFonts.notoSerif(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Hesabınız yok mu
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Hesabınız yok mu?',
                                      style: GoogleFonts.notoSerif(
                                        color: Colors.black,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(AppConstants.routeRegister);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                      child: Text(
                                        'Kayıt olun',
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