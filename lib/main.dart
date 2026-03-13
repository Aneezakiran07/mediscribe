import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

// Services — must all be initialised before runApp()
import 'models/kb_search_models.dart';   // ClinicalTermsService, KBSearchService
import 'models/systemic_models.dart';    // SystemicReviewService
import 'models/examination_models.dart'; // KBService

// import 'package:hive_flutter/hive_flutter.dart';
// import 'models/patient_info.dart';
// import 'models/history_models.dart';
// import 'models/vitals_models.dart';
// import 'models/lab_models.dart';
// import 'models/soap_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — clinical tool, no landscape needed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // await Hive.initFlutter();
  // Hive.registerAdapter(PatientInfoAdapter());          // typeId: 0
  // Hive.registerAdapter(ComplaintDetailAdapter());      // typeId: 1
  // Hive.registerAdapter(FamilyMemberAdapter());         // typeId: 2
  // Hive.registerAdapter(HistoryFormDataAdapter());      // typeId: 3
  // Hive.registerAdapter(SystemicHistoryDataAdapter());  // typeId: 4
  // Hive.registerAdapter(VitalsDataAdapter());           // typeId: 5
  // Hive.registerAdapter(CustomVitalAdapter());          // typeId: 6
  // Hive.registerAdapter(LabDataAdapter());              // typeId: 7
  // Hive.registerAdapter(SystemExamSessionAdapter());    // typeId: 8
  // Hive.registerAdapter(ExaminationDataAdapter());      // typeId: 9
  // Hive.registerAdapter(SoapNoteAdapter());             // typeId: 10
  // await Future.wait([
  //   Hive.openBox<PatientInfo>('patients'),
  //   Hive.openBox<SoapNote>('soap_notes'),
  // ]);

  // Load all JSON knowledge assets in parallel.
  // KBSearchService.init() already calls ClinicalTermsService.init() internally,
  // but we call both explicitly so SystemicReviewService also gets the JSON
  // data without being blocked by KBSearchService's internal chain.
  await Future.wait([
    SettingsService.instance.init(),
    ClinicalTermsService.init(),    // assets/clinical_terms.json
    SystemicReviewService.init(),   // assets/clinical_terms.json → systemic_review key
    KBSearchService.init(),         // assets/knowledge_base.json + clinical_terms.json
    KBService.init(),               // assets/knowledge_base.json → examination engine
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
        scaffoldBackgroundColor: const Color(0xFFF0F4F4), // AppColors.pageBackground
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFF035955), // AppColors.sectionHeader
          secondary: Color(0xFF89B0AE), // AppColors.teal
          surface:   Color(0xFFFFFFFF), // AppColors.background
          error:     Color(0xFFD32F2F), // AppColors.emergencyRed
        ),
        splashColor:    const Color(0x1A035955),
        highlightColor: const Color(0x0D035955),
      ),
      home: const HomeScreen(),
    );
  }
}