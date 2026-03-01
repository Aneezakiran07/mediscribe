import 'package:flutter/material.dart';
import '../services/inference_engine.dart';

class ExaminationScreen extends StatefulWidget {
  final String examinationId;
  const ExaminationScreen({super.key, required this.examinationId});

  @override
  State<ExaminationScreen> createState() => _ExaminationScreenState();
}

class _ExaminationScreenState extends State<ExaminationScreen> {
  final InferenceEngine engine = InferenceEngine();
  List<Map> activeQuestions = [];
  Set<String> injectedIds = {};
  int currentIndex = 0;
  Map<String, List<String>> selectedAnswers = {};
  bool loading = true;
  bool finished = false;
  List<String> alerts = [];
  late Map examination;

  @override
  void initState() {
    super.initState();
    _loadExamination();
  }

  Future<void> _loadExamination() async {
    await engine.loadKnowledgeBase();
    examination = engine.getExamination(widget.examinationId);
    List<Map> baseQuestions = (examination["questions"] as List)
        .where((q) => q["injected"] == false)
        .map((q) => Map<String, dynamic>.from(q))
        .toList();
    setState(() {
      activeQuestions = baseQuestions;
      loading = false;
    });
  }

  void _submitAnswer() {
    Map currentQuestion = activeQuestions[currentIndex];
    String storesAs = currentQuestion["stores_as"];
    List<String> answers = selectedAnswers[storesAs] ?? [];

    engine.storeFact(storesAs, answers);

    List<String> violations = engine.checkConstraints(examination);
    if (violations.isNotEmpty) {
      for (var v in violations) {
        if (!alerts.contains(v)) {
          setState(() => alerts.add(v));
        }
      }
      engine.workingMemory.remove(storesAs);
      return;
    }

    Map? action = engine.evaluateRules(examination["rules"]);
    if (action != null) _handleAction(action);

    if (currentIndex < activeQuestions.length - 1) {
      setState(() => currentIndex++);
    } else {
      _finish();
    }
  }

  void _handleAction(Map action) {
    String type = action["type"];
    if (type == "inject_question") {
      String targetId = action["target"];
      if (!injectedIds.contains(targetId)) {
        Map? targetQ = (examination["questions"] as List)
            .firstWhere((q) => q["id"] == targetId, orElse: () => null);
        if (targetQ != null) {
          setState(() {
            injectedIds.add(targetId);
            activeQuestions.insert(currentIndex + 1, Map.from(targetQ));
          });
        }
      }
    } else if (type == "flag_alert") {
      String msg = action["message"];
      if (!alerts.contains(msg)) {
        setState(() => alerts.add(msg));
      }
    }
  }

  void _finish() {
    int score = engine.calculateScore(examination["questions"]);
    String acuity = engine.interpretScore(score);
    List<Map> diagnoses = engine.calculateCertaintyFactors(examination);
    setState(() => finished = true);
    _showResults(score, acuity, diagnoses);
  }

  void _showResults(int score, String acuity, List<Map> diagnoses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Examination Complete",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text("Total Score: $score",
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text("Acuity: $acuity",
                style: const TextStyle(color: Colors.orange, fontSize: 14)),
            if (diagnoses.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "Differential Diagnoses",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...diagnoses.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d["name"],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              Text(d["description"],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text("${d["certainty"]}%",
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("⚠️ Alerts:",
                  style: TextStyle(color: Colors.red, fontSize: 16)),
              ...alerts.map((a) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(a,
                        style: const TextStyle(color: Colors.redAccent)),
                  )),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    Map currentQuestion = activeQuestions[currentIndex];
    String storesAs = currentQuestion["stores_as"];
    List<String> options = List<String>.from(currentQuestion["options"]);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(
          examination["examination_title"],
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (currentIndex + 1) / activeQuestions.length,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
            const SizedBox(height: 8),
            Text(
              "Step ${currentIndex + 1} of ${activeQuestions.length}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Doctor context label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "🩺 You are the examining doctor, enter findings as you examine the patient",
                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentQuestion["phase"].toString().toUpperCase(),
                style:
                    const TextStyle(color: Colors.blueAccent, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currentQuestion["text"],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (alerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A0A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  "⚠️ ${alerts.last}",
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  String option = options[index];
                  bool selected =
                      (selectedAnswers[storesAs] ?? []).contains(option);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAnswers[storesAs] ??= [];
                        if (selected) {
                          selectedAnswers[storesAs]!.remove(option);
                        } else {
                          selectedAnswers[storesAs]!.add(option);
                        }
                        alerts.removeWhere(
                            (a) => a.startsWith("Contradiction"));
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF1A3A5C)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Colors.blueAccent
                              : const Color(0xFF2A2A2A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color:
                                selected ? Colors.blueAccent : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Submit & Continue",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}