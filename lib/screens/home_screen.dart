import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'history_taking_screen.dart';
import '../core/app_colors.dart';


// DATA MODELS
// Hive wiring notes (RecentPatient):
//   @HiveType(typeId: 0)  on class
//   @HiveField(n)         on each field
//   run: flutter pub run build_runner build
//   read: Hive.box<RecentPatient>('patients').values.toList()
class RecentPatient {
  final String id;
  final String name;
  final String diagnosis;
  final String admissionMode; // 'Emergency' | 'OPD'
  final DateTime admittedOn;
  final bool isOnline;

  const RecentPatient({
    required this.id,
    required this.name,
    required this.diagnosis,
    required this.admissionMode,
    required this.admittedOn,
    this.isOnline = true,
  });
}

//swap body w hive when reade
class PatientRepository {
  static List<RecentPatient> getRecentPatients() => [
        RecentPatient(
          id: '001', name: 'John Doe',
          diagnosis: 'Hypertension',
          admissionMode: 'OPD',
          admittedOn: DateTime(2026, 2, 28),
          isOnline: true,
        ),
        RecentPatient(
          id: '002', name: 'Jane Smith',
          diagnosis: 'Pneumonia',
          admissionMode: 'Emergency',
          admittedOn: DateTime(2026, 2, 27),
          isOnline: true,
        ),
        RecentPatient(
          id: '003', name: 'Robert B.',
          diagnosis: 'Acute Myocarditis',
          admissionMode: 'Emergency',
          admittedOn: DateTime(2026, 2, 25),
          isOnline: false,
        ),
        RecentPatient(
          id: '004', name: 'Aisha K.',
          diagnosis: 'Appendicitis',
          admissionMode: 'Emergency',
          admittedOn: DateTime(2026, 2, 24),
          isOnline: true,
        ),
      ];

  // Replace with: Hive.box('stats').get('todayCases', defaultValue: 0)
  static int getTodayCases()    => 4;
  static int getPendingFlags()  => 2;
  static int getTotalSaved()    => 12;
}

// ═══════════════════════════════════════════════════════════════════════════════
void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediScribe AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.sectionHeader,
          surface: AppColors.background,
        ),
),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0;

  // Each nav tab would push its own screen 
  // TODO: replace body with Navigator when screens exist
  final List<Widget> _pages = const [
    _HomeBody(),
    // TODO: PatientListScreen(),
    // TODO: DiagnoseScreen(),
    // TODO: LabsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _HomeBody(), // always show home body for now
      bottomNavigationBar: _BottomNavBar(
        activeIndex: _activeNavIndex,
        onTap: (i) => setState(() => _activeNavIndex = i),
      ),
    );
  }
}
//home body extracted so can be used later above
class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final patients = PatientRepository.getRecentPatients();

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          const SliverToBoxAdapter(child: _AppHeader()),
          //. quick actiosn
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // New Patient 
                  _QuickActionCard(
                    // person_add_alt_1: adds a person with a plus 
                    icon: Icons.person_add_alt_1,
                    label: 'New Patient',
                    description: 'Start history taking for a new case.',
                    fullWidth: true,
                    onTap: () {
                      // navigate to history taking
                    Navigator.push(
                       context,
                       MaterialPageRoute(
                          builder: (_) => const HistoryTakingScreen(),
                       ),
                      );
                    
                    },
                  ),

                  const SizedBox(height: 12),

                  // 2-column row
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          // folder_open: open folder — standard Material
                          icon: Icons.folder_open,
                          label: 'Patient Records',
                          description: 'Browse all saved records.',
                          onTap: () {
                            // TODO: Navigator.push → PatientListScreen
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          // assignment_outlined: clipboard checklist 
                          icon: Icons.assignment_outlined,
                          label: 'Exam Guidance',
                          description: 'Step-by-step clinical exam.',
                          onTap: () {
                            // TODO: Navigator.push → ExaminationScreen
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─today stats
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
                      // assignment_turned_in: clipboard with tick 
                      icon: Icons.assignment_turned_in,
                      value: PatientRepository.getTodayCases().toString(),
                      label: 'Cases\nToday',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      // warning_amber_rounded: triangle warning
                      icon: Icons.warning_amber_rounded,
                      value: PatientRepository.getPendingFlags().toString(),
                      label: 'Pending\nFlags',
                      highlight: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      // save_outlined: floppy disk save — standard Material
                      icon: Icons.save_outlined,
                      value: PatientRepository.getTotalSaved().toString(),
                      label: 'Total\nSaved',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // recent patients
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: _SectionHeader(
                title: 'Recent Patients',
                actionLabel: 'View All',
                onAction: () {
                  // TODO: Navigator.push → PatientListScreen
                },
              ),
            ),
          ),

          // Horizontal patient chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: patients.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _PatientChip(patient: patients[i]),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _TipBanner(),
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
              children: const [
                Text(
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
                      'Welcome, Doctor ',
                      style: TextStyle(
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
              color: Colors.black.withOpacity(0.04),
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

  const _PatientChip({required this.patient});

  @override
  Widget build(BuildContext context) {
    final isEmergency = patient.admissionMode == 'Emergency';

    return GestureDetector(
      onTap: () {
        // TODO: Navigator.push(context,
        //   MaterialPageRoute(builder: (_) => PatientDetailScreen(id: patient.id)));
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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

class _TipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.constitutional,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.sectionHeader.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              // lightbulb_outline: idea/tip icon — standard Material
              Icons.lightbulb_outline,
              color: AppColors.sectionHeader,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip of the Day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sectionHeader,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Always complete history before examination — a thorough HOPI guides your diagnosis.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subtleGrey,
                    height: 1.4,
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

//Bottom nav bar, icon verified from googles icons
class _BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.activeIndex, required this.onTap});

  static const List<_NavItemData> _items = [
    _NavItemData(
      // home_outlined / home — house shape
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    _NavItemData(
      // people_outline / people — group of people
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Patients',
    ),
    _NavItemData(
      // psychology_outlined / psychology — brain/head shape, represents AI diagnosis
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology,
      label: 'Diagnose',
    ),
    _NavItemData(
      // biotech_outlined / biotech — microscope shape, represents lab/science
      icon: Icons.biotech_outlined,
      activeIcon: Icons.biotech,
      label: 'Labs',
    ),
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
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active indicator dot above icon
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
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
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

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
