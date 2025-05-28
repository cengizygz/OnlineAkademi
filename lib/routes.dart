import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/features/auth/screens/login_screen.dart';
import 'package:math_app/features/auth/screens/register_screen.dart';
import 'package:math_app/features/student/screens/student_profile_screen.dart' as viewonly;
import 'package:math_app/features/student/screens/ask_question_screen.dart';
import 'package:math_app/features/student/screens/exam_view_screen.dart';
import 'package:math_app/features/student/screens/homework_view_screen.dart';
import 'package:math_app/features/student/screens/question_create_screen.dart';
import 'package:math_app/features/student/screens/question_detail_screen.dart';
import 'package:math_app/features/student/screens/question_pool_screen.dart';
import 'package:math_app/features/student/screens/class_detail_screen.dart' as student;
import 'package:math_app/features/student/screens/student_home_screen.dart';
import 'package:math_app/features/profile/screens/student_profile_screen.dart' as self;
import 'package:math_app/features/common/screens/class_chat_list_screen.dart';
import 'package:math_app/features/common/screens/class_chat_screen.dart';
import 'package:math_app/features/teacher/screens/class_detail_screen.dart';
import 'package:math_app/features/teacher/screens/create_class_screen.dart';
import 'package:math_app/features/teacher/screens/exam_create_screen.dart';
import 'package:math_app/features/teacher/screens/exam_grading_screen.dart';
import 'package:math_app/features/teacher/screens/exam_submission_review_screen.dart';
import 'package:math_app/features/teacher/screens/homework_create_screen.dart';
import 'package:math_app/features/teacher/screens/homework_grading_screen.dart';
import 'package:math_app/features/teacher/screens/homework_submission_review_screen.dart';
import 'package:math_app/features/teacher/screens/question_approval_screen.dart';
import 'package:math_app/features/teacher/screens/student_exams_screen.dart';
import 'package:math_app/features/teacher/screens/student_homeworks_screen.dart';
import 'package:math_app/features/teacher/screens/student_progress_screen.dart';
import 'package:math_app/features/teacher/screens/student_questions_screen.dart';
import 'package:math_app/features/teacher/screens/teacher_home_screen.dart';
import 'package:math_app/screens/storage_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        // Auth routes
        AppConstants.routeLogin: (context) => const LoginScreen(),
        AppConstants.routeRegister: (context) => const RegisterScreen(),
        
        // Teacher routes
        AppConstants.routeTeacherHome: (context) => const TeacherHomeScreen(),
        AppConstants.routeExamCreate: (context) => const ExamCreateScreen(),
        AppConstants.routeTeacherAddClass: (context) => const CreateClassScreen(),
        AppConstants.routeQuestionApproval: (context) => const QuestionApprovalScreen(),
        
        // Student routes
        AppConstants.routeStudentHome: (context) => const StudentHomeScreen(),
        AppConstants.routeAskQuestion: (context) => const AskQuestionScreen(),
        AppConstants.routeQuestionPool: (context) => const QuestionPoolScreen(),
        AppConstants.routeQuestionCreate: (context) => const QuestionCreateScreen(),
        
        // Common routes
        AppConstants.routeProfile: (context) => const self.StudentSelfProfileScreen(),
        AppConstants.routeClassChatList: (context) => const ClassChatListScreen(),
        
        // Utility routes
        AppConstants.routeStorageTest: (context) => const StorageTestScreen(),
      };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Route arguments kullanılan sayfalar
    if (settings.name == AppConstants.routeQuestionDetail) {
      final String questionId = settings.arguments as String;
      return MaterialPageRoute(
        builder: (context) => QuestionDetailScreen(questionId: questionId),
      );
    }
    
    if (settings.name == AppConstants.routeExamGrading) {
      final String examId = settings.arguments as String;
      return MaterialPageRoute(
        builder: (context) => ExamGradingScreen(examId: examId),
      );
    }
    
    if (settings.name == AppConstants.routeExamSubmissionReview) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => ExamSubmissionReviewScreen(
          examId: args['examId'] as String,
          studentId: args['studentId'] as String,
        ),
      );
    }
    
    if (settings.name == AppConstants.routeExamView) {
      final dynamic args = settings.arguments;
      String? examId;
      
      // String olarak geçilmiş ID
      if (args is String) {
        examId = args;
      } 
      // Map olarak geçilmiş ID
      else if (args is Map<String, dynamic> && args.containsKey('id')) {
        examId = args['id']?.toString();
      }
      
      print('Route: ExamView için sınav ID: $examId');
      
      return MaterialPageRoute(
        builder: (context) => ExamViewScreen(examId: examId),
      );
    }
    
    if (settings.name == AppConstants.routeHomeworkView) {
      final dynamic args = settings.arguments;
      String? homeworkId;
      
      // String olarak geçilmiş ID
      if (args is String) {
        homeworkId = args;
      } 
      // Map olarak geçilmiş ID
      else if (args is Map<String, dynamic> && args.containsKey('id')) {
        homeworkId = args['id']?.toString();
      }
      
      print('Route: HomeworkView için ödev ID: $homeworkId');
      
      return MaterialPageRoute(
        builder: (context) => HomeworkViewScreen(homeworkId: homeworkId),
      );
    }
    
    if (settings.name == AppConstants.routeHomeworkCreate) {
      // HomeworkCreateScreen için classId parametresini destekle
      if (settings.arguments != null) {
        final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
        final String? classId = args['classId'] as String?;
        final String? homeworkId = args['homeworkId'] as String?;
        
        return MaterialPageRoute(
          builder: (context) => HomeworkCreateScreen(
            classId: classId,
            homeworkId: homeworkId,
          ),
        );
      }
      
      return MaterialPageRoute(
        builder: (context) => const HomeworkCreateScreen(),
      );
    }
    
    if (settings.name == AppConstants.routeStudentQuestions) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => StudentQuestionsScreen(
          studentId: args['studentId'] as String,
          studentName: args['studentName'] as String,
        ),
      );
    }
    
    if (settings.name == AppConstants.routeClassDetail) {
      final String classId = settings.arguments as String;
      // Öğretmen ekranını varsayılan olarak gösterelim
      // Kullanıcı rolü daha sonra ekranda kontrol edilecek
      return MaterialPageRoute(
        builder: (context) => FutureBuilder<String>(
          future: _getUserRole(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final userRole = snapshot.data ?? AppConstants.roleStudent;
            if (userRole == AppConstants.roleTeacher) {
              return ClassDetailScreen(classId: classId);
            } else {
              return student.ClassDetailScreen(classId: classId);
            }
          },
        ),
      );
    }
    
    if (settings.name == AppConstants.routeClassChat) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => ClassChatScreen(
          classId: args['classId'],
          className: args['className'],
        ),
      );
    }
    
    if (settings.name == AppConstants.routeStudentProfile) {
      final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('studentId') && args.containsKey('studentName')) {
        // Başka bir öğrencinin profili (sadece görüntüleme)
        return MaterialPageRoute(
          builder: (context) => viewonly.StudentViewProfileScreen(
            studentId: args['studentId'],
            studentName: args['studentName'],
          ),
        );
      } else {
        // Kendi profilini göster (düzenlenebilir)
        return MaterialPageRoute(
          builder: (context) => const self.StudentSelfProfileScreen(),
        );
      }
    }
    
    if (settings.name == AppConstants.routeHomeworkGrading) {
      final String homeworkId = settings.arguments as String;
      return MaterialPageRoute(
        builder: (context) => HomeworkGradingScreen(homeworkId: homeworkId),
      );
    }
    
    if (settings.name == AppConstants.routeHomeworkSubmissionReview) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => HomeworkSubmissionReviewScreen(
          homeworkId: args['homeworkId'] as String,
          studentId: args['studentId'] as String,
        ),
      );
    }
    
    if (settings.name == AppConstants.routeStudentHomeworkList) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => StudentHomeworksScreen(
          studentId: args['studentId'],
          studentName: args['studentName'],
        ),
      );
    }
    
    if (settings.name == AppConstants.routeStudentExamList) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => StudentExamsScreen(
          studentId: args['studentId'],
          studentName: args['studentName'],
        ),
      );
    }
    
    if (settings.name == AppConstants.routeStudentProgress) {
      final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => StudentProgressScreen(
          studentId: args['studentId'],
          studentName: args['studentName'],
        ),
      );
    }
    
    // Diğer ekranlar zamanla eklendiğinde burada yönlendirmeler yapılacak
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: Text('${settings.name} ekranı henüz eklenmedi'),
        ),
      ),
    );
  }
  
  static Route<dynamic> unknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sayfa Bulunamadı'),
        ),
        body: const Center(
          child: Text('Aradığınız sayfa bulunamadı'),
        ),
      ),
    );
  }

  static Future<String> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUserRole) ?? AppConstants.roleStudent;
  }
} 