import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

// Models
import 'models/patient_session.dart';

// Services — must all be initialised before runApp()
import 'models/kb_search_models.dart';   // ClinicalTermsService, KBSearchService
import 'models/systemic_models.dart';    // SystemicReviewService
import 'models/examination_models.dart'; // KBService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — clinical tool, no landscape needed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Hive ────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(PatientSessionAdapter()); // typeId: 0
  await Hive.openBox<PatientSession>('sessions');
  // ────────────────────────────────────────────────────────────────────────

  // Load all JSON knowledge assets + settings in parallel
  await Future.wait([
    SettingsService.instance.init(),
    ClinicalTermsService.init(),
    SystemicReviewService.init(),
    KBSearchService.init(),
    KBService.init(),
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
          primary:   Color(0xFF035955),
          secondary: Color(0xFF89B0AE),
          surface:   Color(0xFFFFFFFF),
          error:     Color(0xFFD32F2F),
        ),
        splashColor:    const Color(0x1A035955),
        highlightColor: const Color(0x0D035955),
      ),
      home: const HomeScreen(),
    );
  }
}