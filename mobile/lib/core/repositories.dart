import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _userKey = 'vibe.user';

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(
        key: _userKey, value: jsonEncode(session.user.toJson()));
  }

  Future<(String?, String?, AppUser?)> readSessionData() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final rawUser = await _storage.read(key: _userKey);

    AppUser? user;
    if (rawUser != null && rawUser.trim().isNotEmpty) {
      try {
        user = AppUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }

    return (accessToken, refreshToken, user);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}

class LocalStudyStorage {
  static const _profileKey = 'vibe.cache.profile';
  static const _feedKey = 'vibe.cache.feed';
  static const _pendingSubmissionsKey = 'vibe.queue.submissions';
  static const _lessonPrefix = 'vibe.cache.lesson.';

  Future<void> saveProfile(ProfileBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(bundle.toJson()));
  }

  Future<ProfileBundle?> readProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_profileKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      return ProfileBundle.fromJson(
          jsonDecode(rawValue) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFeedPage(FeedPage page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedKey, jsonEncode(page.toJson()));
  }

  Future<FeedPage?> readFeedPage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_feedKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      return FeedPage.fromJson(jsonDecode(rawValue) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLessonDetail(LessonDetail lesson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_lessonPrefix${lesson.slug}', jsonEncode(lesson.toJson()));
  }

  Future<LessonDetail?> readLessonDetail(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString('$_lessonPrefix$slug');
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      return LessonDetail.fromJson(
          jsonDecode(rawValue) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<PendingPracticeSubmission>> readPendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_pendingSubmissionsKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return [];
    }

    try {
      return (jsonDecode(rawValue) as List<dynamic>)
          .map((item) =>
              PendingPracticeSubmission.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueuePendingSubmission(
      PendingPracticeSubmission submission) async {
    final prefs = await SharedPreferences.getInstance();
    final currentItems = await readPendingSubmissions();
    final deduplicated = currentItems
        .where(
            (item) => item.clientSubmissionId != submission.clientSubmissionId)
        .toList();
    deduplicated.add(submission);
    await prefs.setString(
      _pendingSubmissionsKey,
      jsonEncode(deduplicated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> removePendingSubmission(String clientSubmissionId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentItems = await readPendingSubmissions();
    final updatedItems = currentItems
        .where((item) => item.clientSubmissionId != clientSubmissionId)
        .toList();
    await prefs.setString(
      _pendingSubmissionsKey,
      jsonEncode(updatedItems.map((item) => item.toJson()).toList()),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isLikelyOfflineError(Object error) {
  if (error is! DioException) {
    return false;
  }

  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
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
  ProfileRepository(this._dio, this._storage);

  final Dio _dio;
  final LocalStudyStorage _storage;

  Future<ProfileBundle> getMyProfile(String accessToken) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/profile/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final bundle = ProfileBundle.fromJson(response.data!);
      await _storage.saveProfile(bundle);
      return bundle;
    } catch (error) {
      final cachedBundle = await _storage.readProfile();
      if (cachedBundle != null && isLikelyOfflineError(error)) {
        return cachedBundle;
      }
      rethrow;
    }
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
    final bundle = ProfileBundle.fromJson(response.data!);
    await _storage.saveProfile(bundle);
    return bundle;
  }
}

class FeedRepository {
  FeedRepository(this._dio, this._storage);

  final Dio _dio;
  final LocalStudyStorage _storage;

  PendingPracticeSubmission buildPendingSubmission({
    required int exerciseId,
    required List<PracticeLineResult> lineResults,
  }) {
    final transcript = lineResults
        .map((item) => item.transcriptEn)
        .where((item) => item.trim().isNotEmpty)
        .join(' ');

    return PendingPracticeSubmission(
      clientSubmissionId:
          '${exerciseId}_${DateTime.now().microsecondsSinceEpoch}',
      exerciseId: exerciseId,
      transcriptEn: transcript,
      transcriptPt: '',
      lineResults: lineResults,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<FeedPage> getPersonalizedFeed(String accessToken) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/feed/personalized',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final page = FeedPage.fromJson(response.data!);
      await _storage.saveFeedPage(page);
      return page;
    } catch (error) {
      final cachedPage = await _storage.readFeedPage();
      if (cachedPage != null && isLikelyOfflineError(error)) {
        return cachedPage;
      }
      rethrow;
    }
  }

  Future<FeedBootstrapStatus> getFeedBootstrapStatus(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/feed/bootstrap-status',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return FeedBootstrapStatus.fromJson(response.data!);
  }

  Future<FeedBootstrapStatus> startFeedBootstrap(String accessToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/feed/bootstrap',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return FeedBootstrapStatus.fromJson(response.data!);
  }

  Future<LessonDetail> getLessonDetail(String slug,
      {String? accessToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lessons/$slug',
        options: accessToken == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final lesson = LessonDetail.fromJson(response.data!);
      await _storage.saveLessonDetail(lesson);
      return lesson;
    } catch (error) {
      final cachedLesson = await _storage.readLessonDetail(slug);
      if (cachedLesson != null && isLikelyOfflineError(error)) {
        return cachedLesson;
      }
      rethrow;
    }
  }

  Future<int> syncPendingSubmissions(String accessToken) async {
    final pendingSubmissions = await _storage.readPendingSubmissions();
    var syncedCount = 0;

    for (final submission in pendingSubmissions) {
      try {
        await _dio.post<void>(
          '/submissions',
          data: submission.toJson(),
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        await _storage.removePendingSubmission(submission.clientSubmissionId);
        syncedCount += 1;
      } on DioException catch (error) {
        if (isLikelyOfflineError(error)) {
          break;
        }
      }
    }

    return syncedCount;
  }

  Future<SubmissionDispatchResult> submitPractice({
    required String accessToken,
    required int exerciseId,
    required List<PracticeLineResult> lineResults,
  }) async {
    final pendingSubmission = buildPendingSubmission(
      exerciseId: exerciseId,
      lineResults: lineResults,
    );

    try {
      await _dio.post<void>(
        '/submissions',
        data: pendingSubmission.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      await _storage
          .removePendingSubmission(pendingSubmission.clientSubmissionId);
      return SubmissionDispatchResult(
        queuedOffline: false,
        clientSubmissionId: pendingSubmission.clientSubmissionId,
      );
    } catch (error) {
      if (isLikelyOfflineError(error)) {
        await _storage.enqueuePendingSubmission(pendingSubmission);
        return SubmissionDispatchResult(
          queuedOffline: true,
          clientSubmissionId: pendingSubmission.clientSubmissionId,
        );
      }
      rethrow;
    }
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
