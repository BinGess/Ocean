import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/domain/repositories/sarah_letter_repository.dart';
import 'package:mindflow/domain/usecases/get_sarah_letters_usecase.dart';
import 'package:mindflow/domain/usecases/mark_sarah_letter_read_usecase.dart';
import 'package:mindflow/domain/usecases/request_sarah_weekly_letter_usecase.dart';

void main() {
  group('Sarah letter use cases', () {
    test('GetSarahLettersUseCase syncs from remote-backed repository', () async {
      final repository = _FakeSarahLetterRepository(
        syncedLetters: [_letter('synced')],
      );
      final useCase = GetSarahLettersUseCase(repository: repository);

      final letters = await useCase();

      expect(repository.didSync, isTrue);
      expect(letters.single.id, 'synced');
    });

    test('MarkSarahLetterReadUseCase delegates read state update', () async {
      final repository = _FakeSarahLetterRepository();
      final useCase = MarkSarahLetterReadUseCase(repository: repository);

      await useCase('letter-1');

      expect(repository.markedReadIds, ['letter-1']);
    });

    test('RequestSarahWeeklyLetterUseCase delegates backend generation check', () async {
      final repository = _FakeSarahLetterRepository(
        generatedLetter: _letter('weekly'),
      );
      final useCase = RequestSarahWeeklyLetterUseCase(repository: repository);

      final letter = await useCase(
        weekStart: DateTime.utc(2026, 5, 18),
        weekEnd: DateTime.utc(2026, 5, 24),
      );

      expect(repository.requestedWeekStart, DateTime.utc(2026, 5, 18));
      expect(letter?.id, 'weekly');
    });
  });
}

SarahLetter _letter(String id) {
  return SarahLetter(
    id: id,
    type: LetterType.weekly,
    createdAt: DateTime(2026, 5, 18),
    content: '嗨，\n\n给你的一封信。\n\nSarah',
    illustrationIndex: 1,
    isRead: false,
  );
}

class _FakeSarahLetterRepository implements SarahLetterRepository {
  _FakeSarahLetterRepository({
    this.syncedLetters = const [],
    this.generatedLetter,
  });

  final List<SarahLetter> syncedLetters;
  final SarahLetter? generatedLetter;
  final List<String> markedReadIds = [];
  bool didSync = false;
  DateTime? requestedWeekStart;

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async {
    didSync = true;
    return syncedLetters;
  }

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async => null;

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(List<SarahLetter> letters) async {
    return letters;
  }

  @override
  Future<void> markRead(String id) async {
    markedReadIds.add(id);
  }

  @override
  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    requestedWeekStart = weekStart;
    return generatedLetter;
  }

  @override
  Future<List<SarahLetter>> getLocalLetters() async => const [];

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {}

  @override
  Future<SarahLetter?> getLocalLetter(String id) async => null;

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {}

  @override
  Future<void> markLocalRead(String id) async {}

  @override
  Future<int> getLocalUnreadCount() async => 0;
}
