import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import '../models/history_models.dart';
import '../models/systemic_models.dart';
import '../models/vitals_models.dart';
import '../models/lab_models.dart';
import '../models/examination_models.dart';
import 'diagnosis_screen.dart';

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
        builder: (_) => DiagnosisScreen(
          patient:     widget.patient,
          history:     widget.history,
          systemic:    widget.systemic,
          vitals:      widget.vitals,
          examination: _data,
          labs:        widget.labs,
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

// 
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

