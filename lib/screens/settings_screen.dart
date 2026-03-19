import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';


class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kName        = 'settings_clinician_name';
  static const _kDesignation = 'settings_designation';
  static const _kHospital    = 'settings_hospital';
  static const _kDarkMode    = 'settings_dark_mode';

  String _clinicianName  = '';
  String _designation    = '';
  String _hospitalName   = '';
  bool   _darkMode       = false;

  String get clinicianName => _clinicianName.isEmpty ? 'Doctor' : _clinicianName;
  String get designation   => _designation;
  String get hospitalName  => _hospitalName.isEmpty ? 'MediScribe AI' : _hospitalName;
  bool   get darkMode      => _darkMode;

  /// Load persisted values — call once in main() before runApp()
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _clinicianName = prefs.getString(_kName)        ?? '';
    _designation   = prefs.getString(_kDesignation) ?? '';
    _hospitalName  = prefs.getString(_kHospital)    ?? '';
    _darkMode      = prefs.getBool(_kDarkMode)       ?? false;
  }

  Future<void> save({
    required String clinicianName,
    required String designation,
    required String hospitalName,
    required bool   darkMode,
  }) async {
    _clinicianName = clinicianName;
    _designation   = designation;
    _hospitalName  = hospitalName;
    _darkMode      = darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName,        clinicianName);
    await prefs.setString(_kDesignation, designation);
    await prefs.setString(_kHospital,    hospitalName);
    await prefs.setBool(_kDarkMode,      darkMode);
  }
}
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl        = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _hospitalCtrl    = TextEditingController();
  bool  _darkMode        = false;
  bool  _saving          = false;
  bool  _saved           = false;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    // Don't pre-fill the placeholder values — only real saved values
    _nameCtrl.text        = s.clinicianName == 'Doctor'         ? '' : s.clinicianName;
    _designationCtrl.text = s.designation;
    _hospitalCtrl.text    = s.hospitalName  == 'MediScribe AI'  ? '' : s.hospitalName;
    _darkMode             = s.darkMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saved = false; });
    await SettingsService.instance.save(
      clinicianName: _nameCtrl.text.trim(),
      designation:   _designationCtrl.text.trim(),
      hospitalName:  _hospitalCtrl.text.trim(),
      darkMode:      _darkMode,
    );
    setState(() { _saving = false; _saved = true; });
    // Reset saved badge after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageBackground,
      child: Column(
        children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _sectionLabel('Clinician Details'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _Field(
                        icon:        Icons.person_outline,
                        label:       'Full Name',
                        hint:        'e.g. Dr. Sarah Khan',
                        controller:  _nameCtrl,
                        onChanged:   (_) => setState(() {}),
                      ),
                      _Divider(),
                      _Field(
                        icon:        Icons.badge_outlined,
                        label:       'Designation',
                        hint:        'e.g. MBBS, FCPS (Medicine)',
                        controller:  _designationCtrl,
                        onChanged:   (_) => setState(() {}),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    _sectionLabel('Institution'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _Field(
                        icon:        Icons.local_hospital_outlined,
                        label:       'Hospital / Clinic',
                        hint:        'e.g. Shaukat Khanum Memorial Hospital',
                        controller:  _hospitalCtrl,
                        onChanged:   (_) => setState(() {}),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    _sectionLabel('Appearance'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _Toggle(
                        icon:     Icons.dark_mode_outlined,
                        label:    'Dark Mode',
                        subtitle: 'Coming soon',
                        value:    _darkMode,
                        enabled:  false,
                        onChanged: (v) => setState(() => _darkMode = v),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    _sectionLabel('About'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _InfoRow(icon: Icons.info_outline,
                               label: 'Version',     value: '1.0.0 (Beta)'),
                      _Divider(),
                      _InfoRow(icon: Icons.psychology_outlined,
                               label: 'AI Engine',   value: 'Offline KB + Rule-based CF'),
                      _Divider(),
                      _InfoRow(icon: Icons.school_outlined,
                               label: 'Built for',   value: 'Final Year Project — Clinical Exam Aid'),
                    ]),
                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sectionHeader,
                          disabledBackgroundColor:
                              AppColors.sectionHeader.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.headerText))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _saved ? Icons.check_circle_outline : Icons.save_outlined,
                                    color: AppColors.headerText, size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _saved ? 'Saved!' : 'Save Settings',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.headerText,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildHeader() {
    return Container(
      color: AppColors.sectionHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.settings_outlined,
                  color: AppColors.headerText, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Settings',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headerText,
                        letterSpacing: -0.3)),
              ),
              if (_saved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: AppColors.headerText),
                      SizedBox(width: 4),
                      Text('Saved',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.headerText)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.sectionHeader,
                letterSpacing: 0.5)),
      );
}


class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}


class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.sectionHeader),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtleGrey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.bodyText,
                      decoration: TextDecoration.none),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        fontSize: 14, color: AppColors.subtleGrey),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
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

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: enabled ? AppColors.sectionHeader : AppColors.subtleGrey),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: enabled
                            ? AppColors.bodyText
                            : AppColors.subtleGrey,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtleGrey,
                          decoration: TextDecoration.none)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.sectionHeader,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
}


class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.subtleGrey),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtleGrey,
                  decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}


class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 1, color: AppColors.divider, indent: 50);
  }
}