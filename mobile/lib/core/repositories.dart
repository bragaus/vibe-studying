import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibe_studying_mobile/core/models.dart';

class AppConfig {
  static String get defaultApiBaseUrl {
    const configuredBaseUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configuredBaseUrl.trim().isNotEmpty) {
      return normalizeApiBaseUrl(configuredBaseUrl);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  static String normalizeApiBaseUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return defaultApiBaseUrl;
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final withoutTrailingSlash = withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;

    if (withoutTrailingSlash.endsWith('/api')) {
      return withoutTrailingSlash;
    }

    return '$withoutTrailingSlash/api';
  }
}

class ApiBaseUrlStorage {
  ApiBaseUrlStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _apiBaseUrlKey = 'vibe.api_base_url';

  Future<String?> readBaseUrl() async {
    final value = await _storage.read(key: _apiBaseUrlKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return AppConfig.normalizeApiBaseUrl(value);
  }

  Future<void> saveBaseUrl(String value) async {
    await _storage.write(
      key: _apiBaseUrlKey,
      value: AppConfig.normalizeApiBaseUrl(value),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _apiBaseUrlKey);
  }
}

class SessionStorage {
  SessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'vibe.access_token';
  static const _refreshTokenKey = 'vibe.refresh_token';

  Future<void> saveTokens(
      {required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<(String?, String?)> readTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    return (accessToken, refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
    return AuthSession.fromJson(response.data!);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return AuthSession.fromJson(response.data!);
  }

  Future<AppUser> me(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return AppUser.fromJson(response.data!);
  }
}

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<ProfileBundle> getMyProfile(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profile/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return ProfileBundle.fromJson(response.data!);
  }

  Future<ProfileBundle> completeOnboarding({
    required String accessToken,
    required String englishLevel,
    required List<String> favoriteSongs,
    required List<String> favoriteMovies,
    required List<String> favoriteSeries,
    required List<String> favoriteAnime,
    required List<String> favoriteArtists,
    required List<String> favoriteGenres,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/profile/onboarding',
      data: {
        'english_level': englishLevel,
        'favorite_songs': favoriteSongs,
        'favorite_movies': favoriteMovies,
        'favorite_series': favoriteSeries,
        'favorite_anime': favoriteAnime,
        'favorite_artists': favoriteArtists,
        'favorite_genres': favoriteGenres,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return ProfileBundle.fromJson(response.data!);
  }
}

class FeedRepository {
  FeedRepository(this._dio);

  final Dio _dio;

  Future<FeedPage> getPersonalizedFeed(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/feed/personalized',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return FeedPage.fromJson(response.data!);
  }

  Future<LessonDetail> getLessonDetail(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>('/lessons/$slug');
    return LessonDetail.fromJson(response.data!);
  }

  Future<void> submitPractice({
    required String accessToken,
    required int exerciseId,
    required List<PracticeLineResult> lineResults,
  }) async {
    final transcript = lineResults
        .map((item) => item.transcriptEn)
        .where((item) => item.trim().isNotEmpty)
        .join(' ');

    await _dio.post<void>(
      '/submissions',
      data: {
        'exercise_id': exerciseId,
        'transcript_en': transcript,
        'transcript_pt': '',
        'line_results': lineResults.map((item) => item.toJson()).toList(),
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}

String parseApiError(Object error) {
  if (error is DioException) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      if (detail is String) {
        return detail;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'O backend em ${error.requestOptions.baseUrl} demorou para responder.';
      case DioExceptionType.connectionError:
        return 'Nao foi possivel conectar ao backend em ${error.requestOptions.baseUrl}. Verifique se o servidor esta rodando.';
      default:
        break;
    }

    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!;
    }
  }

  if (error is ApiException) {
    return error.message;
  }

  return 'Falha inesperada ao acessar o backend.';
}
