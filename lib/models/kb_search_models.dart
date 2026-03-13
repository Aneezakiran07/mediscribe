// lib/models/kb_search_models.dart
// Extracted from history_taking_screen.dart
// Import this wherever you need ClinicalTermsService, KBSearchService, KBSearchResult
// Used by: history_taking_screen.dart

import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';

class ClinicalTermsService {
  ClinicalTermsService._();
  static Map<String, dynamic> _data   = {};
  static bool                 _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/clinical_terms.json');
      _data = (jsonDecode(raw) as Map<String, dynamic>)['clinical_terms'] as Map<String, dynamic>;
    } catch (_) {
      // use fallbacks
    }
    _loaded = true;
  }

  static List<String> get commonConditions    => List<String>.from(_data['common_conditions']     ?? _fallbackConditions);
  static List<String> get commonDrugs         => List<String>.from(_data['common_drugs']          ?? _fallbackDrugs);
  static List<String> get conditionChips      => List<String>.from(_data['condition_chips']       ?? _fallbackConditionChips);
  static List<String> get drugChips           => List<String>.from(_data['drug_chips']            ?? _fallbackDrugChips);
  static List<String> get familyConditionChips=> List<String>.from(_data['family_condition_chips']?? _fallbackFamilyChips);
  static List<String> get familyRelationships => List<String>.from(_data['family_relationships']  ?? _fallbackRelationships);

  // fallbacks
  static const _fallbackConditionChips = [
    'Diabetes', 'Hypertension', 'Asthma', 'Heart Disease', 'Tuberculosis', 'None',
  ];
  static const _fallbackDrugChips = [
    'Aspirin', 'Metformin', 'Atorvastatin', 'Amlodipine', 'Lisinopril', 'Omeprazole',
  ];
  static const _fallbackFamilyChips = [
    'Diabetes', 'Hypertension', 'Heart Disease', 'Cancer',
    'Tuberculosis', 'Asthma', 'Mental Illness', 'Stroke',
    'Kidney Disease', 'Liver Disease', 'Epilepsy', 'None',
  ];
  static const _fallbackRelationships = [
    'Father', 'Mother', 'Brother', 'Sister', 'Son', 'Daughter',
    'Paternal Uncle', 'Paternal Aunt', 'Maternal Uncle', 'Maternal Aunt',
    'Paternal Grandfather', 'Paternal Grandmother', 'Maternal Grandfather', 'Maternal Grandmother',
  ];
  static const _fallbackConditions = [
    'Diabetes mellitus', 'Hypertension', 'Asthma',
    'Tuberculosis', 'Chronic Kidney Disease', 'Ischemic Heart Disease',
  ];
  static const _fallbackDrugs = [
    'Aspirin', 'Metformin', 'Amlodipine', 'Lisinopril',
    'Omeprazole', 'Salbutamol', 'Prednisolone',
  ];
}
class KBSearchResult {
  final String term;
  final String source;
  const KBSearchResult({required this.term, required this.source});
}

// Searches symptoms, diagnoses, conditions, options from knowledge_base.json
// + conditions/drugs from clinical_terms.json via ClinicalTermsService.
class KBSearchService {
  KBSearchService._();
  static List<KBSearchResult> _allTerms = [];
  static bool                 _loaded   = false;

  static Future<void> init() async {
    if (_loaded) return;
    // ClinicalTermsService must be initialised first
    await ClinicalTermsService.init();
    try {
      final raw  = await rootBundle.loadString('assets/knowledge_base.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _allTerms  = _parseFromJson(json);
    } catch (_) {
      _allTerms = _builtInConditionsAndDrugs();
    }
    _loaded = true;
  }

  static List<KBSearchResult> _parseFromJson(Map<String, dynamic> json) {
    final results     = <KBSearchResult>[];
    final examinations = json['knowledge_base']['examinations'] as List;

    const prefixMap = {
      'CVS_001':   'CVS',
      'RESP_001':  'RESP',
      'ABD_001':   'ABD',
      'NEURO_001': 'NEURO',
    };

    String phaseLabel(String phase) {
      const map = {
        'history': 'Symptoms',              'general_examination': 'GPE',
        'pulse_examination': 'Pulse',       'precordium_inspection': 'Inspection',
        'precordium_palpation': 'Palpation','auscultation': 'Auscultation',
        'auscultation_detail': 'Auscultation','tamponade_assessment': 'Assessment',
        'pnd_assessment': 'Assessment',     'inspection': 'Inspection',
        'palpation': 'Palpation',           'palpation_light': 'Palpation',
        'palpation_deep': 'Palpation',      'percussion': 'Percussion',
        'consolidation_assessment': 'Assessment','effusion_assessment': 'Assessment',
        'pneumothorax_assessment': 'Assessment','stridor_assessment': 'Assessment',
        'ascites_assessment': 'Assessment', 'peritonitis_assessment': 'Assessment',
        'upper_gi_bleed': 'Assessment',     'consciousness': 'Consciousness',
        'higher_functions': 'Higher Functions','cranial_nerves': 'Cranial Nerves',
        'motor_system': 'Motor',            'reflexes': 'Reflexes',
        'sensory_system': 'Sensory',        'coordination': 'Coordination',
        'meningeal_signs': 'Meningeal',     'UMN_localization': 'Localisation',
        'LMN_localization': 'Localisation', 'meningitis_confirmation': 'Assessment',
      };
      return map[phase] ?? phase.replaceAll('_', ' ');
    }

    for (final exam in examinations) {
      final examId    = exam['examination_id'] as String;
      final prefix    = prefixMap[examId] ?? examId;
      final questions = exam['questions']  as List;
      final diagnoses = exam['diagnoses']  as List;

      for (final q in questions) {
        final phase   = q['phase']   as String;
        final options = q['options'] as List;
        final source  = '$prefix · ${phaseLabel(phase)}';
        for (final opt in options) {
          final term = opt as String;
          if (term.toLowerCase().startsWith('no ')    ||
              term.toLowerCase().startsWith('normal') ||
              term.toLowerCase().startsWith('absent (')||
              term.toLowerCase() == 'none') continue;
          results.add(KBSearchResult(term: term, source: source));
        }
      }
      for (final dx in diagnoses) {
        results.add(KBSearchResult(term: dx['name'] as String, source: '$prefix · Diagnosis'));
      }
    }
    results.addAll(_builtInConditionsAndDrugs());
    return results;
  }

  static List<KBSearchResult> _builtInConditionsAndDrugs() => [
    ...ClinicalTermsService.commonConditions.map((c) => KBSearchResult(term: c, source: 'Conditions')),
    ...ClinicalTermsService.commonDrugs     .map((d) => KBSearchResult(term: d, source: 'Drugs')),
  ];

  static List<KBSearchResult> search(
    String query, {
    String? filter,
    List<String> alreadySelected = const [],
  }) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _allTerms.where((r) {
      final matchesQuery  = r.term.toLowerCase().contains(q);
      final matchesFilter = filter == null || r.source.contains(filter);
      final notSelected   = !alreadySelected.contains(r.term);
      return matchesQuery && matchesFilter && notSelected;
    }).take(8).toList();
  }
}
