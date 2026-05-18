import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ocean_record_sync_mapper.dart';
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
