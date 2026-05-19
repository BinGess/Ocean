import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/data/models/sarah_letter_model.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';

void main() {
  group('SarahLetterModel', () {
    test('round trips a SarahLetter entity', () {
      final entity = SarahLetter(
        id: 'letter-1',
        type: LetterType.legacy,
        createdAt: DateTime.utc(2026, 5, 10, 12),
        weekStart: DateTime.utc(2026, 5, 4),
        weekEnd: DateTime.utc(2026, 5, 10),
        content: '嗨，\n\n这一周你已经很努力了。\n\nSarah',
        previewText: '这一周你已经很努力了。',
        illustrationIndex: 12,
        isRead: true,
        updatedAt: DateTime.utc(2026, 5, 10, 13),
        userId: 'user-1',
        accountId: 'account-1',
        sourceLegacyReportId: 'report-1',
        deletedAt: DateTime.utc(2026, 5, 12),
      );

      final model = SarahLetterModel.fromEntity(entity);
      final restored = model.toEntity();

      expect(restored.id, entity.id);
      expect(restored.type, entity.type);
      expect(restored.createdAt, entity.createdAt);
      expect(restored.weekStart, entity.weekStart);
      expect(restored.weekEnd, entity.weekEnd);
      expect(restored.content, entity.content);
      expect(restored.previewText, entity.previewText);
      expect(restored.illustrationIndex, entity.illustrationIndex);
      expect(restored.isRead, entity.isRead);
      expect(restored.updatedAt, entity.updatedAt);
      expect(restored.userId, entity.userId);
      expect(restored.accountId, entity.accountId);
      expect(restored.sourceLegacyReportId, entity.sourceLegacyReportId);
      expect(restored.deletedAt, entity.deletedAt);
    });
  });
}
