import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import '../models/history_models.dart';
import '../models/systemic_models.dart';
import 'vitals_screen.dart';

class SystemicHistoryScreen extends StatefulWidget {
  final String patientGender;         // 'Male' | 'Female' | 'Other'
  final List<String> chiefComplaints; // from HistoryTakingScreen Page 1
  final PatientInfo? patient;
  final HistoryFormData? history;

  const SystemicHistoryScreen({
    super.key,
    required this.patientGender,
    required this.chiefComplaints,
    this.patient,
    this.history,
  });

  @override
  State<SystemicHistoryScreen> createState() => _SystemicHistoryScreenState();
}

class _SystemicHistoryScreenState extends State<SystemicHistoryScreen> {
  final SystemicHistoryData _data = SystemicHistoryData();

  SystemicHistoryData _buildSystemicData() => _data;

  // Track which system panels are collapsed
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    SystemicReviewService.init().then((_) { if (mounted) setState(() {}); });
  }

  bool get _isFemale =>
      widget.patientGender.toLowerCase() == 'female';

  List<SystemDef> get _visibleSystems => SystemicReviewService.systems
      .where((s) => s.femaleOnly ? _isFemale : true)
      .toList();

  SymptomMap _mapForSystem(String id) {
    switch (id) {
      case 'cardiovascular':   return _data.cardiovascular;
      case 'respiratory':      return _data.respiratory;
      case 'cns':              return _data.cns;
      case 'gastrointestinal': return _data.gastrointestinal;
      case 'genitourinary':    return _data.genitourinary;
      case 'musculoskeletal':  return _data.musculoskeletal;
      case 'gynaecological':   return _data.gynaecological;
      case 'endocrine':        return _data.endocrine;
      case 'constitutional':   return _data.constitutional;
      default:                 return {};
    }
  }

  List<String> _negativeFor(String id) {
    final map = _mapForSystem(id);
    return map.entries.where((e) => e.value == false).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final negativeAll = _data.negativeSymptoms;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          
          _SystemicAppBar(onBack: () => Navigator.of(context).maybePop()),

          
          _InfoBanner(complaints: widget.chiefComplaints),

          
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Build one card per visible system
                  ..._visibleSystems.map((system) {
                    final map = _mapForSystem(system.id);
                    final customs = _data.customSymptoms[system.id] ?? [];
                    final collapsed = _collapsed.contains(system.id);

                    return _SystemSection(
                      system: system,
                      map: map,
                      customSymptoms: customs,
                      collapsed: collapsed,
                      onToggleCollapse: () => setState(() {
                        collapsed
                            ? _collapsed.remove(system.id)
                            : _collapsed.add(system.id);
                      }),
                      onAnswer: (symptom, val) => setState(() {
                        map[symptom] = val;
                      }),
                      onAddCustomSymptom: (symptom) => setState(() {
                        _data.customSymptoms
                            .putIfAbsent(system.id, () => [])
                            .add(symptom);
                        map[symptom] = null;
                      }),
                      onRemoveCustomSymptom: (symptom) => setState(() {
                        _data.customSymptoms[system.id]?.remove(symptom);
                        map.remove(symptom);
                      }),
                    );
                  }),

                  const SizedBox(height: 8),

                  
                  _AddYourselfSection(
                    entries: _data.customEntries,
                    onAdd: (entry) => setState(() {
                      _data.customEntries.add(entry);
                    }),
                    onAnswer: (index, val) => setState(() {
                      _data.customEntries[index].answer = val;
                    }),
                    onRemove: (index) => setState(() {
                      _data.customEntries.removeAt(index);
                    }),
                  ),

                  const SizedBox(height: 16),

                  
                  if (negativeAll.isNotEmpty)
                    _NegativeHistorySummary(negativeSymptoms: negativeAll),

                  const SizedBox(height: 100), // space for bottom button
                ],
              ),
            ),
          ),

          // Pushes to VitalsScreen
          // To pass data forward, add params to VitalsScreen constructor first
          _NextButton(
            onNext: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VitalsScreen(
                    patient: widget.patient,
                    history: widget.history,
                    systemic: _buildSystemicData(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SystemicAppBar extends StatelessWidget {
  final VoidCallback onBack;
  const _SystemicAppBar({required this.onBack});

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
              const Expanded(
                child: Text(
                  'Systemic History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headerText,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text(
                  'MediScribe AI',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.headerText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small banner that shows the chief complaints below the app bar
class _InfoBanner extends StatelessWidget {
  final List<String> complaints;
  const _InfoBanner({required this.complaints});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.constitutional,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.sectionHeader,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtleGrey,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Showing relevant systems based on your complaint',
                  ),
                  if (complaints.isNotEmpty) ...[
                    const TextSpan(text: ': '),
                    TextSpan(
                      text: complaints.join(', '),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.sectionHeader,
                      ),
                    ),
                  ],
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// One collapsible card for each body system
class _SystemSection extends StatefulWidget {
  final SystemDef system;
  final SymptomMap map;
  final List<String> customSymptoms;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final void Function(String symptom, bool val) onAnswer;
  final void Function(String symptom) onAddCustomSymptom;
  final void Function(String symptom) onRemoveCustomSymptom;

  const _SystemSection({
    required this.system,
    required this.map,
    required this.customSymptoms,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onAnswer,
    required this.onAddCustomSymptom,
    required this.onRemoveCustomSymptom,
  });

  @override
  State<_SystemSection> createState() => _SystemSectionState();
}

class _SystemSectionState extends State<_SystemSection> {
  @override
  Widget build(BuildContext context) {
    final system = widget.system;
    final isConstitutional = system.alwaysAsk;
    final allSymptoms = [...system.symptoms, ...widget.customSymptoms];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // Constitutional gets a slightly more prominent border
          color: isConstitutional
              ? AppColors.sectionHeader.withOpacity(0.5)
              : AppColors.divider,
          width: isConstitutional ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          
          GestureDetector(
            onTap: widget.onToggleCollapse,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.sectionHeader,
                borderRadius: widget.collapsed
                    ? BorderRadius.circular(13)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13),
                      ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    system.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          system.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headerText,
                          ),
                        ),
                        if (system.alwaysAsk) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Always Asked',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.headerText,
                              ),
                            ),
                          ),
                        ],
                        if (system.femaleOnly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Female only',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.headerText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    widget.collapsed
                        ? Icons.expand_more
                        : Icons.expand_less,
                    color: AppColors.headerText,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          
          if (!widget.collapsed) ...[
            ...allSymptoms.asMap().entries.map((entry) {
              final i = entry.key;
              final symptom = entry.value;
              final isCustom = i >= system.symptoms.length;
              final answer = widget.map[symptom];
              final isYes = answer == true;

              return Column(
                children: [
                  _SymptomRow(
                    symptom: symptom,
                    answer: answer,
                    isHighlighted: answer == true,
                    isCustom: isCustom,
                    onYes: () => widget.onAnswer(symptom, true),
                    onNo: () => widget.onAnswer(symptom, false),
                    onRemoveCustom: isCustom
                        ? () => widget.onRemoveCustomSymptom(symptom)
                        : null,
                  ),
                  if (i < allSymptoms.length - 1)
                    const Divider(height: 1, color: AppColors.divider,
                        indent: 16, endIndent: 16),
                ],
              );
            }),

            
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _AddSymptomRow(
                systemTitle: system.title,
                onAdd: widget.onAddCustomSymptom,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// One row showing a symptom name with YES and NO pills
class _SymptomRow extends StatelessWidget {
  final String symptom;
  final bool? answer;
  final bool isHighlighted; // green tint when YES
  final bool isCustom;      // custom symptom added by user
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback? onRemoveCustom;

  const _SymptomRow({
    required this.symptom,
    required this.answer,
    required this.isHighlighted,
    required this.isCustom,
    required this.onYes,
    required this.onNo,
    this.onRemoveCustom,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isHighlighted
          ? AppColors.constitutional
          : AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isCustom) ...[
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.sectionHeader,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    symptom,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: AppColors.bodyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          _AnswerPill(
            label: 'YES',
            selected: answer == true,
            onTap: onYes,
          ),
          const SizedBox(width: 8),
          
          _AnswerPill(
            label: 'NO',
            selected: answer == false,
            onTap: onNo,
            isNo: true,
          ),
          
          if (isCustom && onRemoveCustom != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemoveCustom,
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.subtleGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// YES or NO pill button
class _AnswerPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isNo;

  const _AnswerPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isNo = false,
  });

  @override
  Widget build(BuildContext context) {
    
    
    
    Color bg;
    Color textColor;
    Color border;

    if (selected && !isNo) {
      bg = AppColors.pillYesBg;
      textColor = AppColors.pillYesText;
      border = AppColors.pillYesBg;
    } else if (selected && isNo) {
      bg = AppColors.background;
      textColor = AppColors.bodyText;
      border = AppColors.bodyText;
    } else {
      bg = AppColors.pillNoBg;
      textColor = AppColors.pillNoText;
      border = AppColors.pillNoBg;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 30,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// Inline button to add a custom symptom inside a system section
class _AddSymptomRow extends StatefulWidget {
  final String systemTitle;
  final ValueChanged<String> onAdd;

  const _AddSymptomRow({required this.systemTitle, required this.onAdd});

  @override
  State<_AddSymptomRow> createState() => _AddSymptomRowState();
}

class _AddSymptomRowState extends State<_AddSymptomRow> {
  final _ctrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = _ctrl.text.trim();
    if (val.isNotEmpty) {
      widget.onAdd(val);
      _ctrl.clear();
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onTap: () => setState(() => _editing = true),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.constitutional,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.sectionHeader.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: AppColors.sectionHeader,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Add symptom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sectionHeader,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
            decoration: InputDecoration(
              hintText: 'Add symptom to ${widget.systemTitle}…',
              hintStyle: const TextStyle(
                color: AppColors.subtleGrey, fontSize: 13,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppColors.constitutional,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.sectionHeader),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                    color: AppColors.sectionHeader, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                    color: AppColors.sectionHeader.withOpacity(0.4)),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _submit,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.sectionHeader,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: AppColors.headerText),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() {
            _ctrl.clear();
            _editing = false;
          }),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.pillNoBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 14, color: AppColors.pillNoText),
          ),
        ),
      ],
    );
  }
}

// Section where the doctor can add a custom system and symptom not in the list
class _AddYourselfSection extends StatefulWidget {
  final List<CustomSystemEntry> entries;
  final ValueChanged<CustomSystemEntry> onAdd;
  final void Function(int index, bool val) onAnswer;
  final ValueChanged<int> onRemove;

  const _AddYourselfSection({
    required this.entries,
    required this.onAdd,
    required this.onAnswer,
    required this.onRemove,
  });

  @override
  State<_AddYourselfSection> createState() => _AddYourselfSectionState();
}

class _AddYourselfSectionState extends State<_AddYourselfSection> {
  final _systemCtrl  = TextEditingController();
  final _symptomCtrl = TextEditingController();
  bool _showForm = false;

  @override
  void dispose() {
    _systemCtrl.dispose();
    _symptomCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final system  = _systemCtrl.text.trim();
    final symptom = _symptomCtrl.text.trim();
    if (system.isNotEmpty && symptom.isNotEmpty) {
      widget.onAdd(CustomSystemEntry(system: system, symptom: symptom));
      _systemCtrl.clear();
      _symptomCtrl.clear();
      setState(() => _showForm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sectionHeader,
          width: 1.5,
          
          
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Container(
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: widget.entries.isEmpty && !_showForm
                  ? BorderRadius.circular(13)
                  : const BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13),
                    ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('✏️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add It Yourself',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sectionHeader,
                        ),
                      ),
                      Text(
                        'Missing something? Add your own system or symptom.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subtleGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          
          if (widget.entries.isNotEmpty) ...[
            ...widget.entries.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Column(
                children: [
                  Container(
                    color: e.answer == true
                        ? AppColors.constitutional
                        : AppColors.background,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.system,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.sectionHeader,
                                ),
                              ),
                              Text(
                                e.symptom,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.bodyText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _AnswerPill(
                          label: 'YES',
                          selected: e.answer == true,
                          onTap: () => widget.onAnswer(i, true),
                        ),
                        const SizedBox(width: 8),
                        _AnswerPill(
                          label: 'NO',
                          selected: e.answer == false,
                          onTap: () => widget.onAnswer(i, false),
                          isNo: true,
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => widget.onRemove(i),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.subtleGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < widget.entries.length - 1)
                    const Divider(height: 1, color: AppColors.divider,
                        indent: 16, endIndent: 16),
                ],
              );
            }),
            const Divider(height: 1, color: AppColors.divider),
          ],

          
          if (_showForm) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System / Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MiniTextField(
                    controller: _systemCtrl,
                    hint: 'e.g. Dermatological, Psychiatric…',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Symptom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MiniTextField(
                    controller: _symptomCtrl,
                    hint: 'e.g. Rash, Low mood, Bruising…',
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _submit,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.sectionHeader,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.headerText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _systemCtrl.clear();
                            _symptomCtrl.clear();
                            _showForm = false;
                          }),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.pillNoBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pillNoText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ] else ...[
            
            Padding(
              padding: const EdgeInsets.all(14),
              child: GestureDetector(
                onTap: () => setState(() => _showForm = true),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.sectionHeader, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add,
                        color: AppColors.sectionHeader,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Add custom symptom',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sectionHeader,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  const _MiniTextField({
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtleGrey, fontSize: 13),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.constitutional,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.sectionHeader, width: 1.5),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _NegativeHistorySummary extends StatelessWidget {
  final List<String> negativeSymptoms;
  const _NegativeHistorySummary({required this.negativeSymptoms});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.constitutional,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.remove_circle_outline,
                size: 16,
                color: AppColors.sectionHeader,
              ),
              SizedBox(width: 8),
              Text(
                'Negative History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sectionHeader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: negativeSymptoms
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtleGrey,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.subtleGrey,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onNext;
  const _NextButton({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sectionHeader,
            foregroundColor: AppColors.headerText,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Next',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.headerText,
            ),
          ),
        ),
      ),
    );
  }
}