import '../../domain/entities/sarah_letter.dart';
import '../../domain/repositories/sarah_letter_repository.dart';
import '../datasources/local/hive_database.dart';
import '../datasources/remote/sarah_letter_remote_datasource.dart';
import '../models/sarah_letter_model.dart';

class SarahLetterRepositoryImpl implements SarahLetterRepository {
  SarahLetterRepositoryImpl({
    required this.database,
    this.remoteDataSource,
  });

  final HiveDatabase database;
  final SarahLetterRemoteDataSource? remoteDataSource;

  @override
  Future<List<SarahLetter>> getLocalLetters() async {
    final letters = database.sarahLettersBox.values
        .map((model) => model.toEntity())
        .toList()
      ..sort(SarahLetter.newestFirst);
    return letters;
  }

  @override
  Future<List<SarahLetter>> syncRemoteLetters() async {
    final remote = remoteDataSource;
    if (remote == null) return getLocalLetters();

    try {
      final localBeforeSync = await getLocalLetters();
      final letters = await remote.fetchLetters();
      if (letters.isEmpty && localBeforeSync.isNotEmpty) {
        return localBeforeSync;
      }
      await replaceLocalLetters(
          _mergeRemoteWithLocal(letters, localBeforeSync));
      return getLocalLetters();
    } catch (_) {
      return getLocalLetters();
    }
  }

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async {
    final letter = await remoteDataSource?.ensureWelcomeLetter();
    if (letter != null) {
      await upsertLocalLetter(letter);
    }
    return letter;
  }

  @override
  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final letter = await remoteDataSource?.requestWeeklyGeneration(
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
    if (letter != null) {
      await upsertLocalLetter(letter);
    }
    return letter;
  }

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(
      List<SarahLetter> letters) async {
    if (letters.isEmpty) return const [];

    final migrated =
        await remoteDataSource?.migrateLegacyLetters(letters) ?? letters;
    for (final letter in migrated) {
      await upsertLocalLetter(letter);
    }
    return migrated;
  }

  @override
  Future<void> replaceLocalLetters(List<SarahLetter> letters) async {
    await database.sarahLettersBox.clear();
    for (final letter in letters) {
      await upsertLocalLetter(letter);
    }
  }

  @override
  Future<SarahLetter?> getLocalLetter(String id) async {
    return database.sarahLettersBox.get(id)?.toEntity();
  }

  @override
  Future<void> upsertLocalLetter(SarahLetter letter) async {
    await database.sarahLettersBox.put(
      letter.id,
      SarahLetterModel.fromEntity(letter),
    );
  }

  @override
  Future<void> markLocalRead(String id) async {
    final existing = await getLocalLetter(id);
    if (existing == null || existing.isRead) return;
    await upsertLocalLetter(
      existing.copyWith(
        isRead: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> markRead(String id) async {
    final remoteLetter = await remoteDataSource?.markRead(id);
    if (remoteLetter != null) {
      await upsertLocalLetter(remoteLetter);
      return;
    }
    await markLocalRead(id);
  }

  @override
  Future<int> getLocalUnreadCount() async {
    return database.sarahLettersBox.values
        .where((model) => !model.isRead)
        .length;
  }

  List<SarahLetter> _mergeRemoteWithLocal(
    List<SarahLetter> remote,
    List<SarahLetter> local,
  ) {
    final mergedById = <String, SarahLetter>{
      for (final letter in local) letter.id: letter,
      for (final letter in remote) letter.id: letter,
    };
    return mergedById.values.toList()..sort(SarahLetter.newestFirst);
  }
}
