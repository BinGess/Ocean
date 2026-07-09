import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/data/models/record_model.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/record.dart';

void main() {
  test('RecordModel preserves journal and weekly extension fields', () {
    final record = Record(
      id: 'weekly-1',
      type: RecordType.weekly,
      transcription: 'weekly body',
      createdAt: DateTime.utc(2026, 5, 7),
      updatedAt: DateTime.utc(2026, 5, 8),
      title: '这一周',
      summary: '更稳定了',
      date: '2026-05-07',
      referencedFragments: const ['fragment-1'],
      weekRange: '2026-05-04 ~ 2026-05-10',
      referencedRecords: const ['record-1', 'record-2'],
      patternFeedback: 'like',
    );

    final restored = RecordModel.fromEntity(record).toEntity();

    expect(restored.title, '这一周');
    expect(restored.summary, '更稳定了');
    expect(restored.date, '2026-05-07');
    expect(restored.referencedFragments, ['fragment-1']);
    expect(restored.weekRange, '2026-05-04 ~ 2026-05-10');
    expect(restored.referencedRecords, ['record-1', 'record-2']);
    expect(restored.patternFeedback, 'like');
  });

  test('RecordModel preserves deep analysis results', () {
    final analysis = DeepAnalysisResult(
      type: 'boundarySupport',
      title: '边界支持',
      methodLabel: '边界支持',
      theorySource: 'Boundary psychology',
      overview: '看见边界',
      stuckPoint: '不敢拒绝',
      groundedUnderstanding: '你的需要也重要',
      oneSmallStep: '先说一句我需要想想',
      steadySentence: '慢慢来也是可以的',
      analyzedAt: DateTime.utc(2026, 7, 7, 12),
      emotions: const [DeepEmotion(name: '紧张', intensity: 64)],
    );
    final record = Record(
      id: 'record-deep',
      type: RecordType.quickNote,
      transcription: '我需要一点边界',
      createdAt: DateTime.utc(2026, 7, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 7, 12),
      deepAnalyses: [analysis],
    );

    final restored = RecordModel.fromEntity(record).toEntity();

    expect(restored.deepAnalyses, hasLength(1));
    expect(restored.deepAnalyses!.single.title, '边界支持');
    expect(restored.deepAnalyses!.single.emotions.single.intensity, 64);
  });
}
