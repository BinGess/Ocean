import '../../../core/network/ocean_api_client.dart';
import '../../../domain/entities/sarah_letter.dart';

class SarahLetterRemoteDataSource {
  SarahLetterRemoteDataSource({
    required this.api,
  });

  final OceanSarahLettersApi api;

  Future<List<SarahLetter>> fetchLetters() async {
    final response = await api.listSarahLetters();
    return _lettersFromResponse(response);
  }

  Future<SarahLetter?> ensureWelcomeLetter() async {
    final response = await api.ensureSarahWelcomeLetter();
    return _letterFromResponse(response);
  }

  Future<List<SarahLetter>> migrateLegacyLetters(
    List<SarahLetter> letters,
  ) async {
    final response = await api.migrateLegacySarahLetters(
      letters.map((letter) => letter.toJson()).toList(),
    );
    return _lettersFromResponse(response);
  }

  Future<SarahLetter?> markRead(String id) async {
    final response = await api.updateSarahLetter(id, {'isRead': true});
    return _letterFromResponse(response);
  }

  Future<void> deleteLetter(String id) async {
    await api.deleteSarahLetter(id);
  }

  List<SarahLetter> _lettersFromResponse(Map<String, dynamic> response) {
    final rawLetters = _readPayload(response, 'letters');
    if (rawLetters is! List) return const [];

    return rawLetters
        .whereType<Map>()
        .map((item) => SarahLetter.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort(SarahLetter.newestFirst);
  }

  SarahLetter? _letterFromResponse(Map<String, dynamic> response) {
    final rawLetter = _readPayload(response, 'letter');
    if (rawLetter is Map) {
      return SarahLetter.fromJson(Map<String, dynamic>.from(rawLetter));
    }

    final rawLetters = _lettersFromResponse(response);
    return rawLetters.isEmpty ? null : rawLetters.first;
  }

  dynamic _readPayload(Map<String, dynamic> response, String key) {
    if (response.containsKey(key)) return response[key];
    final data = response['data'];
    if (data is Map && data.containsKey(key)) return data[key];
    return null;
  }
}
