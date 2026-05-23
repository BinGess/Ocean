import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/domain/repositories/sarah_letter_repository.dart';
import 'package:mindflow/domain/usecases/ensure_welcome_letter_usecase.dart';

void main() {
  test('ensures welcome letter through repository', () async {
    final welcome = SarahLetter(
      id: 'welcome',
      type: LetterType.welcome,
      createdAt: DateTime(2026, 5, 18),
      content: '嗨，\n\n我是 Sarah。',
      illustrationIndex: 1,
      isRead: false,
    );
    final repository = _FakeSarahLetterRepository(welcome: welcome);
    final useCase = EnsureWelcomeLetterUseCase(repository: repository);

    final letter = await useCase();

    expect(repository.didEnsureWelcome, isTrue);
    expect(letter?.id, 'welcome');
  });
}

class _FakeSarahLetterRepository implements SarahLetterRepository {
  _FakeSarahLetterRepository({this.welcome});

  final SarahLetter? welcome;
  bool didEnsureWelcome = false;

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async {
    didEnsureWelcome = true;
    return welcome;
  }

  @override
  Future<List<SarahLetter>> getLocalLetters() async => const [];

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async => const [];

  @override
  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    return null;
  }

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {}

  @override
  Future<SarahLetter?> getLocalLetter(String id) async => null;

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {}

  @override
  Future<void> markLocalRead(String id) async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<int> getLocalUnreadCount() async => 0;

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(List<SarahLetter> letters) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLetter(String id) async {}
}
