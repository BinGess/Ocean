import '../entities/sarah_letter.dart';

abstract class SarahLetterRepository {
  Future<List<SarahLetter>> getLocalLetters();

  Future<List<SarahLetter>> syncRemoteLetters();

  Future<SarahLetter?> ensureWelcomeLetter();

  Future<SarahLetter?> requestWeeklyGeneration({
    required DateTime weekStart,
    required DateTime weekEnd,
  });

  Future<List<SarahLetter>> migrateLegacyLetters(List<SarahLetter> letters);

  Future<void> replaceLocalLetters(List<SarahLetter> letters);

  Future<SarahLetter?> getLocalLetter(String id);

  Future<void> upsertLocalLetter(SarahLetter letter);

  Future<void> markLocalRead(String id);

  Future<void> markRead(String id);

  Future<void> deleteLetter(String id);

  Future<int> getLocalUnreadCount();
}
