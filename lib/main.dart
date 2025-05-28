import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:math_app/core/constants/app_constants.dart';
import 'package:math_app/core/theme/app_theme.dart';
import 'package:math_app/routes.dart';

void main() async {
  // Flutter engine'i başlat
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase başlat
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Önline Akademi',
      theme: AppTheme.lightTheme,
      initialRoute: AppConstants.routeLogin,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
      onUnknownRoute: AppRoutes.unknownRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
