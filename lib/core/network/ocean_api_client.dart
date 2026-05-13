import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

class OceanAuthTokens {
  const OceanAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String? email;
}

abstract class OceanTokenStore {
  Future<OceanAuthTokens?> readTokens();
  Future<void> saveTokens(OceanAuthTokens tokens);
  Future<void> clear();
}

abstract class OceanAccountApi {
  Future<bool> get isSignedIn;
  Future<String?> get currentEmail;
  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  });
  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  });
  Future<void> sendSmsCode({required String phone});
  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  });
  Future<void> logout();
}

class OceanSecureTokenStore implements OceanTokenStore {
  OceanSecureTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'ocean_access_token';
  static const _refreshTokenKey = 'ocean_refresh_token';
  static const _emailKey = 'ocean_account_email';

  final FlutterSecureStorage _storage;

  @override
  Future<OceanAuthTokens?> readTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    return OceanAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: await _storage.read(key: _emailKey),
    );
  }

  @override
  Future<void> saveTokens(OceanAuthTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    final email = tokens.email;
    if (email == null || email.isEmpty) {
      await _storage.delete(key: _emailKey);
    } else {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailKey);
  }
}

abstract class OceanSyncApi {
  Future<Map<String, dynamic>> getSnapshot();
  Future<Map<String, dynamic>> pushData({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> records = const [],
    List<Map<String, dynamic>> dailySummaries = const [],
    List<Map<String, dynamic>> dailyMoods = const [],
    List<Map<String, dynamic>> insightReports = const [],
    List<Map<String, dynamic>> weeklyInsights = const [],
  });
  Future<Map<String, dynamic>> pushRecords(List<Map<String, dynamic>> records);
  Future<Map<String, dynamic>> pull({required String cursor});
}

abstract class OceanRecordsApi {
  Future<bool> get isSignedIn;
  Future<Map<String, dynamic>> listRecords();
  Future<Map<String, dynamic>> createRecord(Map<String, dynamic> record);
  Future<Map<String, dynamic>> updateRecord(
    String id,
    Map<String, dynamic> record,
  );
  Future<Map<String, dynamic>> deleteRecord(String id);
}

abstract class OceanUserDataApi {
  Future<bool> get isSignedIn;
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>> updateDailyMood(
    String date,
    Map<String, dynamic> mood,
  );
  Future<Map<String, dynamic>> updateDailySummary(
    String date,
    Map<String, dynamic> summary,
  );
  Future<Map<String, dynamic>> upsertReport({
    required String periodType,
    required String periodKey,
    required Map<String, dynamic> report,
  });
}

class OceanApiClient
    implements
        OceanAccountApi,
        OceanSyncApi,
        OceanRecordsApi,
        OceanUserDataApi {
  OceanApiClient({
    required this.tokenStore,
    Dio? dio,
    String? baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? EnvConfig.oceanApiBaseUrl,
                connectTimeout: AppConstants.apiTimeout,
                receiveTimeout: AppConstants.apiTimeout,
              ),
            ) {
    final resolvedBaseUrl = baseUrl ?? _dio.options.baseUrl;
    if (_dio.options.baseUrl.isEmpty) {
      _dio.options.baseUrl = resolvedBaseUrl.isNotEmpty
          ? resolvedBaseUrl
          : EnvConfig.oceanApiBaseUrl;
    }
  }

  final OceanTokenStore tokenStore;
  final Dio _dio;

  @override
  Future<bool> get isSignedIn async => (await tokenStore.readTokens()) != null;

  @override
  Future<String?> get currentEmail async =>
      (await tokenStore.readTokens())?.email;

  @override
  Future<OceanAuthTokens> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (nickname != null && nickname.trim().isNotEmpty)
            'nickname': nickname.trim(),
        },
      );
      return await _saveAuthResponse(response.data, email);
    } on DioException catch (error) {
      throw OceanApiException.fromDio(error);
    }
  }

  @override
  Future<OceanAuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return await _saveAuthResponse(response.data, email);
    } on DioException catch (error) {
      throw OceanApiException.fromDio(error);
    }
  }

  @override
  Future<void> sendSmsCode({required String phone}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/sms/send-code',
        data: {'phone': phone},
      );
    } on DioException catch (error) {
      throw OceanApiException.fromDio(error);
    }
  }

  @override
  Future<OceanAuthTokens> loginWithSms({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/sms/login',
        data: {
          'phone': phone,
          'code': code,
        },
      );
      return await _saveAuthResponse(response.data, null);
    } on DioException catch (error) {
      throw OceanApiException.fromDio(error);
    }
  }

  Future<OceanAuthTokens> refresh() async {
    final current = await tokenStore.readTokens();
    final refreshToken = current?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const OceanAuthException('Missing refresh token');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return await _saveAuthResponse(response.data, current?.email);
    } on DioException catch (error) {
      throw OceanApiException.fromDio(error);
    }
  }

  @override
  Future<void> logout() async {
    final current = await tokenStore.readTokens();
    final refreshToken = current?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authorizedRequest<void>(
          () => _dio.post<void>(
            '/auth/logout',
            data: {'refreshToken': refreshToken},
          ),
        );
      } catch (_) {
        // Local logout must still clear tokens when the remote session is gone.
      }
    }
    await tokenStore.clear();
  }

  @override
  Future<Map<String, dynamic>> getSnapshot() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/sync/snapshot'),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> pushData({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> records = const [],
    List<Map<String, dynamic>> dailySummaries = const [],
    List<Map<String, dynamic>> dailyMoods = const [],
    List<Map<String, dynamic>> insightReports = const [],
    List<Map<String, dynamic>> weeklyInsights = const [],
  }) async {
    final payload = <String, dynamic>{
      if (profile != null) 'profile': profile,
      if (records.isNotEmpty) 'records': records,
      if (dailySummaries.isNotEmpty) 'dailySummaries': dailySummaries,
      if (dailyMoods.isNotEmpty) 'dailyMoods': dailyMoods,
      if (insightReports.isNotEmpty) 'insightReports': insightReports,
      if (weeklyInsights.isNotEmpty) 'weeklyInsights': weeklyInsights,
    };
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: payload,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> pushRecords(
    List<Map<String, dynamic>> records,
  ) {
    return pushData(records: records);
  }

  @override
  Future<Map<String, dynamic>> pull({required String cursor}) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {'cursor': cursor},
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> listRecords() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>('/records'),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> createRecord(
    Map<String, dynamic> record,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/records',
        data: record,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> updateRecord(
    String id,
    Map<String, dynamic> record,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.put<Map<String, dynamic>>(
        '/records/$id',
        data: record,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> deleteRecord(String id) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.delete<Map<String, dynamic>>('/records/$id'),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profile,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.put<Map<String, dynamic>>(
        '/me/profile',
        data: profile,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> updateDailyMood(
    String date,
    Map<String, dynamic> mood,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.put<Map<String, dynamic>>(
        '/daily/$date/mood',
        data: mood,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> updateDailySummary(
    String date,
    Map<String, dynamic> summary,
  ) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.put<Map<String, dynamic>>(
        '/daily/$date/summary',
        data: summary,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  @override
  Future<Map<String, dynamic>> upsertReport({
    required String periodType,
    required String periodKey,
    required Map<String, dynamic> report,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      () => _dio.put<Map<String, dynamic>>(
        '/reports/$periodType/${Uri.encodeComponent(periodKey)}',
        data: report,
      ),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function() request, {
    bool hasRetried = false,
  }) async {
    await _applyAccessToken();
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && !hasRetried) {
        await refresh();
        return _authorizedRequest(request, hasRetried: true);
      }
      throw OceanApiException.fromDio(error);
    }
  }

  Future<void> _applyAccessToken() async {
    final tokens = await tokenStore.readTokens();
    final accessToken = tokens?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OceanAuthException('Missing access token');
    }
    _dio.options.headers['Authorization'] = 'Bearer $accessToken';
  }

  Future<OceanAuthTokens> _saveAuthResponse(
    Map<String, dynamic>? data,
    String? email,
  ) async {
    final accessToken = data?['accessToken'] as String?;
    final refreshToken = data?['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw const OceanAuthException('Invalid auth response');
    }
    final tokens = OceanAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
    );
    await tokenStore.saveTokens(tokens);
    return tokens;
  }
}

class OceanAuthException implements Exception {
  const OceanAuthException(this.message);

  final String message;

  @override
  String toString() => 'OceanAuthException: $message';
}

class OceanApiException implements Exception {
  const OceanApiException(this.message, {this.statusCode});

  factory OceanApiException.fromDio(DioException error) {
    return OceanApiException(
      _extractMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  final String message;
  final int? statusCode;

  static String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final rawMessage = data['message'];
      if (rawMessage is List) {
        return rawMessage.map((item) => item.toString()).join('\n');
      }
      if (rawMessage != null) {
        return rawMessage.toString();
      }
      final errorText = data['error'];
      if (errorText != null) return errorText.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return '请求失败（HTTP $statusCode）';
    return error.message ?? '网络请求失败';
  }

  String get displayMessage => _translateKnownMessage(message);

  static String _translateKnownMessage(String message) {
    if (message.contains('password must be longer than or equal to 8')) {
      return '密码至少需要 8 位';
    }
    if (message.contains('email must be an email')) {
      return '请输入有效的邮箱地址';
    }
    if (message.contains('Email already registered')) {
      return '这个邮箱已经注册，请直接登录';
    }
    if (message.contains('Invalid credentials')) {
      return '邮箱或密码不正确';
    }
    if (message.contains('Invalid refresh token')) {
      return '登录状态已失效，请重新登录';
    }
    if (message.contains('Missing bearer token')) {
      return '请先登录 Ocean 账号';
    }
    if (message.contains('Invalid SMS verification code')) {
      return '验证码错误或已过期';
    }
    if (message.contains('isv.ValidateFail') || message.contains('验证码校验失败')) {
      return '验证码已失效或已被使用，请重新获取验证码';
    }
    if (message.contains('Too Many Requests') ||
        message.contains('验证码发送过于频繁')) {
      return '验证码发送过于频繁，请稍后再试';
    }
    return message;
  }

  @override
  String toString() => displayMessage;
}
