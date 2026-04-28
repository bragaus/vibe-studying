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
    List<String> asStringList(String key) => ((json[key] as List<dynamic>? ?? const [])).cast<String>();

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
    required this.teacherName,
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
  final String teacherName;
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
      teacherName: json['teacher_name'] as String,
      matchReason: json['match_reason'] as String?,
    );
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
}

class ExerciseLineItem {
  const ExerciseLineItem({
    required this.id,
    required this.order,
    required this.textEn,
    required this.textPt,
    required this.phoneticHint,
    required this.referenceStartMs,
    required this.referenceEndMs,
  });

  final int? id;
  final int order;
  final String textEn;
  final String textPt;
  final String phoneticHint;
  final int referenceStartMs;
  final int referenceEndMs;

  factory ExerciseLineItem.fromJson(Map<String, dynamic> json) {
    return ExerciseLineItem(
      id: json['id'] as int?,
      order: json['order'] as int,
      textEn: json['text_en'] as String,
      textPt: (json['text_pt'] ?? '') as String,
      phoneticHint: (json['phonetic_hint'] ?? '') as String,
      referenceStartMs: (json['reference_start_ms'] ?? 0) as int,
      referenceEndMs: (json['reference_end_ms'] ?? 0) as int,
    );
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
          .map((item) => ExerciseLineItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
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
    required this.exercise,
  });

  final String slug;
  final String title;
  final String description;
  final String contentType;
  final String difficulty;
  final List<String> tags;
  final ExerciseDetail exercise;

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    return LessonDetail(
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: (json['description'] ?? '') as String,
      contentType: json['content_type'] as String,
      difficulty: (json['difficulty'] ?? 'easy') as String,
      tags: ((json['tags'] as List<dynamic>? ?? const [])).cast<String>(),
      exercise: ExerciseDetail.fromJson(json['exercise'] as Map<String, dynamic>),
    );
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
}
