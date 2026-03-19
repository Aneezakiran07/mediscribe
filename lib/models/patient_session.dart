// lib/models/patient_session.dart
//
// Single Hive-persisted model for a complete patient encounter.
// Stores all sub-data as JSON strings — no nested adapters needed.
// TypeId: 0  (only one registered adapter in this app)

import 'package:hive/hive.dart';

// ── ADAPTER (hand-written — no build_runner needed) ───────────────────────────
class PatientSessionAdapter extends TypeAdapter<PatientSession> {
  @override final int typeId = 0;

  @override
  PatientSession read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return PatientSession()
      ..sessionId        = (f[0]  as String?)   ?? ''
      ..patientName      = (f[1]  as String?)   ?? ''
      ..patientAge       = (f[2]  as String?)   ?? ''
      ..patientGender    = (f[3]  as String?)   ?? ''
      ..patientId        = (f[4]  as String?)   ?? ''
      ..modeOfAdmission  = (f[5]  as String?)   ?? 'OPD'
      ..dateOfAdmission  = (f[6]  as DateTime?) ?? DateTime.now()
      ..chiefComplaint   = (f[7]  as String?)   ?? ''
      ..provisionalDx    = (f[8]  as String?)   ?? ''
      ..status           = (f[9]  as String?)   ?? 'active'
      ..patientInfoJson  = (f[10] as String?)   ?? '{}'
      ..historyJson      = (f[11] as String?)   ?? '{}'
      ..systemicJson     = (f[12] as String?)   ?? '{}'
      ..vitalsJson       = (f[13] as String?)   ?? '{}'
      ..labsJson         = (f[14] as String?)   ?? '{}'
      ..examinationJson  = (f[15] as String?)   ?? '{}'
      ..soapSubjective   = (f[16] as String?)   ?? ''
      ..soapObjective    = (f[17] as String?)   ?? ''
      ..soapAssessment   = (f[18] as String?)   ?? ''
      ..soapPlan         = (f[19] as String?)   ?? ''
      ..soapGeneratedAt  =  f[20] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, PatientSession obj) {
    writer.writeByte(21);
    writer
      ..writeByte(0)..write(obj.sessionId)
      ..writeByte(1)..write(obj.patientName)
      ..writeByte(2)..write(obj.patientAge)
      ..writeByte(3)..write(obj.patientGender)
      ..writeByte(4)..write(obj.patientId)
      ..writeByte(5)..write(obj.modeOfAdmission)
      ..writeByte(6)..write(obj.dateOfAdmission)
      ..writeByte(7)..write(obj.chiefComplaint)
      ..writeByte(8)..write(obj.provisionalDx)
      ..writeByte(9)..write(obj.status)
      ..writeByte(10)..write(obj.patientInfoJson)
      ..writeByte(11)..write(obj.historyJson)
      ..writeByte(12)..write(obj.systemicJson)
      ..writeByte(13)..write(obj.vitalsJson)
      ..writeByte(14)..write(obj.labsJson)
      ..writeByte(15)..write(obj.examinationJson)
      ..writeByte(16)..write(obj.soapSubjective)
      ..writeByte(17)..write(obj.soapObjective)
      ..writeByte(18)..write(obj.soapAssessment)
      ..writeByte(19)..write(obj.soapPlan)
      ..writeByte(20)..write(obj.soapGeneratedAt);
  }
}

// ── MODEL ─────────────────────────────────────────────────────────────────────
class PatientSession extends HiveObject {
  String   sessionId        = '';
  String   patientName      = '';
  String   patientAge       = '';
  String   patientGender    = '';
  String   patientId        = '';
  String   modeOfAdmission  = 'OPD';
  DateTime dateOfAdmission  = DateTime.now();
  String   chiefComplaint   = '';
  String   provisionalDx    = '';
  String   status           = 'active'; // active | reviewed | discharged

  // Full sub-data stored as JSON — deserialised by PatientRepository
  String patientInfoJson  = '{}';
  String historyJson      = '{}';
  String systemicJson     = '{}';
  String vitalsJson       = '{}';
  String labsJson         = '{}';
  String examinationJson  = '{}';
  String soapSubjective   = '';
  String soapObjective    = '';
  String soapAssessment   = '';
  String soapPlan         = '';
  DateTime? soapGeneratedAt;
}
