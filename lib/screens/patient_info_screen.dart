import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient_info.dart';
import '../core/app_colors.dart';
import 'history_taking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// STANDALONE ENTRY — remove when integrating
// ═══════════════════════════════════════════════════════════════════════════════
void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediScribe AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sectionHeader,
        surface: AppColors.background,
      ),
    ),
    home: const PatientInfoScreen(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATIENT INFO SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class PatientInfoScreen extends StatefulWidget {
  const PatientInfoScreen({super.key});

  @override
  State<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _info      = PatientInfo();
  bool _submitted  = false;

  // Text controllers for fields that need them
  final _nameCtrl      = TextEditingController();
  final _ageCtrl       = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _religionCtrl  = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _religionCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Auto-generate patient ID
    _info.patientId = 'MR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => HistoryTakingScreen(patientInfo: _info),
    ));
  }

  Future<void> _pickAdmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.sectionHeader,
            onPrimary: AppColors.headerText,
            surface: AppColors.background,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _info.dateOfAdmission = picked);
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Page heading ────────────────────────────────────────
                    _PageHeading(),

                    const SizedBox(height: 20),

                    // ── Section: Personal Details ────────────────────────────
                    _SectionCard(
                      title: 'Personal Details',
                      icon: Icons.person_outline,
                      children: [

                        // Full Name
                        _FieldLabel('Full Name', required: true),
                        _TextInput(
                          controller: _nameCtrl,
                          hint: 'e.g. Muhammad Ali',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Full name is required' : null,
                          onSaved: (v) => _info.fullName = v?.trim() ?? '',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\.]')),
                          ],
                        ),

                        const _FieldDivider(),

                        // Age + Gender row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Age
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Age', required: true),
                                  _TextInput(
                                    controller: _ageCtrl,
                                    hint: 'Years',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      final n = int.tryParse(v);
                                      if (n == null || n < 0 || n > 130) return 'Invalid';
                                      return null;
                                    },
                                    onSaved: (v) => _info.age = int.tryParse(v ?? ''),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Gender
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Gender', required: true),
                                  _DropdownInput(
                                    value: _info.gender.isEmpty ? null : _info.gender,
                                    hint: 'Select',
                                    items: const ['Male', 'Female', 'Other'],
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Required' : null,
                                    onChanged: (v) => setState(() => _info.gender = v ?? ''),
                                    onSaved: (v) => _info.gender = v ?? '',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const _FieldDivider(),

                        // Date of Birth
                        _FieldLabel('Date of Birth'),
                        _DOBField(
                          onSaved: (v) => _info.dateOfBirth = v,
                        ),

                        const _FieldDivider(),

                        // Address
                        _FieldLabel('Address'),
                        _TextInput(
                          controller: _addressCtrl,
                          hint: 'Street, City, Province',
                          maxLines: 2,
                          onSaved: (v) => _info.address = v?.trim() ?? '',
                        ),

                        const _FieldDivider(),

                        // Marital Status
                        _FieldLabel('Marital Status'),
                        _DropdownInput(
                          value: _info.maritalStatus.isEmpty ? null : _info.maritalStatus,
                          hint: 'Select',
                          items: const ['Single', 'Married', 'Widowed', 'Divorced', 'Separated'],
                          onChanged: (v) => setState(() => _info.maritalStatus = v ?? ''),
                          onSaved: (v) => _info.maritalStatus = v ?? '',
                        ),

                        const _FieldDivider(),

                        // Religion
                        _FieldLabel('Religion'),
                        _TextInput(
                          controller: _religionCtrl,
                          hint: 'e.g. Islam, Christianity, Hinduism',
                          onSaved: (v) => _info.religion = v?.trim() ?? '',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Section: Admission Details ───────────────────────────
                    _SectionCard(
                      title: 'Admission Details',
                      icon: Icons.local_hospital_outlined,
                      children: [

                        // Date of Admission
                        _FieldLabel('Date of Admission'),
                        GestureDetector(
                          onTap: _pickAdmissionDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 16, color: AppColors.sectionHeader),
                                const SizedBox(width: 10),
                                Text(
                                  _info.dateOfAdmission != null
                                      ? _formatDate(_info.dateOfAdmission!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _info.dateOfAdmission != null
                                        ? AppColors.bodyText
                                        : AppColors.subtleGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const _FieldDivider(),

                        // Mode of Admission toggle
                        _FieldLabel('Mode of Admission'),
                        const SizedBox(height: 4),
                        _ModeOfAdmissionToggle(
                          value: _info.modeOfAdmission,
                          onChanged: (v) => setState(() => _info.modeOfAdmission = v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Next Button ──────────────────────────────────────────
                    _NextButton(onPressed: _onNext),

                    const SizedBox(height: 8),

                    // Required fields note
                    Center(
                      child: Text(
                        '* Full Name, Age and Gender are required',
                        style: TextStyle(fontSize: 11, color: AppColors.subtleGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deepTeal,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.headerText, size: 22),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Icon(Icons.psychology_outlined,
                  color: AppColors.headerText, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('MediScribe AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.headerText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('New Patient Profile',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
              color: AppColors.bodyText, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('Fill in the patient\'s basic information to begin.',
          style: TextStyle(fontSize: 13, color: AppColors.subtleGrey)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.constitutional,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15), topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.sectionHeader),
                const SizedBox(width: 8),
                Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.sectionHeader)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel(this.label, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.bodyText),
        children: required
            ? [const TextSpan(text: ' *',
                style: TextStyle(color: AppColors.emergencyRed))]
            : [],
      ),
    ),
  );
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: AppColors.divider),
  );
}

class _TextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;

  const _TextInput({
    this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtleGrey, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.sectionHeader, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.emergencyRed)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.emergencyRed, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.emergencyRed),
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final String? Function(String?)? validator;
  final void Function(String?) onChanged;
  final void Function(String?)? onSaved;

  const _DropdownInput({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.validator,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
      hint: Text(hint, style: const TextStyle(color: AppColors.subtleGrey, fontSize: 14)),
      style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.sectionHeader, size: 22),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.sectionHeader, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.emergencyRed)),
        errorStyle: const TextStyle(fontSize: 11, color: AppColors.emergencyRed),
      ),
      items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Text(i),
      )).toList(),
    );
  }
}

// Date of Birth — three linked dropdowns (Day / Month / Year)
// More reliable than showDatePicker for entering historical dates
class _DOBField extends StatefulWidget {
  final void Function(String) onSaved;
  const _DOBField({required this.onSaved});

  @override
  State<_DOBField> createState() => _DOBFieldState();
}

class _DOBFieldState extends State<_DOBField> {
  int? _day;
  int? _month;
  int? _year;

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  int get _daysInMonth {
    if (_month == null || _year == null) return 31;
    return DateTime(_year!, _month! + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      120, (i) => DateTime.now().year - i,
    );

    return Row(
      children: [
        // Day
        Expanded(
          child: _CompactDropdown(
            hint: 'Day',
            value: _day?.toString(),
            items: List.generate(_daysInMonth, (i) => (i + 1).toString()),
            onChanged: (v) {
              setState(() => _day = int.tryParse(v ?? ''));
              _save();
            },
          ),
        ),
        const SizedBox(width: 8),
        // Month
        Expanded(
          flex: 2,
          child: _CompactDropdown(
            hint: 'Month',
            value: _month != null ? _months[_month! - 1] : null,
            items: _months,
            onChanged: (v) {
              setState(() => _month = v != null ? _months.indexOf(v) + 1 : null);
              _save();
            },
          ),
        ),
        const SizedBox(width: 8),
        // Year
        Expanded(
          flex: 2,
          child: _CompactDropdown(
            hint: 'Year',
            value: _year?.toString(),
            items: years.map((y) => y.toString()).toList(),
            onChanged: (v) {
              setState(() => _year = int.tryParse(v ?? ''));
              _save();
            },
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_day != null && _month != null && _year != null) {
      widget.onSaved(
          '${_day.toString().padLeft(2,'0')}/${_month.toString().padLeft(2,'0')}/$_year');
    }
  }
}

class _CompactDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _CompactDropdown({
    required this.hint, required this.value,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(
              color: AppColors.subtleGrey, fontSize: 13)),
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.sectionHeader, size: 18),
          items: items.map((i) => DropdownMenuItem(
              value: i, child: Text(i))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Emergency / OPD toggle — two pills, only one active at a time
class _ModeOfAdmissionToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _ModeOfAdmissionToggle({
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModePill(
          label: 'Emergency',
          icon: Icons.emergency_outlined,
          selected: value == 'Emergency',
          selectedColor: AppColors.emergencyRed,
          selectedBg: AppColors.emergencyBg,
          onTap: () => onChanged('Emergency'),
        ),
        const SizedBox(width: 12),
        _ModePill(
          label: 'OPD',
          icon: Icons.local_hospital_outlined,
          selected: value == 'OPD',
          selectedColor: AppColors.sectionHeader,
          selectedBg: AppColors.constitutional,
          onTap: () => onChanged('OPD'),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback onTap;

  const _ModePill({
    required this.label, required this.icon,
    required this.selected, required this.selectedColor,
    required this.selectedBg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? selectedColor : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle circle indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: selected ? selectedColor : AppColors.divider,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? selectedColor : AppColors.subtleGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NextButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deepTeal,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Next — History Taking',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.headerText)),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: AppColors.headerText, size: 18),
        ],
      ),
    ),
  );
}