// lib/models/systemic_models.dart
// Extracted from systemic_history_screen.dart
// Import this wherever you need SystemicHistoryData, CustomSystemEntry, SystemDef,
// SymptomMap, and SystemicReviewService

import 'dart:convert';
import 'package:flutter/services.dart';

// null = not answered, true = YES, false = NO
typedef SymptomMap = Map<String, bool?>;

// @HiveType(typeId: 4)
class SystemicHistoryData {
  // One map per system — key = symptom name, value = YES / NO / null
  final SymptomMap cardiovascular   = {};
  final SymptomMap respiratory      = {};
  final SymptomMap cns              = {};
  final SymptomMap gastrointestinal = {};
  final SymptomMap genitourinary    = {};
  final SymptomMap musculoskeletal  = {};
  final SymptomMap gynaecological   = {};
  final SymptomMap endocrine        = {};
  final SymptomMap constitutional   = {};

  // Custom symptoms added by the user per system
  // key = system id, value = list of custom symptom names
  final Map<String, List<String>> customSymptoms = {};

  // Custom free-text entries from the "Add it yourself" section
  final List<CustomSystemEntry> customEntries = [];

  // All symptoms answered YES across all systems
  List<String> get positiveSymptoms {
    final result = <String>[];
    for (final map in _allMaps.values) {
      map.forEach((k, v) { if (v == true) result.add(k); });
    }
    for (final entry in customEntries) {
      if (entry.answer == true) result.add('${entry.system}: ${entry.symptom}');
    }
    return result;
  }

  // All symptoms answered NO
  List<String> get negativeSymptoms {
    final result = <String>[];
    for (final map in _allMaps.values) {
      map.forEach((k, v) { if (v == false) result.add(k); });
    }
    return result;
  }

  Map<String, SymptomMap> get _allMaps => {
    'cardiovascular':   cardiovascular,
    'respiratory':      respiratory,
    'cns':              cns,
    'gastrointestinal': gastrointestinal,
    'genitourinary':    genitourinary,
    'musculoskeletal':  musculoskeletal,
    'gynaecological':   gynaecological,
    'endocrine':        endocrine,
    'constitutional':   constitutional,
  };
}

class CustomSystemEntry {
  String system;   // user-typed system name
  String symptom;  // user-typed symptom name
  bool?  answer;   // YES / NO

  CustomSystemEntry({
    this.system  = '',
    this.symptom = '',
    this.answer,
  });
}

// All body systems defined here, UI builds from this list automatically.
class SystemDef {
  final String       id;
  final String       title;
  final String       emoji;
  final List<String> symptoms;
  final bool         alwaysAsk;
  final bool         femaleOnly;

  const SystemDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.symptoms,
    this.alwaysAsk  = false,
    this.femaleOnly = false,
  });

  factory SystemDef.fromJson(Map<String, dynamic> j) => SystemDef(
    id:         j['id']          as String,
    title:      j['title']       as String,
    emoji:      j['emoji']       as String? ?? '',
    symptoms:   List<String>.from(j['symptoms'] as List? ?? []),
    femaleOnly: j['female_only'] as bool? ?? false,
    alwaysAsk:  j['always_ask']  as bool? ?? false,
  );
}

// Loads body systems from clinical_terms.json['clinical_terms']['systemic_review']
class SystemicReviewService {
  SystemicReviewService._();
  static List<SystemDef> _systems = _fallback();
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final raw  = await rootBundle.loadString('assets/clinical_terms.json');
      final data = (jsonDecode(raw) as Map<String, dynamic>)['clinical_terms'] as Map<String, dynamic>;
      final list = data['systemic_review'] as List;
      _systems   = list.map((e) => SystemDef.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // keep fallback
    }
    _loaded = true;
  }

  static List<SystemDef> get systems => _systems;

  static List<SystemDef> _fallback() => [
    const SystemDef(id: 'cardiovascular',   title: 'Cardiovascular',   emoji: '🫀', alwaysAsk: false,
      symptoms: ['Chest pain', 'Shortness of breath', 'Palpitations', 'Syncope', 'Leg swelling']),
    const SystemDef(id: 'respiratory',      title: 'Respiratory',      emoji: '🫁',
      symptoms: ['Cough', 'Sputum / hemoptysis', 'Shortness of breath', 'Wheeze', 'Pleuritic chest pain']),
    const SystemDef(id: 'cns',              title: 'CNS',              emoji: '🧠',
      symptoms: ['Headache', 'Weakness', 'Numbness / tingling', 'Seizures', 'Loss of consciousness', 'Visual or speech changes']),
    const SystemDef(id: 'gastrointestinal', title: 'Gastrointestinal', emoji: '🍽️',
      symptoms: ['Abdominal pain', 'Nausea / vomiting', 'Change in bowel habit', 'Blood in stool / black stool', 'Weight loss']),
    const SystemDef(id: 'genitourinary',    title: 'Genitourinary',    emoji: '🚽',
      symptoms: ['Dysuria', 'Frequency / nocturia', 'Hematuria', 'Incontinence']),
    const SystemDef(id: 'musculoskeletal',  title: 'Musculoskeletal',  emoji: '🦴',
      symptoms: ['Joint pain', 'Joint swelling', 'Morning stiffness', 'Back pain']),
    const SystemDef(id: 'gynaecological',   title: 'Gynaecological',   emoji: '🩸', femaleOnly: true,
      symptoms: ['Amenorrhea', 'Dysmenorrhea']),
    const SystemDef(id: 'endocrine',        title: 'Endocrine',        emoji: '🧴',
      symptoms: ['Weight change', 'Heat / cold intolerance', 'Polyuria / polydipsia']),
    const SystemDef(id: 'constitutional',   title: 'Constitutional',   emoji: '🌡️', alwaysAsk: true,
      symptoms: ['Fever', 'Weight loss', 'Night sweats', 'Loss of appetite']),
  ];
}
