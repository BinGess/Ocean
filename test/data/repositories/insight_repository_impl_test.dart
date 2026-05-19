import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/models/weekly_insight_model.dart';
import 'package:mindflow/data/repositories/insight_repository_impl.dart';

void main() {
  late Directory tempDir;
  late Box<String> insightReportsBox;
  late Box<WeeklyInsightModel> weeklyInsightsBox;
  late InsightRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('insight_repo_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WeeklyInsightModelAdapter());
    }
    insightReportsBox = await Hive.openBox<String>('insight_reports_test');
    weeklyInsightsBox =
        await Hive.openBox<WeeklyInsightModel>('weekly_insights_test');
    repository = InsightRepositoryImpl(
      database: _TestHiveDatabase(
        insightReportsBox: insightReportsBox,
        weeklyInsightsBox: weeklyInsightsBox,
      ),
    );
  });

  tearDown(() async {
    await insightReportsBox.close();
    await weeklyInsightsBox.close();
    await tempDir.delete(recursive: true);
  });

  test('reads legacy insight cache with camel case report fields', () async {
    await insightReportsBox.put(
      '2026-05-04 ~ 2026-05-10',
      jsonEncode({
        'cached_at': '2026-05-07T13:44:00.000Z',
        'report': {
          'id': 'report-1',
          'reportType': '每周洞察报告',
          'emotionOverview': {'summary': '这一周有点累。'},
          'patternHypothesis': {
            'text': '你很需要一点安静。',
            'highlightTags': const [],
          },
          'weekRange': '2026-05-04 ~ 2026-05-10',
          'createdAt': '2026-05-07T13:44:00.000Z',
          'recordCount': 3,
        },
      }),
    );

    final reports = await repository.getAllCachedInsightReports();

    expect(reports, hasLength(1));
    expect(reports.single.report.emotionOverview.summary, '这一周有点累。');
    expect(reports.single.report.patternHypothesis.text, '你很需要一点安静。');
  });
}

class _TestHiveDatabase extends HiveDatabase {
  _TestHiveDatabase({
    required Box<String> insightReportsBox,
    required Box<WeeklyInsightModel> weeklyInsightsBox,
  })  : _insightReportsBox = insightReportsBox,
        _weeklyInsightsBox = weeklyInsightsBox;

  final Box<String> _insightReportsBox;
  final Box<WeeklyInsightModel> _weeklyInsightsBox;

  @override
  Box<String> get insightReportsBox => _insightReportsBox;

  @override
  Box<WeeklyInsightModel> get weeklyInsightsBox => _weeklyInsightsBox;
}
