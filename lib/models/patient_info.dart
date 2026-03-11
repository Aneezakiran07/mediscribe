class PatientInfo {
  String fullName        = '';
  int?   age;
  String gender          = '';
  String dateOfBirth     = '';
  String address         = '';
  DateTime? dateOfAdmission;
  String modeOfAdmission = 'OPD';
  String maritalStatus   = '';
  String religion        = '';
  String patientId       = '';

  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      age != null &&
      gender.isNotEmpty;
}