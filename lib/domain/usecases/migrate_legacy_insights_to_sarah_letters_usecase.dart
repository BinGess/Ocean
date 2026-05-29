import '../entities/insight_report_cache.dart';
import '../entities/sarah_letter.dart';
import '../repositories/insight_repository.dart';
import '../repositories/sarah_letter_repository.dart';
import 'package:uuid/uuid.dart';

class MigrateLegacyInsightsToSarahLettersUseCase {
  const MigrateLegacyInsightsToSarahLettersUseCase({
    required this.insightRepository,
    required this.sarahLetterRepository,
  });

  final InsightRepository insightRepository;
  final SarahLetterRepository sarahLetterRepository;

  Future<List<SarahLetter>> call() async {
    final caches = await insightRepository.getAllCachedInsightReports();
    final letters = caches
        .map(_letterFromCache)
        .whereType<SarahLetter>()
        .toList()
      ..sort(SarahLetter.newestFirst);

    if (letters.isEmpty) return const [];
    return sarahLetterRepository.migrateLegacyLetters(letters);
  }

  SarahLetter? _letterFromCache(InsightReportCache cache) {
    final report = cache.report;
    final summary = report.emotionOverview.summary.trim();
    final needText = report.patternHypothesis.text.trim();
    if (summary.isEmpty && needText.isEmpty) return null;

    final dates = _parseWeekRange(report.weekRange);
    final bodyParts = [
      if (summary.isNotEmpty) summary,
      if (needText.isNotEmpty) needText,
    ];

    return SarahLetter(
      id: _stableLegacyId(report),
      type: LetterType.legacy,
      createdAt: dates?.end ?? report.createdAt,
      weekStart: dates?.start,
      weekEnd: dates?.end,
      content: '嗨，\n\n${bodyParts.join('\n\n')}\n\nSarah',
      previewText: bodyParts.first,
      illustrationIndex: _stableIllustrationIndex(report.weekRange),
      isRead: true,
      updatedAt: cache.cachedAt,
      sourceLegacyReportId: report.id,
    );
  }

  _WeekDates? _parseWeekRange(String weekRange) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2}).*?(\d{4}-\d{2}-\d{2})')
        .firstMatch(weekRange);
    if (match == null) return null;

    final start = DateTime.tryParse(match.group(1)!);
    final end = DateTime.tryParse(match.group(2)!);
    if (start == null || end == null) return null;
    return _WeekDates(start: start, end: end);
  }

  int _stableIllustrationIndex(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
    return (hash % SarahLetter.illustrationCount) + 1;
  }

  String _stableLegacyId(report) {
    return const Uuid().v5(
      Namespace.url.value,
      'sarah-legacy:${report.id}:${report.weekRange}',
    );
  }
}

class _WeekDates {
  const _WeekDates({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
