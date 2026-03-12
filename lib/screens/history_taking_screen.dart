import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient_info.dart';
import '../core/app_colors.dart';
import 'systemic_history_screen.dart';

class ClinicalTermsService {
  ClinicalTermsService._();
  static Map<String, dynamic> _data = {};
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/clinical_terms.json');
      _data = (jsonDecode(raw) as Map<String, dynamic>)['clinical_terms'] as Map<String, dynamic>;
      _loaded = true;
    } catch (_) {
      _loaded = true; // use fallbacks
    }
  }

  static List<String> get commonConditions =>
      List<String>.from(_data['common_conditions'] ?? _fallbackConditions);

  static List<String> get commonDrugs =>
      List<String>.from(_data['common_drugs'] ?? _fallbackDrugs);

  static List<String> get conditionChips =>
      List<String>.from(_data['condition_chips'] ?? _fallbackConditionChips);

  static List<String> get drugChips =>
      List<String>.from(_data['drug_chips'] ?? _fallbackDrugChips);

  static List<String> get familyConditionChips =>
      List<String>.from(_data['family_condition_chips'] ?? _fallbackFamilyChips);

  static List<String> get familyRelationships =>
      List<String>.from(_data['family_relationships'] ?? _fallbackRelationships);
//fallbacks
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

// ═══════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE BASE SEARCH ENGINE
// Searches symptoms, diagnoses, conditions, options from knowledge_base.json
// + conditions/drugs from clinical_terms.json via ClinicalTermsService.
// ═══════════════════════════════════════════════════════════════════════════════
class KBSearchResult {
  final String term;
  final String source;
  const KBSearchResult({required this.term, required this.source});
}

class KBSearchService {
  KBSearchService._();
  static List<KBSearchResult> _allTerms = [];
  static bool _loaded = false;

  static Future<void> init() async {
    if (_loaded) return;
    // Init ClinicalTermsService first so conditions/drugs come from JSON
    await ClinicalTermsService.init();
    try {
      final raw = await rootBundle.loadString('assets/knowledge_base.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _allTerms = _parseFromJson(json);
      _loaded = true;
    } catch (_) {
      _allTerms = _builtInConditionsAndDrugs();
      _loaded = true;
    }
  }

  static List<KBSearchResult> _parseFromJson(Map<String, dynamic> json) {
    final List<KBSearchResult> results = [];
    final examinations = json['knowledge_base']['examinations'] as List;

    const prefixMap = {
      'CVS_001':   'CVS',
      'RESP_001':  'RESP',
      'ABD_001':   'ABD',
      'NEURO_001': 'NEURO',
    };

    String phaseLabel(String phase) {
      const map = {
        'history': 'Symptoms', 'general_examination': 'GPE',
        'pulse_examination': 'Pulse', 'precordium_inspection': 'Inspection',
        'precordium_palpation': 'Palpation', 'auscultation': 'Auscultation',
        'auscultation_detail': 'Auscultation', 'tamponade_assessment': 'Assessment',
        'pnd_assessment': 'Assessment', 'inspection': 'Inspection',
        'palpation': 'Palpation', 'palpation_light': 'Palpation',
        'palpation_deep': 'Palpation', 'percussion': 'Percussion',
        'consolidation_assessment': 'Assessment', 'effusion_assessment': 'Assessment',
        'pneumothorax_assessment': 'Assessment', 'stridor_assessment': 'Assessment',
        'ascites_assessment': 'Assessment', 'peritonitis_assessment': 'Assessment',
        'upper_gi_bleed': 'Assessment', 'consciousness': 'Consciousness',
        'higher_functions': 'Higher Functions', 'cranial_nerves': 'Cranial Nerves',
        'motor_system': 'Motor', 'reflexes': 'Reflexes', 'sensory_system': 'Sensory',
        'coordination': 'Coordination', 'meningeal_signs': 'Meningeal',
        'UMN_localization': 'Localisation', 'LMN_localization': 'Localisation',
        'meningitis_confirmation': 'Assessment',
      };
      return map[phase] ?? phase.replaceAll('_', ' ');
    }

    for (final exam in examinations) {
      final examId    = exam['examination_id'] as String;
      final prefix    = prefixMap[examId] ?? examId;
      final questions = exam['questions'] as List;
      final diagnoses = exam['diagnoses'] as List;
      for (final q in questions) {
        final phase   = q['phase'] as String;
        final options = q['options'] as List;
        final source  = '$prefix · ${phaseLabel(phase)}';
        for (final opt in options) {
          final term = opt as String;
          if (term.toLowerCase().startsWith('no ') ||
              term.toLowerCase().startsWith('normal') ||
              term.toLowerCase().startsWith('absent (') ||
              term.toLowerCase() == 'none') continue;
          results.add(KBSearchResult(term: term, source: source));
        }
      }
      for (final dx in diagnoses) {
        results.add(KBSearchResult(term: dx['name'] as String, source: '$prefix · Diagnosis'));
      }
    }
    // Conditions and drugs now come from clinical_terms.json via ClinicalTermsService
    results.addAll(_builtInConditionsAndDrugs());
    return results;
  }

  // Now reads from ClinicalTermsService (which loaded clinical_terms.json)
  static List<KBSearchResult> _builtInConditionsAndDrugs() => [
    ...ClinicalTermsService.commonConditions
        .map((c) => KBSearchResult(term: c, source: 'Conditions')),
    ...ClinicalTermsService.commonDrugs
        .map((d) => KBSearchResult(term: d, source: 'Drugs')),
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

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════
class ComplaintDetail {
  String complaint;
  int durationValue;
  String durationUnit; // 'hours' | 'days' | 'weeks' | 'months' | 'years'
  String severity;     // 'mild' | 'moderate' | 'severe'
  String notes;

  ComplaintDetail({
    required this.complaint,
    this.durationValue = 1,
    this.durationUnit = 'days',
    this.severity = 'mild',
    this.notes = '',
  });
}

// @HiveType(typeId: 2)
class FamilyMember {
  String relationship;
  List<String> conditions;
  String notes;
  bool isDeceased;

  FamilyMember({
    this.relationship = '',
    List<String>? conditions,
    this.notes = '',
    this.isDeceased = false,
  }) : conditions = conditions ?? [];
}

// @HiveType(typeId: 1)
class HistoryFormData {
  // Page 1
  List<String> complaints = [];
  List<ComplaintDetail> complaintDetails = [];
  // Page 2
  bool? hadHospitalizations;
  String hospitalizationDetails = '';
  bool? hadSurgeries;
  String surgeryDetails = '';
  bool? hasAllergies;
  String allergyDetails = '';
  List<String> knownConditions = [];
  String occupation = '';
  String smoking = '';
  String alcohol = '';
  String livingConditions = '';
  String diet = '';
  String sleep = '';
  String bladder = '';
  String bowelHabits = '';
  List<String> currentDrugs = [];
  bool? onRegularMedication;
  String regularMedicationDetails = '';
  bool? hasAdverseReactions;
  String adverseReactionDetails = '';
  // Page 3
  List<FamilyMember> familyMembers = [];
  String familyNotes = '';
  // Patient gender — needed when pushing systemic screen
  String patientGender = 'Male'; // 'Male' | 'Female' | 'Other'
}

// ═══════════════════════════════════════════════════════════════════════════════
// STANDALONE ENTRY
// ═══════════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ClinicalTermsService.init(); // loads clinical_terms.json (conditions, drugs, chips)
  await KBSearchService.init(); // parses knowledge_base.json into search index
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediScribe AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.sectionHeader,
          surface: AppColors.background,
        ),
      ),
      home: const HistoryTakingScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY TAKING SCREEN — 3-page flow
// ═══════════════════════════════════════════════════════════════════════════════
class HistoryTakingScreen extends StatefulWidget {
  final PatientInfo? patientInfo;
  const HistoryTakingScreen({super.key, this.patientInfo});

  @override
  State<HistoryTakingScreen> createState() => _HistoryTakingScreenState();
}

class _HistoryTakingScreenState extends State<HistoryTakingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final HistoryFormData _formData = HistoryFormData();

  static const List<String> _pageTitles = [
    'History Taking',
    'MediScribe AI',
    'MediScribe AI',
  ];

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SystemicHistoryScreen(
            patientGender: _formData.patientGender,
            chiefComplaints: _formData.complaints,
            patient: widget.patientInfo,
            history: _formData,
          ),
        ),
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _HistoryAppBar(
            title: _pageTitles[_currentPage],
            onBack: _prevPage,
            currentPage: _currentPage,
            totalPages: 3,
          ),
          _ProgressBar(currentPage: _currentPage, totalPages: 3),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _Page1ComplaintsHOPI(
                  formData: _formData,
                  onChanged: () => setState(() {}),
                ),
                _Page2PastPersonalHistory(
                  formData: _formData,
                  onChanged: () => setState(() {}),
                ),
                _Page3FamilyHistory(
                  formData: _formData,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          _BottomNextButton(
            currentPage: _currentPage,
            totalPages: 3,
            onNext: _nextPage,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _HistoryAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final int currentPage;
  final int totalPages;

  const _HistoryAppBar({
    required this.title, required this.onBack,
    required this.currentPage, required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerText, size: 22),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.headerText, letterSpacing: -0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${currentPage + 1} / $totalPages',
                  style: const TextStyle(fontSize: 13, color: AppColors.headerText,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  const _ProgressBar({required this.currentPage, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sectionHeader,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: List.generate(totalPages, (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < totalPages - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: i <= currentPage
                  ? AppColors.headerText
                  : AppColors.headerText.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }
}

class _BottomNextButton extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  const _BottomNextButton({
    required this.currentPage, required this.totalPages, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == totalPages - 1;
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sectionHeader,
            foregroundColor: AppColors.headerText,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            isLast ? 'Save & Continue to Systemic History' : 'Next',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.headerText),
          ),
        ),
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final String title;
  const _SectionBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.sectionHeader,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.headerText, letterSpacing: 0.1),
      ),
    );
  }
}

// YES/NO toggle
class _YesNoPill extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  const _YesNoPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(label: 'YES', selected: value == true, onTap: () => onChanged(true)),
        const SizedBox(width: 6),
        _Pill(label: 'NO',  selected: value == false, onTap: () => onChanged(false)),
      ],
    );
  }
}

// Generic selectable pill
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  const _Pill({required this.label, required this.selected,
      required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 14, vertical: small ? 5 : 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.pillYesBg : AppColors.pillNoBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.sectionHeader : AppColors.divider),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: small ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.pillYesText : AppColors.pillNoText,
          ),
        ),
      ),
    );
  }
}

// Removable teal tag chip
class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sectionHeader,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.headerText)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.headerText),
          ),
        ],
      ),
    );
  }
}

class _KBSearchField extends StatefulWidget {
  final String hint;              // placeholder when typing
  final String buttonLabel;       // text on the collapsed pill e.g. "Add symptom"
  final String? kbFilter;         // optional filter e.g. 'Drugs', 'Conditions'
  final List<String> alreadySelected;
  final ValueChanged<String> onAdd;

  const _KBSearchField({
    required this.hint,
    required this.buttonLabel,
    required this.onAdd,
    this.kbFilter,
    this.alreadySelected = const [],
  });

  @override
  State<_KBSearchField> createState() => _KBSearchFieldState();
}

class _KBSearchFieldState extends State<_KBSearchField> {
  final _ctrl = TextEditingController();
  bool _editing = false;
  List<KBSearchResult> _results = [];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onQueryChanged(String q) {
    setState(() {
      _results = KBSearchService.search(
        q,
        filter: widget.kbFilter,
        alreadySelected: widget.alreadySelected,
      );
    });
  }

  void _pick(String term) {
    widget.onAdd(term);
    _ctrl.clear();
    setState(() { _results = []; _editing = false; });
  }

  void _addRaw() {
    final val = _ctrl.text.trim();
    if (val.isNotEmpty) _pick(val);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.constitutional,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.sectionHeader.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline,
                  size: 14, color: AppColors.sectionHeader),
              const SizedBox(width: 5),
              Text(widget.buttonLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.sectionHeader)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AppColors.subtleGrey, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  prefixIcon: const Icon(Icons.search, size: 16,
                      color: AppColors.sectionHeader),
                  filled: true,
                  fillColor: AppColors.constitutional,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.sectionHeader)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.sectionHeader, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.sectionHeader.withOpacity(0.4))),
                ),
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _addRaw(),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() { _ctrl.clear(); _results = []; _editing = false; }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.pillNoBg, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14,
                    color: AppColors.pillNoText),
              ),
            ),
          ],
        ),
        // Results dropdown
        if (_ctrl.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                // KB matched results
                ..._results.map((r) => _KBResultTile(
                  result: r,
                  onTap: () => _pick(r.term),
                )),
                // Divider if there are KB results + raw add option
                if (_results.isNotEmpty)
                  const Divider(height: 1, color: AppColors.divider),
                // Always show "Add as custom" at bottom
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_circle_outline,
                      color: AppColors.sectionHeader, size: 16),
                  title: Text(
                    'Add "${_ctrl.text.trim()}" as custom',
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.sectionHeader, fontWeight: FontWeight.w600),
                  ),
                  onTap: _addRaw,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KBResultTile extends StatelessWidget {
  final KBSearchResult result;
  final VoidCallback onTap;
  const _KBResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(result.term,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.constitutional,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(result.source,
          style: const TextStyle(fontSize: 10, color: AppColors.sectionHeader,
              fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// Simple text note field
class _NoteField extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _NoteField({required this.hint, required this.value,
      required this.onChanged, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtleGrey, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.sectionHeader, width: 1.5)),
      ),
      onChanged: onChanged,
    );
  }
}

// Single-select option row (Diet, Sleep, Bladder, Bowel)
class _OptionRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _OptionRow({required this.label, required this.options,
      required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: AppColors.bodyText))),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: options.map((opt) => _Pill(
                label: opt,
                selected: selected == opt,
                onTap: () => onChanged(opt),
                small: true,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Yes/No card row
class _YesNoRow extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _YesNoRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w500, color: AppColors.bodyText))),
          _YesNoPill(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  const _ExpandedDetail({required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: _NoteField(hint: hint, value: value, onChanged: onChanged),
  );
}

// Small dropdown
class _SmallDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SmallDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.sectionHeader),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 1 — PRESENTING COMPLAINTS + HOPI
// ═══════════════════════════════════════════════════════════════════════════════
class _Page1ComplaintsHOPI extends StatefulWidget {
  final HistoryFormData formData;
  final VoidCallback onChanged;
  const _Page1ComplaintsHOPI({required this.formData, required this.onChanged});

  @override
  State<_Page1ComplaintsHOPI> createState() => _Page1State();
}

class _Page1State extends State<_Page1ComplaintsHOPI> {
  void _addComplaint(String complaint) {
    final fd = widget.formData;
    if (!fd.complaints.contains(complaint)) {
      setState(() {
        fd.complaints.add(complaint);
        fd.complaintDetails.add(ComplaintDetail(complaint: complaint));
      });
      widget.onChanged();
    }
  }

  void _removeComplaint(String complaint) {
    setState(() {
      widget.formData.complaintDetails.removeWhere((d) => d.complaint == complaint);
      widget.formData.complaints.remove(complaint);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final fd = widget.formData;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const _SectionBar(title: 'Presenting Complaints'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected complaint tags
                if (fd.complaints.isNotEmpty) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: fd.complaints.map((c) => _TagChip(
                      label: c, onRemove: () => _removeComplaint(c),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                // KB search — searches all symptom terms from knowledge_base.json
                _KBSearchField(
                  hint: 'Search complaints from clinical KB…',
                  buttonLabel: 'Add complaint',
                  alreadySelected: fd.complaints,
                  onAdd: _addComplaint,
                  // No filter — searches all terms so any symptom can be a complaint
                ),
              ],
            ),
),
          const _SectionBar(title: 'History of Present Illness'),
          const SizedBox(height: 8),

          if (fd.complaintDetails.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add at least one presenting complaint above to fill in HOPI.',
                style: TextStyle(fontSize: 13, color: AppColors.subtleGrey,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            ...fd.complaintDetails.map((detail) => _HOPICard(
              detail: detail,
              onChanged: () => setState(() => widget.onChanged()),
            )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// HOPI expandable card
class _HOPICard extends StatefulWidget {
  final ComplaintDetail detail;
  final VoidCallback onChanged;
  const _HOPICard({required this.detail, required this.onChanged});

  @override
  State<_HOPICard> createState() => _HOPICardState();
}

class _HOPICardState extends State<_HOPICard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(child: Text(d.complaint,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.bodyText))),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.subtleGrey, size: 22),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration
                  Row(
                    children: [
                      const SizedBox(width: 80,
                        child: Text('Duration', style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w500, color: AppColors.bodyText))),
                      Container(
                        width: 60, height: 36,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(8)),
                        child: TextFormField(
                          initialValue: d.durationValue.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
                          decoration: const InputDecoration(isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8)),
                          onChanged: (v) { d.durationValue = int.tryParse(v) ?? 1; widget.onChanged(); },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SmallDropdown(
                        value: d.durationUnit,
                        items: const ['hours', 'days', 'weeks', 'months', 'years'],
                        onChanged: (v) { setState(() => d.durationUnit = v); widget.onChanged(); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Severity
                  Row(
                    children: [
                      const SizedBox(width: 80,
                        child: Text('Severity', style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w500, color: AppColors.bodyText))),
                      Wrap(
                        spacing: 8,
                        children: ['mild', 'moderate', 'severe'].map((s) => _Pill(
                          label: s, selected: d.severity == s,
                          onTap: () { setState(() => d.severity = s); widget.onChanged(); },
                          small: true,
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _NoteField(
                    hint: 'Type notes for ${d.complaint}…',
                    value: d.notes,
                    onChanged: (v) { d.notes = v; widget.onChanged(); },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — PAST TREATMENT + SOCIO-ECONOMIC + PERSONAL + DRUG HISTORY
// ═══════════════════════════════════════════════════════════════════════════════
class _Page2PastPersonalHistory extends StatefulWidget {
  final HistoryFormData formData;
  final VoidCallback onChanged;
  const _Page2PastPersonalHistory({required this.formData, required this.onChanged});

  @override
  State<_Page2PastPersonalHistory> createState() => _Page2State();
}

class _Page2State extends State<_Page2PastPersonalHistory> {
  // Chips come from clinical_terms.json via ClinicalTermsService
  List<String> get _knownConditionChips => ClinicalTermsService.conditionChips;
  List<String> get _drugChips => ClinicalTermsService.drugChips;

  @override
  Widget build(BuildContext context) {
    final fd = widget.formData;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const _SectionBar(title: 'Past Treatment History'),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider)),
            child: Column(children: [
              _YesNoRow(
                label: 'Any previous hospitalizations?',
                value: fd.hadHospitalizations,
                onChanged: (v) => setState(() { fd.hadHospitalizations = v; widget.onChanged(); }),
              ),
              if (fd.hadHospitalizations == true)
                _ExpandedDetail(hint: 'Describe hospitalizations…',
                    value: fd.hospitalizationDetails,
                    onChanged: (v) { fd.hospitalizationDetails = v; widget.onChanged(); }),
              const Divider(height: 1, color: AppColors.divider),
              _YesNoRow(
                label: 'Any previous surgeries?',
                value: fd.hadSurgeries,
                onChanged: (v) => setState(() { fd.hadSurgeries = v; widget.onChanged(); }),
              ),
              if (fd.hadSurgeries == true)
                _ExpandedDetail(hint: 'Describe surgeries…',
                    value: fd.surgeryDetails,
                    onChanged: (v) { fd.surgeryDetails = v; widget.onChanged(); }),
              const Divider(height: 1, color: AppColors.divider),
              _YesNoRow(
                label: 'Any known allergies?',
                value: fd.hasAllergies,
                onChanged: (v) => setState(() { fd.hasAllergies = v; widget.onChanged(); }),
              ),
              if (fd.hasAllergies == true)
                _ExpandedDetail(hint: 'Describe allergies…',
                    value: fd.allergyDetails,
                    onChanged: (v) { fd.allergyDetails = v; widget.onChanged(); }),
              const Divider(height: 1, color: AppColors.divider),
              // Known conditions
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Known medical conditions:',
                  style: TextStyle(fontSize: 13, color: AppColors.subtleGrey,
                      fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8,
                    children: [
                      ..._knownConditionChips.map((c) {
                        final sel = fd.knownConditions.contains(c);
                        return _Pill(label: c, selected: sel, onTap: () => setState(() {
                          sel ? fd.knownConditions.remove(c) : fd.knownConditions.add(c);
                          widget.onChanged();
                        }));
                      }),
                      // Extra chips from KB search show as selected pills
                      ...fd.knownConditions.where((c) => !_knownConditionChips.contains(c))
                          .map((c) => _TagChip(label: c, onRemove: () => setState(() {
                                fd.knownConditions.remove(c); widget.onChanged();
                              }))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // KB search — filter to Conditions
                  _KBSearchField(
                    hint: 'Search conditions from clinical KB…',
                    buttonLabel: 'Add condition',
                    kbFilter: 'Conditions',
                    alreadySelected: fd.knownConditions,
                    onAdd: (v) => setState(() {
                      if (!fd.knownConditions.contains(v)) {
                        fd.knownConditions.add(v); widget.onChanged();
                      }
                    }),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Socio-economic History ─────────────────────────────────────────
          const _SectionBar(title: 'Socio-economic History'),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const SizedBox(width: 110, child: Text('Occupation',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.bodyText))),
                  Expanded(child: _NoteField(
                    hint: 'e.g. Teacher, Farmer…', value: fd.occupation, maxLines: 1,
                    onChanged: (v) { fd.occupation = v; widget.onChanged(); },
                  )),
                ]),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _OptionRow(label: 'Smoking',
                  options: const ['Never', 'Ex-smoker', 'Current'], selected: fd.smoking,
                  onChanged: (v) => setState(() { fd.smoking = v; widget.onChanged(); })),
              const Divider(height: 1, color: AppColors.divider),
              _OptionRow(label: 'Alcohol',
                  options: const ['Never', 'Occasional', 'Regular'], selected: fd.alcohol,
                  onChanged: (v) => setState(() { fd.alcohol = v; widget.onChanged(); })),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const SizedBox(width: 110, child: Text('Living conditions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.bodyText))),
                  Expanded(child: _SmallDropdown(
                    value: fd.livingConditions.isEmpty ? 'Good' : fd.livingConditions,
                    items: const ['Good', 'Average', 'Poor'],
                    onChanged: (v) => setState(() { fd.livingConditions = v; widget.onChanged(); }),
                  )),
                ]),
              ),
            ]),
          ),

          // ── Personal History ───────────────────────────────────────────────
          const _SectionBar(title: 'Personal History'),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider)),
            child: Column(children: [
              _OptionRow(label: 'Diet',
                  options: const ['Vegetarian', 'Mixed'], selected: fd.diet,
                  onChanged: (v) => setState(() { fd.diet = v; widget.onChanged(); })),
              const Divider(height: 1, color: AppColors.divider),
              _OptionRow(label: 'Sleep',
                  options: const ['Normal', 'Disturbed'], selected: fd.sleep,
                  onChanged: (v) => setState(() { fd.sleep = v; widget.onChanged(); })),
              const Divider(height: 1, color: AppColors.divider),
              _OptionRow(label: 'Bladder',
                  options: const ['Normal', 'Abnormal'], selected: fd.bladder,
                  onChanged: (v) => setState(() { fd.bladder = v; widget.onChanged(); })),
              const Divider(height: 1, color: AppColors.divider),
              _OptionRow(label: 'Bowel habits',
                  options: const ['Normal', 'Constipation', 'Diarrhea'], selected: fd.bowelHabits,
                  onChanged: (v) => setState(() { fd.bowelHabits = v; widget.onChanged(); })),
            ]),
          ),

          // ── Drug History ───────────────────────────────────────────────────
          const _SectionBar(title: 'Drug History'),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _YesNoRow(
                label: 'On regular medication?',
                value: fd.onRegularMedication,
                onChanged: (v) => setState(() { fd.onRegularMedication = v; widget.onChanged(); }),
              ),
              if (fd.onRegularMedication == true) ...[
                const Divider(height: 1, color: AppColors.divider),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Select current medications:',
                    style: TextStyle(fontSize: 13, color: AppColors.subtleGrey,
                        fontWeight: FontWeight.w500)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 8,
                      children: [
                        ..._drugChips.map((drug) {
                          final sel = fd.currentDrugs.contains(drug);
                          return _Pill(label: drug, selected: sel, onTap: () => setState(() {
                            sel ? fd.currentDrugs.remove(drug) : fd.currentDrugs.add(drug);
                            widget.onChanged();
                          }));
                        }),
                        // Extra from KB search
                        ...fd.currentDrugs.where((d) => !_drugChips.contains(d))
                            .map((d) => _TagChip(label: d, onRemove: () => setState(() {
                                  fd.currentDrugs.remove(d); widget.onChanged();
                                }))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // KB search — filter to Drugs
                    _KBSearchField(
                      hint: 'Search drug name from clinical KB…',
                      buttonLabel: 'Add drug',
                      kbFilter: 'Drugs',
                      alreadySelected: fd.currentDrugs,
                      onAdd: (v) => setState(() {
                        if (!fd.currentDrugs.contains(v)) {
                          fd.currentDrugs.add(v); widget.onChanged();
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    _NoteField(
                      hint: 'Add dose / frequency notes…',
                      value: fd.regularMedicationDetails,
                      onChanged: (v) { fd.regularMedicationDetails = v; widget.onChanged(); },
                    ),
                  ]),
                ),
              ],
              const Divider(height: 1, color: AppColors.divider),
              _YesNoRow(
                label: 'Any adverse drug reactions?',
                value: fd.hasAdverseReactions,
                onChanged: (v) => setState(() { fd.hasAdverseReactions = v; widget.onChanged(); }),
              ),
              if (fd.hasAdverseReactions == true)
                _ExpandedDetail(
                  hint: 'Describe the reaction and causative drug…',
                  value: fd.adverseReactionDetails,
                  onChanged: (v) { fd.adverseReactionDetails = v; widget.onChanged(); },
                ),
            ]),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 3 — FAMILY HISTORY
// ═══════════════════════════════════════════════════════════════════════════════
class _Page3FamilyHistory extends StatefulWidget {
  final HistoryFormData formData;
  final VoidCallback onChanged;
  const _Page3FamilyHistory({required this.formData, required this.onChanged});

  @override
  State<_Page3FamilyHistory> createState() => _Page3State();
}

class _Page3State extends State<_Page3FamilyHistory> {
  void _addMember() => setState(() {
    widget.formData.familyMembers.add(FamilyMember());
    widget.onChanged();
  });

  void _removeMember(int index) => setState(() {
    widget.formData.familyMembers.removeAt(index);
    widget.onChanged();
  });

  @override
  Widget build(BuildContext context) {
    final fd = widget.formData;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const _SectionBar(title: 'Family History'),

        // Empty state
        if (fd.familyMembers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.constitutional,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sectionHeader.withOpacity(0.25)),
              ),
              child: Column(children: const [
                Icon(Icons.family_restroom, size: 40, color: AppColors.sectionHeader),
                SizedBox(height: 10),
                Text('No family members added yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.sectionHeader)),
                SizedBox(height: 4),
                Text('Tap "Add Family Member" below to record relevant family medical history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.subtleGrey, height: 1.5)),
              ]),
            ),
          ),

        // Member cards
        ...List.generate(fd.familyMembers.length, (i) => _FamilyMemberCard(
          member: fd.familyMembers[i],
          index: i,
          onChanged: () => setState(() => widget.onChanged()),
          onRemove: () => _removeMember(i),
        )),

        // Add member button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: _addMember,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sectionHeader, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.person_add_alt_1, color: AppColors.sectionHeader, size: 20),
                SizedBox(width: 8),
                Text('Add Family Member', style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.sectionHeader)),
              ]),
            ),
          ),
        ),

        // General family notes (shown once there's at least one member)
        if (fd.familyMembers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: AppColors.sectionHeader,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('General Family Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.headerText)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _NoteField(
              hint: 'Any additional notes across all family history…',
              value: fd.familyNotes,
              maxLines: 4,
              onChanged: (v) { fd.familyNotes = v; widget.onChanged(); },
            ),
          ),
        ],

        const SizedBox(height: 32),
      ]),
    );
  }
}

// ── Family Member Card ────────────────────────────────────────────────────────
class _FamilyMemberCard extends StatefulWidget {
  final FamilyMember member;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _FamilyMemberCard({required this.member, required this.index,
      required this.onChanged, required this.onRemove});

  @override
  State<_FamilyMemberCard> createState() => _FamilyMemberCardState();
}

class _FamilyMemberCardState extends State<_FamilyMemberCard> {
  bool _expanded = true;

  // Relationships and condition chips come from clinical_terms.json via ClinicalTermsService
  List<String> get _relationships => ClinicalTermsService.familyRelationships;
  List<String> get _conditionChips => ClinicalTermsService.familyConditionChips;

  String get _cardTitle => widget.member.relationship.isNotEmpty
      ? widget.member.relationship
      : 'Family Member ${widget.index + 1}';

  @override
  Widget build(BuildContext context) {
    final m = widget.member;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Card header
        Container(
          color: AppColors.constitutional,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.sectionHeader.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('${widget.index + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppColors.sectionHeader))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_cardTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.bodyText))),
            // Alive/Deceased toggle
            GestureDetector(
              onTap: () { setState(() => m.isDeceased = !m.isDeceased); widget.onChanged(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: m.isDeceased ? AppColors.subtleGrey.withOpacity(0.2) : AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(m.isDeceased ? 'Deceased' : 'Alive',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: m.isDeceased ? AppColors.subtleGrey : AppColors.sectionHeader)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.subtleGrey, size: 22),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onRemove,
              child: const Icon(Icons.delete_outline, color: AppColors.subtleGrey, size: 20),
            ),
          ]),
        ),

        if (_expanded) ...[
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Relationship dropdown
              const Text('Relationship', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.bodyText)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(color: AppColors.background,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: m.relationship.isEmpty ? null : m.relationship,
                    hint: const Text('Select relationship…',
                        style: TextStyle(color: AppColors.subtleGrey, fontSize: 13)),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.sectionHeader),
                    style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
                    items: _relationships.map((r) =>
                        DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) { setState(() => m.relationship = v ?? ''); widget.onChanged(); },
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text('Medical Conditions', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.bodyText)),
              const SizedBox(height: 8),

              Wrap(spacing: 7, runSpacing: 7,
                children: [
                  ..._conditionChips.map((c) {
                    final sel = m.conditions.contains(c);
                    return _Pill(label: c, selected: sel, small: true,
                      onTap: () { setState(() {
                        sel ? m.conditions.remove(c) : m.conditions.add(c);
                      }); widget.onChanged(); });
                  }),
                  // Extra conditions from KB search
                  ...m.conditions.where((c) => !_conditionChips.contains(c))
                      .map((c) => _TagChip(label: c, onRemove: () { setState(() {
                            m.conditions.remove(c); widget.onChanged();
                          });})),
                ],
              ),
              const SizedBox(height: 8),
              // KB search — filter to Conditions + Diagnoses
              _KBSearchField(
                hint: 'Search condition from clinical KB…',
                buttonLabel: 'Add condition',
                kbFilter: 'Conditions',
                alreadySelected: m.conditions,
                onAdd: (v) { setState(() {
                  if (!m.conditions.contains(v)) { m.conditions.add(v); widget.onChanged(); }
                }); },
              ),

              const SizedBox(height: 14),
              _NoteField(
                hint: 'Notes for this family member…',
                value: m.notes,
                onChanged: (v) { m.notes = v; widget.onChanged(); },
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}