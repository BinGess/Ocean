import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/data/models/record_model.dart';
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
}
