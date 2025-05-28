class AppConstants {
  // Routes
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeTeacherHome = '/teacher/home';
  static const String routeStudentHome = '/student/home';
  static const String routeProfile = '/profile';
  static const String routeExamCreate = '/teacher/exam/create';
  static const String routeExamView = '/student/exam/view';
  static const String routeHomeworkCreate = '/teacher/homework/create';
  static const String routeHomeworkView = '/student/homework/view';
  static const String routeAskQuestion = '/student/question/ask';
  static const String routeQuestionDetail = '/student/question/detail';
  static const String routeStudentQuestions = '/teacher/student/questions';
  static const String routeCalendar = '/calendar';
  
  // New class-related routes
  static const String routeTeacherClasses = '/teacher/classes';
  static const String routeClassDetail = '/teacher/classes/detail';
  static const String routeClassChat = '/class/chat';
  static const String routeClassChatList = '/class/chat/list';
  static const String routeStudentProfile = '/student/profile';
  static const String routeTeacherAddClass = '/teacher/classes/add';
  
  // Teacher Routes
  static const String routeExamGrading = '/teacher/exam-grading';
  static const String routeExamSubmissionReview = '/teacher/exam-submission-review';
  static const String routeHomeworkGrading = '/teacher/homework-grading';
  static const String routeHomeworkSubmissionReview = '/teacher/homework-submission-review';
  static const String routeQuestionApproval = '/teacher/question-approval';
  
  // Öğrenci ilerleme takibi için yeni rotalar
  static const String routeStudentHomeworkList = '/teacher/student/homeworks';
  static const String routeStudentExamList = '/teacher/student/exams';
  static const String routeStudentProgress = '/teacher/student/progress';
  
  // Soru havuzu için rotalar
  static const String routeQuestionPool = '/student/question-pool';
  static const String routeQuestionCreate = '/student/question-create';
  static const String routeQuestionSolve = '/question/solve';
  
  // Roles
  static const String roleTeacher = 'teacher';
  static const String roleStudent = 'student';
  
  // Storage keys
  static const String keyUserRole = 'user_role';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';

  // Special routes
  static const String routeNotFound = '/not-found';
  static const String routeNoConnection = '/no-connection';
  static const String routeLoading = '/loading';
  static const String routeStorageTest = '/storage-test';
} 