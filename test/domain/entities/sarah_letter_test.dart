import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';

void main() {
  group('SarahLetter', () {
    test('builds preview from first meaningful content line', () {
      final letter = SarahLetter(
        id: 'welcome',
        type: LetterType.welcome,
        createdAt: DateTime(2026, 5, 18, 9),
        content: '嗨，\n\n我是 Sarah。\n很高兴认识你。\n\nSarah',
        illustrationIndex: 4,
        isRead: false,
      );

      expect(letter.resolvedPreviewText, '我是 Sarah。');
    });

    test('uses explicit preview before deriving from content', () {
      final letter = SarahLetter(
        id: 'weekly',
        type: LetterType.weekly,
        createdAt: DateTime(2026, 5, 10),
        weekStart: DateTime(2026, 5, 4),
        weekEnd: DateTime(2026, 5, 10),
        content: '嗨，\n\n你这周写到很多事。\nSarah',
        previewText: '那件关于周三的事...',
        illustrationIndex: 8,
        isRead: true,
      );

      expect(letter.resolvedPreviewText, '那件关于周三的事...');
    });

    test('sorts newest letters first', () {
      final older = SarahLetter(
        id: 'older',
        type: LetterType.legacy,
        createdAt: DateTime(2026, 4, 20),
        content: '旧信',
        illustrationIndex: 1,
        isRead: true,
      );
      final newer = SarahLetter(
        id: 'newer',
        type: LetterType.weekly,
        createdAt: DateTime(2026, 5, 18),
        content: '新信',
        illustrationIndex: 2,
        isRead: false,
      );

      final letters = [older, newer]..sort(SarahLetter.newestFirst);

      expect(letters.map((letter) => letter.id), ['newer', 'older']);
    });

    test('normalizes illustration index into the available range', () {
      final low = SarahLetter(
        id: 'low',
        type: LetterType.weekly,
        createdAt: DateTime(2026, 5, 18),
        content: '低索引',
        illustrationIndex: 0,
        isRead: false,
      );
      final high = SarahLetter(
        id: 'high',
        type: LetterType.weekly,
        createdAt: DateTime(2026, 5, 18),
        content: '高索引',
        illustrationIndex: 41,
        isRead: false,
      );

      expect(low.normalizedIllustrationIndex, 1);
      expect(high.normalizedIllustrationIndex, 1);
      expect(high.illustrationAssetPath, 'assets/images/sarah/sarah_01.png');
    });

    test('preserves backend metadata fields in json', () {
      final letter = SarahLetter.fromJson({
        'id': 'legacy-1',
        'userId': 'user-1',
        'account_id': 'account-1',
        'letter_type': 'legacy',
        'created_at': '2026-05-04T00:00:00.000Z',
        'content': '嗨，\n\n旧信。',
        'illustration_index': 3,
        'is_read': true,
        'updated_at': '2026-05-05T00:00:00.000Z',
        'source_legacy_report_id': 'report-1',
        'deleted_at': null,
      });

      expect(letter.userId, 'user-1');
      expect(letter.accountId, 'account-1');
      expect(letter.sourceLegacyReportId, 'report-1');
      expect(letter.toJson()['sourceLegacyReportId'], 'report-1');
      expect(letter.toJson()['userId'], 'user-1');
      expect(letter.toJson()['accountId'], 'account-1');
    });
  });
}
