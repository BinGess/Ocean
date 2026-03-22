import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/record.dart';
import 'package:mindflow/presentation/screens/records/records_screen.dart';

void main() {
  test('buildDailySummarySyncSignature is stable for equivalent grouped data',
      () {
    final baseTime = DateTime(2026, 3, 22, 10, 30);
    final groupedRecords = <DateTime, List<Record>>{
      DateTime(2026, 3, 22): [
        _record(
          id: 'b',
          createdAt: baseTime.add(const Duration(minutes: 30)),
          updatedAt: baseTime.add(const Duration(minutes: 31)),
        ),
        _record(
          id: 'a',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        ),
      ],
    };

    final reorderedGroupedRecords = <DateTime, List<Record>>{
      DateTime(2026, 3, 22): [
        _record(
          id: 'a',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        ),
        _record(
          id: 'b',
          createdAt: baseTime.add(const Duration(minutes: 30)),
          updatedAt: baseTime.add(const Duration(minutes: 31)),
        ),
      ],
    };

    expect(
      buildDailySummarySyncSignature(groupedRecords),
      buildDailySummarySyncSignature(reorderedGroupedRecords),
    );
  });

  test('buildDailySummarySyncSignature changes when record payload changes',
      () {
    final baseTime = DateTime(2026, 3, 22, 10, 30);
    final initialGroupedRecords = <DateTime, List<Record>>{
      DateTime(2026, 3, 22): [
        _record(
          id: 'a',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 2)),
        ),
      ],
    };
    final updatedGroupedRecords = <DateTime, List<Record>>{
      DateTime(2026, 3, 22): [
        _record(
          id: 'a',
          createdAt: baseTime,
          updatedAt: baseTime.add(const Duration(minutes: 3)),
        ),
      ],
    };

    expect(
      buildDailySummarySyncSignature(initialGroupedRecords),
      isNot(buildDailySummarySyncSignature(updatedGroupedRecords)),
    );
  });

  test('buildDailySummarySyncSignature marks empty state explicitly', () {
    expect(buildDailySummarySyncSignature(const {}), 'empty');
  });
}

Record _record({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return Record(
    id: id,
    type: RecordType.quickNote,
    transcription: 'record-$id',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
