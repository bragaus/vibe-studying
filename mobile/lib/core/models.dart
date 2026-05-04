class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? email : fullName;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': user.toJson(),
    };
  }
}

class StudentProfile {
  const StudentProfile({
    required this.onboardingCompleted,
    required this.englishLevel,
    required this.favoriteSongs,
    required this.favoriteMovies,
    required this.favoriteSeries,
    required this.favoriteAnime,
    required this.favoriteArtists,
    required this.favoriteGenres,
  });

  final bool onboardingCompleted;
  final String englishLevel;
  final List<String> favoriteSongs;
  final List<String> favoriteMovies;
  final List<String> favoriteSeries;
  final List<String> favoriteAnime;
  final List<String> favoriteArtists;
  final List<String> favoriteGenres;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(String key) =>
        ((json[key] as List<dynamic>? ?? const [])).cast<String>();

    return StudentProfile(
      onboardingCompleted: (json['onboarding_completed'] ?? false) as bool,
      englishLevel: (json['english_level'] ?? 'beginner') as String,
      favoriteSongs: asStringList('favorite_songs'),
      favoriteMovies: asStringList('favorite_movies'),
      favoriteSeries: asStringList('favorite_series'),
      favoriteAnime: asStringList('favorite_anime'),
      favoriteArtists: asStringList('favorite_artists'),
      favoriteGenres: asStringList('favorite_genres'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onboarding_completed': onboardingCompleted,
      'english_level': englishLevel,
      'favorite_songs': favoriteSongs,
      'favorite_movies': favoriteMovies,
      'favorite_series': favoriteSeries,
      'favorite_anime': favoriteAnime,
      'favorite_artists': favoriteArtists,
      'favorite_genres': favoriteGenres,
    };
  }
}

class ProfileBundle {
  const ProfileBundle({required this.user, required this.profile});

  final AppUser user;
  final StudentProfile profile;

  factory ProfileBundle.fromJson(Map<String, dynamic> json) {
    return ProfileBundle(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      profile: StudentProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'profile': profile.toJson(),
    };
  }
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.contentType,
    required this.sourceType,
    required this.difficulty,
    required this.tags,
    required this.mediaUrl,
    required this.mediaManifest,
    required this.coverImageUrl,
    required this.sourceUrl,
    required this.teacherName,
    required this.isPersonalized,
    required this.matchReason,
  });

  final int id;
  final String slug;
  final String title;
  final String description;
  final String contentType;
  final String sourceType;
  final String difficulty;
  final List<String> tags;
  final String mediaUrl;
  final MediaManifest? mediaManifest;
  final String coverImageUrl;
  final String sourceUrl;
  final String teacherName;
  final bool isPersonalized;
  final String? matchReason;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as int,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      contentType: json['content_type'] as String,
      sourceType: json['source_type'] as String,
      difficulty: (json['difficulty'] ?? 'easy') as String,
      tags: ((json['tags'] as List<dynamic>? ?? const [])).cast<String>(),
      mediaUrl: json['media_url'] as String,
      mediaManifest: json['media_manifest'] is Map<String, dynamic>
          ? MediaManifest.fromJson(
              json['media_manifest'] as Map<String, dynamic>)
          : null,
      coverImageUrl: (json['cover_image_url'] ?? '') as String,
      sourceUrl: (json['source_url'] ?? '') as String,
      teacherName: json['teacher_name'] as String,
      isPersonalized: (json['is_personalized'] ?? false) as bool,
      matchReason: json['match_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'content_type': contentType,
      'source_type': sourceType,
      'difficulty': difficulty,
      'tags': tags,
      'media_url': mediaUrl,
      'media_manifest': mediaManifest?.toJson(),
      'cover_image_url': coverImageUrl,
      'source_url': sourceUrl,
      'teacher_name': teacherName,
      'is_personalized': isPersonalized,
      'match_reason': matchReason,
    };
  }
}

class FeedBootstrapStatus {
  const FeedBootstrapStatus({
    required this.status,
    required this.readyItems,
    required this.targetItems,
    required this.generatedItems,
    required this.startedAt,
    required this.finishedAt,
    required this.lastError,
  });

  final String status;
  final int readyItems;
  final int targetItems;
  final int generatedItems;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? lastError;

  bool get isRunning => status == 'pending' || status == 'running';
  bool get isDone => status == 'done';
  bool get hasFailed => status == 'failed';

  factory FeedBootstrapStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(value);
    }

    return FeedBootstrapStatus(
      status: (json['status'] ?? 'idle') as String,
      readyItems: (json['ready_items'] ?? 0) as int,
      targetItems: (json['target_items'] ?? 0) as int,
      generatedItems: (json['generated_items'] ?? 0) as int,
      startedAt: parseDate('started_at'),
      finishedAt: parseDate('finished_at'),
      lastError: json['last_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'ready_items': readyItems,
      'target_items': targetItems,
      'generated_items': generatedItems,
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'last_error': lastError,
    };
  }
}

class FeedPage {
  const FeedPage({required this.items, required this.nextCursor});

  final List<FeedItem> items;
  final int? nextCursor;

  factory FeedPage.fromJson(Map<String, dynamic> json) {
    return FeedPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'next_cursor': nextCursor,
    };
  }
}

class MediaPlaylistItem {
  const MediaPlaylistItem({
    required this.title,
    required this.artistName,
    required this.audioUrl,
    required this.sourceUrl,
    required this.coverImageUrl,
    required this.durationMs,
    required this.offsetMs,
  });

  final String title;
  final String artistName;
  final String audioUrl;
  final String sourceUrl;
  final String coverImageUrl;
  final int durationMs;
  final int offsetMs;

  factory MediaPlaylistItem.fromJson(Map<String, dynamic> json) {
    return MediaPlaylistItem(
      title: (json['title'] ?? '') as String,
      artistName: (json['artist_name'] ?? '') as String,
      audioUrl: (json['audio_url'] ?? '') as String,
      sourceUrl: (json['source_url'] ?? '') as String,
      coverImageUrl: (json['cover_image_url'] ?? '') as String,
      durationMs: (json['duration_ms'] ?? 0) as int,
      offsetMs: (json['offset_ms'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist_name': artistName,
      'audio_url': audioUrl,
      'source_url': sourceUrl,
      'cover_image_url': coverImageUrl,
      'duration_ms': durationMs,
      'offset_ms': offsetMs,
    };
  }
}

class MediaManifest {
  const MediaManifest({
    required this.type,
    required this.playback,
    required this.speedUpEveryMs,
    required this.items,
  });

  final String type;
  final String playback;
  final int speedUpEveryMs;
  final List<MediaPlaylistItem> items;

  bool get hasPlaylist => items.isNotEmpty;

  factory MediaManifest.fromJson(Map<String, dynamic> json) {
    return MediaManifest(
      type: (json['type'] ?? '') as String,
      playback: (json['playback'] ?? 'sequential') as String,
      speedUpEveryMs: (json['speed_up_every_ms'] ?? 30000) as int,
      items: ((json['items'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
          .map(MediaPlaylistItem.fromJson)
          .where((item) => item.audioUrl.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'playback': playback,
      'speed_up_every_ms': speedUpEveryMs,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ExerciseLineItem {
  const ExerciseLineItem({
    required this.id,
    required this.order,
    required this.textEn,
    required this.textPt,
    required this.phoneticHint,
    required this.trackTitle,
    required this.artistName,
    required this.segmentIndex,
    required this.referenceStartMs,
    required this.referenceEndMs,
  });

  final int? id;
  final int order;
  final String textEn;
  final String textPt;
  final String phoneticHint;
  final String trackTitle;
  final String artistName;
  final int segmentIndex;
  final int referenceStartMs;
  final int referenceEndMs;

  factory ExerciseLineItem.fromJson(Map<String, dynamic> json) {
    return ExerciseLineItem(
      id: json['id'] as int?,
      order: json['order'] as int,
      textEn: json['text_en'] as String,
      textPt: (json['text_pt'] ?? '') as String,
      phoneticHint: (json['phonetic_hint'] ?? '') as String,
      trackTitle: (json['track_title'] ?? '') as String,
      artistName: (json['artist_name'] ?? '') as String,
      segmentIndex: (json['segment_index'] ?? 0) as int,
      referenceStartMs: (json['reference_start_ms'] ?? 0) as int,
      referenceEndMs: (json['reference_end_ms'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'text_en': textEn,
      'text_pt': textPt,
      'phonetic_hint': phoneticHint,
      'track_title': trackTitle,
      'artist_name': artistName,
      'segment_index': segmentIndex,
      'reference_start_ms': referenceStartMs,
      'reference_end_ms': referenceEndMs,
    };
  }
}

class ExerciseDetail {
  const ExerciseDetail({
    required this.id,
    required this.exerciseType,
    required this.instructionText,
    required this.expectedPhraseEn,
    required this.expectedPhrasePt,
    required this.maxScore,
    required this.lines,
  });

  final int id;
  final String exerciseType;
  final String instructionText;
  final String expectedPhraseEn;
  final String expectedPhrasePt;
  final int maxScore;
  final List<ExerciseLineItem> lines;

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    return ExerciseDetail(
      id: json['id'] as int,
      exerciseType: json['exercise_type'] as String,
      instructionText: json['instruction_text'] as String,
      expectedPhraseEn: json['expected_phrase_en'] as String,
      expectedPhrasePt: json['expected_phrase_pt'] as String,
      maxScore: json['max_score'] as int,
      lines: (json['lines'] as List<dynamic>)
          .map(
              (item) => ExerciseLineItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_type': exerciseType,
      'instruction_text': instructionText,
      'expected_phrase_en': expectedPhraseEn,
      'expected_phrase_pt': expectedPhrasePt,
      'max_score': maxScore,
      'lines': lines.map((item) => item.toJson()).toList(),
    };
  }
}

class LessonDetail {
  const LessonDetail({
    required this.slug,
    required this.title,
    required this.description,
    required this.contentType,
    required this.difficulty,
    required this.tags,
    required this.mediaUrl,
    required this.mediaManifest,
    required this.coverImageUrl,
    required this.sourceUrl,
    required this.exercise,
  });

  final String slug;
  final String title;
  final String description;
  final String contentType;
  final String difficulty;
  final List<String> tags;
  final String mediaUrl;
  final MediaManifest? mediaManifest;
  final String coverImageUrl;
  final String sourceUrl;
  final ExerciseDetail exercise;

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    return LessonDetail(
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      contentType: json['content_type'] as String,
      difficulty: (json['difficulty'] ?? 'easy') as String,
      tags: ((json['tags'] as List<dynamic>? ?? const [])).cast<String>(),
      mediaUrl: (json['media_url'] ?? '') as String,
      mediaManifest: json['media_manifest'] is Map<String, dynamic>
          ? MediaManifest.fromJson(
              json['media_manifest'] as Map<String, dynamic>)
          : null,
      coverImageUrl: (json['cover_image_url'] ?? '') as String,
      sourceUrl: (json['source_url'] ?? '') as String,
      exercise:
          ExerciseDetail.fromJson(json['exercise'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'description': description,
      'content_type': contentType,
      'difficulty': difficulty,
      'tags': tags,
      'media_url': mediaUrl,
      'media_manifest': mediaManifest?.toJson(),
      'cover_image_url': coverImageUrl,
      'source_url': sourceUrl,
      'exercise': exercise.toJson(),
    };
  }
}

class PracticeLineResult {
  const PracticeLineResult({
    required this.exerciseLineId,
    required this.transcriptEn,
    required this.accuracyScore,
    required this.pronunciationScore,
    required this.wrongWords,
    required this.feedback,
    required this.status,
  });

  final int? exerciseLineId;
  final String transcriptEn;
  final int accuracyScore;
  final int pronunciationScore;
  final List<String> wrongWords;
  final Map<String, dynamic> feedback;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'exercise_line_id': exerciseLineId,
      'transcript_en': transcriptEn,
      'accuracy_score': accuracyScore,
      'pronunciation_score': pronunciationScore,
      'wrong_words': wrongWords,
      'feedback': feedback,
      'status': status,
    };
  }

  factory PracticeLineResult.fromJson(Map<String, dynamic> json) {
    return PracticeLineResult(
      exerciseLineId: json['exercise_line_id'] as int?,
      transcriptEn: (json['transcript_en'] ?? '') as String,
      accuracyScore: (json['accuracy_score'] ?? 0) as int,
      pronunciationScore: (json['pronunciation_score'] ?? 0) as int,
      wrongWords:
          ((json['wrong_words'] as List<dynamic>? ?? const [])).cast<String>(),
      feedback: (json['feedback'] as Map<String, dynamic>? ?? const {}),
      status: (json['status'] ?? 'pending') as String,
    );
  }
}

class PendingPracticeSubmission {
  const PendingPracticeSubmission({
    required this.clientSubmissionId,
    required this.exerciseId,
    required this.transcriptEn,
    required this.transcriptPt,
    required this.lineResults,
    required this.createdAt,
  });

  final String clientSubmissionId;
  final int exerciseId;
  final String transcriptEn;
  final String transcriptPt;
  final List<PracticeLineResult> lineResults;
  final String createdAt;

  factory PendingPracticeSubmission.fromJson(Map<String, dynamic> json) {
    return PendingPracticeSubmission(
      clientSubmissionId: json['client_submission_id'] as String,
      exerciseId: json['exercise_id'] as int,
      transcriptEn: (json['transcript_en'] ?? '') as String,
      transcriptPt: (json['transcript_pt'] ?? '') as String,
      lineResults: ((json['line_results'] as List<dynamic>? ?? const []).map(
              (item) =>
                  PracticeLineResult.fromJson(item as Map<String, dynamic>)))
          .toList(),
      createdAt:
          (json['created_at'] ?? DateTime.now().toIso8601String()) as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_submission_id': clientSubmissionId,
      'exercise_id': exerciseId,
      'transcript_en': transcriptEn,
      'transcript_pt': transcriptPt,
      'line_results': lineResults.map((item) => item.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}

class SubmissionDispatchResult {
  const SubmissionDispatchResult({
    required this.queuedOffline,
    required this.clientSubmissionId,
  });

  final bool queuedOffline;
  final String clientSubmissionId;
}
