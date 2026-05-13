import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/network/ocean_api_client.dart';

void main() {
  test('register converts validation response into readable exception',
      () async {
    final adapter = _FakeAdapter((options) {
      return _jsonResponse(
        statusCode: 400,
        body: {
          'statusCode': 400,
          'message': ['password must be longer than or equal to 8 characters'],
        },
        requestOptions: options,
      );
    });
    final client = OceanApiClient(
      tokenStore: _MemoryTokenStore(),
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    expect(
      () => client.register(
        email: 'user@example.com',
        password: 'short',
      ),
      throwsA(
        isA<OceanApiException>().having(
          (error) => error.message,
          'message',
          'password must be longer than or equal to 8 characters',
        ),
      ),
    );
  });

  test('pushRecords refreshes expired access token and retries once', () async {
    final adapter = _FakeAdapter((options) {
      if (options.path == '/sync/push' &&
          options.headers['Authorization'] == 'Bearer old-access') {
        return _jsonResponse(
          statusCode: 401,
          body: {'message': 'expired'},
          requestOptions: options,
        );
      }
      if (options.path == '/auth/refresh') {
        return _jsonResponse(
          body: {
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          },
          requestOptions: options,
        );
      }
      if (options.path == '/sync/push' &&
          options.headers['Authorization'] == 'Bearer new-access') {
        return _jsonResponse(
          statusCode: 201,
          body: {'accepted': 1, 'ignored': 0, 'cursor': '7'},
          requestOptions: options,
        );
      }
      return _jsonResponse(
        statusCode: 500,
        body: {'message': 'unexpected request'},
        requestOptions: options,
      );
    });
    final tokenStore = _MemoryTokenStore(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    final client = OceanApiClient(
      tokenStore: tokenStore,
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    final result = await client.pushRecords([
      {'id': 'record-1'},
    ]);

    expect(result['cursor'], '7');
    expect(tokenStore.accessToken, 'new-access');
    expect(tokenStore.refreshToken, 'new-refresh');
  });

  test('login waits until tokens are persisted before returning', () async {
    final adapter = _FakeAdapter((options) {
      return _jsonResponse(
        body: {
          'accessToken': 'access-after-login',
          'refreshToken': 'refresh-after-login',
        },
        requestOptions: options,
      );
    });
    final tokenStore = _DelayedTokenStore();
    final client = OceanApiClient(
      tokenStore: tokenStore,
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    await client.login(
      email: 'user@example.com',
      password: 'StrongerPass123',
    );

    expect(tokenStore.saveCompleted, isTrue);
    expect((await tokenStore.readTokens())?.accessToken, 'access-after-login');
  });

  test('createRecord posts to server-first records endpoint', () async {
    RequestOptions? captured;
    final adapter = _FakeAdapter((options) {
      captured = options;
      return _jsonResponse(
        statusCode: 201,
        body: {
          'revision': '1',
          'data': {
            'id': 'record-1',
            'type': 'quick_note',
            'transcription': 'server first',
            'createdAt': '2026-05-08T08:00:00.000Z',
            'updatedAt': '2026-05-08T08:01:00.000Z',
            'audioUrl': null,
          },
        },
        requestOptions: options,
      );
    });
    final client = OceanApiClient(
      tokenStore: _MemoryTokenStore(
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    final result = await client.createRecord({
      'id': 'record-1',
      'type': 'quick_note',
      'transcription': 'server first',
      'createdAt': '2026-05-08T08:00:00.000Z',
      'updatedAt': '2026-05-08T08:01:00.000Z',
      'audioUrl': '/private/local/audio.wav',
    });

    expect(result['revision'], '1');
    expect(result['data'], isA<Map<String, dynamic>>());
    expect(captured?.path, '/records');
    expect(captured?.method, 'POST');
    expect(captured?.headers['Authorization'], 'Bearer access');
  });

  test('sends SMS code and logs in through phone endpoint', () async {
    final paths = <String>[];
    final tokenStore = _MemoryTokenStore();
    final adapter = _FakeAdapter((options) {
      paths.add('${options.method} ${options.path}');
      if (options.path == '/auth/sms/login') {
        return _jsonResponse(
          statusCode: 201,
          body: {
            'accessToken': 'sms-access',
            'refreshToken': 'sms-refresh',
            'user': {'phone': '138****8000'},
          },
          requestOptions: options,
        );
      }
      return _jsonResponse(
        statusCode: 201,
        body: {'success': true, 'cooldownSeconds': 60},
        requestOptions: options,
      );
    });
    final client = OceanApiClient(
      tokenStore: tokenStore,
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    await client.sendSmsCode(phone: '13800138000');
    await client.loginWithSms(phone: '13800138000', code: '123456');

    expect(paths, [
      'POST /auth/sms/send-code',
      'POST /auth/sms/login',
    ]);
    expect(tokenStore.accessToken, 'sms-access');
    expect(tokenStore.refreshToken, 'sms-refresh');
  });

  test('translates Aliyun SMS verification failure into readable text',
      () async {
    const error = OceanApiException(
      '验证码校验失败：isv.ValidateFail: code: 400, 验证失败 request id: 123',
      statusCode: 400,
    );

    expect(error.displayMessage, '验证码已失效或已被使用，请重新获取验证码');
  });

  test('updates profile, daily mood, daily summary, and report endpoints',
      () async {
    final paths = <String>[];
    final adapter = _FakeAdapter((options) {
      paths.add('${options.method} ${options.path}');
      return _jsonResponse(
        body: {
          'revision': paths.length.toString(),
          'data': options.data is Map
              ? Map<String, dynamic>.from(options.data as Map)
              : {},
        },
        requestOptions: options,
      );
    });
    final client = OceanApiClient(
      tokenStore: _MemoryTokenStore(
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter,
    );

    await client.updateProfile({'nickname': 'Ocean'});
    await client.updateDailyMood('2026-05-08', {'imagePath': 'calm.png'});
    await client.updateDailySummary('2026-05-08', {'moodWord': '平静'});
    await client.upsertReport(
      periodType: 'weekly',
      periodKey: '2026-05-04 ~ 2026-05-10',
      report: {
        'report': {'id': 'report-1'}
      },
    );

    expect(paths, [
      'PUT /me/profile',
      'PUT /daily/2026-05-08/mood',
      'PUT /daily/2026-05-08/summary',
      'PUT /reports/weekly/2026-05-04%20~%202026-05-10',
    ]);
  });
}

typedef _Responder = FutureOr<ResponseBody> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._responder);

  final _Responder _responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse({
  int statusCode = 200,
  required Map<String, dynamic> body,
  required RequestOptions requestOptions,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _MemoryTokenStore implements OceanTokenStore {
  _MemoryTokenStore({this.accessToken, this.refreshToken});

  String? accessToken;

  String? refreshToken;

  String? email;

  @override
  Future<OceanAuthTokens?> readTokens() async {
    final access = accessToken;
    final refresh = refreshToken;
    if (access == null || refresh == null) return null;
    return OceanAuthTokens(
      accessToken: access,
      refreshToken: refresh,
      email: email,
    );
  }

  @override
  Future<void> saveTokens(OceanAuthTokens tokens) async {
    accessToken = tokens.accessToken;
    refreshToken = tokens.refreshToken;
    email = tokens.email;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    email = null;
  }
}

class _DelayedTokenStore extends _MemoryTokenStore {
  bool saveCompleted = false;

  @override
  Future<void> saveTokens(OceanAuthTokens tokens) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.saveTokens(tokens);
    saveCompleted = true;
  }
}
