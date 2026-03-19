import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/patient_info.dart';
import '../models/patient_session.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/patient_repository.dart';
import 'patient_info_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PATIENT RECORDS SCREEN
// Designed to be embedded inside HomeScreen's Scaffold (no Scaffold of its own)
// so the bottom nav bar persists. HomeScreen passes a FAB via floatingActionButton.
//
// Use patientRecordsFAB() to get the FAB widget to pass to HomeScreen.
// ═══════════════════════════════════════════════════════════════════════════════

enum StatusDot { green, amber, red }

// PatientRecord — thin view-model wrapping PatientSession for the UI.
// Built from real Hive data by PatientRecordRepo.fromSessions().
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

// Reads from Hive via PatientRepository
class PatientRecordRepo {
  static List<PatientRecord> all() {
    return PatientRepository.getAllSessions().map(_fromSession).toList();
  }

  static PatientRecord _fromSession(PatientSession s) {
    StatusDot dot;
    switch (s.status) {
      case 'reviewed':   dot = StatusDot.amber; break;
      case 'discharged': dot = StatusDot.red;   break;
      default:           dot = StatusDot.green;
    }
    return PatientRecord(
      id:                  s.sessionId,
      name:                s.patientName.isEmpty ? 'Unknown' : s.patientName,
      age:                 s.patientAge,
      gender:              s.patientGender,
      chiefComplaint:      s.chiefComplaint,
      provisionalDiagnosis: s.provisionalDx,
      dateOfAdmission:     s.dateOfAdmission,
      admissionMode:       s.modeOfAdmission,
      status:              dot,
    );
  }
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

// ── SCREEN (no Scaffold — embedded in HomeScreen) ─────────────────────────────

class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
  }

  // Called inside ValueListenableBuilder — always fresh from Hive
  List<PatientRecord> _getFiltered() {
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
          // ── Teal banner header ────────────────────────────────────────────
          Container(
            color: AppColors.sectionHeader,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.people, color: AppColors.headerText, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Patient Records',
                        style: TextStyle(
                          fontSize: 17,
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
          // ── Body ─────────────────────────────────────────────────────────
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
                  // ── List — ValueListenableBuilder keeps it live ──────────
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable:
                          Hive.box<PatientSession>('sessions').listenable(),
                      builder: (context, box, _) {
                        final records = _getFiltered();
                        return records.isEmpty
                            ? _buildEmpty()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 100),
                                itemCount: records.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) =>
                                    _PatientCard(record: records[i]),
                              );
                      },
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

// ── PATIENT CARD ──────────────────────────────────────────────────────────────

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
  PatientInfo _toPatientInfo() {
    // Restore full PatientInfo from Hive session (all fields preserved)
    final session = PatientRepository.getSession(record.id);
    if (session != null) {
      return PatientRepository.restorePatientInfo(session);
    }
    // Fallback if session not found
    return PatientInfo()
      ..fullName        = record.name
      ..age             = int.tryParse(record.age)
      ..gender          = record.gender
      ..dateOfAdmission = record.dateOfAdmission
      ..modeOfAdmission = record.admissionMode
      ..patientId       = record.id;
  }

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
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await PatientRepository.deleteSession(record.id);
              // ValueListenableBuilder auto-refreshes the list — no extra pop needed
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${record.name} deleted'),
                    backgroundColor: AppColors.emergencyRed,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
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
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PatientDetailScreen(record: record),
      )),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                // ── 3-dot menu button ──────────────────────────────────────
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
    ));
  }
}

// ── ACTION SHEET ──────────────────────────────────────────────────────────────

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
                color: color.withValues(alpha: 0.1),
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
            Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}


// ── INFO ROW ──────────────────────────────────────────────────────────────────

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

// ═══════════════════════════════════════════════════════════════════════════════
// PATIENT DETAIL SCREEN — full session view, pushed from card tap
// ═══════════════════════════════════════════════════════════════════════════════

class PatientDetailScreen extends StatelessWidget {
  final PatientRecord record;
  const PatientDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final session = PatientRepository.getSession(record.id);
    final info    = session != null ? PatientRepository.restorePatientInfo(session)   : null;
    final history = session != null ? PatientRepository.restoreHistory(session)       : null;
    final vitals  = session != null ? PatientRepository.restoreVitals(session)        : null;
    final labs    = session != null ? PatientRepository.restoreLabs(session)          : null;
    final soap    = session != null ? PatientRepository.restoreSoap(session)          : null;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
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
                    const Icon(Icons.person_outline,
                        color: AppColors.headerText, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(record.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.headerText)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('MR# ${record.id}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.headerText
                                  .withValues(alpha: 0.7))),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (info != null)    _DetailSection('Patient Info',    _buildInfoRows(info)),
                  if (history != null) _DetailSection('History',         _buildHistoryRows(history)),
                  if (vitals != null)  _DetailSection('Vitals',          _buildVitalsRows(vitals)),
                  if (labs != null)    _DetailSection('Labs',            _buildLabsRows(labs)),
                  if (soap != null)    _DetailSection('SOAP Note',       _buildSoapRows(soap)),
                  if (session == null) _emptyState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Full session data not available',
              style: TextStyle(color: AppColors.subtleGrey, fontSize: 14)),
        ),
      );

  // ── Patient info rows ─────────────────────────────────────────────────────
  List<_DetailRow> _buildInfoRows(dynamic info) => [
    _DetailRow('Full Name',         info.fullName),
    _DetailRow('Age',               info.age?.toString() ?? '-'),
    _DetailRow('Gender',            info.gender),
    _DetailRow('Date of Birth',     info.dateOfBirth.isEmpty ? '-' : info.dateOfBirth),
    _DetailRow('Address',           info.address.isEmpty ? '-' : info.address),
    _DetailRow('Marital Status',    info.maritalStatus.isEmpty ? '-' : info.maritalStatus),
    _DetailRow('Religion',          info.religion.isEmpty ? '-' : info.religion),
    _DetailRow('Mode of Admission', info.modeOfAdmission),
    _DetailRow('Date of Admission', info.dateOfAdmission != null
        ? '${info.dateOfAdmission!.day}/${info.dateOfAdmission!.month}/${info.dateOfAdmission!.year}'
        : '-'),
  ];

  // ── History rows ──────────────────────────────────────────────────────────
  List<_DetailRow> _buildHistoryRows(dynamic h) {
    final rows = <_DetailRow>[];
    if (h.complaints.isNotEmpty)
      rows.add(_DetailRow('Chief Complaints', h.complaints.join(', ')));
    if (h.complaintDetails.isNotEmpty) {
      for (final cd in h.complaintDetails) {
        rows.add(_DetailRow(cd.complaint,
            '${cd.durationValue} ${cd.durationUnit} — ${cd.severity}${cd.notes.isNotEmpty ? '\nNotes: ${cd.notes}' : ''}'));
      }
    }
    rows.add(_DetailRow('Hospitalizations',
        h.hadHospitalizations == true ? h.hospitalizationDetails : 'None'));
    rows.add(_DetailRow('Surgeries',
        h.hadSurgeries == true ? h.surgeryDetails : 'None'));
    rows.add(_DetailRow('Allergies',
        h.hasAllergies == true ? h.allergyDetails : 'None'));
    if (h.knownConditions.isNotEmpty)
      rows.add(_DetailRow('Known Conditions', h.knownConditions.join(', ')));
    if (h.occupation.isNotEmpty)
      rows.add(_DetailRow('Occupation', h.occupation));
    rows.add(_DetailRow('Smoking', h.smoking.isEmpty ? '-' : h.smoking));
    rows.add(_DetailRow('Alcohol', h.alcohol.isEmpty ? '-' : h.alcohol));
    if (h.currentDrugs.isNotEmpty)
      rows.add(_DetailRow('Current Drugs', h.currentDrugs.join(', ')));
    if (h.onRegularMedication == true && h.regularMedicationDetails.isNotEmpty)
      rows.add(_DetailRow('Regular Medication', h.regularMedicationDetails));
    if (h.familyMembers.isNotEmpty) {
      for (final fm in h.familyMembers) {
        rows.add(_DetailRow(
            'Family — ${fm.relationship}',
            fm.conditions.join(', ')));
      }
    }
    return rows;
  }

  // ── Vitals rows ───────────────────────────────────────────────────────────
  List<_DetailRow> _buildVitalsRows(dynamic v) {
    final rows = <_DetailRow>[];
    if (v.systolic != null && v.diastolic != null)
      rows.add(_DetailRow('Blood Pressure',
          '${v.systolic!.toStringAsFixed(0)}/${v.diastolic!.toStringAsFixed(0)} mmHg'));
    if (v.pulse != null)
      rows.add(_DetailRow('Pulse', '${v.pulse!.toStringAsFixed(0)} bpm'));
    if (v.temperature != null)
      rows.add(_DetailRow('Temperature',
          '${v.temperature!.toStringAsFixed(1)} ${v.isFahrenheit ? '°F' : '°C'}'));
    if (v.respiratoryRate != null)
      rows.add(_DetailRow('Respiratory Rate',
          '${v.respiratoryRate!.toStringAsFixed(0)} /min'));
    if (v.spO2 != null)
      rows.add(_DetailRow('SpO2', '${v.spO2!.toStringAsFixed(1)}%'));
    if (v.weightKg != null)
      rows.add(_DetailRow('Weight', '${v.weightKg!.toStringAsFixed(1)} kg'));
    if (v.heightCm != null)
      rows.add(_DetailRow('Height', '${v.heightCm!.toStringAsFixed(1)} cm'));
    if (v.bmi != null)
      rows.add(_DetailRow('BMI', v.bmi!.toStringAsFixed(1)));
    if (v.bloodGlucose != null)
      rows.add(_DetailRow('Blood Glucose',
          '${v.bloodGlucose!.toStringAsFixed(1)} mg/dL (${v.isFastingGlucose ? 'Fasting' : 'Random'})'));
    return rows.isEmpty ? [const _DetailRow('Vitals', 'None recorded')] : rows;
  }

  // ── Labs rows ─────────────────────────────────────────────────────────────
  List<_DetailRow> _buildLabsRows(dynamic l) {
    final rows = <_DetailRow>[];
    final abnormals = l.abnormalSummary as List<String>;
    if (abnormals.isEmpty) {
      rows.add(const _DetailRow('Lab Results', 'All within normal limits'));
    } else {
      for (final a in abnormals) {
        final parts = a.split(':');
        rows.add(_DetailRow(
            parts.first.trim(),
            parts.length > 1 ? parts.sublist(1).join(':').trim() : a));
      }
    }
    if ((l.bloodCultureResult as String).isNotEmpty)
      rows.add(_DetailRow('Blood Culture', l.bloodCultureResult));
    if ((l.urineCultureResult as String).isNotEmpty)
      rows.add(_DetailRow('Urine Culture', l.urineCultureResult));
    return rows;
  }

  // ── SOAP rows ─────────────────────────────────────────────────────────────
  List<_DetailRow> _buildSoapRows(dynamic soap) => [
    _DetailRow('Subjective',  soap.subjective.isEmpty  ? '-' : soap.subjective),
    _DetailRow('Objective',   soap.objective.isEmpty   ? '-' : soap.objective),
    _DetailRow('Assessment',  soap.assessment.isEmpty  ? '-' : soap.assessment),
    _DetailRow('Plan',        soap.plan.isEmpty        ? '-' : soap.plan),
  ];
}

// ── Section card ──────────────────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String          title;
  final List<_DetailRow> rows;
  const _DetailSection(this.title, this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sectionHeader,
                    letterSpacing: 0.5)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(rows[i].label,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.subtleGrey,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rows[i].value,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.bodyText,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1)
                    const Divider(
                        height: 1, thickness: 1,
                        color: AppColors.divider, indent: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}