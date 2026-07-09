import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ocean_record_sync_mapper.dart';
import 'package:mindflow/domain/entities/deep_analysis_result.dart';
import 'package:mindflow/domain/entities/record.dart';

void main() {
  group('OceanRecordSyncMapper', () {
    test('toServerRecord omits local audioUrl and uses API enum values', () {
      final record = Record(
        id: 'record-1',
        type: RecordType.quickNote,
        transcription: 'hello ocean',
        createdAt: DateTime.utc(2026, 5, 7, 13, 40),
        updatedAt: DateTime.utc(2026, 5, 7, 13, 41),
        audioUrl: '/private/local/audio.m4a',
        processingMode: ProcessingMode.withNVC,
        moods: const ['calm'],
        needs: const ['rest'],
      );

      final payload = OceanRecordSyncMapper.toServerRecord(record);

      expect(payload['id'], 'record-1');
      expect(payload['type'], 'quick_note');
      expect(payload['processingMode'], 'with_nvc');
      expect(payload['audioUrl'], isNull);
      expect(payload['createdAt'], '2026-05-07T13:40:00.000Z');
      expect(payload['updatedAt'], '2026-05-07T13:41:00.000Z');
    });

    test('round-trips deep analysis results with server payload', () {
      final analysis = DeepAnalysisResult(
        type: 'selfCompassion',
        title: '接住自己的好',
        methodLabel: '自我关怀与滋养',
        theorySource: 'Self-Compassion & Savoring',
        overview: '轻轻放松下来',
        stuckPoint: '刚刚松了一口气',
        groundedUnderstanding: '你撑过了紧绷的日子',
        oneSmallStep: '深呼吸三次',
        steadySentence: '这份轻松值得被看见',
        analyzedAt: DateTime.utc(2026, 7, 7, 10, 13),
        face: 'high',
        resonance: '终于能松一口气了啊',
        emotions: const [DeepEmotion(name: '放松', intensity: 72)],
        observedLabel: '你匆匆带过的好',
        observedValue: '终于可以轻松一点',
        truthLabel: '而这份好里',
        truthValue: '有你一直撑住自己的努力',
        microActionKind: 'savoring',
      );
      final record = Record(
        id: 'record-deep',
        type: RecordType.quickNote,
        transcription: '终于能松一口气了啊',
        createdAt: DateTime.utc(2026, 7, 7, 10),
        updatedAt: DateTime.utc(2026, 7, 7, 10, 13),
        deepAnalyses: [analysis],
      );

      final payload = OceanRecordSyncMapper.toServerRecord(record);
      final restored = OceanRecordSyncMapper.fromServerRecord(payload);

      expect(payload['deepAnalyses'], [analysis.toJson()]);
      expect(restored.deepAnalyses, hasLength(1));
      expect(restored.deepAnalyses!.single.type, 'selfCompassion');
      expect(restored.deepAnalyses!.single.emotions.single.name, '放松');
    });

    test('fromServerRecord accepts server camelCase fields', () {
      final record = OceanRecordSyncMapper.fromServerRecord({
        'id': 'record-2',
        'type': 'journal',
        'transcription': 'journal body',
        'createdAt': '2026-05-07T13:40:00.000Z',
        'updatedAt': '2026-05-07T13:41:00.000Z',
        'audioUrl': null,
        'title': 'Today',
        'summary': 'A short day',
        'referencedFragments': ['record-1'],
        'patternFeedback': 'like',
      });

      expect(record.id, 'record-2');
      expect(record.type, RecordType.journal);
      expect(record.title, 'Today');
      expect(record.summary, 'A short day');
      expect(record.referencedFragments, ['record-1']);
      expect(record.patternFeedback, 'like');
      expect(record.audioUrl, isNull);
    });
  });
}
