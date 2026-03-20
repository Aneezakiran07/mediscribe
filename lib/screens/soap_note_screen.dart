import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import '../models/history_models.dart';
import '../models/systemic_models.dart';
import '../models/vitals_models.dart';
import '../models/lab_models.dart';
import '../models/examination_models.dart';
import '../models/soap_models.dart';
import '../services/patient_repository.dart';

class SoapNoteGenerator {

  static SoapNote generate({
    required PatientInfo patient,
    required HistoryFormData history,
    required SystemicHistoryData systemic,
    required VitalsData vitals,
    required ExaminationData examination,
    required LabData labs,
  }) {
    final note = SoapNote();
    note.subjective  = _buildSubjective(patient, history, systemic);
    note.objective   = _buildObjective(vitals, examination, labs);
    note.assessment  = _buildAssessment(examination);
    note.plan        = _buildPlan(examination, labs);
    note.generatedAt = DateTime.now();
    return note;
  }

  static String _buildSubjective(
    PatientInfo patient,
    HistoryFormData history,
    SystemicHistoryData systemic,
  ) {
    final buf = StringBuffer();

    // Patient demographics
    final name   = patient.fullName.isNotEmpty ? patient.fullName : 'Unknown Patient';
    final age    = patient.age != null ? '${patient.age}-year-old' : '';
    final gender = patient.gender.isNotEmpty ? patient.gender.toLowerCase() : '';
    final mrn    = patient.patientId.isNotEmpty ? '  |  MR# ${patient.patientId}' : '';
    buf.writeln('Patient: $name$mrn');
    buf.writeln('$age $gender, ${patient.modeOfAdmission} admission.');
    buf.writeln('');

    // Chief complaints
    if (history.complaintDetails.isNotEmpty) {
      buf.writeln('Chief Complaint(s):');
      for (final c in history.complaintDetails) {
        final dur = '${c.durationValue} ${c.durationUnit}';
        final sev = c.severity.isNotEmpty ? ' (${c.severity})' : '';
        buf.write('• ${c.complaint} for $dur$sev');
        if (c.notes.isNotEmpty) buf.write(' — ${c.notes}');
        buf.writeln('');
      }
      buf.writeln('');
    } else if (history.complaints.isNotEmpty) {
      buf.writeln('Chief Complaint(s): ${history.complaints.join(', ')}');
      buf.writeln('');
    }

    // Past medical history
    final pmhParts = <String>[];
    if (history.knownConditions.isNotEmpty) pmhParts.add(history.knownConditions.join(', '));
    if (history.hadHospitalizations == true && history.hospitalizationDetails.isNotEmpty) {
      pmhParts.add('Hospitalizations: ${history.hospitalizationDetails}');
    }
    if (history.hadSurgeries == true && history.surgeryDetails.isNotEmpty) {
      pmhParts.add('Surgeries: ${history.surgeryDetails}');
    }
    if (pmhParts.isNotEmpty) {
      buf.writeln('Past Medical History: ${pmhParts.join('; ')}');
    } else {
      buf.writeln('Past Medical History: Not significant.');
    }

    // Medications
    if (history.currentDrugs.isNotEmpty) {
      buf.writeln('Current Medications: ${history.currentDrugs.join(', ')}');
    } else if (history.onRegularMedication == false) {
      buf.writeln('Current Medications: None reported.');
    }

    // Allergies
    if (history.hasAllergies == true && history.allergyDetails.isNotEmpty) {
      buf.writeln('Allergies: ${history.allergyDetails}');
    } else if (history.hasAllergies == false) {
      buf.writeln('Allergies: NKDA (No Known Drug Allergies).');
    }

    // Social history
    final socialParts = <String>[];
    if (history.smoking.isNotEmpty)          socialParts.add('Smoking: ${history.smoking}');
    if (history.alcohol.isNotEmpty)          socialParts.add('Alcohol: ${history.alcohol}');
    if (history.occupation.isNotEmpty)       socialParts.add('Occupation: ${history.occupation}');
    if (history.livingConditions.isNotEmpty) socialParts.add('Living: ${history.livingConditions}');
    if (socialParts.isNotEmpty) {
      buf.writeln('Social History: ${socialParts.join('; ')}');
    }

    // Family history
    if (history.familyMembers.isNotEmpty) {
      final famParts = history.familyMembers
          .where((m) => m.conditions.isNotEmpty && m.relationship.isNotEmpty)
          .map((m) {
            final deceased = m.isDeceased ? ' (deceased)' : '';
            return '${m.relationship}$deceased: ${m.conditions.join(', ')}';
          })
          .toList();
      if (famParts.isNotEmpty) {
        buf.writeln('Family History: ${famParts.join('; ')}');
      }
    }

    // Positive systemic review
    final positives = systemic.positiveSymptoms;
    if (positives.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Review of Systems (Positive):');
      for (final s in positives) {
        buf.writeln('• $s');
      }
    }

    return buf.toString().trimRight();
  }

  static String _buildObjective(
    VitalsData vitals,
    ExaminationData examination,
    LabData labs,
  ) {
    final buf = StringBuffer();

    // Vitals
    buf.writeln('Vital Signs:');
    if (vitals.systolic != null && vitals.diastolic != null) {
      buf.writeln('• BP: ${vitals.systolic!.toStringAsFixed(0)}/${vitals.diastolic!.toStringAsFixed(0)} mmHg');
    }
    if (vitals.pulse != null) {
      buf.writeln('• Pulse: ${vitals.pulse!.toStringAsFixed(0)} bpm');
    }
    if (vitals.temperature != null) {
      final tempC = vitals.tempAsCelsius.toStringAsFixed(1);
      final tempF = vitals.isFahrenheit
          ? ' (${vitals.temperature!.toStringAsFixed(1)}°F)'
          : '';
      buf.writeln('• Temperature: ${tempC}°C$tempF');
    }
    if (vitals.respiratoryRate != null) {
      buf.writeln('• Respiratory Rate: ${vitals.respiratoryRate!.toStringAsFixed(0)}/min');
    }
    if (vitals.spO2 != null) {
      buf.writeln('• SpO₂: ${vitals.spO2!.toStringAsFixed(0)}%');
    }
    if (vitals.bmi != null) {
      buf.writeln('• BMI: ${vitals.bmi!.toStringAsFixed(1)} kg/m²');
    }
    if (vitals.bloodGlucose != null) {
      final fasting = vitals.isFastingGlucose ? 'Fasting' : 'Random';
      buf.writeln('• Blood Glucose ($fasting): ${vitals.bloodGlucose!.toStringAsFixed(1)} mg/dL');
    }
    for (final cv in vitals.customVitals) {
      if (cv.name.isNotEmpty && cv.value.isNotEmpty) {
        buf.writeln('• ${cv.name}: ${cv.value} ${cv.unit}');
      }
    }

    // Physical examination findings per system
    buf.writeln('');
    buf.writeln('Physical Examination:');
    for (final config in kExamConfigs) {
      final session = examination.sessions[config.examId];
      if (session == null || session.answers.isEmpty) continue;

      final allFindings = <String>[];
      for (final entry in session.answers.entries) {
        if (entry.value.isNotEmpty) {
          allFindings.addAll(entry.value);
        }
      }
      if (allFindings.isEmpty) continue;

      buf.writeln('${config.title}:');
      for (final f in allFindings) {
        buf.writeln('  • $f');
      }
    }

    // Alert messages from examination rules
    final allAlerts = <String>[];
    for (final config in kExamConfigs) {
      final session = examination.sessions[config.examId];
      if (session != null) allAlerts.addAll(session.alertMessages);
    }
    if (allAlerts.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Clinical Alerts:');
      for (final a in allAlerts) {
        buf.writeln('• $a');
      }
    }

    // Lab results — all entered values grouped by panel
    bool anyLabEntered = false;
    final labBuf = StringBuffer();
    for (int p = 0; p < kLabPanels.length; p++) {
      final panel = kLabPanels[p];
      final panelLines = <String>[];
      for (int t = 0; t < panel.tests.length; t++) {
        final v = labs.getValue(p, t);
        if (v != null) {
          final interp = panel.tests[t].interpret(v);
          final flag   = interp.isAbnormal ? ' [${interp.label.toUpperCase()}]' : '';
          panelLines.add('  ${panel.tests[t].shortName}: $v ${panel.tests[t].unit}$flag');
        }
      }
      if (panelLines.isNotEmpty) {
        anyLabEntered = true;
        labBuf.writeln('${panel.title}:');
        for (final line in panelLines) labBuf.writeln(line);
      }
    }
    if (anyLabEntered) {
      buf.writeln('');
      buf.writeln('Laboratory Results:');
      buf.write(labBuf.toString());
    } else {
      buf.writeln('');
      buf.writeln('Laboratory Results: No values entered.');
    }

    // Culture results
    final cultures = <String, String>{
      'Blood Culture':  labs.bloodCultureResult,
      'Urine Culture':  labs.urineCultureResult,
      'Sputum Culture': labs.sputumCultureResult,
      'Wound Culture':  labs.woundCultureResult,
    };
    final filledCultures = cultures.entries.where((e) => e.value.trim().isNotEmpty);
    if (filledCultures.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Culture Results:');
      for (final e in filledCultures) {
        buf.writeln('• ${e.key}: ${e.value}');
      }
    }

    return buf.toString().trimRight();
  }

  // _buildAssessment
  //
  // Uses the SAME calculateCertaintyFactors() engine as DiagnosisScreen so the
  // SOAP note always reflects exactly what the doctor saw on the diagnosis screen.
  //
  // Rules:
  //   • Skip systems with no answers (same as DiagnosisScreen)
  //   • Filter certainty > 0  (same filter as DiagnosisScreen)
  //   • Sort highest certainty first (same order as DiagnosisScreen)
  //   • If nothing passes, say so explicitly rather than leaving Assessment blank
  static String _buildAssessment(ExaminationData examination) {
    final buf = StringBuffer();
    buf.writeln('Differential Diagnosis:');

    bool anySystemWritten = false;

    for (final config in kExamConfigs) {
      final exam    = KBService.getExam(config.examId);
      if (exam == null) continue;

      final session = examination.sessions[config.examId];

      // Skip systems that were never opened or have no answers — same gate as
      // DiagnosisScreen._initDiagnoses()
      if (session == null || session.answers.isEmpty) continue;

      // Use the exact same engine as DiagnosisScreen
      final factors = session.calculateCertaintyFactors(exam);

      // Apply the same certainty > 0 filter as DiagnosisScreen
      final visible = factors
          .where((f) => (f['certainty'] as int) > 0)
          .toList();

      // If every diagnosis for this system was filtered out, skip the section
      // so we don't print an empty system header
      if (visible.isEmpty) continue;

      anySystemWritten = true;
      buf.writeln('');
      buf.writeln('${config.title}:');

      for (final dx in visible) {
        final certainty = dx['certainty'] as int;
        final band = certainty >= 70 ? 'Probable'
            : certainty >= 40       ? 'Possible'
            :                         'Unlikely';
        final bar = _certaintyBar(certainty);
        buf.writeln('  • ${dx['name']}');
        buf.writeln('    $bar $certainty% — $band');
        if ((dx['description'] as String).isNotEmpty) {
          buf.writeln('    ${dx['description']}');
        }
      }
    }

    // Nothing passed the filter at all
    if (!anySystemWritten) {
      buf.writeln('');
      buf.writeln('No diagnosis scored above 0% based on current findings.');
      buf.writeln('Complete more examination steps to generate a differential diagnosis.');
    }

    return buf.toString().trimRight();
  }

  static String _certaintyBar(int certainty) {
    final filled = (certainty / 10).round().clamp(0, 10);
    return '[' + ('█' * filled) + ('░' * (10 - filled)) + ']';
  }

  static String _buildPlan(ExaminationData examination, LabData labs) {
    final buf = StringBuffer();

    buf.writeln('Investigations:');

    // Suggest investigations based on abnormal labs
    if (labs.hasAnyAbnormal) {
      buf.writeln('• Repeat abnormal laboratory tests to confirm findings.');
    }

    // Suggest system-specific workup based on flagged alerts
    final allAlerts = <String>[];
    for (final config in kExamConfigs) {
      final session = examination.sessions[config.examId];
      if (session != null && session.alertMessages.isNotEmpty) {
        allAlerts.addAll(session.alertMessages);
      }
    }
    if (allAlerts.isNotEmpty) {
      buf.writeln('• Urgent workup indicated — see clinical alerts above.');
    }

    buf.writeln('• ECG, Chest X-ray, and additional imaging as clinically indicated.');
    buf.writeln('• Specialist referral if diagnosis remains uncertain.');
    buf.writeln('');
    buf.writeln('Treatment:');
    buf.writeln('• [Enter medications, dosages, and duration here]');
    buf.writeln('');
    buf.writeln('Follow-up:');
    buf.writeln('• [Enter follow-up instructions and review date here]');
    buf.writeln('');
    buf.writeln('Patient Education:');
    buf.writeln('• [Enter patient counselling points here]');

    return buf.toString().trimRight();
  }
}

// SOAP Note Screen
class SoapNoteScreen extends StatefulWidget {
  final PatientInfo         patient;
  final HistoryFormData     history;
  final SystemicHistoryData systemic;
  final VitalsData          vitals;
  final ExaminationData     examination;
  final LabData             labs;
  final String?             existingSessionId;

  const SoapNoteScreen({
    super.key,
    required this.patient,
    required this.history,
    required this.systemic,
    required this.vitals,
    required this.examination,
    required this.labs,
    this.existingSessionId,
  });

  @override
  State<SoapNoteScreen> createState() => _SoapNoteScreenState();
}

class _SoapNoteScreenState extends State<SoapNoteScreen>
    with SingleTickerProviderStateMixin {

  late SoapNote _note;
  late TabController _tabController;

  final _sCtrl = TextEditingController();
  final _oCtrl = TextEditingController();
  final _aCtrl = TextEditingController();
  final _pCtrl = TextEditingController();

  bool _edited  = false;
  bool _kbReady = false;

  static const _tabs      = ['S', 'O', 'A', 'P'];
  static const _tabLabels = ['Subjective', 'Objective', 'Assessment', 'Plan'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    KBService.init().then((_) {
      if (!mounted) return;
      setState(() {
        _kbReady = true;
        _generateNote();
      });
    });
  }

  void _generateNote() {
    _note = SoapNoteGenerator.generate(
      patient:     widget.patient,
      history:     widget.history,
      systemic:    widget.systemic,
      vitals:      widget.vitals,
      examination: widget.examination,
      labs:        widget.labs,
    );
    _sCtrl.text = _note.subjective;
    _oCtrl.text = _note.objective;
    _aCtrl.text = _note.assessment;
    _pCtrl.text = _note.plan;
    _edited = false;
  }

  void _onTextChanged() {
    if (!_edited) setState(() => _edited = true);
  }

  void _onCopyAll() {
    final full = 'SUBJECTIVE\n${_sCtrl.text}\n\n'
        'OBJECTIVE\n${_oCtrl.text}\n\n'
        'ASSESSMENT\n${_aCtrl.text}\n\n'
        'PLAN\n${_pCtrl.text}';
    Clipboard.setData(ClipboardData(text: full));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Full SOAP note copied to clipboard'),
      backgroundColor: AppColors.sectionHeader,
      duration: Duration(seconds: 2),
    ));
  }

  void _onRegenerate() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerate SOAP Note?'),
        content: const Text(
          'This will discard your edits and regenerate the note from your collected data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(_generateNote);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  // Save to Hive
  bool _saving = false;
  bool _saved  = false;

  Future<void> _saveToHive() async {
    if (_saving) return;
    setState(() => _saving = true);

    final soap = SoapNote()
      ..subjective  = _sCtrl.text
      ..objective   = _oCtrl.text
      ..assessment  = _aCtrl.text
      ..plan        = _pCtrl.text
      ..generatedAt = DateTime.now();

    try {
      await PatientRepository.saveSession(
        patient:           widget.patient,
        history:           widget.history,
        systemic:          widget.systemic,
        vitals:            widget.vitals,
        labs:              widget.labs,
        examination:       widget.examination,
        soap:              soap,
        existingSessionId: widget.existingSessionId,
      );
      if (!mounted) return;
      setState(() { _saving = false; _saved = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Patient record saved'),
        backgroundColor: AppColors.sectionHeader,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: AppColors.emergencyRed,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sCtrl.dispose();
    _oCtrl.dispose();
    _aCtrl.dispose();
    _pCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _buildAppBar(),
          _buildPatientBanner(),
          _buildTabBar(),
          Expanded(
            child: !_kbReady
                ? const Center(child: CircularProgressIndicator(color: AppColors.sectionHeader))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _SoapSection(
                        sectionLetter: 'S',
                        sectionLabel:  'Subjective',
                        description:   'Chief complaints, history, review of systems — what the patient tells you.',
                        controller:    _sCtrl,
                        onChanged:     _onTextChanged,
                      ),
                      _SoapSection(
                        sectionLetter: 'O',
                        sectionLabel:  'Objective',
                        description:   'Vitals, physical examination findings, lab results — measurable data.',
                        controller:    _oCtrl,
                        onChanged:     _onTextChanged,
                      ),
                      _SoapSection(
                        sectionLetter: 'A',
                        sectionLabel:  'Assessment',
                        description:   'Differential diagnoses with certainty levels from examination engine.',
                        controller:    _aCtrl,
                        onChanged:     _onTextChanged,
                      ),
                      _SoapSection(
                        sectionLetter: 'P',
                        sectionLabel:  'Plan',
                        description:   'Investigations, treatment, follow-up, and patient education.',
                        controller:    _pCtrl,
                        onChanged:     _onTextChanged,
                      ),
                    ],
                  ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.headerText, size: 22),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Icon(Icons.psychology_outlined, color: AppColors.headerText, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MediScribe AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headerText),
                ),
              ),
              if (_edited)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warnBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warnBorder),
                  ),
                  child: const Text(
                    'Unsaved',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warnText),
                  ),
                ),
              IconButton(
                icon: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.headerText))
                    : Icon(_saved ? Icons.check_circle_outline : Icons.save_outlined,
                        color: AppColors.headerText, size: 20),
                tooltip: 'Save record',
                onPressed: _saveToHive,
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, color: AppColors.headerText, size: 20),
                tooltip: 'Copy full note',
                onPressed: _onCopyAll,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.headerText, size: 20),
                tooltip: 'Regenerate',
                onPressed: _onRegenerate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientBanner() {
    final p      = widget.patient;
    final name   = p.fullName.isNotEmpty ? p.fullName : 'Unknown Patient';
    final details = [
      if (p.age != null) '${p.age}y',
      if (p.gender.isNotEmpty) p.gender,
      if (p.patientId.isNotEmpty) p.patientId,
      p.modeOfAdmission,
    ].join(' · ');

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.sectionHeader, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.bodyText),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12, color: AppColors.subtleGrey),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sectionHeader.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'SOAP Note',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sectionHeader),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.divider),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.sectionHeader,
            unselectedLabelColor: AppColors.subtleGrey,
            indicatorColor: AppColors.sectionHeader,
            indicatorWeight: 2.5,
            tabs: List.generate(4, (i) => Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _tabs[i],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _tabLabels[i],
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveAndGoHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sectionHeader,
                disabledBackgroundColor: AppColors.constitutional,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.headerText))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined, color: AppColors.headerText, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Save & Back to Home',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headerText,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.home_outlined, color: AppColors.headerText, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text(
              'Discard & Exit without saving',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtleGrey,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.subtleGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndGoHome() async {
    if (_saving) return;
    setState(() => _saving = true);

    final soap = SoapNote()
      ..subjective  = _sCtrl.text
      ..objective   = _oCtrl.text
      ..assessment  = _aCtrl.text
      ..plan        = _pCtrl.text
      ..generatedAt = DateTime.now();

    try {
      await PatientRepository.saveSession(
        patient:           widget.patient,
        history:           widget.history,
        systemic:          widget.systemic,
        vitals:            widget.vitals,
        labs:              widget.labs,
        examination:       widget.examination,
        soap:              soap,
        existingSessionId: widget.existingSessionId,
      );
      if (!mounted) return;
      setState(() { _saving = false; _saved = true; });
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: AppColors.emergencyRed,
        duration: const Duration(seconds: 3),
      ));
    }
  }
}

// One editable SOAP section tab
class _SoapSection extends StatelessWidget {
  final String sectionLetter;
  final String sectionLabel;
  final String description;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SoapSection({
    required this.sectionLetter,
    required this.sectionLabel,
    required this.description,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.sectionHeader,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      sectionLetter,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: AppColors.headerText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionLabel,
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.headerText,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.headerText.withValues(alpha: 0.8),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Editable text area
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toolbar row
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.constitutional,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13), topRight: Radius.circular(13),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.sectionHeader),
                      const SizedBox(width: 6),
                      const Text(
                        'Edit freely — auto-generated from your session data',
                        style: TextStyle(fontSize: 11, color: AppColors.sectionHeader, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: controller.text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Section copied'),
                            duration: Duration(seconds: 1),
                            backgroundColor: AppColors.sectionHeader,
                          ));
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.copy_outlined, size: 16, color: AppColors.sectionHeader),
                        ),
                      ),
                    ],
                  ),
                ),

                // Text field
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextFormField(
                    controller: controller,
                    onChanged: (_) => onChanged(),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.bodyText,
                      height: 1.65,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




