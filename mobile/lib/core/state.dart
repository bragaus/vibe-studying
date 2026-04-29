import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final apiBaseUrlStorageProvider =
    Provider((ref) => ApiBaseUrlStorage(ref.watch(secureStorageProvider)));

class ApiBaseUrlController extends StateNotifier<String> {
  ApiBaseUrlController(this._storage) : super(AppConfig.defaultApiBaseUrl);

  final ApiBaseUrlStorage _storage;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final savedValue = await _storage.readBaseUrl();
    if (savedValue != null) {
      state = savedValue;
    }
    _loaded = true;
  }

  Future<void> update(String rawValue) async {
    final normalizedValue = AppConfig.normalizeApiBaseUrl(rawValue);
    await _storage.saveBaseUrl(normalizedValue);
    state = normalizedValue;
    _loaded = true;
  }

  Future<void> reset() async {
    await _storage.clear();
    state = AppConfig.defaultApiBaseUrl;
    _loaded = true;
  }
}

final apiBaseUrlControllerProvider =
    StateNotifierProvider<ApiBaseUrlController, String>(
  (ref) => ApiBaseUrlController(ref.watch(apiBaseUrlStorageProvider)),
);

final dioProvider = Provider(
  (ref) => Dio(
    BaseOptions(
      baseUrl: ref.watch(apiBaseUrlControllerProvider),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  ),
);

final sessionStorageProvider =
    Provider((ref) => SessionStorage(ref.watch(secureStorageProvider)));
final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(dioProvider)));
final profileRepositoryProvider =
    Provider((ref) => ProfileRepository(ref.watch(dioProvider)));
final feedRepositoryProvider =
    Provider((ref) => FeedRepository(ref.watch(dioProvider)));
final profilePhotoPathProvider = StateProvider<String?>((ref) => null);

enum SessionStatus { initial, loading, authenticated, unauthenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.session,
    this.errorMessage,
  });

  final SessionStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated && session != null;

  SessionState copyWith({
    SessionStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._authRepository, this._sessionStorage)
      : super(const SessionState(status: SessionStatus.initial));

  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;

  Future<AuthSession?> bootstrap() async {
    state = const SessionState(status: SessionStatus.loading);
    final (accessToken, refreshToken) = await _sessionStorage.readTokens();
    if (accessToken == null || refreshToken == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return null;
    }

    try {
      final user = await _authRepository.me(accessToken);
      final session = AuthSession(
          accessToken: accessToken, refreshToken: refreshToken, user: user);
      state =
          SessionState(status: SessionStatus.authenticated, session: session);
      return session;
    } catch (_) {
      try {
        final refreshedSession = await _authRepository.refresh(refreshToken);
        await _sessionStorage.saveTokens(
          accessToken: refreshedSession.accessToken,
          refreshToken: refreshedSession.refreshToken,
        );
        state = SessionState(
            status: SessionStatus.authenticated, session: refreshedSession);
        return refreshedSession;
      } catch (error) {
        await _sessionStorage.clear();
        state = SessionState(
            status: SessionStatus.unauthenticated,
            errorMessage: parseApiError(error));
        return null;
      }
    }
  }

  Future<AuthSession?> login(
      {required String email, required String password}) async {
    state = const SessionState(status: SessionStatus.loading);
    try {
      final session =
          await _authRepository.login(email: email, password: password);
      await _sessionStorage.saveTokens(
          accessToken: session.accessToken, refreshToken: session.refreshToken);
      state =
          SessionState(status: SessionStatus.authenticated, session: session);
      return session;
    } catch (error) {
      state = SessionState(
          status: SessionStatus.unauthenticated,
          errorMessage: parseApiError(error));
      return null;
    }
  }

  Future<AuthSession?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = const SessionState(status: SessionStatus.loading);
    try {
      final session = await _authRepository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _sessionStorage.saveTokens(
          accessToken: session.accessToken, refreshToken: session.refreshToken);
      state =
          SessionState(status: SessionStatus.authenticated, session: session);
      return session;
    } catch (error) {
      state = SessionState(
          status: SessionStatus.unauthenticated,
          errorMessage: parseApiError(error));
      return null;
    }
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(
      ref.watch(authRepositoryProvider), ref.watch(sessionStorageProvider)),
);

class ProfileController extends StateNotifier<AsyncValue<ProfileBundle?>> {
  ProfileController(this._repository) : super(const AsyncValue.data(null));

  final ProfileRepository _repository;

  Future<ProfileBundle> load(String accessToken) async {
    state = const AsyncValue.loading();
    final profile =
        await AsyncValue.guard(() => _repository.getMyProfile(accessToken));
    state = profile;
    return profile.requireValue;
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
    state = const AsyncValue.loading();
    final profile = await AsyncValue.guard(
      () => _repository.completeOnboarding(
        accessToken: accessToken,
        englishLevel: englishLevel,
        favoriteSongs: favoriteSongs,
        favoriteMovies: favoriteMovies,
        favoriteSeries: favoriteSeries,
        favoriteAnime: favoriteAnime,
        favoriteArtists: favoriteArtists,
        favoriteGenres: favoriteGenres,
      ),
    );
    state = profile;
    return profile.requireValue;
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<ProfileBundle?>>(
  (ref) => ProfileController(ref.watch(profileRepositoryProvider)),
);

final personalizedFeedProvider =
    FutureProvider.autoDispose<FeedPage>((ref) async {
  final session = ref.watch(sessionControllerProvider).session;
  if (session == null) {
    throw const ApiException('Sessão não encontrada.');
  }
  return ref
      .watch(feedRepositoryProvider)
      .getPersonalizedFeed(session.accessToken);
});

final lessonDetailProvider =
    FutureProvider.autoDispose.family<LessonDetail, String>((ref, slug) async {
  return ref.watch(feedRepositoryProvider).getLessonDetail(slug);
});
