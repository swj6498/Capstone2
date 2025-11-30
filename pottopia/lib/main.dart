import 'package:flutter/material.dart';
import 'screen/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screen/Login.dart';
import 'package:ai_profanity_textfield/ai_profanity_textfield.dart';



final geminiService = GeminiService(apiKey: 'AIzaSyCokGLMmaBr_y3EEtrfiX430vxVY-XFoZk');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase 초기화
  await initializeDateFormatting('ko');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '팟topia',
      theme: ThemeData(
        
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
