import 'dart:convert';
import 'package:flutter/services.dart';

class InferenceEngine {
  Map<String, dynamic> workingMemory = {};
  Map<String, dynamic>? knowledgeBase;

  Future<void> loadKnowledgeBase() async {
    String jsonString = await rootBundle.loadString('assets/knowledge_base.json');
    knowledgeBase = jsonDecode(jsonString);
  }

  Map getExamination(String examId) {
    List exams = knowledgeBase!["knowledge_base"]["examinations"];
    return exams.firstWhere((e) => e["examination_id"] == examId);
  }

  void storeFact(String key, dynamic value) {
    workingMemory[key] = value;
  }

  bool evaluateCondition(Map condition) {
    dynamic stored = workingMemory[condition["fact"]];
    if (stored == null) return false;
    switch (condition["operator"]) {
      case "contains":
        return (stored as List).contains(condition["value"]);
      case "contains_any":
        return (condition["value"] as List).any((v) => (stored as List).contains(v));
      case "equals":
        return stored == condition["value"];
      default:
        return false;
    }
  }

  Map? evaluateRules(List rules) {
    List<Map> firedRules = [];
    for (var rule in rules) {
      List conditions = rule["conditions"];
      String match = rule["match"];
      bool fired = match == "ALL"
          ? conditions.every((c) => evaluateCondition(c))
          : conditions.any((c) => evaluateCondition(c));
      if (fired) firedRules.add(Map.from(rule));
    }
    if (firedRules.isEmpty) return null;
    firedRules.sort((a, b) => b["priority"].compareTo(a["priority"]));
    return firedRules.first["action"];
  }

  int calculateScore(List questions) {
    int totalScore = 0;
    for (var question in questions) {
      String storesAs = question["stores_as"];
      Map weights = question["weights"] ?? {};
      dynamic answers = workingMemory[storesAs];
      if (answers == null) continue;
      for (var answer in (answers as List)) {
        totalScore += (weights[answer] ?? 0) as int;
      }
    }
    return totalScore;
  }

  String interpretScore(int score) {
    if (score <= 5) return "Low acuity — routine evaluation";
    if (score <= 12) return "Moderate acuity — prioritize workup";
    if (score <= 20) return "High acuity — expedited assessment";
    return "Critical — emergency evaluation";
  }

  void reset() {
    workingMemory = {};
  }

  List<Map> calculateCertaintyFactors(Map examination) {
    List diagnoses = examination["diagnoses"] ?? [];
    List<Map> results = [];

    for (var diagnosis in diagnoses) {
      int threshold = diagnosis["min_score_threshold"];
      int maxScore = diagnosis["max_score"];
      List requiredFacts = diagnosis["key_facts_required"];

      bool hasRequiredFacts = requiredFacts
          .every((fact) => workingMemory.containsKey(fact));
      if (!hasRequiredFacts) continue;

      int diagnosisScore = 0;
      List questions = examination["questions"];

      for (var question in questions) {
        if (!requiredFacts.contains(question["stores_as"])) continue;
        String storesAs = question["stores_as"];
        Map weights = question["weights"] ?? {};
        dynamic answers = workingMemory[storesAs];
        if (answers == null) continue;
        for (var answer in (answers as List)) {
          diagnosisScore += (weights[answer] ?? 0) as int;
        }
      }

      if (diagnosisScore < threshold) continue;

      double certainty = (diagnosisScore / maxScore) * 100;
      if (certainty > 100) certainty = 100;

      results.add({
        "name": diagnosis["name"],
        "description": diagnosis["description"],
        "certainty": certainty.toStringAsFixed(1),
        "score": diagnosisScore,
      });
    }

    results.sort((a, b) =>
        double.parse(b["certainty"]).compareTo(double.parse(a["certainty"])));
    return results;
  }

  List<String> checkConstraints(Map examination) {
    List constraints = examination["constraints"] ?? [];
    List<String> violations = [];

    for (var constraint in constraints) {
      String fact = constraint["fact"];
      List conflicting = constraint["conflicting_values"];
      dynamic stored = workingMemory[fact];
      if (stored == null) continue;

      int matches = conflicting
          .where((v) => (stored as List).contains(v))
          .length;

      if (matches > 1) {
        violations.add(constraint["message"]);
      }
    }

    return violations;
  }
}