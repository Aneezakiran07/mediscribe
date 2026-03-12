// lib/models/examination_models.dart
// Extracted from examination_screen.dart
// Import this wherever you need ExaminationData, SystemExamSession, KBExamination etc.
// The KB classes (KBQuestion, KBRule, KBDiagnosis, KBExamination, KBService)
// and ExamSystemConfig / kExamConfigs are also here since they are pure data/logic.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── KNOWLEDGE BASE MODELS ─────────────────────────────────────────────────────

// @HiveType(typeId: 8)
class KBQuestion {
  final String       id;
  final String       phase;
  final String       text;
  final List<String> options;
  final Map<String, int> weights;
  final String       storesAs;
  final bool         isInjected;
  final String       phaseTitle;
  final String       instruction;
  final String       tip;

  const KBQuestion({
    required this.id, required this.phase, required this.text,
    required this.options, required this.weights,
    required this.storesAs, required this.isInjected,
    required this.phaseTitle, required this.instruction, required this.tip,
  });

  factory KBQuestion.fromJson(Map<String, dynamic> j) => KBQuestion(
    id:          j['id']          as String,
    phase:       j['phase']       as String,
    text:        j['text']        as String,
    options:     List<String>.from(j['options'] as List),
    weights:     Map<String, int>.from(
                   (j['weights'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
    storesAs:    j['stores_as']   as String,
    isInjected:  j['injected']    as bool? ?? false,
    phaseTitle:  j['phase_title'] as String? ?? (j['phase'] as String).replaceAll('_', ' '),
    instruction: j['instruction'] as String? ?? 'Select all findings that apply.',
    tip:         j['tip']         as String? ?? 'Tip: Document all positive and negative findings systematically.',
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
      id:            j['id']      as String,
      conditions:    List<Map<String, dynamic>>.from(j['conditions'] as List),
      match:         j['match']   as String,
      actionType:    action['type']    as String,
      actionTarget:  action['target']  as String?,
      actionMessage: action['message'] as String,
    );
  }
}

class KBDiagnosis {
  final String       id;
  final String       name;
  final int          minScoreThreshold;
  final int          maxScore;
  final String       description;
  final List<String> keyFindings;

  const KBDiagnosis({
    required this.id, required this.name,
    required this.minScoreThreshold, required this.maxScore,
    required this.description, this.keyFindings = const [],
  });

  factory KBDiagnosis.fromJson(Map<String, dynamic> j) => KBDiagnosis(
    id:                j['id']                   as String,
    name:              j['name']                 as String,
    minScoreThreshold: (j['min_score_threshold'] as num).toInt(),
    maxScore:          (j['max_score']           as num).toInt(),
    description:       j['description']          as String,
    keyFindings:       List<String>.from(j['key_findings'] as List? ?? []),
  );
}

class KBExamination {
  final String             examinationId;
  final String             examinationTitle;
  final List<KBQuestion>   questions;
  final List<KBRule>       rules;
  final List<KBDiagnosis>  diagnoses;

  const KBExamination({
    required this.examinationId, required this.examinationTitle,
    required this.questions, required this.rules, required this.diagnoses,
  });

  factory KBExamination.fromJson(Map<String, dynamic> j) => KBExamination(
    examinationId:    j['examination_id']    as String,
    examinationTitle: j['examination_title'] as String,
    questions:  (j['questions'] as List).map((q) => KBQuestion.fromJson(q  as Map<String, dynamic>)).toList(),
    rules:      (j['rules']     as List).map((r) => KBRule.fromJson(r      as Map<String, dynamic>)).toList(),
    diagnoses:  (j['diagnoses'] as List).map((d) => KBDiagnosis.fromJson(d as Map<String, dynamic>)).toList(),
  );
}

// ── KB SERVICE ────────────────────────────────────────────────────────────────
// Call await KBService.init() in main() before runApp()
// Requires: flutter: assets: - assets/knowledge_base.json
class KBService {
  static final Map<String, KBExamination> _exams = {};
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final raw  = await rootBundle.loadString('assets/knowledge_base.json');
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

// ── SYSTEM EXAM SESSION ───────────────────────────────────────────────────────
// @HiveType(typeId: 9)
class SystemExamSession {
  final Map<String, List<String>> answers          = {}; // storesAs → selected options
  final Set<String>               unlockedFollowUps = {};
  final List<String>              alertMessages     = [];

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

  // Mutually-exclusive option pairs per storesAs key.
  // Selecting BOTH options in any pair is clinically impossible.
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
    'consciousness_level': [
      ['Alert and oriented (GCS 15)', 'Confused / disoriented'],
      ['Alert and oriented (GCS 15)', 'Drowsy but rousable'],
      ['Alert and oriented (GCS 15)', 'Responds to pain only'],
      ['Alert and oriented (GCS 15)', 'Deeply unconscious (GCS 3)'],
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
      ["Kernig's Sign NEGATIVE (normal)", "Kernig's Sign POSITIVE (cannot extend knee with hip flexed 90°)"],
      ["Brudzinski's Sign NEGATIVE (normal)", "Brudzinski's Sign POSITIVE (neck flexion causes hip/knee flexion)"],
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

  String? checkConstraints(String storesAs) {
    final pairs    = _constraints[storesAs];
    if (pairs == null) return null;
    final selected = answers[storesAs] ?? [];
    for (final pair in pairs) {
      if (selected.contains(pair[0]) && selected.contains(pair[1])) {
        return 'Contradiction: "${pair[0]}" and "${pair[1]}" cannot both be present. Please select only one.';
      }
    }
    return null;
  }

  void rollback(String storesAs, String option) {
    answers[storesAs]?.remove(option);
  }

  // Diagnosis certainty engine — see examination_screen.dart for detailed comments
  List<Map<String, dynamic>> calculateCertaintyFactors(KBExamination exam) {
    final allAnswers = answers;
    final results    = <Map<String, dynamic>>[];

    for (final dx in exam.diagnoses) {
      int dxScore;
      int dxMaxPossible;

      if (dx.keyFindings.isNotEmpty) {
        final Map<String, int> findingWeights = {};
        for (final q in exam.questions) {
          for (final kf in dx.keyFindings) {
            if (q.weights.containsKey(kf)) findingWeights[kf] = q.weights[kf]!;
          }
        }
        dxScore = 0;
        for (final selectedList in allAnswers.values) {
          for (final selected in selectedList) {
            if (dx.keyFindings.contains(selected)) dxScore += findingWeights[selected] ?? 1;
          }
        }
        dxMaxPossible = findingWeights.values.fold(0, (a, b) => a + b);
        if (dxMaxPossible == 0) dxMaxPossible = dx.keyFindings.length;
      } else {
        dxScore       = computeScore(exam);
        dxMaxPossible = dx.maxScore;
      }

      if (dxScore < dx.minScoreThreshold) continue;

      final range = dxMaxPossible - dx.minScoreThreshold;
      int certainty = range <= 0
          ? 100
          : (((dxScore - dx.minScoreThreshold) / range) * 100).clamp(0, 100).round();

      int penaltyPoints = 0;
      for (final q in exam.questions) {
        final selected = allAnswers[q.storesAs] ?? [];
        for (final s in selected) {
          final weight = q.weights[s] ?? 0;
          if (weight == 0 && dx.keyFindings.isNotEmpty) {
            final hasKeyFinding = q.weights.keys.any((k) => dx.keyFindings.contains(k));
            if (hasKeyFinding) penaltyPoints += 8;
          }
        }
      }
      certainty = (certainty - penaltyPoints.clamp(0, 40)).clamp(0, 95);

      results.add({
        'name':        dx.name,
        'description': dx.description,
        'certainty':   certainty,
        'id':          dx.id,
        'score':       dxScore,
        'mode':        dx.keyFindings.isNotEmpty ? 'key_findings' : 'total_score',
      });
    }

    results.sort((a, b) => (b['certainty'] as int).compareTo(a['certainty'] as int));
    return results;
  }
}

// ── EXAMINATION DATA ──────────────────────────────────────────────────────────
// @HiveType(typeId: 10)
class ExaminationData {
  final Map<String, SystemExamSession> sessions = {};
  final List<String> vitalsFlags;

  ExaminationData({this.vitalsFlags = const []});

  SystemExamSession sessionFor(String examId) =>
      sessions.putIfAbsent(examId, SystemExamSession.new);
}

// ── EXAM SYSTEM CONFIG ────────────────────────────────────────────────────────
class ExamSystemConfig {
  final String   examId;
  final String   title;
  final String   subtitle;
  final IconData icon;

  const ExamSystemConfig({
    required this.examId, required this.title,
    required this.subtitle, required this.icon,
  });
}

const List<ExamSystemConfig> kExamConfigs = [
  ExamSystemConfig(examId: 'CVS_001',   title: 'Cardiovascular', subtitle: 'Heart, vessels, JVP, pulses',      icon: Icons.favorite_border),
  ExamSystemConfig(examId: 'RESP_001',  title: 'Respiratory',    subtitle: 'Chest, lungs, airways',            icon: Icons.air),
  ExamSystemConfig(examId: 'ABD_001',   title: 'Abdomen',        subtitle: 'Liver, spleen, bowel, peritoneum', icon: Icons.circle_outlined),
  ExamSystemConfig(examId: 'NEURO_001', title: 'Neurological',   subtitle: 'CNS, cranial nerves, reflexes',    icon: Icons.psychology_outlined),
];
