import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/core/services/deep_analysis_local_service.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> settingsBox;
  late DeepAnalysisLocalService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('deep_analysis_test');
    Hive.init(tempDirectory.path);
    settingsBox = await Hive.openBox<dynamic>('settings');
    final database = HiveDatabase()..settingsBox = settingsBox;
    service = DeepAnalysisLocalService(database: database);
  });

  tearDown(() async {
    await settingsBox.close();
    await tempDirectory.delete(recursive: true);
  });

  DeepAnalysisResult buildResult({
    required String type,
    required String title,
  }) {
    return DeepAnalysisResult(
      type: type,
      title: title,
      methodLabel: type,
      theorySource: '理论来源',
      overview: '方法概述',
      stuckPoint: '你把压力转成了自责。',
      groundedUnderstanding: '自责说明你重视，不等于你很差劲。',
      oneSmallStep: '先把责任和自我否定分开。',
      steadySentence: '我可以先停止追责自己。',
      analyzedAt: DateTime.utc(2026, 6, 7),
    );
  }

  test('saves, restores, and deletes multiple results by record id', () async {
    final first = buildResult(
      type: 'selfCompassion',
      title: '站回自己这边',
    );
    final second = buildResult(
      type: 'releaseControl',
      title: '放下控制',
    );

    await service.saveForRecord('record-1', [first, second]);

    final restored = service.getForRecord('record-1');
    expect(restored.map((item) => item.title), [
      '站回自己这边',
      '放下控制',
    ]);

    await service.deleteForRecord('record-1');
    expect(service.getForRecord('record-1'), isEmpty);
  });

  test('restores the legacy single-result format as a list', () async {
    final result = buildResult(
      type: 'selfCompassion',
      title: '站回自己这边',
    );
    await settingsBox.put(
      'deep_analysis_v1_record-legacy',
      '{"type":"${result.type}","title":"${result.title}",'
          '"methodLabel":"${result.methodLabel}",'
          '"theorySource":"${result.theorySource}",'
          '"overview":"${result.overview}",'
          '"stuckPoint":"${result.stuckPoint}",'
          '"groundedUnderstanding":"${result.groundedUnderstanding}",'
          '"oneSmallStep":"${result.oneSmallStep}",'
          '"steadySentence":"${result.steadySentence}",'
          '"analyzedAt":"${result.analyzedAt.toIso8601String()}"}',
    );

    final restored = service.getForRecord('record-legacy');
    expect(restored, hasLength(1));
    expect(restored.single.title, '站回自己这边');
  });
}
