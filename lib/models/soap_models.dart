// lib/models/soap_models.dart
// Import this wherever you need SoapNote

// @HiveType(typeId: 11)
class SoapNote {
  String   subjective  = '';
  String   objective   = '';
  String   assessment  = '';
  String   plan        = '';
  DateTime generatedAt = DateTime.now();
}

