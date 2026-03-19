import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import '../models/history_models.dart';
import '../models/systemic_models.dart';
import '../models/vitals_models.dart';
import '../models/lab_models.dart';
import '../models/examination_models.dart';
import 'soap_note_screen.dart';

// 
// DIAGNOSIS SCREEN
// Pulls calculateCertaintyFactors() from each examined SystemExamSession,
// ranks diagnoses by certainty, groups into Probable / Possible / Unlikely,
// and shows contributing key findings + clinical alerts.
//
// Flow: ExaminationScreen → DiagnosisScreen → SoapNoteScreen
// 

class DiagnosisScreen extends StatefulWidget {
  final PatientInfo?         patient;
  final HistoryFormData?     history;
  final SystemicHistoryData? systemic;
  final VitalsData?          vitals;
  final ExaminationData      examination;
  final LabData?             labs;
  final String?              existingSessionId;

  const DiagnosisScreen({
    super.key,
    this.patient,
    this.history,
    this.systemic,
    this.vitals,
    required this.examination,
    this.labs,
    this.existingSessionId,
  });

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _staggerCtrl;

  // Computed once on init — list of _SystemDiagnosis (one per examined system)
  List<_SystemDiagnosis> _systemDiagnoses = [];
  List<String>           _allAlerts       = [];
  bool                   _kbLoaded        = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _initDiagnoses();
  }

  Future<void> _initDiagnoses() async {
    await KBService.init();
    if (!mounted) return;

    final diagnoses = <_SystemDiagnosis>[];
    final alerts    = <String>[];

    for (final config in kExamConfigs) {
      final session = widget.examination.sessions[config.examId];

      // Collect alerts
      if (session != null) {
        for (final a in session.alertMessages) {
          if (!alerts.contains(a)) alerts.add(a);
        }
      }

      final exam = KBService.getExam(config.examId);
      if (exam == null) continue;

      // If session has no answers, show all diagnoses for this exam at 0%
      // so the doctor sees what could be considered rather than a blank screen
      if (session == null || session.answers.isEmpty) {
        diagnoses.add(_SystemDiagnosis(
          config: config,
          results: exam.diagnoses.map((dx) => _DiagnosisResult(
            name:        dx.name,
            description: dx.description,
            certainty:   0,
            id:          dx.id,
          )).toList(),
        ));
        continue;
      }

      final factors = session.calculateCertaintyFactors(exam);

      // factors will now always be non-empty (threshold no longer hard-skips)
      // but guard anyway
      if (factors.isEmpty) continue;

      diagnoses.add(_SystemDiagnosis(
        config:  config,
        results: factors.map((f) => _DiagnosisResult(
          name:        f['name']        as String,
          description: f['description'] as String,
          certainty:   f['certainty']   as int,
          id:          f['id']          as String,
        )).toList(),
      ));
    }

    setState(() {
      _systemDiagnoses = diagnoses;
      _allAlerts       = alerts;
      _kbLoaded        = true;
    });

    _fadeCtrl.forward();
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _goToSoap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoapNoteScreen(
          patient:           widget.patient     ?? PatientInfo(),
          history:           widget.history     ?? HistoryFormData(),
          systemic:          widget.systemic    ?? SystemicHistoryData(),
          vitals:            widget.vitals      ?? VitalsData(),
          examination:       widget.examination,
          labs:              widget.labs        ?? LabData(),
          existingSessionId: widget.existingSessionId,
        ),
      ),
    );
  }

  // Count of all diagnoses (shown regardless of certainty)
  int get _probableCount => _systemDiagnoses
      .expand((s) => s.results)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _DiagnosisAppBar(
            onBack:        () => Navigator.of(context).maybePop(),
            alertCount:    _allAlerts.length,
            probableCount: _probableCount,
          ),
          Expanded(
            child: !_kbLoaded
                ? _buildLoading()
                : _systemDiagnoses.isEmpty
                    ? _buildEmpty()
                    : _buildContent(),
          ),
          _ProceedButton(onTap: _goToSoap),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.sectionHeader, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Analysing findings...',
              style: TextStyle(fontSize: 14, color: AppColors.subtleGrey)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.constitutional,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 40, color: AppColors.sectionHeader),
            ),
            const SizedBox(height: 20),
            const Text('No Diagnoses Generated',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bodyText)),
            const SizedBox(height: 8),
            const Text(
              'Complete at least one system examination with findings to generate a differential diagnosis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.subtleGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Alert banner 
          if (_allAlerts.isNotEmpty) _AlertBanner(alerts: _allAlerts),

          // Summary pill row 
          _SummaryRow(systemDiagnoses: _systemDiagnoses),

          const SizedBox(height: 8),

          // Per-system diagnosis cards 
          ...List.generate(_systemDiagnoses.length, (i) {
            final delay = i * 0.15;
            return AnimatedBuilder(
              animation: _staggerCtrl,
              builder: (context, child) {
                final progress = Curves.easeOut.transform(
                  ((_staggerCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - progress)),
                    child: child,
                  ),
                );
              },
              child: _SystemDiagnosisCard(
                systemDx: _systemDiagnoses[i],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// DATA CLASSES 

class _DiagnosisResult {
  final String name;
  final String description;
  final int    certainty;
  final String id;

  const _DiagnosisResult({
    required this.name,
    required this.description,
    required this.certainty,
    required this.id,
  });

  // Probable ≥ 70, Possible 40–69, Unlikely < 40
  _DxBand get band {
    if (certainty >= 70) return _DxBand.probable;
    if (certainty >= 40) return _DxBand.possible;
    return _DxBand.unlikely;
  }
}

class _SystemDiagnosis {
  final ExamSystemConfig      config;
  final List<_DiagnosisResult> results;
  const _SystemDiagnosis({required this.config, required this.results});
}

enum _DxBand { probable, possible, unlikely }

extension _DxBandStyle on _DxBand {
  String get label {
    switch (this) {
      case _DxBand.probable: return 'Probable';
      case _DxBand.possible: return 'Possible';
      case _DxBand.unlikely: return 'Unlikely';
    }
  }

  Color get textColor {
    switch (this) {
      case _DxBand.probable: return AppColors.normalText;
      case _DxBand.possible: return AppColors.warnText;
      case _DxBand.unlikely: return AppColors.subtleGrey;
    }
  }

  Color get bgColor {
    switch (this) {
      case _DxBand.probable: return AppColors.normalBg;
      case _DxBand.possible: return AppColors.warnBg;
      case _DxBand.unlikely: return const Color(0xFFF5F5F5);
    }
  }

  Color get barColor {
    switch (this) {
      case _DxBand.probable: return AppColors.normalText;
      case _DxBand.possible: return AppColors.warnText;
      case _DxBand.unlikely: return AppColors.subtleGrey;
    }
  }
}

// APP BAR 

class _DiagnosisAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final int alertCount;
  final int probableCount;

  const _DiagnosisAppBar({
    required this.onBack,
    required this.alertCount,
    required this.probableCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                      'Differential Diagnosis',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headerText,
                          letterSpacing: -0.3),
                    ),
                  ),
                  if (alertCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 13, color: AppColors.headerText),
                          const SizedBox(width: 4),
                          Text(
                            '$alertCount Alert${alertCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.headerText),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Sub-header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                probableCount > 0
                    ? '$probableCount probable diagnos${probableCount == 1 ? 'is' : 'es'} identified'
                    : 'Review findings below',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.headerText.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ALERT BANNER 

class _AlertBanner extends StatefulWidget {
  final List<String> alerts;
  const _AlertBanner({required this.alerts});

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.emergencyBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.emergencyRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.alerts.length} Clinical Alert${widget.alerts.length > 1 ? 's' : ''} — Requires Attention',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emergencyRed),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.emergencyRed,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Alert list
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0x33D32F2F)),
            ...widget.alerts.map((a) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.emergencyRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.emergencyRed,
                                height: 1.45)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// SUMMARY ROW 

class _SummaryRow extends StatelessWidget {
  final List<_SystemDiagnosis> systemDiagnoses;
  const _SummaryRow({required this.systemDiagnoses});

  @override
  Widget build(BuildContext context) {
    // Count across all systems
    int probable = 0, possible = 0, unlikely = 0;
    for (final s in systemDiagnoses) {
      for (final r in s.results) {
        switch (r.band) {
          case _DxBand.probable: probable++; break;
          case _DxBand.possible: possible++; break;
          case _DxBand.unlikely: unlikely++; break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _SummaryPill(count: probable, label: 'Probable',
              textColor: AppColors.normalText, bgColor: AppColors.normalBg,
              borderColor: AppColors.normalBorder),
          const SizedBox(width: 8),
          _SummaryPill(count: possible, label: 'Possible',
              textColor: AppColors.warnText, bgColor: AppColors.warnBg,
              borderColor: AppColors.warnBorder),
          const SizedBox(width: 8),
          _SummaryPill(count: unlikely, label: 'Unlikely',
              textColor: AppColors.subtleGrey, bgColor: const Color(0xFFF5F5F5),
              borderColor: const Color(0xFFE0E0E0)),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final int    count;
  final String label;
  final Color  textColor;
  final Color  bgColor;
  final Color  borderColor;

  const _SummaryPill({
    required this.count,
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor),
          ),
        ],
      ),
    );
  }
}

// SYSTEM DIAGNOSIS CARD 

class _SystemDiagnosisCard extends StatefulWidget {
  final _SystemDiagnosis systemDx;
  const _SystemDiagnosisCard({required this.systemDx});

  @override
  State<_SystemDiagnosisCard> createState() => _SystemDiagnosisCardState();
}

class _SystemDiagnosisCardState extends State<_SystemDiagnosisCard> {
  // All results shown — sorted by certainty descending
  bool _showAll = true;

  List<_DiagnosisResult> get _visible {
    final sorted = [...widget.systemDx.results];
    sorted.sort((a, b) => b.certainty.compareTo(a.certainty));
    return sorted;
  }

  bool get _hasMore => false; // Always show all

  @override
  Widget build(BuildContext context) {
    final config = widget.systemDx.config;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System header 
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sectionHeader.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(config.icon,
                      size: 18, color: AppColors.sectionHeader),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bodyText)),
                      Text(config.subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.subtleGrey)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sectionHeader.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.systemDx.results.length} dx',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sectionHeader),
                  ),
                ),
              ],
            ),
          ),

          // Diagnosis rows 
          ..._visible.map((result) => _DiagnosisRow(result: result)),

          // Show more toggle 
          if (_hasMore)
            InkWell(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAll
                          ? 'Show less'
                          : 'Show ${widget.systemDx.results.length - 3} more',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sectionHeader),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAll
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.sectionHeader,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// DIAGNOSIS ROW 

class _DiagnosisRow extends StatefulWidget {
  final _DiagnosisResult result;
  const _DiagnosisRow({required this.result});

  @override
  State<_DiagnosisRow> createState() => _DiagnosisRowState();
}

class _DiagnosisRowState extends State<_DiagnosisRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;
  late final Animation<double>   _barAnim;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut);

    // Slight delay so the card reveal animation finishes first
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r    = widget.result;
    final band = r.band;

    return Column(
      children: [
        const Divider(height: 1, color: AppColors.divider),
        InkWell(
          onTap: r.description.isNotEmpty
              ? () => setState(() => _descExpanded = !_descExpanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Band pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: band.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(band.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: band.textColor,
                              letterSpacing: 0.3)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bodyText)),
                    ),
                    // Certainty percentage
                    Text(
                      '${r.certainty}%',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: band.barColor),
                    ),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(
                        _descExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: AppColors.subtleGrey,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // Animated certainty bar
                AnimatedBuilder(
                  animation: _barAnim,
                  builder: (context, _) {
                    return _CertaintyBar(
                      certainty:  r.certainty,
                      barColor:   band.barColor,
                      trackColor: band.bgColor,
                      progress:   _barAnim.value,
                    );
                  },
                ),
                // Description
                if (_descExpanded && r.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.constitutional,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtleGrey,
                          height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// CERTAINTY BAR 

class _CertaintyBar extends StatelessWidget {
  final int    certainty;
  final Color  barColor;
  final Color  trackColor;
  final double progress; // 0.0 → 1.0 animation progress

  const _CertaintyBar({
    required this.certainty,
    required this.barColor,
    required this.trackColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final fillFraction = (certainty / 100) * progress;
    return LayoutBuilder(builder: (context, constraints) {
      final totalW = constraints.maxWidth;
      return Stack(
        children: [
          // Track
          Container(
            height: 6,
            width: totalW,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Fill
          Container(
            height: 6,
            width: totalW * fillFraction,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      );
    });
  }
}

// PROCEED BUTTON 

class _ProceedButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ProceedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.description_outlined,
              size: 18, color: AppColors.headerText),
          label: const Text(
            'Generate SOAP Note',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.headerText),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sectionHeader,
            foregroundColor: AppColors.headerText,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}