import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/history_taking_screen.dart';
import 'screens/systemic_history_screen.dart';
import 'screens/examination_screen.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Load all JSON assets in parallel before showing UI
  await Future.wait([
    ClinicalTermsService.init(),   // assets/clinical_terms.json
    SystemicReviewService.init(),  // assets/clinical_terms.json (systemic_review array)
    KBSearchService.init(),        // assets/knowledge_base.json  (also calls ClinicalTermsService internally)
    KBService.init(),              // assets/knowledge_base.json  (examination engine)
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