import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';

import '../models/systemic_models.dart';
import '../models/examination_models.dart';
import '../models/kb_search_models.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Future.wait([
    ClinicalTermsService.init(),    // history_taking_screen.dart
    KBSearchService.init(),         // history_taking_screen.dart
    SystemicReviewService.init(),   // systemic_history_screen.dart
    KBService.init(),               // examination_screen.dart
  ]);

  runApp(const MediScribeApp());
}

class MediScribeApp extends StatelessWidget {
  const MediScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediScribe AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F4F4),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF035955),
          surface: Color(0xFFFFFFFF),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}