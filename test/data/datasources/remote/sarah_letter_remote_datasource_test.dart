import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';
import 'package:mindflow/data/datasources/remote/sarah_letter_remote_datasource.dart';
import 'package:mindflow/domain/entities/sarah_letter.dart';

void main() {
  group('SarahLetterRemoteDataSource', () {
    test('maps backend letter list into SarahLetter entities', () async {
      final api = _FakeSarahLettersApi(
        listResponse: {
          'letters': [
            {
              'id': 'letter-1',
              'type': 'welcome',
              'createdAt': '2026-05-18T09:00:00.000Z',
              'content': '嗨，\n\n我是 Sarah。',
              'previewText': '我是 Sarah。',
              'illustrationIndex': 3,
              'isRead': false,
            },
          ],
        },
      );
      final dataSource = SarahLetterRemoteDataSource(api: api);

      final letters = await dataSource.fetchLetters();

      expect(letters, hasLength(1));
      expect(letters.single.id, 'letter-1');
      expect(letters.single.type, LetterType.welcome);
      expect(letters.single.isRead, isFalse);
    });

    test('requests weekly generation from backend without Coze credentials',
        () async {
      final api = _FakeSarahLettersApi(
        weeklyResponse: {
          'letter': {
            'id': 'weekly-1',
            'type': 'weekly',
            'createdAt': '2026-05-24T10:00:00.000Z',
            'weekStart': '2026-05-18T00:00:00.000Z',
            'weekEnd': '2026-05-24T00:00:00.000Z',
            'content': '嗨，\n\n这一周你很认真。\n\nSarah',
            'illustrationIndex': 5,
            'isRead': false,
          },
        },
      );
      final dataSource = SarahLetterRemoteDataSource(api: api);

      final letter = await dataSource.requestWeeklyGeneration(
        weekStart: DateTime.utc(2026, 5, 18),
        weekEnd: DateTime.utc(2026, 5, 24),
      );

      expect(api.lastWeeklyPayload, {
        'weekStart': '2026-05-18T00:00:00.000Z',
        'weekEnd': '2026-05-24T00:00:00.000Z',
      });
      expect(letter?.id, 'weekly-1');
    });

    test('maps ensured welcome letter from backend response', () async {
      final api = _FakeSarahLettersApi(
        welcomeResponse: {
          'letter': {
            'id': 'welcome-1',
            'type': 'welcome',
            'createdAt': '2026-05-18T09:00:00.000Z',
            'content': '嗨，\n\n我是 Sarah。\n\nSarah',
            'previewText': '我是 Sarah。',
            'illustrationIndex': 1,
            'isRead': false,
          },
        },
      );
      final dataSource = SarahLetterRemoteDataSource(api: api);

      final letter = await dataSource.ensureWelcomeLetter();

      expect(letter?.id, 'welcome-1');
      expect(letter?.type, LetterType.welcome);
      expect(letter?.resolvedPreviewText, '我是 Sarah。');
    });

    test('accepts snake case fields and data wrappers from backend', () async {
      final api = _FakeSarahLettersApi(
        listResponse: {
          'data': {
            'letters': [
              {
                'id': 'legacy-1',
                'letter_type': 'legacy',
                'created_at': '2026-05-04T00:00:00.000Z',
                'week_start': '2026-04-28T00:00:00.000Z',
                'week_end': '2026-05-04T00:00:00.000Z',
                'content': '嗨，\n\n旧周报迁移信。',
                'preview_text': '旧周报迁移信。',
                'illustration_index': 9,
                'is_read': true,
                'updated_at': '2026-05-05T00:00:00.000Z',
              },
            ],
          },
        },
      );
      final dataSource = SarahLetterRemoteDataSource(api: api);

      final letters = await dataSource.fetchLetters();

      expect(letters.single.type, LetterType.legacy);
      expect(letters.single.weekStart, DateTime.utc(2026, 4, 28));
      expect(letters.single.previewText, '旧周报迁移信。');
      expect(letters.single.illustrationIndex, 9);
      expect(letters.single.isRead, isTrue);
    });
  });
}

class _FakeSarahLettersApi implements OceanSarahLettersApi {
  _FakeSarahLettersApi({
    this.listResponse = const {'letters': []},
    this.welcomeResponse = const {},
    this.weeklyResponse = const {},
  });

  final Map<String, dynamic> listResponse;
  final Map<String, dynamic> welcomeResponse;
  final Map<String, dynamic> weeklyResponse;
  Map<String, dynamic>? lastWeeklyPayload;

  @override
  Future<Map<String, dynamic>> listSarahLetters() async => listResponse;

  @override
  Future<Map<String, dynamic>> ensureSarahWelcomeLetter() async =>
      welcomeResponse;

  @override
  Future<Map<String, dynamic>> migrateLegacySarahLetters(
    List<Map<String, dynamic>> letters,
  ) async {
    return {'letters': letters};
  }

  @override
  Future<Map<String, dynamic>> generateSarahWeeklyLetter({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    lastWeeklyPayload = {
      'weekStart': weekStart.toUtc().toIso8601String(),
      'weekEnd': weekEnd.toUtc().toIso8601String(),
    };
    return weeklyResponse;
  }

  @override
  Future<Map<String, dynamic>> updateSarahLetter(
    String id,
    Map<String, dynamic> data,
  ) async {
    return {'letter': data};
  }
}
