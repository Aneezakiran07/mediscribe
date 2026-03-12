// lib/models/vitals_models.dart
// Extracted from vitals_screen.dart
// Import this wherever you need VitalsData, VitalsEngine, VitalStatus, VitalInterpretation, CustomVital

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// normal / warning / danger.
// There is NO 'emergency' value. use VitalStatus.danger
// for critical/emergency states (e.g. hypertensive crisis, severe hypoxia).
enum VitalStatus { normal, warning, danger }

class VitalInterpretation {
  final VitalStatus status;
  final String      label;
  final String      detail;

  const VitalInterpretation({
    required this.status,
    this.label  = '',
    this.detail = '',
  });

  bool get isAbnormal => status != VitalStatus.normal;

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
}

// All thresholds: JNC 8 / AHA 2017 / WHO standards
class VitalsEngine {
  VitalsEngine._();

  // Blood pressure
  static VitalInterpretation interpretBP(double sys, double dia) {
    if (sys < 90 || dia < 60) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hypotension',
        detail: 'BP critically low — assess for shock',
      );
    }
    if (sys >= 180 || dia >= 120) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hypertensive Crisis',
        detail: 'Urgent evaluation required',
      );
    }
    if (sys >= 160 || dia >= 100) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hypertension Stage 2',
        detail: 'Pharmacologic therapy indicated',
      );
    }
    if (sys >= 140 || dia >= 90) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Hypertension Stage 1',
        detail: 'Lifestyle modification advised',
      );
    }
    if (sys >= 130 || dia >= 80) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Elevated BP',
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
        label:  'Severe Bradycardia',
        detail: 'HR critically low — assess for heart block',
      );
    }
    if (bpm < 60) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Bradycardia',
        detail: 'HR < 60 bpm',
      );
    }
    if (bpm > 150) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Severe Tachycardia',
        detail: 'HR critically high — assess for arrhythmia',
      );
    }
    if (bpm > 100) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Tachycardia',
        detail: 'HR > 100 bpm — investigate cause',
      );
    }
    return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal');
  }

  // always pass Celsius regardless of display unit
  static VitalInterpretation interpretTempC(double c) {
    if (c < 35.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hypothermia',
        detail: 'Core temp < 35°C — immediate warming',
      );
    }
    if (c < 36.1) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Low Temperature',
        detail: 'Slightly below normal',
      );
    }
    if (c > 41.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hyperpyrexia',
        detail: 'Temp > 41°C — emergency cooling',
      );
    }
    if (c > 39.0) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'High Fever',
        detail: 'Temp > 39°C — investigate infection/sepsis',
      );
    }
    if (c > 37.5) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Fever',
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
        label:  'Severe Bradypnea',
        detail: 'RR < 8 — risk of respiratory failure',
      );
    }
    if (rr < 12) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Bradypnea',
        detail: 'RR below normal (12–20/min)',
      );
    }
    if (rr > 30) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Severe Tachypnea',
        detail: 'RR > 30 — respiratory distress',
      );
    }
    if (rr > 20) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Tachypnea',
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
        label:  'Severe Hypoxia',
        detail: 'SpO₂ < 90% — urgent oxygen therapy',
      );
    }
    if (pct < 94) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Hypoxia',
        detail: 'SpO₂ 90–93% — consider supplemental O₂',
      );
    }
    if (pct < 96) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Low-normal SpO₂',
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
        label:  'Severe Underweight',
        detail: 'BMI < 16 — nutritional assessment urgent',
      );
    }
    if (bmi < 18.5) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Underweight',
        detail: 'BMI 16–18.4',
      );
    }
    if (bmi < 25) {
      return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal BMI');
    }
    if (bmi < 30) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Overweight',
        detail: 'BMI 25–29.9',
      );
    }
    if (bmi < 35) {
      return const VitalInterpretation(
        status: VitalStatus.warning,
        label:  'Obesity Class I',
        detail: 'BMI 30–34.9',
      );
    }
    return const VitalInterpretation(
      status: VitalStatus.danger,
      label:  'Obesity Class II–III',
      detail: 'BMI ≥ 35 — high cardiovascular risk',
    );
  }

  // Blood glucose — pass value in mmol/L
  static VitalInterpretation interpretGlucose(double mmol, bool fasting) {
    if (mmol < 3.9) {
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Hypoglycemia',
        detail: 'Glucose < 3.9 mmol/L',
      );
    }
    if (fasting) {
      if (mmol <= 5.5) return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal (Fasting)');
      if (mmol <= 6.9) {
        return const VitalInterpretation(
          status: VitalStatus.warning,
          label:  'Impaired Fasting Glucose',
          detail: 'Pre-diabetic range',
        );
      }
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Diabetes Range',
        detail: 'Fasting ≥ 7.0 mmol/L — further workup',
      );
    } else {
      if (mmol < 7.8)  return const VitalInterpretation(status: VitalStatus.normal, label: 'Normal (Random)');
      if (mmol < 11.1) {
        return const VitalInterpretation(
          status: VitalStatus.warning,
          label:  'Impaired Glucose Tolerance',
          detail: '7.8–11.0 mmol/L post-prandial',
        );
      }
      return const VitalInterpretation(
        status: VitalStatus.danger,
        label:  'Diabetes Range',
        detail: 'Random ≥ 11.1 mmol/L',
      );
    }
  }

  // Generate clinical flags from all entered vitals
  // Passed to ExaminationScreen as autoFlags
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
// @HiveType(typeId: 5)
class VitalsData {
  double? systolic;
  double? diastolic;
  double? pulse;
  double? temperature;
  bool    isFahrenheit      = true;
  double? respiratoryRate;
  double? spO2;
  double? weightKg;
  double? heightCm;
  double? bloodGlucose;
  bool    isFastingGlucose  = true;
  List<CustomVital> customVitals = [];

  // Derived — computed on access, not stored
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

// @HiveType(typeId: 6)
class CustomVital {
  String name;
  String value;
  String unit;
  String notes;

  CustomVital({
    this.name  = '',
    this.value = '',
    this.unit  = '',
    this.notes = '',
  });
}