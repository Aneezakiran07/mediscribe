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
import 'examination_screen.dart';

class LabsScreen extends StatefulWidget {
  final PatientInfo?         patient;
  final HistoryFormData?     history;
  final SystemicHistoryData? systemic;
  final VitalsData?          vitals;
  final String?              existingSessionId;
  final LabData?             existingLabs;
  final ExaminationData?     existingExamination;
  final SoapNote?            existingSoap;

  const LabsScreen({
    super.key,
    this.patient,
    this.history,
    this.systemic,
    this.vitals,
    this.existingSessionId,
    this.existingLabs,
    this.existingExamination,
    this.existingSoap,
  });

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  late LabData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.existingLabs ?? LabData();
  }

  // Track which panels are expanded
  final Set<int> _expanded = {0, 1, 2, 3}; // first 4 open by default

  int get _abnormalCount {
    int count = 0;
    for (int p = 0; p < kLabPanels.length; p++) {
      final panel = kLabPanels[p];
      for (int t = 0; t < panel.tests.length; t++) {
        final v = _data.getValue(p, t);
        if (v != null && panel.tests[t].interpret(v).isAbnormal) count++;
      }
    }
    return count;
  }

  void _onSave() {
  final abnormals = _data.abnormalSummary;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaveSummarySheet(
      abnormals: abnormals,
      onConfirm: () {
        Navigator.pop(context); // close sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExaminationScreen(
              autoFlags:            [],
              patient:              widget.patient,
              history:              widget.history,
              systemic:             widget.systemic,
              vitals:               widget.vitals,
              labs:                 _data,
              existingSessionId:    widget.existingSessionId,
              existingExamination:  widget.existingExamination,
              existingSoap:         widget.existingSoap,
            ),
          ),
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _LabsAppBar(abnormalCount: _abnormalCount),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Page heading
                  _PageHeading(abnormalCount: _abnormalCount),
                  const SizedBox(height: 16),

                  // Lab panels — data driven
                  ...List.generate(kLabPanels.length, (p) {
                    return _LabPanelCard(
                      panelIndex: p,
                      panel: kLabPanels[p],
                      data: _data,
                      expanded: _expanded.contains(p),
                      onToggle: () => setState(() {
                        _expanded.contains(p)
                            ? _expanded.remove(p)
                            : _expanded.add(p);
                      }),
                      onValueChanged: () => setState(() {}),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Cultures section (text-based)
                  _CulturesCard(
                    data: _data,
                    onChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: 28),

                  // Save button
                  _SaveButton(onPressed: _onSave),

                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Leave fields blank if test not performed',
                      style: TextStyle(fontSize: 11, color: AppColors.subtleGrey),
                    ),
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
//app bar
class _LabsAppBar extends StatelessWidget {
  final int abnormalCount;
  const _LabsAppBar({required this.abnormalCount});

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
                onPressed: () => Navigator.maybePop(context),
              ),
              const Icon(Icons.science_outlined,
                  color: AppColors.headerText, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('MediScribe AI',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headerText)),
              ),
              if (abnormalCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12, color: AppColors.dangerText),
                      const SizedBox(width: 4),
                      Text('$abnormalCount Abnormal',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerText)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  final int abnormalCount;
  const _PageHeading({required this.abnormalCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Laboratory Data Entry',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.bodyText,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(
          abnormalCount == 0
              ? 'Enter results — leave blank if not performed.'
              : '$abnormalCount abnormal value${abnormalCount > 1 ? 's' : ''} flagged.',
          style: TextStyle(
              fontSize: 13,
              color: abnormalCount > 0
                  ? AppColors.dangerText
                  : AppColors.subtleGrey),
        ),
      ],
    );
  }
}

class _LabPanelCard extends StatelessWidget {
  final int panelIndex;
  final LabPanel panel;
  final LabData data;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onValueChanged;

  const _LabPanelCard({
    required this.panelIndex,
    required this.panel,
    required this.data,
    required this.expanded,
    required this.onToggle,
    required this.onValueChanged,
  });

  int get _abnormalInPanel {
    int count = 0;
    for (int t = 0; t < panel.tests.length; t++) {
      final v = data.getValue(panelIndex, t);
      if (v != null && panel.tests[t].interpret(v).isAbnormal) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final abnormals = _abnormalInPanel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: abnormals > 0 ? AppColors.warnBorder : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Panel header — tappable to expand/collapse
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.constitutional,
                borderRadius: expanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15))
                    : BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(panel.icon, size: 16, color: AppColors.sectionHeader),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(panel.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sectionHeader)),
                  ),
                  if (abnormals > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.dangerBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$abnormals',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dangerText)),
                          const SizedBox(width: 3),
                          const Icon(Icons.warning_amber_rounded,
                              size: 10, color: AppColors.dangerText),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.subtleGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Test rows
          if (expanded) ...[
            // Column headers
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 90,
                    child: Text('Test',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleGrey)),
                  ),
                  const Expanded(
                    child: Text('Value',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleGrey)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('Result',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.subtleGrey)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            ...List.generate(panel.tests.length, (t) {
              final isLast = t == panel.tests.length - 1;
              return _LabTestRow(
                test: panel.tests[t],
                value: data.getValue(panelIndex, t),
                isLast: isLast,
                onChanged: (v) {
                  data.setValue(panelIndex, t, v);
                  onValueChanged();
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

//one row per test inside a panel
class _LabTestRow extends StatefulWidget {
  final LabTest test;
  final double? value;
  final bool isLast;
  final ValueChanged<double?> onChanged;

  const _LabTestRow({
    required this.test,
    required this.value,
    required this.isLast,
    required this.onChanged,
  });

  @override
  State<_LabTestRow> createState() => _LabTestRowState();
}

class _LabTestRowState extends State<_LabTestRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value != null ? widget.value.toString() : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  LabInterpretation? get _interp {
    final v = widget.value;
    if (v == null) return null;
    return widget.test.interpret(v);
  }

  @override
  Widget build(BuildContext context) {
    final interp = _interp;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Test name
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.test.shortName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bodyText)),
                    Text(widget.test.unit,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.subtleGrey)),
                  ],
                ),
              ),

              // Input field
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: interp != null && interp.isAbnormal
                        ? interp.bgColor
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: interp != null
                          ? interp.borderColor
                          : AppColors.divider,
                      width: interp != null && interp.isAbnormal ? 1.5 : 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: interp != null && interp.isAbnormal
                            ? interp.textColor
                            : AppColors.bodyText),
                    decoration: InputDecoration(
                      hintText: widget.test.hint ?? '',
                      hintStyle: const TextStyle(
                          color: AppColors.subtleGrey, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) {
                      widget.onChanged(double.tryParse(v));
                    },
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Result badge
              SizedBox(
                width: 80,
                child: interp == null
                    ? Center(
                        child: Text('-',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.subtleGrey)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: interp.bgColor == Colors.transparent
                              ? AppColors.constitutional
                              : interp.bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: interp.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (interp.icon != null) ...[
                              Icon(interp.icon,
                                  size: 10, color: interp.textColor),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                interp.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: interp.textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (!widget.isLast)
          const Divider(height: 1, color: AppColors.divider, indent: 14, endIndent: 14),
      ],
    );
  }
}

// CULTURES CARD OBV
class _CulturesCard extends StatelessWidget {
  final LabData data;
  final VoidCallback onChanged;

  const _CulturesCard({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.biotech_outlined,
                    size: 16, color: AppColors.sectionHeader),
                SizedBox(width: 8),
                Text('Cultures & Sensitivities',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sectionHeader)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _CultureField(
                  label: 'Blood Culture',
                  hint: 'Organism, sensitivity, resistance...',
                  value: data.bloodCultureResult,
                  onChanged: (v) {
                    data.bloodCultureResult = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                _CultureField(
                  label: 'Urine Culture',
                  hint: 'Organism, colony count, sensitivity...',
                  value: data.urineCultureResult,
                  onChanged: (v) {
                    data.urineCultureResult = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                _CultureField(
                  label: 'Sputum Culture',
                  hint: 'Organism, AFB result, sensitivity...',
                  value: data.sputumCultureResult,
                  onChanged: (v) {
                    data.sputumCultureResult = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                _CultureField(
                  label: 'Wound / Other Culture',
                  hint: 'Site, organism, sensitivity...',
                  value: data.woundCultureResult,
                  onChanged: (v) {
                    data.woundCultureResult = v;
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CultureField extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  const _CultureField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          maxLines: 2,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.subtleGrey, fontSize: 12),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.sectionHeader, width: 1.5)),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sectionHeader,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save_outlined, color: AppColors.headerText, size: 18),
              SizedBox(width: 8),
              Text('Save & Continue to Examination',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerText)),
            ],
          ),
        ),
      );
}

class _SaveSummarySheet extends StatelessWidget {
  final List<String> abnormals;
  final VoidCallback onConfirm;

  const _SaveSummarySheet(
      {required this.abnormals, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Lab Summary',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bodyText)),
          const SizedBox(height: 4),

          if (abnormals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.normalBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle_outline,
                        color: AppColors.normalText, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('All entered values are within normal range.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.bodyText)),
                ],
              ),
            )
          else ...[
            Text('${abnormals.length} abnormal value${abnormals.length > 1 ? 's' : ''} found:',
                style: TextStyle(fontSize: 13, color: AppColors.subtleGrey)),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: abnormals
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.dangerText),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(a,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.bodyText)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sectionHeader,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Continue',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerText)),
            ),
          ),
        ],
      ),
    );
  }
}
