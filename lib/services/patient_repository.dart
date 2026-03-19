// lib/services/patient_repository.dart
//
// Single source of truth for all patient data operations.
// Uses Hive box 'sessions' with PatientSession objects.
//
// Usage:
//   // Save after SOAP note is generated:
//   await PatientRepository.saveSession(session);
//
//   // Load all for records screen:
//   final all = PatientRepository.getAllSessions();
//
//   // Delete:
//   await PatientRepository.deleteSession(sessionId);

import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/patient_session.dart';
import '../models/patient_info.dart';
import '../models/history_models.dart';
import '../models/systemic_models.dart';
import '../models/vitals_models.dart';
import '../models/lab_models.dart';
import '../models/examination_models.dart';
import '../models/soap_models.dart';

class PatientRepository {
  PatientRepository._();

  static Box<PatientSession> get _box => Hive.box<PatientSession>('sessions');

  // ── SAVE (create or update) ───────────────────────────────────────────────
  static Future<String> saveSession({
    required PatientInfo       patient,
    required HistoryFormData   history,
    required SystemicHistoryData? systemic,
    required VitalsData        vitals,
    required LabData           labs,
    required ExaminationData   examination,
    required SoapNote          soap,
    String? existingSessionId,
  }) async {
    final id = existingSessionId ??
        'S-${DateTime.now().millisecondsSinceEpoch}';

    // Extract chief complaint from history
    final cc = history.complaintDetails.isNotEmpty
        ? history.complaintDetails.first.complaint
        : history.complaints.isNotEmpty
            ? history.complaints.first
            : '';

    // Extract provisional diagnosis from SOAP assessment
    final dx = soap.assessment.isNotEmpty
        ? soap.assessment.split('\n').first.replaceAll('Assessment: ', '')
        : '';

    final session = PatientSession()
      ..sessionId        = id
      ..patientName      = patient.fullName
      ..patientAge       = patient.age?.toString() ?? ''
      ..patientGender    = patient.gender
      ..patientId        = patient.patientId
      ..modeOfAdmission  = patient.modeOfAdmission
      ..dateOfAdmission  = patient.dateOfAdmission ?? DateTime.now()
      ..chiefComplaint   = cc
      ..provisionalDx    = dx
      ..status           = 'active'
      ..patientInfoJson  = jsonEncode(_serializePatientInfo(patient))
      ..historyJson      = jsonEncode(_serializeHistory(history))
      ..systemicJson     = jsonEncode(_serializeSystemic(systemic))
      ..vitalsJson       = jsonEncode(_serializeVitals(vitals))
      ..labsJson         = jsonEncode(_serializeLabs(labs))
      ..examinationJson  = jsonEncode(_serializeExamination(examination))
      ..soapSubjective   = soap.subjective
      ..soapObjective    = soap.objective
      ..soapAssessment   = soap.assessment
      ..soapPlan         = soap.plan
      ..soapGeneratedAt  = soap.generatedAt;

    await _box.put(id, session);
    return id;
  }

  // ── READ ──────────────────────────────────────────────────────────────────
  static List<PatientSession> getAllSessions() {
    final list = _box.values.toList();
    list.sort((a, b) => b.dateOfAdmission.compareTo(a.dateOfAdmission));
    return list;
  }

  static PatientSession? getSession(String id) => _box.get(id);

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> deleteSession(String sessionId) async {
    await _box.delete(sessionId);
  }

  // ── RESTORE full objects from session ────────────────────────────────────
  static PatientInfo restorePatientInfo(PatientSession s) {
    final m = jsonDecode(s.patientInfoJson) as Map<String, dynamic>;
    return _deserializePatientInfo(m);
  }

  static HistoryFormData restoreHistory(PatientSession s) {
    final m = jsonDecode(s.historyJson) as Map<String, dynamic>;
    return _deserializeHistory(m);
  }

  static VitalsData restoreVitals(PatientSession s) {
    final m = jsonDecode(s.vitalsJson) as Map<String, dynamic>;
    return _deserializeVitals(m);
  }

  static LabData restoreLabs(PatientSession s) {
    final m = jsonDecode(s.labsJson) as Map<String, dynamic>;
    return _deserializeLabs(m);
  }

  static SoapNote restoreSoap(PatientSession s) {
    return SoapNote()
      ..subjective  = s.soapSubjective
      ..objective   = s.soapObjective
      ..assessment  = s.soapAssessment
      ..plan        = s.soapPlan
      ..generatedAt = s.soapGeneratedAt ?? DateTime.now();
  }


  static SystemicHistoryData restoreSystemic(PatientSession s) {
    final m = jsonDecode(s.systemicJson) as Map<String, dynamic>;
    return _deserializeSystemic(m);
  }

  static ExaminationData restoreExamination(PatientSession s) {
    final m = jsonDecode(s.examinationJson) as Map<String, dynamic>;
    return _deserializeExamination(m);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SERIALISERS
  // ════════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _serializePatientInfo(PatientInfo p) => {
    'fullName':        p.fullName,
    'age':             p.age,
    'gender':          p.gender,
    'dateOfBirth':     p.dateOfBirth,
    'address':         p.address,
    'dateOfAdmission': p.dateOfAdmission?.toIso8601String(),
    'modeOfAdmission': p.modeOfAdmission,
    'maritalStatus':   p.maritalStatus,
    'religion':        p.religion,
    'patientId':       p.patientId,
  };

  static PatientInfo _deserializePatientInfo(Map<String, dynamic> m) {
    return PatientInfo()
      ..fullName        = m['fullName']        as String? ?? ''
      ..age             = m['age']             as int?
      ..gender          = m['gender']          as String? ?? ''
      ..dateOfBirth     = m['dateOfBirth']     as String? ?? ''
      ..address         = m['address']         as String? ?? ''
      ..dateOfAdmission = m['dateOfAdmission'] != null
          ? DateTime.tryParse(m['dateOfAdmission'] as String)
          : null
      ..modeOfAdmission = m['modeOfAdmission'] as String? ?? 'OPD'
      ..maritalStatus   = m['maritalStatus']   as String? ?? ''
      ..religion        = m['religion']        as String? ?? ''
      ..patientId       = m['patientId']       as String? ?? '';
  }

  static Map<String, dynamic> _serializeHistory(HistoryFormData h) => {
    'complaints':       h.complaints,
    'complaintDetails': h.complaintDetails.map((c) => {
      'complaint':     c.complaint,
      'durationValue': c.durationValue,
      'durationUnit':  c.durationUnit,
      'severity':      c.severity,
      'notes':         c.notes,
    }).toList(),
    'hadHospitalizations':      h.hadHospitalizations,
    'hospitalizationDetails':   h.hospitalizationDetails,
    'hadSurgeries':             h.hadSurgeries,
    'surgeryDetails':           h.surgeryDetails,
    'hasAllergies':             h.hasAllergies,
    'allergyDetails':           h.allergyDetails,
    'knownConditions':          h.knownConditions,
    'occupation':               h.occupation,
    'smoking':                  h.smoking,
    'alcohol':                  h.alcohol,
    'livingConditions':         h.livingConditions,
    'diet':                     h.diet,
    'sleep':                    h.sleep,
    'bladder':                  h.bladder,
    'bowelHabits':              h.bowelHabits,
    'currentDrugs':             h.currentDrugs,
    'onRegularMedication':      h.onRegularMedication,
    'regularMedicationDetails': h.regularMedicationDetails,
    'hasAdverseReactions':      h.hasAdverseReactions,
    'adverseReactionDetails':   h.adverseReactionDetails,
    'familyMembers': h.familyMembers.map((fm) => {
      'relationship': fm.relationship,
      'conditions':   fm.conditions,
      'notes':        fm.notes,
      'isDeceased':   fm.isDeceased,
    }).toList(),
    'familyNotes':    h.familyNotes,
    'patientGender':  h.patientGender,
  };

  static HistoryFormData _deserializeHistory(Map<String, dynamic> m) {
    final h = HistoryFormData();
    h.complaints       = List<String>.from(m['complaints'] ?? []);
    h.complaintDetails = ((m['complaintDetails'] as List?) ?? []).map((c) =>
      ComplaintDetail(
        complaint:     c['complaint']     as String? ?? '',
        durationValue: c['durationValue'] as int?    ?? 1,
        durationUnit:  c['durationUnit']  as String? ?? 'days',
        severity:      c['severity']      as String? ?? 'mild',
        notes:         c['notes']         as String? ?? '',
      )).toList();
    h.hadHospitalizations      = m['hadHospitalizations']      as bool?;
    h.hospitalizationDetails   = m['hospitalizationDetails']   as String? ?? '';
    h.hadSurgeries             = m['hadSurgeries']             as bool?;
    h.surgeryDetails           = m['surgeryDetails']           as String? ?? '';
    h.hasAllergies             = m['hasAllergies']             as bool?;
    h.allergyDetails           = m['allergyDetails']           as String? ?? '';
    h.knownConditions          = List<String>.from(m['knownConditions'] ?? []);
    h.occupation               = m['occupation']               as String? ?? '';
    h.smoking                  = m['smoking']                  as String? ?? '';
    h.alcohol                  = m['alcohol']                  as String? ?? '';
    h.livingConditions         = m['livingConditions']         as String? ?? '';
    h.diet                     = m['diet']                     as String? ?? '';
    h.sleep                    = m['sleep']                    as String? ?? '';
    h.bladder                  = m['bladder']                  as String? ?? '';
    h.bowelHabits              = m['bowelHabits']              as String? ?? '';
    h.currentDrugs             = List<String>.from(m['currentDrugs'] ?? []);
    h.onRegularMedication      = m['onRegularMedication']      as bool?;
    h.regularMedicationDetails = m['regularMedicationDetails'] as String? ?? '';
    h.hasAdverseReactions      = m['hasAdverseReactions']      as bool?;
    h.adverseReactionDetails   = m['adverseReactionDetails']   as String? ?? '';
    h.familyMembers = ((m['familyMembers'] as List?) ?? []).map((fm) =>
      FamilyMember(
        relationship: fm['relationship'] as String? ?? '',
        conditions:   List<String>.from(fm['conditions'] ?? []),
        notes:        fm['notes']        as String? ?? '',
        isDeceased:   fm['isDeceased']   as bool?   ?? false,
      )).toList();
    h.familyNotes   = m['familyNotes']   as String? ?? '';
    h.patientGender = m['patientGender'] as String? ?? 'Male';
    return h;
  }

  static Map<String, dynamic> _serializeSystemic(SystemicHistoryData? s) {
    if (s == null) return {};
    // Serialize each named system map
    Map<String, dynamic> serializeSymptomMap(Map<String, bool?> m) =>
        m.map((k, v) => MapEntry(k, v));
    return {
      'cardiovascular':   serializeSymptomMap(s.cardiovascular),
      'respiratory':      serializeSymptomMap(s.respiratory),
      'cns':              serializeSymptomMap(s.cns),
      'gastrointestinal': serializeSymptomMap(s.gastrointestinal),
      'genitourinary':    serializeSymptomMap(s.genitourinary),
      'musculoskeletal':  serializeSymptomMap(s.musculoskeletal),
      'gynaecological':   serializeSymptomMap(s.gynaecological),
      'endocrine':        serializeSymptomMap(s.endocrine),
      'constitutional':   serializeSymptomMap(s.constitutional),
      'customSymptoms':   s.customSymptoms,
      'customEntries': s.customEntries.map((e) => {
        'system':  e.system,
        'symptom': e.symptom,
        'answer':  e.answer,
      }).toList(),
    };
  }

  static SystemicHistoryData _deserializeSystemic(Map<String, dynamic> m) {
    final s = SystemicHistoryData();
    void loadMap(Map<String, bool?> target, String key) {
      final raw = m[key] as Map<String, dynamic>?;
      if (raw == null) return;
      raw.forEach((k, v) => target[k] = v as bool?);
    }
    loadMap(s.cardiovascular,   'cardiovascular');
    loadMap(s.respiratory,      'respiratory');
    loadMap(s.cns,              'cns');
    loadMap(s.gastrointestinal, 'gastrointestinal');
    loadMap(s.genitourinary,    'genitourinary');
    loadMap(s.musculoskeletal,  'musculoskeletal');
    loadMap(s.gynaecological,   'gynaecological');
    loadMap(s.endocrine,        'endocrine');
    loadMap(s.constitutional,   'constitutional');
    final cs = m['customSymptoms'] as Map<String, dynamic>?;
    if (cs != null) {
      cs.forEach((k, v) => s.customSymptoms[k] = List<String>.from(v as List));
    }
    final ce = m['customEntries'] as List?;
    if (ce != null) {
      for (final e in ce) {
        s.customEntries.add(CustomSystemEntry(
          system:  e['system']  as String? ?? '',
          symptom: e['symptom'] as String? ?? '',
          answer:  e['answer']  as bool?,
        ));
      }
    }
    return s;
  }

  static Map<String, dynamic> _serializeVitals(VitalsData v) => {
    'systolic':         v.systolic,
    'diastolic':        v.diastolic,
    'pulse':            v.pulse,
    'temperature':      v.temperature,
    'isFahrenheit':     v.isFahrenheit,
    'respiratoryRate':  v.respiratoryRate,
    'spO2':             v.spO2,
    'weightKg':         v.weightKg,
    'heightCm':         v.heightCm,
    'bloodGlucose':     v.bloodGlucose,
    'isFastingGlucose': v.isFastingGlucose,
    'customVitals': v.customVitals.map((cv) => {
      'name':  cv.name,
      'value': cv.value,
      'unit':  cv.unit,
      'notes': cv.notes,
    }).toList(),
  };

  static VitalsData _deserializeVitals(Map<String, dynamic> m) {
    return VitalsData()
      ..systolic         = (m['systolic']        as num?)?.toDouble()
      ..diastolic        = (m['diastolic']       as num?)?.toDouble()
      ..pulse            = (m['pulse']           as num?)?.toDouble()
      ..temperature      = (m['temperature']     as num?)?.toDouble()
      ..isFahrenheit     = m['isFahrenheit']     as bool? ?? true
      ..respiratoryRate  = (m['respiratoryRate'] as num?)?.toDouble()
      ..spO2             = (m['spO2']            as num?)?.toDouble()
      ..weightKg         = (m['weightKg']        as num?)?.toDouble()
      ..heightCm         = (m['heightCm']        as num?)?.toDouble()
      ..bloodGlucose     = (m['bloodGlucose']    as num?)?.toDouble()
      ..isFastingGlucose = m['isFastingGlucose'] as bool? ?? true
      ..customVitals     = ((m['customVitals'] as List?) ?? []).map((cv) =>
          CustomVital(
            name:  cv['name']  as String? ?? '',
            value: cv['value'] as String? ?? '',
            unit:  cv['unit']  as String? ?? '',
            notes: cv['notes'] as String? ?? '',
          )).toList();
  }

  static Map<String, dynamic> _serializeLabs(LabData l) => {
    'values':              l.values.map((k, v) => MapEntry(k, v)),
    'bloodCultureResult':  l.bloodCultureResult,
    'urineCultureResult':  l.urineCultureResult,
    'sputumCultureResult': l.sputumCultureResult,
    'woundCultureResult':  l.woundCultureResult,
  };

  static LabData _deserializeLabs(Map<String, dynamic> m) {
    final l = LabData();
    ((m['values'] as Map<String, dynamic>?) ?? {}).forEach((k, v) {
      l.values[k] = (v as num?)?.toDouble();
    });
    l.bloodCultureResult  = m['bloodCultureResult']  as String? ?? '';
    l.urineCultureResult  = m['urineCultureResult']  as String? ?? '';
    l.sputumCultureResult = m['sputumCultureResult'] as String? ?? '';
    l.woundCultureResult  = m['woundCultureResult']  as String? ?? '';
    return l;
  }

  static Map<String, dynamic> _serializeExamination(ExaminationData e) => {
    'vitalsFlags': e.vitalsFlags,
    'sessions': e.sessions.map((examId, session) => MapEntry(examId, {
      'answers':           session.answers.map((k, v) => MapEntry(k, v.toList())),
      'unlockedFollowUps': session.unlockedFollowUps.toList(),
      'alertMessages':     session.alertMessages,
    })),
  };

  static ExaminationData _deserializeExamination(Map<String, dynamic> m) {
    final flags = List<String>.from(m['vitalsFlags'] ?? []);
    final e = ExaminationData(vitalsFlags: flags);
    final sessions = m['sessions'] as Map<String, dynamic>?;
    if (sessions != null) {
      sessions.forEach((examId, raw) {
        final session = e.sessionFor(examId);
        final answers = raw['answers'] as Map<String, dynamic>?;
        if (answers != null) {
          answers.forEach((k, v) {
            session.answers[k] = List<String>.from(v as List);
          });
        }
        final followUps = raw['unlockedFollowUps'] as List?;
        if (followUps != null) {
          session.unlockedFollowUps.addAll(followUps.cast<String>());
        }
        final alerts = raw['alertMessages'] as List?;
        if (alerts != null) {
          session.alertMessages.addAll(alerts.cast<String>());
        }
      });
    }
    return e;
  }
}
