import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';
import 'package:mindflow/domain/repositories/sarah_letter_repository.dart';
import 'package:mindflow/domain/usecases/ensure_welcome_letter_usecase.dart';
import 'package:mindflow/domain/usecases/get_sarah_letters_usecase.dart';
import 'package:mindflow/domain/usecases/delete_sarah_letter_usecase.dart';
import 'package:mindflow/domain/usecases/mark_sarah_letter_read_usecase.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_bloc.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_event.dart';
import 'package:mindflow/presentation/bloc/sarah/sarah_state.dart';

// 注意：周报不再由客户端触发生成，而是由服务端 cron（每周日 20:00 CST）
// 生成后推送到数据库，客户端通过 syncRemoteLetters 拉取展示。

// 当前自然周的周一 00:00（本地时间）——用于所有需要 weekStart 落在「本周」的测试
DateTime _thisMonday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

void main() {
  test('load syncs letters and exposes correct letter groups', () async {
    // weekStart = 本周一，createdAt 故意设为「旧日期」，
    // 验证分类以 weekStart 为准、而非 createdAt（覆盖补发/迁移场景）
    final thisMonday = _thisMonday();
    final weekly = _letter(
      id: 'weekly',
      type: LetterType.weekly,
      createdAt: DateTime(2026, 5, 10), // 旧的生成时间，无关分类
      weekStart: thisMonday,             // 本周 → 「本周来信」
      weekEnd: thisMonday.add(const Duration(days: 6, hours: 20)),
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
    );
    final legacyRefresh = _FakeLegacyRefreshUseCase();
    final migration = _FakeMigrationUseCase(legacyRefresh: legacyRefresh);
    final bloc = _makeBloc(repository, legacyRefresh, migration);
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    expect(repository.didEnsureWelcome, isTrue);
    expect(legacyRefresh.didRun, isTrue);
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
    final bloc = _makeBloc(repository);
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

  test('load shows synced letters even when ensure welcome fails', () async {
    // 欢迎信接口失败时，sync 到的信件依然正常展示
    final weekly = _letter(
      id: 'weekly',
      type: LetterType.weekly,
      createdAt: DateTime(2026, 5, 24),
    );
    final repository = _FakeSarahLetterRepository(
      syncedLetters: [weekly],
      welcomeError: Exception('network error'),
    );
    final bloc = _makeBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    expect(state.letters.map((letter) => letter.id), ['weekly']);
    expect(state.totalCount, 1);
  });

  test('backfilled letter with last-week weekStart goes to pastLetters', () async {
    // 重现 bug：服务端补发一封上周的信，createdAt = 今天（最新），
    // 错误的旧逻辑会把它认成「本周来信」；正确逻辑应放入往期。
    final lastMonday = _thisMonday().subtract(const Duration(days: 7));
    final backfilled = _letter(
      id: 'backfilled',
      type: LetterType.weekly,
      createdAt: DateTime.now(), // 今天刚补发
      weekStart: lastMonday,     // 但覆盖的是上周
      weekEnd: lastMonday.add(const Duration(days: 6, hours: 20)),
    );
    final repository = _FakeSarahLetterRepository(syncedLetters: [backfilled]);
    final bloc = _makeBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const SarahLoadRequested());
    final state = await bloc.stream.firstWhere(
      (state) => state.status == SarahStatus.success,
    );

    // 补发信 weekStart = 上周 → 不能显示为「本周来信」
    expect(state.weeklyLetter, isNull);
    // 应出现在往期列表里
    expect(state.pastLetters.map((l) => l.id), ['backfilled']);
  });

  test('load exposes ensured welcome when sync returns empty', () async {
    // 新用户首次加载：sync 返回空，欢迎信由 ensureWelcome 创建
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
    final bloc = _makeBloc(repository);
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

// ── Helpers ──────────────────────────────────────────────────────────────────

SarahBloc _makeBloc(
  _FakeSarahLetterRepository repository, [
  _FakeLegacyRefreshUseCase? legacyRefresh,
  _FakeMigrationUseCase? migration,
]) {
  final refresh = legacyRefresh ?? _FakeLegacyRefreshUseCase();
  final migrate = migration ?? _FakeMigrationUseCase();
  return SarahBloc(
    getLettersUseCase: GetSarahLettersUseCase(repository: repository),
    ensureWelcomeLetterUseCase:
        EnsureWelcomeLetterUseCase(repository: repository),
    refreshLegacyInsightsUseCase: refresh.call,
    migrateLegacyInsightsUseCase: migrate.call,
    markReadUseCase: MarkSarahLetterReadUseCase(repository: repository),
    deleteLetterUseCase: DeleteSarahLetterUseCase(repository: repository),
  );
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

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeLegacyRefreshUseCase {
  bool didRun = false;
  bool completedBeforeMigration = false;

  Future<void> call() async {
    didRun = true;
    completedBeforeMigration = true;
  }
}

class _FakeMigrationUseCase {
  _FakeMigrationUseCase({_FakeLegacyRefreshUseCase? legacyRefresh})
      : _legacyRefresh = legacyRefresh;

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
    this.welcomeError,
    this.cacheWelcomeOnEnsure = true,
  });

  List<SarahLetter> syncedLetters;
  final SarahLetter? welcomeLetter;
  final Object? welcomeError;
  final bool cacheWelcomeOnEnsure;
  bool didEnsureWelcome = false;
  final List<String> markedReadIds = [];

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async => syncedLetters;

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async {
    didEnsureWelcome = true;
    final error = welcomeError;
    if (error != null) throw error;
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
  Future<void> markRead(String id) async {
    markedReadIds.add(id);
    syncedLetters = syncedLetters
        .map((l) => l.id == id ? l.copyWith(isRead: true) : l)
        .toList();
  }

  @override
  Future<List<SarahLetter>> getLocalLetters() async => syncedLetters;

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(
          List<SarahLetter> letters) async =>
      letters;

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {
    syncedLetters = letters;
  }

  @override
  Future<SarahLetter?> getLocalLetter(String id) async =>
      syncedLetters.where((l) => l.id == id).firstOrNull;

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {}

  @override
  Future<void> markLocalRead(String id) async {}

  @override
  Future<int> getLocalUnreadCount() async =>
      syncedLetters.where((l) => !l.isRead).length;

  @override
  Future<void> deleteLetter(String id) async {
    syncedLetters = syncedLetters.where((l) => l.id != id).toList();
  }
}
