class DeepAnalysisResult {
  final String type;
  final String title;
  final String methodLabel;
  final String theorySource;
  final String overview;
  final String stuckPoint;
  final String groundedUnderstanding;
  final String oneSmallStep;
  final String steadySentence;
  final DateTime analyzedAt;

  const DeepAnalysisResult({
    required this.type,
    required this.title,
    required this.methodLabel,
    required this.theorySource,
    required this.overview,
    required this.stuckPoint,
    required this.groundedUnderstanding,
    required this.oneSmallStep,
    required this.steadySentence,
    required this.analyzedAt,
  });

  factory DeepAnalysisResult.fromJson(Map<String, dynamic> json) {
    return DeepAnalysisResult(
      type: json['type'] as String,
      title: json['title'] as String,
      methodLabel: json['methodLabel'] as String,
      theorySource: json['theorySource'] as String,
      overview: json['overview'] as String,
      stuckPoint: json['stuckPoint'] as String,
      groundedUnderstanding: json['groundedUnderstanding'] as String,
      oneSmallStep: json['oneSmallStep'] as String,
      steadySentence: json['steadySentence'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'methodLabel': methodLabel,
      'theorySource': theorySource,
      'overview': overview,
      'stuckPoint': stuckPoint,
      'groundedUnderstanding': groundedUnderstanding,
      'oneSmallStep': oneSmallStep,
      'steadySentence': steadySentence,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }
}
