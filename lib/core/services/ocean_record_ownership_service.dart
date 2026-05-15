import '../../data/datasources/local/hive_database.dart';

class OceanRecordOwnershipService {
  OceanRecordOwnershipService(this._database);

  static const ownerPrefix = 'ocean_owner_record_';
  static const entityOwnerPrefix = 'ocean_owner_';
  static const localOwner = 'local';
  static const accountOwnerPrefix = 'account:';
  static const activeAccountKey = 'ocean_active_account_key';

  final HiveDatabase _database;

  Future<void> markLocal(String recordId) async {
    await _database.settingsBox.put(_ownerKey(recordId), localOwner);
  }

  Future<void> markAccount(String recordId, String accountKey) async {
    await setActiveAccount(accountKey);
    await _database.settingsBox.put(
      _ownerKey(recordId),
      _accountOwner(accountKey),
    );
  }

  Future<void> markManyAccount(
    Iterable<String> recordIds,
    String accountKey,
  ) async {
    for (final recordId in recordIds) {
      await markAccount(recordId, accountKey);
    }
  }

  Future<void> clearOwner(String recordId) async {
    await _database.settingsBox.delete(_ownerKey(recordId));
  }

  Future<void> markEntityLocal(String entityType, String entityId) async {
    await _database.settingsBox.put(
      _entityOwnerKey(entityType, entityId),
      localOwner,
    );
  }

  Future<void> markEntityAccount(
    String entityType,
    String entityId,
    String accountKey,
  ) async {
    await setActiveAccount(accountKey);
    await _database.settingsBox.put(
      _entityOwnerKey(entityType, entityId),
      _accountOwner(accountKey),
    );
  }

  Future<void> clearEntityOwner(String entityType, String entityId) async {
    await _database.settingsBox.delete(_entityOwnerKey(entityType, entityId));
  }

  String ownerOf(String recordId) {
    return ownerOfEntity('record', recordId);
  }

  String? get activeAccount {
    final value = _database.settingsBox.get(activeAccountKey) as String?;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> setActiveAccount(String accountKey) async {
    final trimmed = accountKey.trim();
    if (trimmed.isEmpty) return;
    await _database.settingsBox.put(activeAccountKey, trimmed);
  }

  Future<void> clearActiveAccount() async {
    await _database.settingsBox.delete(activeAccountKey);
  }

  Future<void> detachActiveAccountDataToLocal() async {
    final accountKey = activeAccount;
    if (accountKey == null || accountKey.isEmpty) return;
    final accountOwner = _accountOwner(accountKey);
    final ownerKeys = _database.settingsBox.keys
        .map((key) => key.toString())
        .where(isOwnershipKey)
        .toList(growable: false);
    for (final key in ownerKeys) {
      if (_database.settingsBox.get(key) == accountOwner) {
        await _database.settingsBox.put(key, localOwner);
      }
    }
  }

  String ownerOfEntity(String entityType, String entityId) {
    return _database.settingsBox.get(
      _entityOwnerKey(entityType, entityId),
      defaultValue: localOwner,
    ) as String;
  }

  bool isLocal(String recordId) {
    return ownerOf(recordId) == localOwner;
  }

  bool isEntityLocal(String entityType, String entityId) {
    return ownerOfEntity(entityType, entityId) == localOwner;
  }

  bool isVisible({
    required String recordId,
    required String? accountKey,
  }) {
    final owner = ownerOf(recordId);
    if (accountKey == null || accountKey.isEmpty) {
      return true;
    }
    return owner == localOwner || owner == _accountOwner(accountKey);
  }

  bool isEntityVisible({
    required String entityType,
    required String entityId,
    required String? accountKey,
  }) {
    final owner = ownerOfEntity(entityType, entityId);
    if (accountKey == null || accountKey.isEmpty) {
      return true;
    }
    return owner == localOwner || owner == _accountOwner(accountKey);
  }

  bool isLocalOrCurrentAccount({
    required String recordId,
    required String? accountKey,
  }) {
    return isVisible(recordId: recordId, accountKey: accountKey);
  }

  bool isOwnershipKey(String key) {
    return key.startsWith(entityOwnerPrefix);
  }

  String _ownerKey(String recordId) => _entityOwnerKey('record', recordId);

  String _entityOwnerKey(String entityType, String entityId) {
    if (entityType == 'record') return '$ownerPrefix$entityId';
    return '$entityOwnerPrefix${entityType}_$entityId';
  }

  String _accountOwner(String accountKey) => '$accountOwnerPrefix$accountKey';
}
