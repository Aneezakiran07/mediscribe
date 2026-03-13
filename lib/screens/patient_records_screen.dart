import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import 'patient_info_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PATIENT RECORDS SCREEN
// Designed to be embedded inside HomeScreen's Scaffold (no Scaffold of its own)
// so the bottom nav bar persists. HomeScreen passes a FAB via floatingActionButton.
//
// Use patientRecordsFAB() to get the FAB widget to pass to HomeScreen.
// ═══════════════════════════════════════════════════════════════════════════════

enum StatusDot { green, amber, red }

class PatientRecord {
  final String    id;
  final String    name;
  final String    age;
  final String    gender;
  final String    chiefComplaint;
  final String    provisionalDiagnosis;
  final DateTime  dateOfAdmission;
  final String    admissionMode;
  final StatusDot status;

  const PatientRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.chiefComplaint,
    required this.provisionalDiagnosis,
    required this.dateOfAdmission,
    required this.admissionMode,
    required this.status,
  });
}

// Replace with Hive.box<PatientRecord>('patients').values.toList()
class PatientRecordRepo {
  static List<PatientRecord> all() => [
    PatientRecord(
      id: '001', name: 'John Doe', age: '45', gender: 'Male',
      chiefComplaint: 'Chest Pain',
      provisionalDiagnosis: 'Acute Myocardial Infarction',
      dateOfAdmission: DateTime(2023, 10, 26),
      admissionMode: 'Emergency', status: StatusDot.green,
    ),
    PatientRecord(
      id: '002', name: 'Jane Smith', age: '32', gender: 'Female',
      chiefComplaint: 'Fever & Cough',
      provisionalDiagnosis: 'Pneumonia',
      dateOfAdmission: DateTime(2023, 11, 5),
      admissionMode: 'OPD', status: StatusDot.green,
    ),
    PatientRecord(
      id: '003', name: 'Robert Brown', age: '68', gender: 'Male',
      chiefComplaint: 'Shortness of Breath',
      provisionalDiagnosis: 'Congestive Heart Failure',
      dateOfAdmission: DateTime(2023, 11, 12),
      admissionMode: 'Emergency', status: StatusDot.amber,
    ),
    PatientRecord(
      id: '004', name: 'Maria Garcia', age: '55', gender: 'Female',
      chiefComplaint: 'Abdominal Pain',
      provisionalDiagnosis: 'Appendicitis',
      dateOfAdmission: DateTime(2023, 11, 18),
      admissionMode: 'Emergency', status: StatusDot.green,
    ),
    PatientRecord(
      id: '005', name: 'David Lee', age: '41', gender: 'Male',
      chiefComplaint: 'Dizziness',
      provisionalDiagnosis: 'Hypertension',
      dateOfAdmission: DateTime(2023, 11, 21),
      admissionMode: 'OPD', status: StatusDot.amber,
    ),
  ];
}

// ── FAB — pass this to HomeScreen's floatingActionButton when on Patients tab ─
FloatingActionButton patientRecordsFAB(BuildContext context) {
  return FloatingActionButton(
    onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PatientInfoScreen())),
    backgroundColor: AppColors.sectionHeader,
    foregroundColor: AppColors.headerText,
    elevation: 3,
    shape: const CircleBorder(),
    child: const Icon(Icons.add, size: 26),
  );
}


class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<PatientRecord> get _filtered {
    final all = PatientRecordRepo.all();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.chiefComplaint.toLowerCase().contains(q) ||
        p.provisionalDiagnosis.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageBackground,
      child: Column(
        children: [
          Container(
            color: AppColors.sectionHeader,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                   children: [
              const Icon(Icons.psychology_outlined, color: AppColors.headerText, size: 24),
              const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Patient Records',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headerText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.bodyText),
                          decoration: const InputDecoration(
                            hintText: 'Search patients...',
                            hintStyle: TextStyle(
                                fontSize: 14, color: AppColors.subtleGrey),
                            prefixIcon: Icon(Icons.search,
                                size: 20, color: AppColors.subtleGrey),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _PatientCard(record: _filtered[i]),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppColors.constitutional, shape: BoxShape.circle),
            child: const Icon(Icons.person_search,
                size: 36, color: AppColors.sectionHeader),
          ),
          const SizedBox(height: 16),
          const Text('No patients found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText)),
          const SizedBox(height: 6),
          const Text('Try a different search term',
              style: TextStyle(fontSize: 13, color: AppColors.subtleGrey)),
        ],
      ),
    );
  }
}


class _PatientCard extends StatelessWidget {
  final PatientRecord record;
  const _PatientCard({required this.record});

  Color get _dotColor {
    switch (record.status) {
      case StatusDot.green: return AppColors.onlineGreen;
      case StatusDot.amber: return const Color(0xFFF59E0B);
      case StatusDot.red:   return AppColors.emergencyRed;
    }
  }

  String get _formattedDate {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = record.dateOfAdmission;
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  // Build a PatientInfo from this record for pre-filling PatientInfoScreen
  PatientInfo _toPatientInfo() => PatientInfo()
    ..fullName        = record.name
    ..age             = int.tryParse(record.age)
    ..gender          = record.gender
    ..dateOfAdmission = record.dateOfAdmission
    ..modeOfAdmission = record.admissionMode
    ..patientId       = record.id;

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatientActionSheet(
        record: record,
        onEdit: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PatientInfoScreen(existingPatient: _toPatientInfo()),
          ));
        },
        onCopy: () {
          Navigator.pop(context);
          const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final d = record.dateOfAdmission;
          final date = '${months[d.month]} ${d.day}, ${d.year}';
          final summary = [
            'Patient Summary',
            'MR No: ${record.id}',
            'Name: ${record.name}',
            'Age/Gender: ${record.age} / ${record.gender}',
            'Date of Admission: $date',
            'Mode: ${record.admissionMode}',
            'Chief Complaint: ${record.chiefComplaint}',
            'Provisional Diagnosis: ${record.provisionalDiagnosis}',
          ].join('\n');
          Clipboard.setData(ClipboardData(text: summary));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient summary copied to clipboard'),
              backgroundColor: AppColors.sectionHeader,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Patient?',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.bodyText)),
        content: Text(
          'This will permanently delete ${record.name}\'s record. This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: AppColors.subtleGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.subtleGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Hive.box<PatientRecord>('patients').delete(record.id)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${record.name} deleted'),
                  backgroundColor: AppColors.emergencyRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Teal accent bar
          Container(height: 5, color: AppColors.sectionHeader),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left — demographics
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Patient Name:', value: record.name, bold: true),
                      const SizedBox(height: 5),
                      _InfoRow(label: 'Age/Gender:', value: '${record.age} / ${record.gender}'),
                      const SizedBox(height: 5),
                      _InfoRow(label: 'Date of Admission:', value: _formattedDate, bold: true),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right — clinical + status dot
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              label: 'Chief Complaint:',
                              value: record.chiefComplaint,
                              bold: true,
                            ),
                            const SizedBox(height: 5),
                            _InfoRow(
                              label: 'Provisional Diagnosis:',
                              value: record.provisionalDiagnosis,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Status dot
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: _dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showMenu(context),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(6, 0, 4, 0),
                    child: Icon(Icons.more_vert,
                        size: 20, color: AppColors.subtleGrey),
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

class _PatientActionSheet extends StatelessWidget {
  final PatientRecord record;
  final VoidCallback  onEdit;
  final VoidCallback  onCopy;
  final VoidCallback  onDelete;

  const _PatientActionSheet({
    required this.record,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Patient name header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.constitutional,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 18, color: AppColors.sectionHeader),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bodyText)),
                      Text(record.provisionalDiagnosis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.subtleGrey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, indent: 20, endIndent: 20, color: AppColors.divider),

          // Edit
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Patient Info',
            subtitle: 'Update demographics and admission details',
            color: AppColors.sectionHeader,
            onTap: onEdit,
          ),

          // Copy
          _ActionTile(
            icon: Icons.copy_outlined,
            label: 'Duplicate Record',
            subtitle: 'New visit with same demographics, fresh clinical data',
            color: const Color(0xFF6366F1), // indigo
            onTap: onCopy,
          ),

          // Delete
          _ActionTile(
            icon: Icons.delete_outline,
            label: 'Delete Record',
            subtitle: 'Permanently remove this patient',
            color: AppColors.emergencyRed,
            onTap: onDelete,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtleGrey,
                          height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}



class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   bold;
  const _InfoRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.subtleGrey,
                decoration: TextDecoration.none)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.bodyText,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                decoration: TextDecoration.none)),
      ],
    );
  }
}