import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/insight_report.dart';
import 'package:mindflow/domain/entities/insight_report_cache.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/domain/entities/weekly_insight.dart';
import 'package:mindflow/domain/repositories/insight_repository.dart';
import 'package:mindflow/domain/repositories/sarah_letter_repository.dart';
import 'package:mindflow/domain/usecases/migrate_legacy_insights_to_sarah_letters_usecase.dart';

void main() {
  test('migrates legacy insight reports into Sarah legacy letters', () async {
    final report = _report(
      weekRange: '2026-04-28 ~ 2026-05-04',
      summary: '这周你有些疲惫，但还是把重要的事情做完了。',
      needText: '看起来你很需要安静和被支持。',
    );
    final insightRepository = _FakeInsightRepository([
      InsightReportCache(report: report, cachedAt: DateTime(2026, 5, 4)),
      InsightReportCache(
        report: _report(weekRange: '2026-05-05 ~ 2026-05-11'),
        cachedAt: DateTime(2026, 5, 11),
      ),
    ]);
    final sarahRepository = _FakeSarahLetterRepository();
    final useCase = MigrateLegacyInsightsToSarahLettersUseCase(
      insightRepository: insightRepository,
      sarahLetterRepository: sarahRepository,
    );

    final migrated = await useCase();

    expect(migrated, hasLength(1));
    expect(sarahRepository.uploadedLetters, hasLength(1));
    final letter = sarahRepository.uploadedLetters.single;
    expect(
      letter.id,
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      )),
    );
    expect(letter.type, LetterType.legacy);
    expect(letter.weekStart, DateTime(2026, 4, 28));
    expect(letter.weekEnd, DateTime(2026, 5, 4));
    expect(letter.sourceLegacyReportId, 'report-2026-04-28 ~ 2026-05-04');
    expect(letter.previewText, '这周你有些疲惫，但还是把重要的事情做完了。');
    expect(letter.content, contains('这周你有些疲惫'));
    expect(letter.content, contains('看起来你很需要安静'));
    expect(letter.content, isNot(contains('行动建议')));
    expect(letter.isRead, isTrue);
  });
}

InsightReport _report({
  required String weekRange,
  String summary = '',
  String needText = '',
}) {
  return InsightReport(
    id: 'report-$weekRange',
    reportType: '每周洞察报告',
    emotionOverview: EmotionOverview(summary: summary),
    highFrequencyEmotions: const [
      HighFrequencyEmotion(content: '丢弃的高频情境', time: '周三'),
    ],
    patternHypothesis: PatternHypothesis(
      text: needText,
      highlightTags: const [],
    ),
    actionSuggestions: const [
      ActionSuggestion(title: '行动建议', content: '这段不应迁移'),
    ],
    weekRange: weekRange,
    createdAt: DateTime(2026, 5, 4),
  );
}

class _FakeInsightRepository implements InsightRepository {
  _FakeInsightRepository(this.caches);

  final List<InsightReportCache> caches;

  @override
  Future<List<InsightReportCache>> getAllCachedInsightReports() async => caches;

  @override
  Future<WeeklyInsight> createWeeklyInsight(WeeklyInsight insight) {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight?> getWeeklyInsight(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<List<WeeklyInsight>> getAllWeeklyInsights() {
    throw UnimplementedError();
  }

  @override
  Future<List<WeeklyInsight>> getRecentInsights({int limit = 4}) {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight> updateWeeklyInsight(WeeklyInsight insight) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWeeklyInsight(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePatternFeedback(
    String insightId,
    String patternId,
    String feedback,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateExperimentStatus(
    String insightId,
    String experimentId,
    String status,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateExperimentFeedback(
    String insightId,
    String experimentId,
    String feedback,
  ) {
    throw UnimplementedError();
  }

  @override
  String getCurrentWeekRange() => '2026-05-18 ~ 2026-05-24';

  @override
  Future<bool> hasInsightForWeek(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<InsightReportCache?> getCachedInsightReport(String weekRange) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveInsightReportCache(
    InsightReport report, {
    DateTime? cachedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteInsightReportCache(String weekRange) {
    throw UnimplementedError();
  }
}

class _FakeSarahLetterRepository implements SarahLetterRepository {
  final List<SarahLetter> uploadedLetters = [];

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(
      List<SarahLetter> letters) async {
    uploadedLetters.addAll(letters);
    return letters;
  }

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async => null;

  @override
  Future<List<SarahLetter>> getLocalLetters() async => const [];

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async => const [];

  @override
  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    return null;
  }

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {}

  @override
  Future<SarahLetter?> getLocalLetter(String id) async => null;

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {}

  @override
  Future<void> markLocalRead(String id) async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<int> getLocalUnreadCount() async => 0;

  @override
  Future<void> deleteLetter(String id) async {}
}
