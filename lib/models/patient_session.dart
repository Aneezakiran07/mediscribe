class PatientSession {
  String sessionId;
  String patientName;
  String examinationType;
  Map<String, dynamic> answers;
  int totalScore;
  String acuityLevel;
  DateTime timestamp;

  PatientSession({
    required this.sessionId,
    required this.patientName,
    required this.examinationType,
    required this.answers,
    required this.totalScore,
    required this.acuityLevel,
    required this.timestamp,
  });
}