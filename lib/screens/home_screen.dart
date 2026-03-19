import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'patient_info_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient_session.dart';
import '../services/patient_repository.dart' as repo;
import 'patient_records_screen.dart';
import 'settings_screen.dart';

// DATA MODELS
class RecentPatient {
  final String   id;
  final String   name;
  final String   diagnosis;
  final String   admissionMode;
  final DateTime admittedOn;
  final bool     isOnline;

  const RecentPatient({
    required this.id,
    required this.name,
    required this.diagnosis,
    required this.admissionMode,
    required this.admittedOn,
    this.isOnline = true,
  });
}
class PatientRepository {
  static List<RecentPatient> getRecentPatients() {
    return repo.PatientRepository.getAllSessions()
        .take(5)
        .map((s) => RecentPatient(
              id:            s.sessionId,
              name:          s.patientName.isEmpty ? 'Unknown' : s.patientName,
              diagnosis:     s.provisionalDx.isEmpty ? s.chiefComplaint : s.provisionalDx,
              admissionMode: s.modeOfAdmission,
              admittedOn:    s.dateOfAdmission,
              isOnline:      s.status == 'active',
            ))
        .toList();
  }

  static int getTodayCases() {
    final today = DateTime.now();
    return repo.PatientRepository.getAllSessions()
        .where((s) =>
            s.dateOfAdmission.year  == today.year &&
            s.dateOfAdmission.month == today.month &&
            s.dateOfAdmission.day   == today.day)
        .length;
  }

  static int getPendingFlags() => repo.PatientRepository.getAllSessions()
      .where((s) => s.provisionalDx.isNotEmpty).length;

  static int getTotalSaved() => repo.PatientRepository.getAllSessions().length;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0;

  void _onNavTap(int i) {
    if (i == 3) {
      // New tab (rightmost) — push PatientInfoScreen as a focused flow, no navbar
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PatientInfoScreen()));
    } else {
      setState(() => _activeNavIndex = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Use IndexedStack so all tabs stay alive when switching
      body: IndexedStack(
        index: _activeNavIndex,
        children: [
          _HomeBody(onViewAllPatients: () => setState(() => _activeNavIndex = 1)),
          const PatientRecordsScreen(), // tab 1 — Patients
          const SettingsScreen(),       // tab 2 — Settings
          const SizedBox.shrink(),      // tab 3 = New (always pushes, never shown here)
        ],
      ),
      // Show FAB only on Patients tab (tab 1)
      floatingActionButton: _activeNavIndex == 1
          ? patientRecordsFAB(context)
          : null,
      bottomNavigationBar: _BottomNavBar(
        activeIndex: _activeNavIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
//home body extracted so can be used later above
class _HomeBody extends StatelessWidget {
  final VoidCallback? onViewAllPatients;
  const _HomeBody({this.onViewAllPatients});

@override
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: Hive.box<PatientSession>('sessions').listenable(),
    builder: (context, box, _) {
      final patients = PatientRepository.getRecentPatients();
      return _buildContent(context, patients);
    },
  );
}

Widget _buildContent(BuildContext context, List<RecentPatient> patients) {
  return SafeArea(
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [

        const SliverToBoxAdapter(child: _AppHeader()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // New Patient — now goes to PatientInfoScreen
                _QuickActionCard(
                  icon: Icons.person_add_alt_1,
                  label: 'New Patient',
                  description: 'Start history taking for a new case.',
                  fullWidth: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientInfoScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _QuickActionCard(
                  icon: Icons.folder_open,
                  label: 'Patient Records',
                  description: 'Browse and search all saved patient records.',
                  fullWidth: true,
                  onTap: () => onViewAllPatients?.call(),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: _SectionHeader(title: "Today's Summary"),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.assignment_turned_in,
                    value: PatientRepository.getTodayCases().toString(),
                    label: 'Cases\nToday',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.warning_amber_rounded,
                    value: PatientRepository.getPendingFlags().toString(),
                    label: 'Diagnosed',
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.save_outlined,
                    value: PatientRepository.getTotalSaved().toString(),
                    label: 'Total\nSaved',
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: _SectionHeader(
              title: 'Recent Patients',
              actionLabel: 'View All',
              onAction: onViewAllPatients,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PatientChip(
                patient: patients[i],
                onTapCallback: onViewAllPatients,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    ),
  );
}
}

// WIDGETS FINALLY

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.constitutional, // light teal tint — spec: header stands out
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MediScribe AI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bodyText,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Welcome, ${SettingsService.instance.clinicianName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.bodyText,
                      ),
                    ),
                    
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _OfflineBadge(),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.onlineGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Offline Ready',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}

// Section Header: teal pill label + optional "View All"
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.sectionHeader,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.headerText,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.sectionHeader,
              ),
            ),
          ),
      ],
    );
  }
}

//QUICK card 
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool fullWidth;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teal accent bar at top
            Container(height: 4, color: AppColors.sectionHeader),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.constitutional,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.sectionHeader,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sectionHeader,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.subtleGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fullWidth)
                    const Icon(
                      // chevron_right: right-pointing arrow — standard Material
                      Icons.chevron_right,
                      color: AppColors.subtleGrey,
                      size: 20,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight; // orange-tint for warnings

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = highlight ? const Color(0xFFF57C00) : AppColors.sectionHeader;
    final bgColor   = highlight ? const Color(0xFFFFF3E0) : AppColors.constitutional;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.bodyText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.subtleGrey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientChip extends StatelessWidget {
  final RecentPatient patient;
  final VoidCallback? onTapCallback;

  const _PatientChip({required this.patient, this.onTapCallback});

  @override
  Widget build(BuildContext context) {
    final isEmergency = patient.admissionMode == 'Emergency';

    return GestureDetector(
      onTap: () => onTapCallback?.call(),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Name + online dot
            Row(
              children: [
                Expanded(
                  child: Text(
                    patient.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bodyText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: patient.isOnline
                        ? AppColors.onlineGreen
                        : AppColors.subtleGrey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              patient.diagnosis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.subtleGrey,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Admission mode pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isEmergency
                    ? AppColors.emergencyBg
                    : AppColors.constitutional,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                patient.admissionMode,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isEmergency
                      ? AppColors.emergencyRed
                      : AppColors.sectionHeader,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Bottom nav bar, icon verified from googles icons
class _BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.activeIndex, required this.onTap});

  // Tab 2 (New) is special — it pushes a screen instead of switching tabs
  // so it renders differently (teal circle button) and never becomes "active"
  static const List<_NavItemData> _items = [
    _NavItemData(icon: Icons.home_outlined,     activeIcon: Icons.home,     label: 'Home'),
    _NavItemData(icon: Icons.people_outline,    activeIcon: Icons.people,   label: 'Patients'),
    _NavItemData(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
    _NavItemData(icon: Icons.add,               activeIcon: Icons.add,      label: 'New', isAction: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == activeIndex;

              // "New" tab — rendered as teal FAB-style circle
              if (item.isAction) {
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.sectionHeader,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.headerText, size: 24),
                      ),
                      const SizedBox(height: 3),
                      const Text('New',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sectionHeader)),
                    ],
                  ),
                );
              }

              // Regular tab
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 4 : 0,
                        height: active ? 4 : 0,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.sectionHeader,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color: active
                            ? AppColors.sectionHeader
                            : AppColors.subtleGrey,
                        size: 24,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active
                              ? AppColors.sectionHeader
                              : AppColors.subtleGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isAction; // true = teal circle button (New Patient)

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isAction = false,
  });
}