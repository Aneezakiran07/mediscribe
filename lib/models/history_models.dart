// lib/models/history_models.dart
// Extracted from history_taking_screen.dart
// Import this wherever you need HistoryFormData, ComplaintDetail, FamilyMember

// @HiveType(typeId: 1)
class ComplaintDetail {
  String complaint;
  int    durationValue;
  String durationUnit; // 'hours' | 'days' | 'weeks' | 'months' | 'years'
  String severity;     // 'mild' | 'moderate' | 'severe'
  String notes;

  ComplaintDetail({
    required this.complaint,
    this.durationValue = 1,
    this.durationUnit  = 'days',
    this.severity      = 'mild',
    this.notes         = '',
  });
}

// @HiveType(typeId: 2)
class FamilyMember {
  String       relationship;
  List<String> conditions;
  String       notes;
  bool         isDeceased;

  FamilyMember({
    this.relationship = '',
    List<String>? conditions,
    this.notes        = '',
    this.isDeceased   = false,
  }) : conditions = conditions ?? [];
}

// @HiveType(typeId: 3)
class HistoryFormData {
  // Page 1, Complaints + HOPI
  List<String>          complaints        = [];
  List<ComplaintDetail> complaintDetails  = [];

  // Page 2, Past / Personal / Drug history
  bool?  hadHospitalizations;
  String hospitalizationDetails    = '';
  bool?  hadSurgeries;
  String surgeryDetails            = '';
  bool?  hasAllergies;
  String allergyDetails            = '';
  List<String> knownConditions     = [];
  String occupation                = '';
  String smoking                   = '';
  String alcohol                   = '';
  String livingConditions          = '';
  String diet                      = '';
  String sleep                     = '';
  String bladder                   = '';
  String bowelHabits               = '';
  List<String> currentDrugs        = [];
  bool?  onRegularMedication;
  String regularMedicationDetails  = '';
  bool?  hasAdverseReactions;
  String adverseReactionDetails    = '';

  // Page 3, Family history
  List<FamilyMember> familyMembers = [];
  String familyNotes               = '';

  // Passed to SystemicHistoryScreen
  // Keep in sync when PatientInfo is available (set from patientInfo.gender)
  String patientGender = 'Male'; // 'Male' | 'Female' | 'Other'
}
