import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import 'soap_note_screen.dart';
import '../models/patient_info.dart';
import 'history_taking_screen.dart';
import 'systemic_history_screen.dart';
import 'vitals_screen.dart';
import 'labs_screen.dart';


//models

// One question parsed from knowledge_base.json
// Hive: @HiveType(typeId: 6) when ready
class KBQuestion {
  final String id;
  final String phase;
  final String text;
  final List<String> options;
  final Map<String, int> weights;
  final String storesAs;
  final bool isInjected;
  // Read directly from knowledge_base.json — no more hardcoded maps
  final String phaseTitle;
  final String instruction;
  final String tip;

  const KBQuestion({
    required this.id, required this.phase, required this.text,
    required this.options, required this.weights,
    required this.storesAs, required this.isInjected,
    required this.phaseTitle, required this.instruction, required this.tip,
  });

  factory KBQuestion.fromJson(Map<String, dynamic> j) => KBQuestion(
    id:          j['id'] as String,
    phase:       j['phase'] as String,
    text:        j['text'] as String,
    options:     List<String>.from(j['options'] as List),
    weights:     Map<String, int>.from(
                   (j['weights'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
    storesAs:    j['stores_as'] as String,
    isInjected:  j['injected'] as bool? ?? false,
    phaseTitle:  j['phase_title'] as String? ?? (j['phase'] as String).replaceAll('_', ' '),
    instruction: j['instruction'] as String? ?? 'Select all findings that apply.',
    tip:         j['tip'] as String? ?? 'Tip: Document all positive and negative findings systematically.',
  );
}

class KBRule {
  final String id;
  final List<Map<String, dynamic>> conditions;
  final String match;
  final String actionType;
  final String? actionTarget;
  final String actionMessage;

  const KBRule({
    required this.id, required this.conditions, required this.match,
    required this.actionType, this.actionTarget, required this.actionMessage,
  });

  factory KBRule.fromJson(Map<String, dynamic> j) {
    final action = j['action'] as Map<String, dynamic>;
    return KBRule(
      id:            j['id'] as String,
      conditions:    List<Map<String, dynamic>>.from(j['conditions'] as List),
      match:         j['match'] as String,
      actionType:    action['type'] as String,
      actionTarget:  action['target'] as String?,
      actionMessage: action['message'] as String,
    );
  }
}

// One diagnosis definition
class KBDiagnosis {
  final String id;
  final String name;
  final int minScoreThreshold;
  final int maxScore;
  final String description;
  // key_findings: specific option strings that strongly support THIS diagnosis.
  // If present in JSON, certainty is calculated only from these specific findings.
  // Falls back to total-score method if empty (backward compatible).
  final List<String> keyFindings;

  const KBDiagnosis({
    required this.id, required this.name, required this.minScoreThreshold,
    required this.maxScore, required this.description,
    this.keyFindings = const [],
  });

  factory KBDiagnosis.fromJson(Map<String, dynamic> j) => KBDiagnosis(
    id:                j['id'] as String,
    name:              j['name'] as String,
    minScoreThreshold: (j['min_score_threshold'] as num).toInt(),
    maxScore:          (j['max_score'] as num).toInt(),
    description:       j['description'] as String,
    keyFindings:       List<String>.from(j['key_findings'] as List? ?? []),
  );
}

// Full examination for one system
class KBExamination {
  final String examinationId;
  final String examinationTitle;
  final List<KBQuestion> questions;
  final List<KBRule> rules;
  final List<KBDiagnosis> diagnoses;

  const KBExamination({
    required this.examinationId, required this.examinationTitle,
    required this.questions, required this.rules, required this.diagnoses,
  });

  factory KBExamination.fromJson(Map<String, dynamic> j) => KBExamination(
    examinationId:    j['examination_id'] as String,
    examinationTitle: j['examination_title'] as String,
    questions:        (j['questions'] as List).map((q) => KBQuestion.fromJson(q as Map<String, dynamic>)).toList(),
    rules:            (j['rules'] as List).map((r) => KBRule.fromJson(r as Map<String, dynamic>)).toList(),
    diagnoses:        (j['diagnoses'] as List).map((d) => KBDiagnosis.fromJson(d as Map<String, dynamic>)).toList(),
  );
}

// Loads and parses knowledge_base.json once
// Call await KBService.init() before runApp in main()
// Add to pubspec.yaml: flutter: assets: - assets/knowledge_base.json
class KBService {
  static final Map<String, KBExamination> _exams = {};
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/knowledge_base.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['knowledge_base']['examinations'] as List;
      for (final e in list) {
        final exam = KBExamination.fromJson(e as Map<String, dynamic>);
        _exams[exam.examinationId] = exam;
      }
    } catch (_) {
      // JSON not yet registered — screens still show, questions just empty
    }
    _loaded = true;
  }

  static KBExamination? getExam(String id) => _exams[id];
}

// Holds answers + state for one system session
// Hive: @HiveType(typeId: 7) when ready
class SystemExamSession {
  final Map<String, List<String>> answers = {};     // storesAs → selected options
  final Set<String> unlockedFollowUps = {};          // injected question ids
  final List<String> alertMessages = [];

  int computeScore(KBExamination exam) {
    int total = 0;
    for (final q in exam.questions) {
      for (final opt in answers[q.storesAs] ?? []) {
        total += q.weights[opt] ?? 0;
      }
    }
    return total;
  }

  void runRules(KBExamination exam) {
    for (final rule in exam.rules) {
      if (!_matches(rule)) continue;
      if (rule.actionType == 'inject_question' && rule.actionTarget != null) {
        unlockedFollowUps.add(rule.actionTarget!);
      } else if (rule.actionType == 'flag_alert') {
        if (!alertMessages.contains(rule.actionMessage)) alertMessages.add(rule.actionMessage);
      }
    }
  }

  bool _matches(KBRule rule) {
    final results = rule.conditions.map(_eval).toList();
    return rule.match == 'ALL' ? results.every((r) => r) : results.any((r) => r);
  }

  bool _eval(Map<String, dynamic> cond) {
    final data = answers[cond['fact'] as String] ?? [];
    final op   = cond['operator'] as String;
    final val  = cond['value'];
    switch (op) {
      case 'contains':     return data.contains(val as String);
      case 'contains_any': return (val as List).any((v) => data.contains(v as String));
      case 'contains_all': return (val as List).every((v) => data.contains(v as String));
      default:             return false;
    }
  }
  // Returns a violation message if the current working answers contain a
  // clinically impossible (contradictory) combination, or null if valid.
  // Called after every selection. If non-null → caller must rollback the selection.
  //
  // Constraints are mutually-exclusive option pairs: selecting BOTH is impossible.
  // Format: { storesAs: [ [optionA, optionB], ... ] }
  // e.g. you cannot have BOTH "Regular rhythm" AND "Irregularly irregular rhythm"
  // All keys and option strings copied verbatim from knowledge_base.json
  static const Map<String, List<List<String>>> _constraints = {

    'pulse_findings': [
      ['Rate normal (60-100 bpm)', 'Tachycardia (>100 bpm)'],
      ['Rate normal (60-100 bpm)', 'Bradycardia (<50 bpm)'],
      ['Tachycardia (>100 bpm)', 'Bradycardia (<50 bpm)'],
      ['Regular rhythm', 'Irregularly irregular rhythm (AF pattern)'],
    ],
    'auscultation_findings': [
      ['Normal S1 and S2', 'Muffled heart sounds'],
      ['Normal S1 and S2', 'S3 gallop present'],
      ['Normal S1 and S2', 'S4 gallop present'],
      ['Normal S1 and S2', 'Pericardial friction rub'],
    ],
    'precordium_palpation': [
      ['Apex beat in normal position (5th ICS, medial to MCL)', 'Apex beat displaced laterally'],
      ['Apex beat in normal position (5th ICS, medial to MCL)', 'Apex beat displaced downward'],
      ['No abnormality on palpation', 'Left ventricular heave'],
      ['No abnormality on palpation', 'Right ventricular heave'],
      ['No abnormality on palpation', 'Thrill palpable (palpable murmur)'],
    ],
    'chest_pain_character': [
      ['Relieved by rest', 'Not relieved by rest or nitrates'],
      ['Duration less than 30 minutes (Angina pattern)', 'Duration more than 30 minutes (MI pattern)'],
    ],

    // Resp
    'resp_inspection': [
      ['Respiratory rate normal (14-16/min)', 'Tachypnea (RR > 20/min)'],
      ['Respiratory rate normal (14-16/min)', 'Bradypnea (RR < 10/min)'],
      ['Tachypnea (RR > 20/min)', 'Bradypnea (RR < 10/min)'],
      ['Symmetric chest expansion', 'Asymmetric chest expansion'],
    ],
    'resp_palpation': [
      ['Trachea central', 'Trachea deviated to the RIGHT'],
      ['Trachea central', 'Trachea deviated to the LEFT'],
      ['Trachea deviated to the RIGHT', 'Trachea deviated to the LEFT'],
      ['Equal chest expansion bilaterally', 'Reduced expansion on RIGHT'],
      ['Equal chest expansion bilaterally', 'Reduced expansion on LEFT'],
      ['Vocal fremitus normal', 'Vocal fremitus increased'],
      ['Vocal fremitus normal', 'Vocal fremitus decreased / absent'],
      ['Vocal fremitus increased', 'Vocal fremitus decreased / absent'],
    ],
    'resp_percussion': [
      ['Resonant bilaterally (normal)', 'Dull on RIGHT'],
      ['Resonant bilaterally (normal)', 'Dull on LEFT'],
      ['Resonant bilaterally (normal)', 'Stony dull on RIGHT'],
      ['Resonant bilaterally (normal)', 'Stony dull on LEFT'],
      ['Resonant bilaterally (normal)', 'Hyper-resonant on RIGHT'],
      ['Resonant bilaterally (normal)', 'Hyper-resonant on LEFT'],
      ['Stony dull on RIGHT', 'Hyper-resonant on RIGHT'],
      ['Stony dull on LEFT', 'Hyper-resonant on LEFT'],
    ],
    'resp_auscultation': [
      ['Vesicular breath sounds (normal) bilaterally', 'Bronchial breathing present'],
      ['Vesicular breath sounds (normal) bilaterally', 'Reduced / absent breath sounds on RIGHT'],
      ['Vesicular breath sounds (normal) bilaterally', 'Reduced / absent breath sounds on LEFT'],
      ['Increased vocal resonance', 'Decreased vocal resonance'],
    ],

    // ABD
    'pain_character': [
      ['Relieved by food intake', 'Worsened by food intake'],
    ],
    'abd_inspection': [
      ['Flat / scaphoid (normal or malnourished)', 'Uniformly distended'],
      ['Flat / scaphoid (normal or malnourished)', 'Asymmetric distension'],
      ['Umbilicus central and inverted (normal)', 'Umbilicus everted (suggests ascites / mass)'],
    ],
    'light_palpation': [
      ['No tenderness', 'Tenderness in epigastric region'],
      ['No tenderness', 'Tenderness in right hypochondrium'],
      ['No tenderness', 'Tenderness in right iliac fossa'],
      ['No tenderness', 'Tenderness in left iliac fossa'],
      ['No tenderness', 'Generalized tenderness'],
      ['No tenderness', 'Rebound tenderness (peritoneal irritation)'],
    ],
    'deep_palpation': [
      ['Liver not palpable (normal)', 'Liver palpable (hepatomegaly)'],
      ['Spleen not palpable (normal)', 'Spleen palpable (splenomegaly — must be 2-3x normal size to feel)'],
      ['Kidneys not palpable (normal)', 'Kidney palpable (renomegaly)'],
    ],
    'abd_percussion': [
      ['Tympanic (normal gas-filled bowel)', 'Shifting dullness present (ascites)'],
      ['Tympanic (normal gas-filled bowel)', 'Fluid thrill positive (massive ascites)'],
      ['Liver dullness in right hypochondrium (normal)', 'Liver dullness area enlarged (hepatomegaly)'],
    ],

    // NEURO
    'consciousness_level': [
      ['Alert and oriented (GCS 15)', 'Confused / disoriented'],
      ['Alert and oriented (GCS 15)', 'Drowsy but rousable'],
      ['Alert and oriented (GCS 15)', 'Responds to pain only'],
      ['Alert and oriented (GCS 15)', 'Deeply unconscious (GCS 3)'],
      ['Alert and oriented (GCS 15)', 'No eye opening'],
      ['Eye opening spontaneous', 'Eye opening to voice'],
      ['Eye opening spontaneous', 'Eye opening to pain'],
      ['Eye opening spontaneous', 'No eye opening'],
      ['Eye opening to voice', 'No eye opening'],
      ['Eye opening to pain', 'No eye opening'],
    ],
    'motor_findings': [
      ['Tone normal', 'Spasticity (clasp-knife resistance — UMN pattern)'],
      ['Tone normal', 'Rigidity — lead pipe (Extrapyramidal)'],
      ['Tone normal', 'Rigidity — cog-wheel (Parkinsonian)'],
      ['Tone normal', 'Flaccidity / hypotonia (LMN pattern)'],
      ['Spasticity (clasp-knife resistance — UMN pattern)', 'Flaccidity / hypotonia (LMN pattern)'],
      ['Rigidity — lead pipe (Extrapyramidal)', 'Flaccidity / hypotonia (LMN pattern)'],
      ['Power MRC grade 5/5 (normal) all limbs', 'Hemiplegia (one side affected)'],
      ['Power MRC grade 5/5 (normal) all limbs', 'Paraplegia (both legs affected)'],
      ['Power MRC grade 5/5 (normal) all limbs', 'Monoplegia (one limb affected)'],
      ['Power MRC grade 5/5 (normal) all limbs', 'Power reduced (specify grade 0-4/5)'],
      ['Muscle bulk normal', 'Muscle wasting (atrophy) present'],
    ],
    'reflex_findings': [
      ['Reflexes normal and symmetric', 'Biceps jerk brisk / exaggerated (UMN)'],
      ['Reflexes normal and symmetric', 'Biceps jerk absent / reduced (LMN)'],
      ['Reflexes normal and symmetric', 'Knee jerk brisk / exaggerated (UMN)'],
      ['Reflexes normal and symmetric', 'Knee jerk absent / reduced (LMN)'],
      ['Reflexes normal and symmetric', 'Ankle jerk brisk / exaggerated (UMN)'],
      ['Reflexes normal and symmetric', 'Ankle jerk absent / reduced (LMN)'],
      ['Reflexes normal and symmetric', 'Clonus present'],
      ['Biceps jerk brisk / exaggerated (UMN)', 'Biceps jerk absent / reduced (LMN)'],
      ['Knee jerk brisk / exaggerated (UMN)', 'Knee jerk absent / reduced (LMN)'],
      ['Ankle jerk brisk / exaggerated (UMN)', 'Ankle jerk absent / reduced (LMN)'],
      ['Plantar response flexor (normal)', 'Plantar response extensor — Babinski Sign POSITIVE (UMN lesion)'],
    ],
    'meningeal_signs': [
      ['Neck rigidity absent (normal)', 'Neck rigidity PRESENT (resistance to passive flexion)'],
      ['Kernig\'s Sign NEGATIVE (normal)', 'Kernig\'s Sign POSITIVE (cannot extend knee with hip flexed 90°)'],
      ['Brudzinski\'s Sign NEGATIVE (normal)', 'Brudzinski\'s Sign POSITIVE (neck flexion causes hip/knee flexion)'],
    ],
    'higher_functions': [
      ['Immediate memory intact (digit span normal)', 'Immediate memory impaired'],
      ['Recent memory intact (last 24hr events recalled)', 'Recent memory impaired'],
      ['Remote memory intact', 'Remote memory impaired'],
      ['Speech fluent and coherent', 'Aphasia present (cannot understand or produce speech)'],
      ['Speech fluent and coherent', 'Dysarthria present (mechanical difficulty in speaking)'],
      ['No higher function deficits', 'Immediate memory impaired'],
      ['No higher function deficits', 'Recent memory impaired'],
      ['No higher function deficits', 'Aphasia present (cannot understand or produce speech)'],
      ['No higher function deficits', 'Dysarthria present (mechanical difficulty in speaking)'],
    ],
  };

  // Returns violation message string, or null if no contradiction found.
  // storesAs = the key that was just written to answers before calling this.
  String? checkConstraints(String storesAs) {
    final pairs = _constraints[storesAs];
    if (pairs == null) return null;
    final selected = answers[storesAs] ?? [];
    for (final pair in pairs) {
      if (selected.contains(pair[0]) && selected.contains(pair[1])) {
        return 'Contradiction: "${pair[0]}" and "${pair[1]}" cannot both be present. Please select only one.';
      }
    }
    return null;
  }

  // Removes a specific option from the answers for a given storesAs key (rollback).
  void rollback(String storesAs, String option) {
    answers[storesAs]?.remove(option);
  }

  //
  // The old engine had a fatal flaw: one shared total score meant every
  // diagnosis got 100% if you selected enough findings. This engine fixes that.
  //
  // HOW IT WORKS:
  //
  // Mode A — key_findings present in JSON (preferred):
  //   Each diagnosis declares its own list of specific option strings (key_findings).
  //   Score = sum of weights for only those specific findings the user selected.
  //   This means MI score counts MI-specific findings, AF score counts AF-specific
  //   findings — they don't bleed into each other.
  //
  // Mode B — key_findings empty (fallback, backward compatible):
  //   Uses the original total-score method. Fine for mutually exclusive findings
  //   where only one diagnosis can realistically score high.
  //
  // PENALTY SYSTEM:
  //   If the user selected findings that directly CONTRADICT this diagnosis
  //   (e.g. selected "Regular rhythm" when the diagnosis is AF which needs
  //   "Irregularly irregular rhythm"), apply a certainty penalty.
  //   This prevents a diagnosis from staying at 100% when the user
  //   explicitly selected normal/contradicting findings.
  //
  // THRESHOLD:
  //   Only show a diagnosis if its specific score >= minScoreThreshold.
  //   This prevents diagnoses with 0 key findings from appearing.
  //
  List<Map<String, dynamic>> calculateCertaintyFactors(KBExamination exam) {
    // Collect ALL selected options across all questions for this session
    final Map<String, List<String>> allAnswers = answers;

    final results = <Map<String, dynamic>>[];

    for (final dx in exam.diagnoses) {

      int dxScore;
      int dxMaxPossible;

      if (dx.keyFindings.isNotEmpty) {
        // ── MODE A: Key-findings based scoring 
        // Build a lookup of weight for each key finding from the question bank
        final Map<String, int> findingWeights = {};
        for (final q in exam.questions) {
          for (final kf in dx.keyFindings) {
            if (q.weights.containsKey(kf)) {
              findingWeights[kf] = q.weights[kf]!;
            }
          }
        }

        // Score = sum of weights for key findings the user actually selected
        dxScore = 0;
        for (final selectedList in allAnswers.values) {
          for (final selected in selectedList) {
            if (dx.keyFindings.contains(selected)) {
              dxScore += findingWeights[selected] ?? 1;
            }
          }
        }

        // Max possible = sum of all key finding weights
        dxMaxPossible = findingWeights.values.fold(0, (a, b) => a + b);
        if (dxMaxPossible == 0) dxMaxPossible = dx.keyFindings.length;

      } else {
        dxScore = computeScore(exam);
        dxMaxPossible = dx.maxScore;
      }

      // Gate: must meet minimum threshold
      if (dxScore < dx.minScoreThreshold) continue;

      // Base certainty
      final range = dxMaxPossible - dx.minScoreThreshold;
      int certainty = range <= 0
          ? 100
          : (((dxScore - dx.minScoreThreshold) / range) * 100).clamp(0, 100).round();

      // If the user selected "normal" findings that contradict this diagnosis,
      // reduce certainty. Penalty = 15 per contradicting finding, max 45.
      // This handles the case where someone checks "Regular rhythm" AND
      // "Irregularly irregular rhythm" — AF should be penalised.
      int penaltyPoints = 0;
      for (final q in exam.questions) {
        final selected = allAnswers[q.storesAs] ?? [];
        for (final s in selected) {
          final weight = q.weights[s] ?? 0;
          if (weight == 0 && dx.keyFindings.isNotEmpty) {
            // A weight-0 (normal) finding was selected — minor penalty
            // Only apply if this question contains key findings for this dx
            final hasKeyFinding = q.weights.keys.any((k) => dx.keyFindings.contains(k));
            if (hasKeyFinding) penaltyPoints += 8;
          }
        }
      }
      certainty = (certainty - penaltyPoints.clamp(0, 40)).clamp(0, 100);

      // Cap at 95% — clinical humility, no diagnosis is ever "certain"
      certainty = certainty.clamp(0, 95);

      results.add({
        'name':        dx.name,
        'description': dx.description,
        'certainty':   certainty,
        'id':          dx.id,
        'score':       dxScore,
        'mode':        dx.keyFindings.isNotEmpty ? 'key_findings' : 'total_score',
      });
    }

    // Sort by certainty descending
    results.sort((a, b) => (b['certainty'] as int).compareTo(a['certainty'] as int));
    return results;
  }
}

// Top-level container for the whole examination flow
// Hive: @HiveType(typeId: 8) when ready
class ExaminationData {
  final Map<String, SystemExamSession> sessions = {};
  final List<String> vitalsFlags;

  ExaminationData({this.vitalsFlags = const []});

  SystemExamSession sessionFor(String examId) =>
      sessions.putIfAbsent(examId, SystemExamSession.new);
}

// Display config for each system
class ExamSystemConfig {
  final String examId;
  final String title;
  final String subtitle;
  final IconData icon;

  const ExamSystemConfig({
    required this.examId, required this.title,
    required this.subtitle, required this.icon,
  });
}

const List<ExamSystemConfig> kExamConfigs = [
  ExamSystemConfig(examId: 'CVS_001',   title: 'Cardiovascular',  subtitle: 'Heart, vessels, JVP, pulses',      icon: Icons.favorite_border),
  ExamSystemConfig(examId: 'RESP_001',  title: 'Respiratory',     subtitle: 'Chest, lungs, airways',            icon: Icons.air),
  ExamSystemConfig(examId: 'ABD_001',   title: 'Abdomen',         subtitle: 'Liver, spleen, bowel, peritoneum', icon: Icons.circle_outlined),
  ExamSystemConfig(examId: 'NEURO_001', title: 'Neurological',    subtitle: 'CNS, cranial nerves, reflexes',    icon: Icons.psychology_outlined),
];


// Remove main() when integrating
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KBService.init();
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme: const ColorScheme.light(primary: AppColors.sectionHeader),
    ),
    home: const ExaminationScreen(),
  );
}


// Pass vitalsFlags from VitalsScreen: ExaminationScreen(autoFlags: flags)
class ExaminationScreen extends StatefulWidget {
  final List<String> autoFlags;
  final PatientInfo? patient;
  final HistoryFormData? history;
  final SystemicHistoryData? systemic;
  final VitalsData? vitals;
  final LabData? labs;

  const ExaminationScreen({
    super.key,
    this.autoFlags = const [],
    this.patient,
    this.history,
    this.systemic,
    this.vitals,
    this.labs,
  });

  @override
  State<ExaminationScreen> createState() => _ExaminationScreenState();
}

class _ExaminationScreenState extends State<ExaminationScreen> {
  late final ExaminationData _data;
  bool _kbLoaded = false;

  @override
  void initState() {
    super.initState();
    _data = ExaminationData(vitalsFlags: widget.autoFlags);
    KBService.init().then((_) { if (mounted) setState(() => _kbLoaded = true); });
  }

  int _completed(String examId) {
    final exam = KBService.getExam(examId);
    if (exam == null) return 0;
    final s = _data.sessionFor(examId);
    return exam.questions
        .where((q) => !q.isInjected || s.unlockedFollowUps.contains(q.id))
        .where((q) {
          final stored = s.answers[q.storesAs];
          return stored != null && stored.isNotEmpty;  
        })
        .length;
  }

  int _total(String examId) {
    final exam = KBService.getExam(examId);
    if (exam == null) return 0;
    final s = _data.sessionFor(examId);
    return exam.questions
        .where((q) => !q.isInjected || s.unlockedFollowUps.contains(q.id))
        .length;
  }

  int _flags(String examId) => _data.sessionFor(examId).alertMessages.length;
  int _score(String examId) {
    final exam = KBService.getExam(examId);
    if (exam == null) return 0;
    return _data.sessionFor(examId).computeScore(exam);
  }

  int get _totalFlags =>
      kExamConfigs.fold(0, (s, c) => s + _flags(c.examId)) + widget.autoFlags.length;

  void _onSave() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoapNoteScreen(
          patient:     widget.patient     ?? PatientInfo(),
          history:     widget.history     ?? HistoryFormData(),
          systemic:    widget.systemic    ?? SystemicHistoryData(),
          vitals:      widget.vitals      ?? VitalsData(),
          examination: _data,
          labs:        widget.labs        ?? LabData(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _AppBar(flagCount: _totalFlags),
          Expanded(
            child: !_kbLoaded
                ? const Center(child: CircularProgressIndicator(color: AppColors.sectionHeader))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Physical Examination',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                              color: AppColors.bodyText, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('Tap a system to begin step-by-step guided examination.',
                          style: TextStyle(fontSize: 13, color: AppColors.subtleGrey)),
                        const SizedBox(height: 20),

                        if (widget.autoFlags.isNotEmpty) ...[
                          _VitalsFlagsCard(flags: widget.autoFlags),
                          const SizedBox(height: 16),
                        ],

                        ...kExamConfigs.map((c) {
                          final exam = KBService.getExam(c.examId);
                          if (exam == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SystemOverviewCard(
                              config: c,
                              completed: _completed(c.examId),
                              total: _total(c.examId),
                              flagCount: _flags(c.examId),
                              score: _score(c.examId),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => GuidedExamPage(
                                    exam: exam,
                                    config: c,
                                    session: _data.sessionFor(c.examId),
                                  ),
                                ));
                                setState(() {});
                              },
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        _SaveButton(flagCount: _totalFlags, onSave: _onSave),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


// This is the main innovation: one question at a time, step-by-step,
// matching the mockup exactly: step counter, progress bar, instruction,
// numbered checkboxes, tip popup, Next Step button.
class GuidedExamPage extends StatefulWidget {
  final KBExamination exam;
  final ExamSystemConfig config;
  final SystemExamSession session;

  const GuidedExamPage({
    super.key, required this.exam, required this.config, required this.session,
  });

  @override
  State<GuidedExamPage> createState() => _GuidedExamPageState();
}

class _GuidedExamPageState extends State<GuidedExamPage> {
  int _currentIndex = 0;
  bool _showTip = false;
  String? _contradictionMessage;   // set when user tries to select a contradictory option
  final ScrollController _scrollController = ScrollController();

  KBExamination get exam => widget.exam;
  SystemExamSession get session => widget.session;

  // Visible questions: base (non-injected) + unlocked follow-ups in original order
  List<KBQuestion> get _steps {
  final result = <KBQuestion>[];
  for (final q in exam.questions) {
    if (q.isInjected) continue;          // skip injected in base pass
    result.add(q);
    // insert any unlocked follow-ups that belong after this question
    for (final fq in exam.questions) {
      if (fq.isInjected && session.unlockedFollowUps.contains(fq.id)) {
        if (!result.contains(fq)) result.add(fq);
      }
    }
  }
  return result;
}
  
  KBQuestion get _current => _steps[_currentIndex];

  List<String> get _currentSelections =>
      session.answers[_current.storesAs] ?? [];

  bool get _allSelected => _currentSelections.length == _current.options.length;

  // Next step label based on next question's phase
  String get _nextPhaseHint {
    if (_currentIndex >= _steps.length - 1) return 'View Results';
    return 'Proceed to ${_steps[_currentIndex + 1].phaseTitle}';
  }

  bool get _hasAnySelection => _currentSelections.isNotEmpty;

  void _toggleOption(String option) {
    final storesAs = _current.storesAs;
    final list = session.answers.putIfAbsent(storesAs, () => []);

    if (list.contains(option)) {
      // Deselecting — always allowed, also clears any contradiction banner for this key
      setState(() {
        _showTip = false;
        list.remove(option);
        _contradictionMessage = null;
        session.runRules(exam);
      });
    } else {
      // Selecting — add first, then check constraints
      list.add(option);
      final violation = session.checkConstraints(storesAs);
      if (violation != null) {
        // Rollback the invalid selection and show contradiction banner
        session.rollback(storesAs, option);
        setState(() => _contradictionMessage = violation);
      } else {
        setState(() {
          _showTip = false;
          _contradictionMessage = null;
          session.runRules(exam);
        });
      }
    }
  }

 void _goNext() {
  final steps = _steps;   // capture current list
  if (_currentIndex < steps.length - 1) {
    setState(() {
      _currentIndex++;
      _showTip = false;
      _contradictionMessage = null;
    });
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _showResultsSheet();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showTip = false;
        _contradictionMessage = null;
      });
    }
  }
void _showResultsSheet() {
  final score = session.computeScore(exam);
  final certaintyDiagnoses = session.calculateCertaintyFactors(exam);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _ResultsSheet(
        exam: exam,
        session: session,
        score: score,
        certaintyDiagnoses: certaintyDiagnoses,
        scrollController: scrollController,
        onDone: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final total = steps.length;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          // App bar
          _AppBar(flagCount: session.alertMessages.length, onBack: () => Navigator.pop(context)),

          // Fixed top section: title + step counter + progress bar
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                // Title
                Text(
                  'EXAMINATION GUIDANCE',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                    color: AppColors.bodyText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step ${_currentIndex + 1} of $total',
                  style: TextStyle(fontSize: 13, color: AppColors.subtleGrey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),

                // Progress bar (segmented look)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / total,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(AppColors.sectionHeader),
                    minHeight: 7,
                  ),
                ),

                // Alert banners from flag_alert rules
                if (session.alertMessages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...session.alertMessages.map((msg) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _AlertBanner(message: msg),
                  )),
                ],

                // Contradiction banner — shown when user tries to pick conflicting options
                if (_contradictionMessage != null) ...[
                  const SizedBox(height: 10),
                  _ContradictionBanner(
                    message: _contradictionMessage!,
                    onDismiss: () => setState(() => _contradictionMessage = null),
                  ),
                ],

                const SizedBox(height: 6),
                const Divider(height: 1, color: AppColors.divider),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CURRENT STEP card (teal, matching mockup)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.sectionHeader,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phase label
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CURRENT STEP',
                            style: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: AppColors.headerText, letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // System + phase title
                        Text(
                          '${widget.config.title.toUpperCase()}:',
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.headerText, letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          _current.phaseTitle,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: AppColors.headerText, height: 1.2,
                          ),
                        ),
                        // Follow-up badge
                        if (_current.isInjected) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warnBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Follow-up — triggered by previous findings',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppColors.warnText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // INSTRUCTION card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Instruction:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _current.instruction,
                                    style: const TextStyle(fontSize: 13, color: AppColors.bodyText, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Info (i) button
                            GestureDetector(
                              onTap: () => setState(() => _showTip = !_showTip),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.constitutional,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.sectionHeader.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.info_outline, color: AppColors.sectionHeader, size: 16),
                              ),
                            ),
                          ],
                        ),

                        // Tip (shown when info button tapped — matches mockup frame 4)
                        if (_showTip) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.constitutional,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.sectionHeader.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline, color: AppColors.sectionHeader, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _current.tip,
                                    style: const TextStyle(fontSize: 12, color: AppColors.bodyText, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SUB-STEPS section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sub-steps header
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.constitutional,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(13), topRight: Radius.circular(13),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sectionHeader.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text('SUB-STEPS',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                      color: AppColors.sectionHeader, letterSpacing: 1)),
                              ),
                              const SizedBox(width: 10),
                              const Text('SUB-STEPS TO PERFORM',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
                              const Spacer(),
                              Text(
                                '${_currentSelections.length}/${_current.options.length}',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _hasAnySelection ? AppColors.sectionHeader : AppColors.subtleGrey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Option rows — numbered checkboxes matching mockup
                        ..._current.options.asMap().entries.map((entry) {
                          final i      = entry.key;
                          final option = entry.value;
                          final weight = _current.weights[option] ?? 0;
                          final isSel  = _currentSelections.contains(option);
                          final isLast = i == _current.options.length - 1;

                          return _SubStepRow(
                            number: i + 1,
                            label: option,
                            weight: weight,
                            isSelected: isSel,
                            isLast: isLast,
                            onTap: () => _toggleOption(option),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Fixed bottom: Next Step button (matching mockup)
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navigation row: Back (if not first) + Next
            Row(
              children: [
                if (_currentIndex > 0) ...[
                  GestureDetector(
                    onTap: _goPrev,
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.constitutional,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.sectionHeader, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _hasAnySelection ? _goNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasAnySelection ? AppColors.sectionHeader : AppColors.divider,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: AppColors.divider,
                      ),
                      child: Text(
                        _currentIndex < _steps.length - 1 ? 'NEXT STEP' : 'VIEW RESULTS',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: _hasAnySelection ? AppColors.headerText : AppColors.subtleGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // "Proceed to..." hint text matching mockup
            Text(
              _hasAnySelection ? _nextPhaseHint : 'Select at least one finding to continue',
              style: TextStyle(
                fontSize: 11,
                color: _hasAnySelection ? AppColors.subtleGrey : AppColors.warnText,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// One numbered checkbox row in the sub-steps section
class _SubStepRow extends StatelessWidget {
  final int number;
  final String label;
  final int weight;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _SubStepRow({
    required this.number, required this.label, required this.weight,
    required this.isSelected, required this.isLast, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colour based on severity weight when selected
    Color checkBg, checkBorder, rowBg;
    if (isSelected) {
      if (weight >= 3) {
        checkBg = AppColors.emergencyRed; checkBorder = AppColors.dangerBorder;
        rowBg = AppColors.dangerBg.withOpacity(0.4);
      } else if (weight == 2) {
        checkBg = AppColors.warnText; checkBorder = AppColors.warnBorder;
        rowBg = AppColors.warnBg.withOpacity(0.4);
      } else {
        checkBg = AppColors.sectionHeader; checkBorder = AppColors.sectionHeader;
        rowBg = AppColors.constitutional.withOpacity(0.5);
      }
    } else {
      checkBg = AppColors.background; checkBorder = AppColors.divider;
      rowBg = AppColors.background;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: rowBg,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Number badge
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.sectionHeader.withOpacity(0.15) : AppColors.constitutional,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$number',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.sectionHeader : AppColors.subtleGrey,
                        )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Label
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? (weight >= 3 ? AppColors.dangerText : weight == 2 ? AppColors.warnText : AppColors.bodyText)
                            : AppColors.bodyText,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: checkBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: checkBorder, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 15)
                        : null,
                  ),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: AppColors.divider, indent: 46, endIndent: 14),
          ],
        ),
      ),
    );
  }
}


class _ResultsSheet extends StatelessWidget {
  final KBExamination exam;
  final SystemExamSession session;
  final int score;
  final ScrollController? scrollController; 
  final List<Map<String, dynamic>> certaintyDiagnoses;
  final VoidCallback onDone;
  

  const _ResultsSheet({
    required this.exam, required this.session, required this.score,
    required this.certaintyDiagnoses, required this.onDone,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final acuityLabel = score >= 21 ? 'Critical — emergency evaluation'
        : score >= 13 ? 'High acuity — expedited assessment'
        : score >= 6  ? 'Moderate acuity — prioritize workup'
        : 'Low acuity — routine evaluation';
    final acuityColor = score >= 13 ? AppColors.dangerText
        : score >= 6 ? AppColors.warnText : AppColors.normalText;
    final acuityBg = score >= 13 ? AppColors.dangerBg
        : score >= 6 ? AppColors.warnBg : AppColors.normalBg;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: SingleChildScrollView(
      controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),

            const Text('Examination Complete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.bodyText)),
            const SizedBox(height: 4),
            Text('${exam.examinationTitle} — all steps recorded',
              style: TextStyle(fontSize: 12, color: AppColors.subtleGrey)),

            const SizedBox(height: 16),

            // Score + acuity
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: acuityBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(acuityLabel,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: acuityColor)),
                        Text('Clinical acuity score: $score points',
                          style: TextStyle(fontSize: 11, color: acuityColor)),
                      ],
                    ),
                  ),
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                    child: Center(
                      child: Text('$score',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: acuityColor)),
                    ),
                  ),
                ],
              ),
            ),

            // Alerts
            if (session.alertMessages.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Critical Alerts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
              const SizedBox(height: 8),
              ...session.alertMessages.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertBanner(message: m),
              )),
            ],

            // Diagnoses — now using certainty factors from calculateCertaintyFactors()
            if (certaintyDiagnoses.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Probable Diagnoses',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
              const SizedBox(height: 8),
              ...certaintyDiagnoses.map((dx) {
                final certainty = dx['certainty'] as int;
                final confidence = certainty / 100.0;
                // Colour the bar based on certainty band
                final barColor = certainty >= 70
                    ? AppColors.sectionHeader
                    : certainty >= 40
                        ? AppColors.warnText
                        : AppColors.subtleGrey;
                final bgColor = certainty >= 70
                    ? AppColors.constitutional
                    : certainty >= 40
                        ? AppColors.warnBg
                        : const Color(0xFFF5F5F5);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: barColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(dx['name'] as String,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: barColor))),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$certainty%',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: barColor)),
                              Text(
                                certainty >= 70 ? 'Probable' : certainty >= 40 ? 'Possible' : 'Unlikely',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                    color: barColor.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: confidence,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(dx['description'] as String,
                        style: const TextStyle(fontSize: 11, color: AppColors.subtleGrey, height: 1.4)),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.normalBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.normalText, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('No significant diagnosis threshold reached with current findings.',
                      style: TextStyle(fontSize: 12, color: AppColors.normalText))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sectionHeader, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.headerText)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Shown when user tries to select two mutually exclusive findings.
// Has a dismiss (×) button. The selection is already rolled back when this shows.
class _ContradictionBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ContradictionBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dangerBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: AppColors.dangerText, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.dangerText, height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, color: AppColors.dangerText, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  const _AlertBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isHigh = message.startsWith('HIGH PRIORITY');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHigh ? AppColors.dangerBg : AppColors.warnBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHigh ? AppColors.dangerBorder : AppColors.warnBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isHigh ? Icons.crisis_alert : Icons.warning_amber_rounded,
              color: isHigh ? AppColors.dangerText : AppColors.warnText, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isHigh ? AppColors.dangerText : AppColors.warnText, height: 1.4))),
        ],
      ),
    );
  }
}

class _VitalsFlagsCard extends StatelessWidget {
  final List<String> flags;
  const _VitalsFlagsCard({required this.flags});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warnBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.monitor_heart_outlined, color: AppColors.warnText, size: 16),
            SizedBox(width: 6),
            Text('Vitals flags to consider',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warnText)),
          ]),
          const SizedBox(height: 8),
          ...flags.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.warnText)),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.warnText, height: 1.4))),
            ]),
          )),
        ],
      ),
    );
  }
}

class _SystemOverviewCard extends StatelessWidget {
  final ExamSystemConfig config;
  final int completed, total, flagCount, score;
  final VoidCallback onTap;

  const _SystemOverviewCard({
    required this.config, required this.completed, required this.total,
    required this.flagCount, required this.score, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final isDone = total > 0 && completed == total;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: flagCount > 0 ? AppColors.dangerBorder : AppColors.divider,
              width: flagCount > 0 ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: flagCount > 0 ? AppColors.dangerBg : AppColors.constitutional,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon,
                  color: flagCount > 0 ? AppColors.dangerText : AppColors.sectionHeader, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(config.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
                    const Spacer(),
                    if (flagCount > 0)
                      _SmallBadge('$flagCount alert${flagCount > 1 ? "s" : ""}', AppColors.dangerBg, AppColors.dangerText)
                    else if (isDone)
                      _SmallBadge('Done', AppColors.normalBg, AppColors.normalText)
                    else if (score > 0)
                      _SmallBadge('Score $score', AppColors.constitutional, AppColors.sectionHeader),
                  ]),
                  const SizedBox(height: 2),
                  Text(config.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.subtleGrey)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation(
                              flagCount > 0 ? AppColors.dangerText : AppColors.sectionHeader),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$completed/$total',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtleGrey)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.subtleGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _SmallBadge(String label, Color bg, Color text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
  child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text)),
);

class _AppBar extends StatelessWidget {
  final int flagCount;
  final VoidCallback? onBack;
  const _AppBar({required this.flagCount, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.headerText, size: 22),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const Icon(Icons.psychology_outlined, color: AppColors.headerText, size: 20),
            const SizedBox(width: 6),
            const Expanded(child: Text('MediScribe AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headerText))),
            if (flagCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.dangerBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.flag_outlined, color: AppColors.dangerText, size: 13),
                  const SizedBox(width: 4),
                  Text('$flagCount flag${flagCount > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dangerText)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final int flagCount;
  final VoidCallback onSave;
  const _SaveButton({required this.flagCount, required this.onSave});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sectionHeader, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Save Examination',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.headerText)),
        if (flagCount > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.emergencyRed, borderRadius: BorderRadius.circular(10)),
            child: Text('$flagCount flag${flagCount > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.headerText)),
          ),
        ],
      ]),
    ),
  );
}