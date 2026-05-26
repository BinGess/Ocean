import 'package:flutter/foundation.dart';

import '../../domain/entities/sarah_letter.dart';
import '../../domain/repositories/sarah_letter_repository.dart';
import '../datasources/local/hive_database.dart';
import '../datasources/remote/sarah_letter_remote_datasource.dart';
import '../models/sarah_letter_model.dart';
import '../../core/network/ocean_api_client.dart';

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
      debugPrint('[SarahRepo] fetchLetters=${letters.length}, localBefore=${localBeforeSync.length}');
      if (letters.isEmpty && localBeforeSync.isNotEmpty) {
        // 服务端返回空列表时保守地保留本地数据，避免因网络抖动误删
        return localBeforeSync;
      }
      // 以服务端列表为权威，完全替换本地缓存：
      // - 服务端不再返回的信件（已被删除）会随 replaceLocalLetters 清除
      // - 仅对 isRead 做本地优先合并，防止离线已读状态被服务端覆盖回退
      await replaceLocalLetters(_reconcileWithLocal(letters, localBeforeSync));
      return getLocalLetters();
    } catch (e) {
      debugPrint('[SarahRepo] syncRemoteLetters failed: $e');
      // 鉴权失败（Token 过期）不应静默降级到本地缓存：
      // 本地缓存可能是旧数据，用户需要重新登录才能看到最新内容。
      // 向上抛出让 SarahBloc → 上层 UI 可以感知并提示用户。
      if (e is OceanAuthException) rethrow;
      if (e is OceanApiException && e.statusCode == 401) rethrow;
      return getLocalLetters();
    }
  }

  @override
  Future<SarahLetter?> ensureWelcomeLetter() async {
    // _onLoadRequested 中 syncRemoteLetters() 总在此方法前执行，
    // 因此服务端已有的 welcome 信件此时必然已同步到本地。
    // 如果本地已有 welcome 信件，直接跳过——不再调用服务端，
    // 避免服务端每次创建新 ID 的 welcome 信件造成重复。
    final existing = await getLocalLetters();
    if (existing.any((l) => l.type == LetterType.welcome)) {
      return null;
    }

    final letter = await remoteDataSource?.ensureWelcomeLetter();
    if (letter != null) {
      await upsertLocalLetter(letter);
    }
    return letter;
  }

  @override
  Future<List<SarahLetter>> migrateLegacyLetters(
      List<SarahLetter> letters) async {
    if (letters.isEmpty) return const [];

    // No remote data source → nothing to migrate to.
    // Do NOT fall back to the original `letters` list: those are locally-generated
    // UUIDs that have never been accepted by the server, and writing them to the
    // local cache would create ghost entries that survive subsequent syncs.
    final remote = remoteDataSource;
    if (remote == null) return const [];

    final migrated = await remote.migrateLegacyLetters(letters);
    debugPrint('[SarahRepo] migrateLegacyLetters: sent=${letters.length}, returned=${migrated.length}');
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
  Future<void> deleteLetter(String id) async {
    // Remove from local storage first (immediate, never fails)
    await database.sarahLettersBox.delete(id);

    // Best-effort server delete — ignore failures so offline still works
    try {
      await remoteDataSource?.deleteLetter(id);
    } catch (_) {
      // Server delete failed; local is already removed. The server copy
      // will become orphaned until the next full sync reconciles it.
    }
  }

  @override
  Future<int> getLocalUnreadCount() async {
    return database.sarahLettersBox.values
        .where((model) => !model.isRead)
        .length;
  }

  /// 以服务端数据为权威，全量替换本地缓存。
  ///
  /// 唯一例外：若本地已将某封信标记为已读，但服务端还未同步该状态
  /// （例如 markRead 在网络故障期间失败），则保留本地的已读状态，
  /// 避免用户看到"已读又变未读"的倒退。
  List<SarahLetter> _reconcileWithLocal(
    List<SarahLetter> remote,
    List<SarahLetter> local,
  ) {
    final localById = <String, SarahLetter>{
      for (final l in local) l.id: l,
    };
    return remote.map((remoteLetter) {
      final localLetter = localById[remoteLetter.id];
      if (localLetter != null && localLetter.isRead && !remoteLetter.isRead) {
        return remoteLetter.copyWith(isRead: true);
      }
      return remoteLetter;
    }).toList()
      ..sort(SarahLetter.newestFirst);
  }
}
