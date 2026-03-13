// lib/models/lab_models.dart
// Extracted from labs_screen.dart
// Import this wherever i need LabData, LabTest, LabPanel, LabStatus, kLabPanels

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum LabStatus { normal, low, high, critical }

class LabInterpretation {
  final LabStatus status;
  final String    label;

  const LabInterpretation({required this.status, required this.label});

  bool get isAbnormal => status != LabStatus.normal;
  bool get isCritical => status == LabStatus.critical;

  Color get textColor {
    switch (status) {
      case LabStatus.normal:   return AppColors.normalText;
      case LabStatus.low:      return AppColors.warnText;
      case LabStatus.high:     return AppColors.warnText;
      case LabStatus.critical: return AppColors.dangerText;
    }
  }

  Color get bgColor {
    switch (status) {
      case LabStatus.normal:   return Colors.transparent;
      case LabStatus.low:      return AppColors.warnBg;
      case LabStatus.high:     return AppColors.warnBg;
      case LabStatus.critical: return AppColors.dangerBg;
    }
  }

  Color get borderColor {
    switch (status) {
      case LabStatus.normal:   return AppColors.divider;
      case LabStatus.low:      return AppColors.warnBorder;
      case LabStatus.high:     return AppColors.warnBorder;
      case LabStatus.critical: return AppColors.dangerBorder;
    }
  }

  IconData? get icon {
    switch (status) {
      case LabStatus.normal:   return null;
      case LabStatus.low:      return Icons.arrow_downward_rounded;
      case LabStatus.high:     return Icons.arrow_upward_rounded;
      case LabStatus.critical: return Icons.warning_amber_rounded;
    }
  }
}

class LabTest {
  final String  shortName;
  final String  fullName;
  final String  unit;
  final double? normalMin;
  final double? normalMax;
  final double? criticalMin;
  final double? criticalMax;
  final String  hint;

  const LabTest({
    required this.shortName,
    required this.fullName,
    required this.unit,
    this.normalMin,
    this.normalMax,
    this.criticalMin,
    this.criticalMax,
    required this.hint,
  });

  LabInterpretation interpret(double value) {
    if (criticalMin != null && value < criticalMin!) {
      return LabInterpretation(status: LabStatus.critical, label: 'CRITICAL LOW');
    }
    if (criticalMax != null && value > criticalMax!) {
      return LabInterpretation(status: LabStatus.critical, label: 'CRITICAL HIGH');
    }
    if (normalMin != null && value < normalMin!) {
      return LabInterpretation(status: LabStatus.low, label: 'LOW');
    }
    if (normalMax != null && value > normalMax!) {
      return LabInterpretation(status: LabStatus.high, label: 'HIGH');
    }
    return const LabInterpretation(status: LabStatus.normal, label: 'Normal');
  }
}

class LabPanel {
  final String       title;
  final IconData     icon;
  final List<LabTest> tests;

  const LabPanel({
    required this.title,
    required this.icon,
    required this.tests,
  });
}

// All reference ranges: WHO / standard clinical references
// To add a new panel, add a LabPanel entry here
const List<LabPanel> kLabPanels = [

  LabPanel(
    title: 'Complete Blood Count',
    icon: Icons.water_drop_outlined,
    tests: [
      LabTest(shortName: 'Hb',         fullName: 'Haemoglobin',         unit: 'g/dL',    normalMin: 12.0, normalMax: 17.5, criticalMin: 7.0,  criticalMax: 20.0, hint: '13.5–17.5'),
      LabTest(shortName: 'WBC',        fullName: 'White Blood Cells',   unit: '×10³/µL', normalMin: 4.5,  normalMax: 11.0, criticalMin: 2.0,  criticalMax: 30.0, hint: '4.5–11.0'),
      LabTest(shortName: 'Platelets',  fullName: 'Platelets',           unit: '×10³/µL', normalMin: 150,  normalMax: 400,  criticalMin: 50.0, criticalMax: 1000, hint: '150–400'),
      LabTest(shortName: 'Hct',        fullName: 'Haematocrit',         unit: '%',        normalMin: 36,   normalMax: 52,   hint: '36–52'),
      LabTest(shortName: 'MCV',        fullName: 'Mean Corpuscular Vol', unit: 'fL',      normalMin: 80,   normalMax: 100,  hint: '80–100'),
      LabTest(shortName: 'MCH',        fullName: 'Mean Corpuscular Hb',  unit: 'pg',      normalMin: 27,   normalMax: 33,   hint: '27–33'),
      LabTest(shortName: 'Neutrophils',fullName: 'Neutrophils',          unit: '%',        normalMin: 50,   normalMax: 70,   hint: '50–70'),
      LabTest(shortName: 'Lymphocytes',fullName: 'Lymphocytes',          unit: '%',        normalMin: 20,   normalMax: 40,   hint: '20–40'),
    ],
  ),

  LabPanel(
    title: 'Liver Function Tests',
    icon: Icons.medical_services_outlined,
    tests: [
      LabTest(shortName: 'ALT',      fullName: 'Alanine Aminotransferase',   unit: 'U/L',   normalMin: 7,   normalMax: 56,   criticalMax: 500,  hint: '7–56'),
      LabTest(shortName: 'AST',      fullName: 'Aspartate Aminotransferase', unit: 'U/L',   normalMin: 10,  normalMax: 40,   criticalMax: 500,  hint: '10–40'),
      LabTest(shortName: 'ALP',      fullName: 'Alkaline Phosphatase',       unit: 'U/L',   normalMin: 44,  normalMax: 147,  hint: '44–147'),
      LabTest(shortName: 'GGT',      fullName: 'Gamma-GT',                   unit: 'U/L',   normalMin: 8,   normalMax: 61,   hint: '8–61'),
      LabTest(shortName: 'T.Bili',   fullName: 'Total Bilirubin',            unit: 'mg/dL', normalMin: 0.1, normalMax: 1.2,  criticalMax: 15.0, hint: '0.1–1.2'),
      LabTest(shortName: 'D.Bili',   fullName: 'Direct Bilirubin',           unit: 'mg/dL', normalMin: 0.0, normalMax: 0.3,  hint: '0.0–0.3'),
      LabTest(shortName: 'Albumin',  fullName: 'Albumin',                    unit: 'g/dL',  normalMin: 3.5, normalMax: 5.0,  criticalMin: 2.0,  hint: '3.5–5.0'),
      LabTest(shortName: 'T.Protein',fullName: 'Total Protein',              unit: 'g/dL',  normalMin: 6.0, normalMax: 8.3,  hint: '6.0–8.3'),
    ],
  ),

  LabPanel(
    title: 'Renal Function Tests',
    icon: Icons.blur_circular_outlined,
    tests: [
      LabTest(shortName: 'Creatinine',fullName: 'Serum Creatinine',    unit: 'mg/dL',  normalMin: 0.7, normalMax: 1.2, criticalMax: 10.0, hint: '0.7–1.2'),
      LabTest(shortName: 'Urea',      fullName: 'Blood Urea',          unit: 'mg/dL',  normalMin: 7,   normalMax: 20,  criticalMax: 200,  hint: '7–20'),
      LabTest(shortName: 'BUN',       fullName: 'Blood Urea Nitrogen', unit: 'mg/dL',  normalMin: 7,   normalMax: 25,  criticalMax: 100,  hint: '7–25'),
      LabTest(shortName: 'eGFR',      fullName: 'Est. GFR',            unit: 'mL/min', normalMin: 60,  normalMax: 120, criticalMin: 15.0, hint: '≥60'),
      LabTest(shortName: 'Uric Acid', fullName: 'Uric Acid',           unit: 'mg/dL',  normalMin: 3.5, normalMax: 7.2, hint: '3.5–7.2'),
    ],
  ),

  LabPanel(
    title: 'Electrolytes',
    icon: Icons.bolt_outlined,
    tests: [
      LabTest(shortName: 'Na',   fullName: 'Sodium',      unit: 'mEq/L', normalMin: 136, normalMax: 145, criticalMin: 120, criticalMax: 160, hint: '136–145'),
      LabTest(shortName: 'K',    fullName: 'Potassium',   unit: 'mEq/L', normalMin: 3.5, normalMax: 5.1, criticalMin: 2.5, criticalMax: 6.5, hint: '3.5–5.1'),
      LabTest(shortName: 'Cl',   fullName: 'Chloride',    unit: 'mEq/L', normalMin: 98,  normalMax: 107, criticalMin: 80,  criticalMax: 120, hint: '98–107'),
      LabTest(shortName: 'HCO3', fullName: 'Bicarbonate', unit: 'mEq/L', normalMin: 22,  normalMax: 29,  criticalMin: 10,  criticalMax: 40,  hint: '22–29'),
      LabTest(shortName: 'Ca',   fullName: 'Calcium',     unit: 'mg/dL', normalMin: 8.5, normalMax: 10.5,criticalMin: 7.0, criticalMax: 13.0,hint: '8.5–10.5'),
      LabTest(shortName: 'Mg',   fullName: 'Magnesium',   unit: 'mg/dL', normalMin: 1.7, normalMax: 2.2, criticalMin: 1.0, hint: '1.7–2.2'),
      LabTest(shortName: 'PO4',  fullName: 'Phosphate',   unit: 'mg/dL', normalMin: 2.5, normalMax: 4.5, criticalMin: 1.0, hint: '2.5–4.5'),
    ],
  ),

  LabPanel(
    title: 'Glucose & HbA1c',
    icon: Icons.monitor_heart_outlined,
    tests: [
      LabTest(shortName: 'FBS',   fullName: 'Fasting Blood Sugar',  unit: 'mg/dL', normalMin: 70,  normalMax: 100, criticalMin: 40,  criticalMax: 500,  hint: '70–100'),
      LabTest(shortName: 'RBS',   fullName: 'Random Blood Sugar',   unit: 'mg/dL', normalMin: 70,  normalMax: 140, criticalMin: 40,  criticalMax: 600,  hint: '70–140'),
      LabTest(shortName: 'HbA1c', fullName: 'Glycated Haemoglobin', unit: '%',     normalMin: 4.0, normalMax: 5.6, criticalMax: 12.0,hint: '<5.7'),
      LabTest(shortName: '2hr PP',fullName: '2hr Post-Prandial',    unit: 'mg/dL', normalMin: 70,  normalMax: 140, criticalMin: 40,  criticalMax: 600,  hint: '<140'),
    ],
  ),

  LabPanel(
    title: 'Lipid Profile',
    icon: Icons.water_outlined,
    tests: [
      LabTest(shortName: 'T.Chol',   fullName: 'Total Cholesterol', unit: 'mg/dL', normalMax: 200, criticalMax: 300, hint: '<200'),
      LabTest(shortName: 'LDL',      fullName: 'LDL Cholesterol',   unit: 'mg/dL', normalMax: 100, criticalMax: 190, hint: '<100'),
      LabTest(shortName: 'HDL',      fullName: 'HDL Cholesterol',   unit: 'mg/dL', normalMin: 40,  hint: '>40'),
      LabTest(shortName: 'TG',       fullName: 'Triglycerides',     unit: 'mg/dL', normalMax: 150, criticalMax: 500, hint: '<150'),
      LabTest(shortName: 'VLDL',     fullName: 'VLDL Cholesterol',  unit: 'mg/dL', normalMax: 30,  hint: '<30'),
    ],
  ),

  LabPanel(
    title: 'Thyroid Function Tests',
    icon: Icons.settings_outlined,
    tests: [
      LabTest(shortName: 'TSH', fullName: 'Thyroid Stimulating Hormone', unit: 'mIU/L', normalMin: 0.4, normalMax: 4.0, criticalMin: 0.01, criticalMax: 10.0, hint: '0.4–4.0'),
      LabTest(shortName: 'T3',  fullName: 'Triiodothyronine',            unit: 'ng/dL', normalMin: 80,  normalMax: 200, hint: '80–200'),
      LabTest(shortName: 'T4',  fullName: 'Thyroxine',                   unit: 'µg/dL', normalMin: 5.0, normalMax: 12.0,hint: '5.0–12.0'),
      LabTest(shortName: 'fT3', fullName: 'Free T3',                     unit: 'pg/mL', normalMin: 2.3, normalMax: 4.2, hint: '2.3–4.2'),
      LabTest(shortName: 'fT4', fullName: 'Free T4',                     unit: 'ng/dL', normalMin: 0.8, normalMax: 1.8, hint: '0.8–1.8'),
    ],
  ),

  LabPanel(
    title: 'Cardiac Enzymes',
    icon: Icons.favorite_outline,
    tests: [
      LabTest(shortName: 'Troponin I',fullName: 'Troponin I',           unit: 'ng/mL', normalMax: 0.04, criticalMax: 0.4,  hint: '<0.04'),
      LabTest(shortName: 'Troponin T',fullName: 'Troponin T',           unit: 'ng/mL', normalMax: 0.01, criticalMax: 0.1,  hint: '<0.01'),
      LabTest(shortName: 'CK-MB',     fullName: 'Creatine Kinase-MB',   unit: 'U/L',   normalMax: 25,   criticalMax: 100,  hint: '<25'),
      LabTest(shortName: 'CK',        fullName: 'Total Creatine Kinase', unit: 'U/L',  normalMin: 30,   normalMax: 200,    criticalMax: 1000, hint: '30–200'),
      LabTest(shortName: 'LDH',       fullName: 'Lactate Dehydrogenase', unit: 'U/L',  normalMin: 140,  normalMax: 280,    hint: '140–280'),
      LabTest(shortName: 'BNP',       fullName: 'B-Natriuretic Peptide', unit: 'pg/mL',normalMax: 100,  criticalMax: 400,  hint: '<100'),
    ],
  ),

  LabPanel(
    title: 'Coagulation Profile',
    icon: Icons.compress_outlined,
    tests: [
      LabTest(shortName: 'PT',     fullName: 'Prothrombin Time',         unit: 'sec',   normalMin: 11,  normalMax: 13,  criticalMax: 30,  hint: '11–13'),
      LabTest(shortName: 'INR',    fullName: 'International Norm. Ratio',unit: '',      normalMin: 0.9, normalMax: 1.1, criticalMax: 4.0, hint: '0.9–1.1'),
      LabTest(shortName: 'aPTT',   fullName: 'Activated Partial Thromb.',unit: 'sec',   normalMin: 25,  normalMax: 35,  criticalMax: 70,  hint: '25–35'),
      LabTest(shortName: 'TT',     fullName: 'Thrombin Time',            unit: 'sec',   normalMin: 12,  normalMax: 20,  hint: '12–20'),
      LabTest(shortName: 'Fibrin', fullName: 'Fibrinogen',               unit: 'mg/dL', normalMin: 200, normalMax: 400, criticalMin: 100, hint: '200–400'),
      LabTest(shortName: 'D-Dimer',fullName: 'D-Dimer',                  unit: 'µg/mL', normalMax: 0.5, criticalMax: 2.0,hint: '<0.5'),
    ],
  ),

  LabPanel(
    title: 'Arterial Blood Gas',
    icon: Icons.air_outlined,
    tests: [
      LabTest(shortName: 'pH',   fullName: 'Blood pH',           unit: '',       normalMin: 7.35, normalMax: 7.45, criticalMin: 7.2,  criticalMax: 7.6,  hint: '7.35–7.45'),
      LabTest(shortName: 'PaO2', fullName: 'Partial O2 Pressure',unit: 'mmHg',  normalMin: 75,   normalMax: 100,  criticalMin: 50,   hint: '75–100'),
      LabTest(shortName: 'PaCO2',fullName: 'Partial CO2 Pressure',unit: 'mmHg', normalMin: 35,   normalMax: 45,   criticalMin: 20,   criticalMax: 70,   hint: '35–45'),
      LabTest(shortName: 'SaO2', fullName: 'O2 Saturation',      unit: '%',      normalMin: 95,   normalMax: 100,  criticalMin: 88,   hint: '95–100'),
      LabTest(shortName: 'HCO3', fullName: 'Bicarbonate (ABG)',   unit: 'mEq/L', normalMin: 22,   normalMax: 26,   criticalMin: 15,   criticalMax: 35,   hint: '22–26'),
      LabTest(shortName: 'BE',   fullName: 'Base Excess',         unit: 'mEq/L', normalMin: -2,   normalMax: 2,    criticalMin: -8,   criticalMax: 8,    hint: '-2 to +2'),
    ],
  ),

  LabPanel(
    title: 'Urine Analysis',
    icon: Icons.science_outlined,
    tests: [
      LabTest(shortName: 'Urine pH',     fullName: 'Urine pH',          unit: '',       normalMin: 4.5,  normalMax: 8.0,  hint: '4.5–8.0'),
      LabTest(shortName: 'Sp. Gravity',  fullName: 'Specific Gravity',  unit: '',       normalMin: 1.003,normalMax: 1.030,hint: '1.003–1.030'),
      LabTest(shortName: 'Urine Protein',fullName: 'Urine Protein',     unit: 'mg/dL',  normalMax: 15,   criticalMax: 300,hint: '<15'),
      LabTest(shortName: 'Urine Glucose',fullName: 'Urine Glucose',     unit: 'mg/dL',  normalMax: 0,    hint: 'Negative'),
      LabTest(shortName: 'RBCs',         fullName: 'RBCs/HPF',          unit: '/HPF',   normalMax: 3,    criticalMax: 20, hint: '0–3'),
      LabTest(shortName: 'WBCs',         fullName: 'WBCs/HPF',          unit: '/HPF',   normalMax: 5,    criticalMax: 20, hint: '0–5'),
      LabTest(shortName: '24hr Protein', fullName: '24hr Urine Protein',unit: 'mg/day', normalMax: 150,  criticalMax: 3500,hint: '<150'),
    ],
  ),

  LabPanel(
    title: 'Iron Studies',
    icon: Icons.hardware_outlined,
    tests: [
      LabTest(shortName: 'Serum Fe',   fullName: 'Serum Iron',        unit: 'µg/dL', normalMin: 60,  normalMax: 170, criticalMin: 30,  hint: '60–170'),
      LabTest(shortName: 'TIBC',       fullName: 'Total Iron Binding', unit: 'µg/dL', normalMin: 250, normalMax: 370, hint: '250–370'),
      LabTest(shortName: 'Ferritin',   fullName: 'Serum Ferritin',     unit: 'ng/mL', normalMin: 20,  normalMax: 200, criticalMin: 10,  hint: '20–200'),
      LabTest(shortName: 'Sat %',      fullName: 'Transferrin Sat.',   unit: '%',     normalMin: 20,  normalMax: 50,  criticalMin: 10,  hint: '20–50'),
      LabTest(shortName: 'Transferrin',fullName: 'Transferrin',        unit: 'mg/dL', normalMin: 200, normalMax: 360, hint: '200–360'),
    ],
  ),
  // Culture results are text-based — handled separately in LabData
];

// @HiveType(typeId: 7)
class LabData {
  // key: '$panelIndex-$testIndex', value: entered numeric value
  final Map<String, double?> values = {};

  // Culture / free-text results
  String bloodCultureResult  = '';
  String urineCultureResult  = '';
  String sputumCultureResult = '';
  String woundCultureResult  = '';

  String key(int panelIndex, int testIndex) => '$panelIndex-$testIndex';

  double? getValue(int p, int t) => values[key(p, t)];
  void    setValue(int p, int t, double? v) => values[key(p, t)] = v;

  bool get hasAnyAbnormal {
    for (int p = 0; p < kLabPanels.length; p++) {
      final panel = kLabPanels[p];
      for (int t = 0; t < panel.tests.length; t++) {
        final v = getValue(p, t);
        if (v != null && panel.tests[t].interpret(v).isAbnormal) return true;
      }
    }
    return false;
  }

  List<String> get abnormalSummary {
    final result = <String>[];
    for (int p = 0; p < kLabPanels.length; p++) {
      final panel = kLabPanels[p];
      for (int t = 0; t < panel.tests.length; t++) {
        final v = getValue(p, t);
        if (v != null) {
          final interp = panel.tests[t].interpret(v);
          if (interp.isAbnormal) {
            result.add('${panel.tests[t].shortName}: $v ${panel.tests[t].unit} (${interp.label})');
          }
        }
      }
    }
    return result;
  }
}