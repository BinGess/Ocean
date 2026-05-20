import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/domain/repositories/sarah_letter_repository.dart';
import 'package:mindflow/domain/usecases/ensure_welcome_letter_usecase.dart';
import 'package:mindflow/domain/usecases/get_sarah_letters_usecase.dart';
import 'package:mindflow/domain/usecases/mark_sarah_letter_read_usecase.dart';
import 'package:mindflow/domain/usecases/request_sarah_weekly_letter_usecase.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_bloc.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_event.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_state.dart';

void main() {
  test('load syncs welcome migration weekly request and exposes letter groups',
      () async {
    final weekly = _letter(
      id: 'weekly',
      type: LetterType.weekly,
      createdAt: DateTime(2026, 5, 24),
      weekStart: DateTime(2026, 5, 18),
      weekEnd: DateTime(2026, 5, 24),
    );
    final legacy = _letter(
      id: 'legacy',
      type: LetterType.legacy,
      createdAt: DateTime(2026, 5, 4),
      weekStart: DateTime(2026, 4, 28),
      weekEnd: DateTime(2026, 5, 4),
      isRead: true,
    );
    final repository = _FakeSarahLetterRepository(
      syncedLetters: [weekly, legacy],
      generatedLetter: weekly,
    );
    final legacyRefresh = _FakeLegacyRefreshUseCase();
    final migration = _FakeMigrationUseCase(legacyRefresh: legacyRefresh);
    final bloc = SarahBloc(
      getLettersUseCase: GetSarahLettersUseCase(repository: repository),
      ensureWelcomeLetterUseCase:
          EnsureWelcomeLetterUseCase(repository: repository),
      refreshLegacyInsightsUseCase: legacyRefresh.call,
      migrateLegacyInsightsUseCase: migration.call,
      requestWeeklyLetterUseCase:
          RequestSarahWeeklyLetterUseCase(repository: repository),
      markReadUseCase: MarkSarahLetterReadUseCase(repository: repository),
      now: () => DateTime(2026, 5, 24),
    );
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    expect(repository.didEnsureWelcome, isTrue);
    expect(legacyRefresh.didRun, isTrue);
    expect(repository.didRequestWeekly, isTrue);
    expect(migration.didRun, isTrue);
    expect(legacyRefresh.completedBeforeMigration, isTrue);
    expect(state.weeklyLetter?.id, 'weekly');
    expect(state.pastLetters.map((letter) => letter.id), ['legacy']);
    expect(state.totalCount, 2);
    expect(state.unreadCount, 1);
  });

  test('read event marks letter as read and updates state', () async {
    final unread = _letter(
      id: 'weekly',
      type: LetterType.weekly,
      createdAt: DateTime(2026, 5, 24),
      isRead: false,
    );
    final repository = _FakeSarahLetterRepository(syncedLetters: [unread]);
    final bloc = SarahBloc(
      getLettersUseCase: GetSarahLettersUseCase(repository: repository),
      ensureWelcomeLetterUseCase:
          EnsureWelcomeLetterUseCase(repository: repository),
      refreshLegacyInsightsUseCase: () async {},
      migrateLegacyInsightsUseCase: () async => const [],
      requestWeeklyLetterUseCase:
          RequestSarahWeeklyLetterUseCase(repository: repository),
      markReadUseCase: MarkSarahLetterReadUseCase(repository: repository),
      now: () => DateTime(2026, 5, 20),
    );
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    await bloc.stream
        .firstWhere((state) => state.status == SarahStatus.success);

    bloc.add(const SarahLetterRead(letterId: 'weekly'));
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success && state.unreadCount == 0,
    );

    expect(repository.markedReadIds, ['weekly']);
    expect(state.letters.single.isRead, isTrue);
  });

  test('load keeps welcome letter when weekly generation fails', () async {
    final welcome = _letter(
      id: 'welcome',
      type: LetterType.welcome,
      createdAt: DateTime(2026, 5, 18),
      isRead: false,
    );
    final repository = _FakeSarahLetterRepository(
      syncedLetters: const [],
      welcomeLetter: welcome,
      weeklyGenerationError: Exception('weekly unavailable'),
    );
    final bloc = SarahBloc(
      getLettersUseCase: GetSarahLettersUseCase(repository: repository),
      ensureWelcomeLetterUseCase:
          EnsureWelcomeLetterUseCase(repository: repository),
      refreshLegacyInsightsUseCase: () async {},
      migrateLegacyInsightsUseCase: () async => const [],
      requestWeeklyLetterUseCase:
          RequestSarahWeeklyLetterUseCase(repository: repository),
      markReadUseCase: MarkSarahLetterReadUseCase(repository: repository),
      now: () => DateTime(2026, 5, 20),
    );
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    expect(state.letters.map((letter) => letter.id), ['welcome']);
    expect(state.totalCount, 1);
  });

  test('load exposes ensured welcome when refreshed list is still empty',
      () async {
    final welcome = _letter(
      id: 'welcome',
      type: LetterType.welcome,
      createdAt: DateTime(2026, 5, 18),
      isRead: false,
    );
    final repository = _FakeSarahLetterRepository(
      syncedLetters: const [],
      welcomeLetter: welcome,
      cacheWelcomeOnEnsure: false,
    );
    final bloc = SarahBloc(
      getLettersUseCase: GetSarahLettersUseCase(repository: repository),
      ensureWelcomeLetterUseCase:
          EnsureWelcomeLetterUseCase(repository: repository),
      refreshLegacyInsightsUseCase: () async {},
      migrateLegacyInsightsUseCase: () async => const [],
      requestWeeklyLetterUseCase:
          RequestSarahWeeklyLetterUseCase(repository: repository),
      markReadUseCase: MarkSarahLetterReadUseCase(repository: repository),
      now: () => DateTime(2026, 5, 20),
    );
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    expect(repository.didEnsureWelcome, isTrue);
    expect(state.letters.map((letter) => letter.id), ['welcome']);
    expect(state.totalCount, 1);
  });
}

SarahLetter _letter({
  required String id,
  required LetterType type,
  required DateTime createdAt,
  DateTime? weekStart,
  DateTime? weekEnd,
  bool isRead = false,
}) {
  return SarahLetter(
    id: id,
    type: type,
    createdAt: createdAt,
    weekStart: weekStart,
    weekEnd: weekEnd,
    content: '嗨，\n\n给你的一封信。\n\nSarah',
    illustrationIndex: 1,
    isRead: isRead,
  );
}

class _FakeLegacyRefreshUseCase {
  bool didRun = false;
  bool completedBeforeMigration = false;

  Future<void> call() async {
    didRun = true;
    completedBeforeMigration = true;
  }
}

class _FakeMigrationUseCase {
  _FakeMigrationUseCase({
    _FakeLegacyRefreshUseCase? legacyRefresh,
  }) : _legacyRefresh = legacyRefresh;

  final _FakeLegacyRefreshUseCase? _legacyRefresh;
  bool didRun = false;

  Future<List<SarahLetter>> call() async {
    didRun = true;
    final legacyRefresh = _legacyRefresh;
    if (legacyRefresh != null) {
      legacyRefresh.completedBeforeMigration = legacyRefresh.didRun;
    }
    return const [];
  }
}

class _FakeSarahLetterRepository implements SarahLetterRepository {
  _FakeSarahLetterRepository({
    required this.syncedLetters,
    this.welcomeLetter,
    this.generatedLetter,
    this.weeklyGenerationError,
    this.cacheWelcomeOnEnsure = true,
  });

  List<SarahLetter> syncedLetters;
  final SarahLetter? welcomeLetter;
  final SarahLetter? generatedLetter;
  final Object? weeklyGenerationError;
  final bool cacheWelcomeOnEnsure;
  bool didEnsureWelcome = false;
  bool didRequestWeekly = false;
  final List<String> markedReadIds = [];

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async => syncedLetters;

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async {
    didEnsureWelcome = true;
    final letter = welcomeLetter;
    if (letter != null && cacheWelcomeOnEnsure) {
      syncedLetters = [
        letter,
        ...syncedLetters.where((item) => item.id != letter.id),
      ];
    }
    return letter;
  }

  @override
  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    didRequestWeekly = true;
    final error = weeklyGenerationError;
    if (error != null) throw error;
    return generatedLetter;
  }

  @override
  Future<void> markRead(String id) async {
    markedReadIds.add(id);
    syncedLetters = syncedLetters
        .map((letter) =>
            letter.id == id ? letter.copyWith(isRead: true) : letter)
        .toList();
  }

  @override
  Future<List<SarahLetter>> getLocalLetters() async => syncedLetters;

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(
      List<SarahLetter> letters) async {
    return letters;
  }

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {
    syncedLetters = letters;
  }

  @override
  Future<SarahLetter?> getLocalLetter(String id) async =>
      syncedLetters.where((letter) => letter.id == id).firstOrNull;

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {}

  @override
  Future<void> markLocalRead(String id) async {}

  @override
  Future<int> getLocalUnreadCount() async =>
      syncedLetters.where((letter) => !letter.isRead).length;
}
