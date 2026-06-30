
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/upload_page.dart';
import 'screens/report_page.dart';
import 'screens/consultation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'package:heartmrianalyzer/screens/forgot_password_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting(); // Add this line

  try {
    runApp(
      EasyLocalization(
        supportedLocales: [
          Locale('en', 'US'),
          Locale('fr', 'FR'),
          Locale('ar', 'TN'),
        ],
        path: 'assets/translations',
        fallbackLocale: Locale('en', 'US'),
        child: MyApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heart MRI Analyzer',
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/upload': (context) => UploadPage(),
        '/consultation': (context) => ConsultationScreen(),
        '/history': (context) => HistoryScreen(patientId: '',

        ),
        '/profile': (context) => ProfileScreen(),
        '/report': (context) {
          final result = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ReportPage(result: result, userId: 'userId1', imageFile: null,);
        },

        '/register': (context) => RegisterPage(),
        '/forgot-password': (context) => ForgotPasswordPage(),
      },
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}