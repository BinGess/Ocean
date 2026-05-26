import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/data/datasources/local/hive_database.dart';
import 'package:mindflow/data/datasources/remote/sarah_letter_remote_datasource.dart';
import 'package:mindflow/data/models/sarah_letter_model.dart';
import 'package:mindflow/data/repositories/sarah_letter_repository_impl.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';

void main() {
  late Directory tempDir;
  late Box<SarahLetterModel> box;
  late _TestHiveDatabase database;
  late SarahLetterRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sarah_letters_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(SarahLetterModel.hiveTypeId)) {
      Hive.registerAdapter(SarahLetterModelAdapter());
    }
    box = await Hive.openBox<SarahLetterModel>('sarah_letters_test');
    database = _TestHiveDatabase(box);
    repository = SarahLetterRepositoryImpl(database: database);
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('saves letters locally and returns newest first', () async {
    final older = _letter(
      id: 'older',
      createdAt: DateTime(2026, 4, 28),
    );
    final newer = _letter(
      id: 'newer',
      createdAt: DateTime(2026, 5, 10),
    );

    await repository.replaceLocalLetters([older, newer]);

    final letters = await repository.getLocalLetters();
    expect(letters.map((letter) => letter.id), ['newer', 'older']);
  });

  test('marks a letter as read in local cache', () async {
    await repository.replaceLocalLetters([
      _letter(id: 'weekly', createdAt: DateTime(2026, 5, 10), isRead: false),
    ]);

    await repository.markLocalRead('weekly');

    final letters = await repository.getLocalLetters();
    expect(letters.single.isRead, isTrue);
    expect(letters.single.updatedAt, isNotNull);
  });

  test('syncs remote letters into local cache', () async {
    final remoteLetter = _letter(
      id: 'remote',
      createdAt: DateTime(2026, 5, 18),
      isRead: false,
    );
    repository = SarahLetterRepositoryImpl(
      database: database,
      remoteDataSource:
          _FakeRemoteDataSource(fetchLettersResult: [remoteLetter]),
    );

    final letters = await repository.syncRemoteLetters();

    expect(letters.map((letter) => letter.id), ['remote']);
    expect((await repository.getLocalLetters()).single.id, 'remote');
  });

  test('sync falls back to local letters when remote fetch fails', () async {
    final cached = _letter(
      id: 'cached-welcome',
      createdAt: DateTime(2026, 5, 18),
      isRead: false,
    );
    await repository.upsertLocalLetter(cached);
    repository = SarahLetterRepositoryImpl(
      database: database,
      remoteDataSource: _FakeRemoteDataSource(
        fetchLettersResult: const [],
        fetchError: Exception('network unavailable'),
      ),
    );

    final letters = await repository.syncRemoteLetters();

    expect(letters.map((letter) => letter.id), ['cached-welcome']);
    expect((await repository.getLocalLetters()).single.id, 'cached-welcome');
  });

  test('sync keeps local letters when remote unexpectedly returns empty',
      () async {
    final cached = _letter(
      id: 'cached-welcome',
      createdAt: DateTime(2026, 5, 18),
      isRead: false,
    );
    await repository.upsertLocalLetter(cached);
    repository = SarahLetterRepositoryImpl(
      database: database,
      remoteDataSource: _FakeRemoteDataSource(fetchLettersResult: const []),
    );

    final letters = await repository.syncRemoteLetters();

    expect(letters.map((letter) => letter.id), ['cached-welcome']);
    expect((await repository.getLocalLetters()).single.id, 'cached-welcome');
  });

  test('sync merges remote letters with locally cached legacy letters',
      () async {
    final localLegacy = SarahLetter(
      id: 'legacy-1',
      type: LetterType.legacy,
      createdAt: DateTime(2026, 5, 4),
      weekStart: DateTime(2026, 4, 28),
      weekEnd: DateTime(2026, 5, 4),
      content: '嗨，\n\n旧周报迁移信。\n\nSarah',
      illustrationIndex: 2,
      isRead: true,
      sourceLegacyReportId: 'report-1',
    );
    final remoteWelcome = SarahLetter(
      id: 'welcome',
      type: LetterType.welcome,
      createdAt: DateTime(2026, 5, 18),
      content: '嗨，\n\n欢迎。\n\nSarah',
      illustrationIndex: 1,
      isRead: false,
    );
    await repository.upsertLocalLetter(localLegacy);
    repository = SarahLetterRepositoryImpl(
      database: database,
      remoteDataSource: _FakeRemoteDataSource(
        fetchLettersResult: [remoteWelcome],
      ),
    );

    final letters = await repository.syncRemoteLetters();

    expect(letters.map((letter) => letter.id), ['welcome', 'legacy-1']);
    expect((await repository.getLocalLetters()).map((letter) => letter.id), [
      'welcome',
      'legacy-1',
    ]);
  });

  test('marks read through backend and caches returned letter', () async {
    final unread = _letter(
      id: 'weekly',
      createdAt: DateTime(2026, 5, 24),
      isRead: false,
    );
    final read =
        unread.copyWith(isRead: true, updatedAt: DateTime(2026, 5, 25));
    repository = SarahLetterRepositoryImpl(
      database: database,
      remoteDataSource: _FakeRemoteDataSource(
        fetchLettersResult: const [],
        markReadResult: read,
      ),
    );
    await repository.upsertLocalLetter(unread);

    await repository.markRead('weekly');

    final cached = await repository.getLocalLetter('weekly');
    expect(cached?.isRead, isTrue);
    expect(cached?.updatedAt, DateTime(2026, 5, 25));
  });
}

SarahLetter _letter({
  required String id,
  required DateTime createdAt,
  bool isRead = true,
}) {
  return SarahLetter(
    id: id,
    type: LetterType.weekly,
    createdAt: createdAt,
    content: '嗨，\n\n给你的一封信。\n\nSarah',
    illustrationIndex: 1,
    isRead: isRead,
  );
}

class _TestHiveDatabase extends HiveDatabase {
  _TestHiveDatabase(this._sarahLettersBox);

  final Box<SarahLetterModel> _sarahLettersBox;

  @override
  Box<SarahLetterModel> get sarahLettersBox => _sarahLettersBox;
}

class _FakeRemoteDataSource extends SarahLetterRemoteDataSource {
  _FakeRemoteDataSource({
    required this.fetchLettersResult,
    this.fetchError,
    this.markReadResult,
  }) : super(api: _NoopSarahLettersApi());

  final List<SarahLetter> fetchLettersResult;
  final Object? fetchError;
  final SarahLetter? markReadResult;

  @override
  Future<List<SarahLetter>> fetchLetters() async {
    final error = fetchError;
    if (error != null) throw error;
    return fetchLettersResult;
  }

  @override
  Future<SarahLetter?> markRead(String id) async => markReadResult;
}

class _NoopSarahLettersApi implements OceanSarahLettersApi {
  @override
  Future<Map<String, dynamic>> listSarahLetters() async => const {};

  @override
  Future<Map<String, dynamic>> ensureSarahWelcomeLetter() async => const {};

  @override
  Future<Map<String, dynamic>> migrateLegacySarahLetters(
    List<Map<String, dynamic>> letters,
  ) async {
    return const {};
  }

  @override
  Future<Map<String, dynamic>> updateSarahLetter(
    String id,
    Map<String, dynamic> data,
  ) async {
    return const {};
  }

  @override
  Future<void> deleteSarahLetter(String id) async {}
}
