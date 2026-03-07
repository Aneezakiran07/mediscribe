import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'examination_screen.dart';
import '../core/app_colors.dart';

// VITAL STATUS ENUM
enum VitalStatus { normal, warning, danger }

// VITAL INTERPRETATION MODEL
// Holds the result of running a vital through the engine
class VitalInterpretation {
  final VitalStatus status;
  final String label;   // e.g. "Normal", "Hypertension"
  final String? detail; // short clinical note shown below label

  const VitalInterpretation({
    required this.status,
    required this.label,
    this.detail,
  });

  Color get textColor {
    switch (status) {
      case VitalStatus.normal:  return AppColors.normalText;
      case VitalStatus.warning: return AppColors.warnText;
      case VitalStatus.danger:  return AppColors.dangerText;
    }
  }

  Color get bgColor {
    switch (status) {
      case VitalStatus.normal:  return AppColors.normalBg;
      case VitalStatus.warning: return AppColors.warnBg;
      case VitalStatus.danger:  return AppColors.dangerBg;
    }
  }

  Color get borderColor {
    switch (status) {
      case VitalStatus.normal:  return AppColors.normalBorder;
      case VitalStatus.warning: return AppColors.warnBorder;
      case VitalStatus.danger:  return AppColors.dangerBorder;
    }
  }

  bool get isAbnormal => status != VitalStatus.normal;
}

// CLINICAL ENGINE
// One static method per vital. All ranges from JNC 8 / WHO.
// When integrating: move to lib/services/vitals_engine.dart
class VitalsEngine {
  VitalsEngine._();

  // Blood pressure - JNC 8 / AHA 2017
  static VitalInterpretation interpretBP(double sys, double dia) {
    if (sys < 90 || dia < 60) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hypotension',
        detail: 'BP critically low — assess for shock',
      );
    }
    if (sys >= 180 || dia >= 120) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hypertensive Crisis',
        detail: 'Urgent evaluation required',
      );
    }
    if (sys >= 160 || dia >= 100) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hypertension Stage 2',
        detail: 'Pharmacologic therapy indicated',
      );
    }
    if (sys >= 140 || dia >= 90) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Hypertension Stage 1',
        detail: 'Lifestyle modification advised',
      );
    }
    if (sys >= 130 || dia >= 80) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Elevated BP',
        detail: 'Pre-hypertension range',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // Pulse
  static VitalInterpretation interpretPulse(double bpm) {
    if (bpm < 40) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Bradycardia',
        detail: 'HR critically low — assess for heart block',
      );
    }
    if (bpm < 60) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Bradycardia',
        detail: 'HR < 60 bpm',
      );
    }
    if (bpm > 150) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Tachycardia',
        detail: 'HR critically high — assess for arrhythmia',
      );
    }
    if (bpm > 100) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Tachycardia',
        detail: 'HR > 100 bpm — investigate cause',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // Temperature - takes celsius regardless of display unit
  static VitalInterpretation interpretTempC(double c) {
    if (c < 35.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hypothermia',
        detail: 'Core temp < 35°C — immediate warming',
      );
    }
    if (c < 36.1) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Low Temperature',
        detail: 'Slightly below normal',
      );
    }
    if (c > 41.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hyperpyrexia',
        detail: 'Temp > 41°C — emergency cooling',
      );
    }
    if (c > 39.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'High Fever',
        detail: 'Temp > 39°C — investigate infection/sepsis',
      );
    }
    if (c > 37.5) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Fever',
        detail: 'Temp > 37.5°C',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // Respiratory rate
  static VitalInterpretation interpretRR(double rr) {
    if (rr < 8) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Bradypnea',
        detail: 'RR < 8 — risk of respiratory failure',
      );
    }
    if (rr < 12) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Bradypnea',
        detail: 'RR below normal (12–20/min)',
      );
    }
    if (rr > 30) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Tachypnea',
        detail: 'RR > 30 — respiratory distress',
      );
    }
    if (rr > 20) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Tachypnea',
        detail: 'RR above normal — assess lungs/cardiac',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // SpO2
  static VitalInterpretation interpretSpO2(double pct) {
    if (pct < 90) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Hypoxia',
        detail: 'SpO₂ < 90% — urgent oxygen therapy',
      );
    }
    if (pct < 94) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Hypoxia',
        detail: 'SpO₂ 90–93% — consider supplemental O₂',
      );
    }
    if (pct < 96) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Low-normal SpO₂',
        detail: 'Monitor closely',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // BMI
  static VitalInterpretation interpretBMI(double bmi) {
    if (bmi < 16) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Severe Underweight',
        detail: 'BMI < 16 — nutritional assessment urgent',
      );
    }
    if (bmi < 18.5) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Underweight',
        detail: 'BMI 16–18.4',
      );
    }
    if (bmi < 25) {
      return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal BMI');
    }
    if (bmi < 30) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Overweight',
        detail: 'BMI 25–29.9',
      );
    }
    if (bmi < 35) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label: 'Obesity Class I',
        detail: 'BMI 30–34.9',
      );
    }
    return const VitalInterpretation(
      status: VitalStatus.danger,
      label: 'Obesity Class II–III',
      detail: 'BMI ≥ 35 — high cardiovascular risk',
    );
  }

  // Blood glucose - mmol/L
  static VitalInterpretation interpretGlucose(double mmol, bool fasting) {
    if (mmol < 3.9) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Hypoglycemia',
        detail: 'Glucose < 3.9 mmol/L',
      );
    }
    if (fasting) {
      if (mmol <= 5.5) return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal (Fasting)');
      if (mmol <= 6.9) {
        return const VitalInterpretation(
          status: VitalStatus.warning,
          label: 'Impaired Fasting Glucose',
          detail: 'Pre-diabetic range',
        );
      }
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Diabetes Range',
        detail: 'Fasting ≥ 7.0 mmol/L — further workup',
      );
    } else {
      if (mmol < 7.8) return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal (Random)');
      if (mmol < 11.1) {
        return const VitalInterpretation(
          status: VitalStatus.warning,
          label: 'Impaired Glucose Tolerance',
          detail: '7.8–11.0 mmol/L post-prandial',
        );
      }
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label: 'Diabetes Range',
        detail: 'Random ≥ 11.1 mmol/L',
      );
    }
  }

  // Auto-generate clinical flags from all entered vitals
  // Used to pre-populate the flags list shown at bottom + passed to next screen
  static List<String> generateFlags(VitalsData data) {
    final flags = <String>[];

    if (data.systolic != null && data.diastolic != null) {
      final i = interpretBP(data.systolic!, data.diastolic!);
      if (i.isAbnormal) flags.add('BP: ${i.label} (${data.systolic!.toInt()}/${data.diastolic!.toInt()} mmHg)');
    }
    if (data.pulse != null) {
      final i = interpretPulse(data.pulse!);
      if (i.isAbnormal) flags.add('Pulse: ${i.label} (${data.pulse!.toInt()} bpm)');
    }
    if (data.temperature != null) {
      final i = interpretTempC(data.tempAsCelsius);
      if (i.isAbnormal) {
        final display = data.isFahrenheit
            ? '${data.temperature!.toStringAsFixed(1)}°F'
            : '${data.temperature!.toStringAsFixed(1)}°C';
        flags.add('Temp: ${i.label} ($display)');
      }
    }
    if (data.respiratoryRate != null) {
      final i = interpretRR(data.respiratoryRate!);
      if (i.isAbnormal) flags.add('RR: ${i.label} (${data.respiratoryRate!.toInt()}/min)');
    }
    if (data.spO2 != null) {
      final i = interpretSpO2(data.spO2!);
      if (i.isAbnormal) flags.add('SpO₂: ${i.label} (${data.spO2!.toStringAsFixed(1)}%)');
    }
    if (data.bmi != null) {
      final i = interpretBMI(data.bmi!);
      if (i.isAbnormal) flags.add('BMI: ${i.label} (${data.bmi!.toStringAsFixed(1)})');
    }
    if (data.bloodGlucose != null) {
      final i = interpretGlucose(data.bloodGlucose!, data.isFastingGlucose);
      if (i.isAbnormal) flags.add('Glucose: ${i.label} (${data.bloodGlucose!.toStringAsFixed(1)} mmol/L)');
    }

    return flags;
  }
}

// VITALS DATA MODEL
// Clean plain-dart class - Hive annotations go here later
//
// Hive steps when ready:
//   1. Add: part 'vitals_data.g.dart';
//   2. Add: @HiveType(typeId: 4) above class
//   3. Add: @HiveField(n) above each field
//   4. Run: flutter pub run build_runner build
//   5. Save: Hive.box<VitalsData>('vitals').put(patientId, data);
//   6. Load: Hive.box<VitalsData>('vitals').get(patientId) ?? VitalsData();
class VitalsData {
  double? systolic;
  double? diastolic;
  double? pulse;
  double? temperature;
  bool isFahrenheit = true;
  double? respiratoryRate;
  double? spO2;
  double? weightKg;
  double? heightCm;
  double? bloodGlucose;
  bool isFastingGlucose = true;
  List<CustomVital> customVitals = [];

  // Derived - not stored in Hive, computed on access
  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final hM = heightCm! / 100;
    return weightKg! / (hM * hM);
  }

  double get tempAsCelsius {
    if (temperature == null) return 0;
    return isFahrenheit ? (temperature! - 32) * 5 / 9 : temperature!;
  }
}

// CUSTOM VITAL MODEL
// For doctor-added entries like CVP, ICP, ETCO2
// Hive: @HiveType(typeId: 5)
class CustomVital {
  String name;
  String value;
  String unit;
  String notes;

  CustomVital({
    this.name = '',
    this.value = '',
    this.unit = '',
    this.notes = '',
  });
}

// STANDALONE ENTRY - remove main() when integrating
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBackground,
        fontFamily: 'SF Pro Display',
        colorScheme: const ColorScheme.light(primary: AppColors.sectionHeader),
      ),
      home: const VitalsScreen(),
    );
  }
}

// VITALS SCREEN - main widget
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final VitalsData _data = VitalsData();
  bool _addCustomOpen = false;

  int get _flagCount => VitalsEngine.generateFlags(_data).length;

  void _onSave() {
    final flags = VitalsEngine.generateFlags(_data);

    // When integrating with Hive, save before navigating:
    // await Hive.box<VitalsData>('vitals').put(patientId, _data);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExaminationScreen(autoFlags: flags),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _AppBar(flagCount: _flagCount),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Screen title
                  const Text(
                    'Enter Vitals',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.bodyText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clinical flags appear as you type.',
                    style: TextStyle(fontSize: 13, color: AppColors.subtleGrey),
                  ),
                  const SizedBox(height: 20),

                  // Blood Pressure card
                  _BPCard(
                    systolic: _data.systolic,
                    diastolic: _data.diastolic,
                    onSysChanged: (v) => setState(() => _data.systolic = v),
                    onDiaChanged: (v) => setState(() => _data.diastolic = v),
                  ),
                  const SizedBox(height: 12),

                  // Pulse card
                  _SingleVitalCard(
                    title: 'Pulse',
                    unit: 'BPM',
                    hint: '72',
                    value: _data.pulse,
                    allowDecimal: false,
                    interpretation: _data.pulse != null
                        ? VitalsEngine.interpretPulse(_data.pulse!)
                        : null,
                    onChanged: (v) => setState(() => _data.pulse = v),
                  ),
                  const SizedBox(height: 12),

                  // Temperature card
                  _TempCard(
                    value: _data.temperature,
                    isFahrenheit: _data.isFahrenheit,
                    interpretation: _data.temperature != null
                        ? VitalsEngine.interpretTempC(_data.tempAsCelsius)
                        : null,
                    onChanged: (v) => setState(() => _data.temperature = v),
                    onUnitToggle: (isF) => setState(() {
                      // Convert existing value when toggling unit
                      if (_data.temperature != null) {
                        _data.temperature = isF
                            ? (_data.temperature! * 9 / 5) + 32
                            : (_data.temperature! - 32) * 5 / 9;
                      }
                      _data.isFahrenheit = isF;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Respiratory Rate card
                  _SingleVitalCard(
                    title: 'Respiratory Rate',
                    unit: 'breaths/min',
                    hint: '16',
                    value: _data.respiratoryRate,
                    allowDecimal: false,
                    interpretation: _data.respiratoryRate != null
                        ? VitalsEngine.interpretRR(_data.respiratoryRate!)
                        : null,
                    onChanged: (v) => setState(() => _data.respiratoryRate = v),
                  ),
                  const SizedBox(height: 12),

                  // SpO2 card
                  _SingleVitalCard(
                    title: 'Oxygen Saturation',
                    unit: 'SpO₂ %',
                    hint: '98',
                    value: _data.spO2,
                    allowDecimal: true,
                    interpretation: _data.spO2 != null
                        ? VitalsEngine.interpretSpO2(_data.spO2!)
                        : null,
                    onChanged: (v) => setState(() => _data.spO2 = v),
                  ),
                  const SizedBox(height: 12),

                  // Weight + Height → BMI card
                  _BMICard(
                    weight: _data.weightKg,
                    height: _data.heightCm,
                    bmi: _data.bmi,
                    bmiInterp: _data.bmi != null
                        ? VitalsEngine.interpretBMI(_data.bmi!)
                        : null,
                    onWeightChanged: (v) => setState(() => _data.weightKg = v),
                    onHeightChanged: (v) => setState(() => _data.heightCm = v),
                  ),
                  const SizedBox(height: 12),

                  // Blood Glucose card
                  _GlucoseCard(
                    value: _data.bloodGlucose,
                    isFasting: _data.isFastingGlucose,
                    interpretation: _data.bloodGlucose != null
                        ? VitalsEngine.interpretGlucose(
                            _data.bloodGlucose!, _data.isFastingGlucose)
                        : null,
                    onChanged: (v) => setState(() => _data.bloodGlucose = v),
                    onFastingChanged: (v) =>
                        setState(() => _data.isFastingGlucose = v),
                  ),
                  const SizedBox(height: 20),

                  // Auto-generated flags summary
                  if (_flagCount > 0)
                    _FlagsPanel(flags: VitalsEngine.generateFlags(_data)),

                  if (_flagCount > 0) const SizedBox(height: 20),

                  // Custom vitals list
                  ..._data.customVitals.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CustomVitalTile(
                      vital: e.value,
                      onRemove: () => setState(
                          () => _data.customVitals.removeAt(e.key)),
                    ),
                  )),

                  // Add custom vital button or form
                  _AddCustomSection(
                    isOpen: _addCustomOpen,
                    onToggle: () =>
                        setState(() => _addCustomOpen = !_addCustomOpen),
                    onAdd: (cv) => setState(() {
                      _data.customVitals.add(cv);
                      _addCustomOpen = false;
                    }),
                    onCancel: () => setState(() => _addCustomOpen = false),
                  ),
                  const SizedBox(height: 24),

                  // Save Vitals button
                  _SaveButton(flagCount: _flagCount, onSave: _onSave),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// APP BAR
class _AppBar extends StatelessWidget {
  final int flagCount;
  const _AppBar({required this.flagCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerText, size: 22),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Icon(Icons.psychology_outlined,
                  color: AppColors.headerText, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MediScribe AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headerText,
                  ),
                ),
              ),
              if (flagCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined,
                          color: AppColors.dangerText, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '$flagCount flag${flagCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerText,
                        ),
                      ),
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

// SHARED: VITAL CARD WRAPPER
// All vital cards share this shell - title + optional status strip + content
class _VitalCardShell extends StatelessWidget {
  final String title;
  final VitalInterpretation? interpretation;
  final Widget child;
  final Widget? trailing;

  const _VitalCardShell({
    required this.title,
    required this.child,
    this.interpretation,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = interpretation?.status == VitalStatus.danger;
    final isWarn   = interpretation?.status == VitalStatus.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDanger
              ? AppColors.dangerBorder
              : isWarn
                  ? AppColors.warnBorder
                  : AppColors.divider,
          width: isDanger ? 1.5 : 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sectionHeader,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),

          // Red/orange strip if abnormal
          if (interpretation != null && interpretation!.isAbnormal)
            _StatusStrip(interp: interpretation!),

          // Input area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// Coloured strip showing label + detail
class _StatusStrip extends StatelessWidget {
  final VitalInterpretation interp;
  const _StatusStrip({required this.interp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: interp.bgColor,
      child: Row(
        children: [
          Icon(
            interp.status == VitalStatus.danger
                ? Icons.error_rounded
                : Icons.warning_amber_rounded,
            color: interp.textColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            interp.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: interp.textColor,
            ),
          ),
          if (interp.detail != null) ...[
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '· ${interp.detail}',
                style: TextStyle(
                  fontSize: 11,
                  color: interp.textColor.withOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// SHARED: VITAL INPUT FIELD
// Outlined text field that turns red when abnormal
class _VitalInput extends StatelessWidget {
  final String label;
  final String hint;
  final VitalInterpretation? interp;
  final ValueChanged<String> onChanged;
  final bool allowDecimal;
  final String? suffixText;
  final double? initialValue;

  const _VitalInput({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.interp,
    this.allowDecimal = true,
    this.suffixText,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = interp?.status == VitalStatus.danger;
    final isWarn   = interp?.status == VitalStatus.warning;

    Color borderColor = const Color(0xFFBDBDBD);
    Color labelColor  = AppColors.subtleGrey;
    Color fillColor   = AppColors.background;
    Color textColor   = AppColors.bodyText;

    if (isDanger) {
      borderColor = AppColors.dangerBorder;
      labelColor  = AppColors.dangerText;
      fillColor   = AppColors.dangerBg;
      textColor   = AppColors.dangerText;
    } else if (isWarn) {
      borderColor = AppColors.warnBorder;
      labelColor  = AppColors.warnText;
    }

    return TextFormField(
      initialValue: initialValue != null
          ? (allowDecimal
              ? initialValue!.toStringAsFixed(allowDecimal ? 1 : 0)
              : initialValue!.toInt().toString())
          : null,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[\d.]') : RegExp(r'\d'),
        ),
      ],
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: labelColor),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          color: AppColors.subtleGrey.withOpacity(0.5),
        ),
        suffixText: suffixText,
        suffixStyle: TextStyle(fontSize: 13, color: labelColor),
        prefixIcon: isDanger
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(Icons.error_rounded,
                    color: AppColors.dangerText, size: 18),
              )
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// Status label shown below a field - "Normal", "Hypertension" etc
class _StatusLabel extends StatelessWidget {
  final VitalInterpretation? interp;
  const _StatusLabel({this.interp});

  @override
  Widget build(BuildContext context) {
    if (interp == null) {
      return const SizedBox(height: 18);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        interp!.label,
        style: TextStyle(
          fontSize: 12,
          color: interp!.textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// BLOOD PRESSURE CARD - two side-by-side fields
class _BPCard extends StatefulWidget {
  final double? systolic;
  final double? diastolic;
  final ValueChanged<double?> onSysChanged;
  final ValueChanged<double?> onDiaChanged;

  const _BPCard({
    required this.systolic,
    required this.diastolic,
    required this.onSysChanged,
    required this.onDiaChanged,
  });

  @override
  State<_BPCard> createState() => _BPCardState();
}

class _BPCardState extends State<_BPCard> {
  VitalInterpretation? get _interp {
    if (widget.systolic != null && widget.diastolic != null) {
      return VitalsEngine.interpretBP(widget.systolic!, widget.diastolic!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _VitalCardShell(
      title: 'Blood Pressure',
      interpretation: _interp,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VitalInput(
                  label: 'Systolic',
                  hint: '120',
                  interp: _interp,
                  allowDecimal: false,
                  initialValue: widget.systolic,
                  onChanged: (v) => widget.onSysChanged(double.tryParse(v)),
                ),
                _StatusLabel(interp: _interp?.status == VitalStatus.normal
                    ? _interp : null),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '/',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w200,
                  color: AppColors.subtleGrey.withOpacity(0.6),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VitalInput(
                  label: 'Diastolic',
                  hint: '80',
                  interp: _interp,
                  allowDecimal: false,
                  initialValue: widget.diastolic,
                  onChanged: (v) => widget.onDiaChanged(double.tryParse(v)),
                ),
                _StatusLabel(interp: _interp),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              'mmHg',
              style: TextStyle(fontSize: 11, color: AppColors.subtleGrey),
            ),
          ),
        ],
      ),
    );
  }
}

// SINGLE VITAL CARD - generic card for pulse, RR, SpO2
class _SingleVitalCard extends StatelessWidget {
  final String title;
  final String unit;
  final String hint;
  final double? value;
  final bool allowDecimal;
  final VitalInterpretation? interpretation;
  final ValueChanged<double?> onChanged;

  const _SingleVitalCard({
    required this.title,
    required this.unit,
    required this.hint,
    required this.value,
    required this.allowDecimal,
    required this.interpretation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _VitalCardShell(
      title: title,
      interpretation: interpretation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VitalInput(
            label: unit,
            hint: hint,
            interp: interpretation,
            allowDecimal: allowDecimal,
            initialValue: value,
            onChanged: (v) => onChanged(double.tryParse(v)),
          ),
          _StatusLabel(interp: interpretation),
        ],
      ),
    );
  }
}

// TEMPERATURE CARD - includes F/C sliding toggle
class _TempCard extends StatelessWidget {
  final double? value;
  final bool isFahrenheit;
  final VitalInterpretation? interpretation;
  final ValueChanged<double?> onChanged;
  final ValueChanged<bool> onUnitToggle;

  const _TempCard({
    required this.value,
    required this.isFahrenheit,
    required this.interpretation,
    required this.onChanged,
    required this.onUnitToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _VitalCardShell(
      title: 'Temperature',
      interpretation: interpretation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VitalInput(
                  label: 'F/C Toggle',
                  hint: isFahrenheit ? '98.6' : '37.0',
                  interp: interpretation,
                  allowDecimal: true,
                  suffixText: isFahrenheit ? '°F' : '°C',
                  initialValue: value,
                  onChanged: (v) => onChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const SizedBox(height: 6),
                  // Sliding F/C pill toggle
                  GestureDetector(
                    onTap: () => onUnitToggle(!isFahrenheit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.sectionHeader,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        children: [
                          // Sliding white pill
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: isFahrenheit
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isFahrenheit ? 'F' : 'C',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.sectionHeader,
                                ),
                              ),
                            ),
                          ),
                          // Background labels
                          Positioned(
                            left: 9,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                'C',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isFahrenheit
                                      ? AppColors.background.withOpacity(0.6)
                                      : AppColors.sectionHeader,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 9,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                'F',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: !isFahrenheit
                                      ? AppColors.background.withOpacity(0.6)
                                      : AppColors.sectionHeader,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'F/C',
                    style: TextStyle(fontSize: 10, color: AppColors.subtleGrey),
                  ),
                ],
              ),
            ],
          ),
          _StatusLabel(interp: interpretation),
        ],
      ),
    );
  }
}

// BMI CARD - weight + height, shows live BMI
class _BMICard extends StatelessWidget {
  final double? weight;
  final double? height;
  final double? bmi;
  final VitalInterpretation? bmiInterp;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<double?> onHeightChanged;

  const _BMICard({
    required this.weight,
    required this.height,
    required this.bmi,
    required this.bmiInterp,
    required this.onWeightChanged,
    required this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _VitalCardShell(
      title: 'Weight & Height',
      interpretation: bmiInterp,
      trailing: bmi != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bmiInterp?.bgColor ?? AppColors.constitutional,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'BMI ${bmi!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: bmiInterp?.textColor ?? AppColors.teal,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _VitalInput(
                  label: 'Weight (kg)',
                  hint: '70',
                  allowDecimal: true,
                  initialValue: weight,
                  onChanged: (v) => onWeightChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VitalInput(
                  label: 'Height (cm)',
                  hint: '170',
                  allowDecimal: false,
                  initialValue: height,
                  onChanged: (v) => onHeightChanged(double.tryParse(v)),
                ),
              ),
            ],
          ),
          if (bmi != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'BMI: ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.subtleGrey),
                ),
                Text(
                  bmi!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: bmiInterp?.textColor ?? AppColors.bodyText,
                  ),
                ),
                const SizedBox(width: 8),
                if (bmiInterp != null)
                  Text(
                    bmiInterp!.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bmiInterp!.textColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// GLUCOSE CARD - value + fasting/random toggle
class _GlucoseCard extends StatelessWidget {
  final double? value;
  final bool isFasting;
  final VitalInterpretation? interpretation;
  final ValueChanged<double?> onChanged;
  final ValueChanged<bool> onFastingChanged;

  const _GlucoseCard({
    required this.value,
    required this.isFasting,
    required this.interpretation,
    required this.onChanged,
    required this.onFastingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _VitalCardShell(
      title: 'Blood Glucose',
      interpretation: interpretation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VitalInput(
                  label: 'mmol/L',
                  hint: '5.0',
                  interp: interpretation,
                  allowDecimal: true,
                  initialValue: value,
                  onChanged: (v) => onChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 12),
              // Fasting / Random inline toggle
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.constitutional,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['Fasting', 'Random'].asMap().entries.map((e) {
                        final active = (e.key == 0) == isFasting;
                        return GestureDetector(
                          onTap: () => onFastingChanged(e.key == 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.sectionHeader : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? AppColors.background
                                    : AppColors.subtleGrey,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _StatusLabel(interp: interpretation),
        ],
      ),
    );
  }
}

// FLAGS PANEL - auto-generated from VitalsEngine.generateFlags()
// Shown only when there are abnormal values
class _FlagsPanel extends StatelessWidget {
  final List<String> flags;
  const _FlagsPanel({required this.flags});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.flag_rounded, color: AppColors.dangerText, size: 16),
              SizedBox(width: 6),
              Text(
                'Clinical Flags',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...flags.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle,
                      size: 6, color: AppColors.dangerText),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 4),
          Text(
            'These flags will be passed to the next screen.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.dangerText.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// CUSTOM VITAL TILE - shows one doctor-added custom vital
class _CustomVitalTile extends StatelessWidget {
  final CustomVital vital;
  final VoidCallback onRemove;

  const _CustomVitalTile({required this.vital, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.science_outlined,
                color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vital.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      vital.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bodyText,
                      ),
                    ),
                    if (vital.unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        vital.unit,
                        style:
                            TextStyle(fontSize: 12, color: AppColors.subtleGrey),
                      ),
                    ],
                  ],
                ),
                if (vital.notes.isNotEmpty)
                  Text(
                    vital.notes,
                    style: TextStyle(fontSize: 11, color: AppColors.subtleGrey),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.constitutional,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.close, color: AppColors.subtleGrey, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ADD CUSTOM VITAL SECTION
// Collapsed = teal outlined button
// Expanded = form with name, value, unit, notes
class _AddCustomSection extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<CustomVital> onAdd;
  final VoidCallback onCancel;

  const _AddCustomSection({
    required this.isOpen,
    required this.onToggle,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<_AddCustomSection> createState() => _AddCustomSectionState();
}

class _AddCustomSectionState extends State<_AddCustomSection> {
  final _nameCtrl  = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _unitCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _valueCtrl.text.trim().isEmpty) return;
    widget.onAdd(CustomVital(
      name: _nameCtrl.text.trim(),
      value: _valueCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    ));
    _nameCtrl.clear();
    _valueCtrl.clear();
    _unitCtrl.clear();
    _notesCtrl.clear();
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {bool numeric = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 12, color: AppColors.subtleGrey),
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.subtleGrey),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.background,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) {
      return GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sectionHeader, width: 1.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  color: AppColors.sectionHeader, size: 18),
              SizedBox(width: 8),
              Text(
                'Add Custom Vital',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sectionHeader,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.constitutional,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  color: AppColors.sectionHeader, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Add Custom Vital',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sectionHeader,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onCancel,
                child: const Icon(Icons.close,
                    color: AppColors.subtleGrey, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(
                    _nameCtrl, 'Vital name *', 'e.g. CVP, ICP, ETCO₂'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(_unitCtrl, 'Unit', 'mmHg, %'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _field(_valueCtrl, 'Value *', 'Measured value',
              numeric: true),
          const SizedBox(height: 10),
          _field(
            _notesCtrl,
            'Notes (optional)',
            'e.g. via A-line, post-intubation',
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 44,
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
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.subtleGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// SAVE VITALS BUTTON
// Shows flag count badge when abnormals exist
class _SaveButton extends StatelessWidget {
  final int flagCount;
  final VoidCallback onSave;

  const _SaveButton({required this.flagCount, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sectionHeader,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Save Vitals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.background,
              ),
            ),
            if (flagCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerText,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$flagCount flag${flagCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.background,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}