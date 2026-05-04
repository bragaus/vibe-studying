import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.lessonSlug});

  final String lessonSlug;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  static const double _musicViewportHeight = 420;
  static const double _musicItemExtent = 92;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _musicScrollController = ScrollController();
  final List<PracticeLineResult> _results = [];

  Timer? _laneTimer;
  Timer? _fallbackPlaybackTimer;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<int?>? _audioIndexSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;

  bool _sessionStarted = false;
  bool _isListening = false;
  bool _showCoach = false;
  bool _audioPlaying = false;
  bool _audioPluginAvailable = true;
  bool _speechReady = false;
  bool _musicScrollSyncQueued = false;
  double _laneProgress = 0;
  double _speedMultiplier = 1;
  int _currentLineIndex = 0;
  int _currentPlaylistIndex = 0;
  int _lastSettledLineIndex = -1;
  int _lastVisualProgressMs = -1;
  int _globalPlaybackMs = 0;
  String _recognizedText = '';
  String _coachMessage = '';
  String? _preparedAudioSlug;

  @override
  void dispose() {
    _laneTimer?.cancel();
    _fallbackPlaybackTimer?.cancel();
    _audioPositionSubscription?.cancel();
    _audioIndexSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _musicScrollController.dispose();
    unawaited(_safeStopSpeech());
    unawaited(_safeDisposeAudioPlayer());
    super.dispose();
  }

  Future<void> _safeDisposeAudioPlayer() async {
    try {
      await _audioPlayer.dispose();
    } catch (_) {
      _audioPluginAvailable = false;
    }
  }

  Future<void> _safeStopSpeech() async {
    if (!_speechReady) {
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {
      _speechReady = false;
    }
  }

  Future<bool> _safeInitializeSpeech() async {
    try {
      final available = await _speech.initialize();
      _speechReady = available;
      return available;
    } catch (_) {
      _speechReady = false;
      return false;
    }
  }

  bool _isMusicLesson(LessonDetail lesson) => lesson.contentType == 'music';

  double get _musicTopPadding =>
      (_musicViewportHeight * 0.28).clamp(96.0, 160.0);

  double get _musicBottomPadding =>
      (_musicViewportHeight - _musicTopPadding - _musicItemExtent)
          .clamp(96.0, 220.0);

  List<MediaPlaylistItem> _playlistForLesson(LessonDetail lesson) {
    final manifest = lesson.mediaManifest;
    if (manifest != null && manifest.items.isNotEmpty) {
      return manifest.items;
    }
    if (lesson.mediaUrl.trim().isEmpty) {
      return const [];
    }
    return [
      MediaPlaylistItem(
        title: lesson.title,
        artistName: '',
        audioUrl: lesson.mediaUrl,
        sourceUrl: lesson.sourceUrl,
        coverImageUrl: lesson.coverImageUrl,
        durationMs: 30000,
        offsetMs: 0,
      ),
    ];
  }

  int _totalMusicDurationMs(LessonDetail lesson) {
    final playlist = _playlistForLesson(lesson);
    if (playlist.isNotEmpty) {
      final last = playlist.last;
      return last.offsetMs + last.durationMs;
    }
    if (lesson.exercise.lines.isEmpty) {
      return 0;
    }
    return lesson.exercise.lines.last.referenceEndMs + 1200;
  }

  void _handleMusicProgress(LessonDetail lesson, int globalPlaybackMs) {
    if (!mounted || !_sessionStarted) {
      return;
    }

    final pausedForCoaching =
        _settleElapsedMusicLines(lesson, globalPlaybackMs);
    if (pausedForCoaching) {
      return;
    }

    final currentLineIndex =
        _resolveCurrentLineIndex(lesson.exercise.lines, globalPlaybackMs);
    final speedEveryMs = lesson.mediaManifest?.speedUpEveryMs ?? 30000;
    final speedTier = speedEveryMs <= 0 ? 0 : globalPlaybackMs ~/ speedEveryMs;
    final nextSpeedMultiplier = 1 + (speedTier * 0.18);
    final shouldRefreshVisuals = currentLineIndex != _currentLineIndex ||
        (nextSpeedMultiplier - _speedMultiplier).abs() >= 0.01 ||
        (globalPlaybackMs - _lastVisualProgressMs).abs() >= 40;

    _globalPlaybackMs = globalPlaybackMs;
    if (!shouldRefreshVisuals) {
      _scheduleMusicLaneScrollSync(lesson);
      return;
    }

    _lastVisualProgressMs = globalPlaybackMs;

    setState(() {
      _globalPlaybackMs = globalPlaybackMs;
      _currentLineIndex = currentLineIndex;
      _speedMultiplier = nextSpeedMultiplier;
    });
    _scheduleMusicLaneScrollSync(lesson);
  }

  void _scheduleMusicLaneScrollSync(LessonDetail lesson) {
    if (_musicScrollSyncQueued || !_isMusicLesson(lesson)) {
      return;
    }

    _musicScrollSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _musicScrollSyncQueued = false;
      if (!mounted) {
        return;
      }
      _syncMusicLaneScroll(lesson);
    });
  }

  void _syncMusicLaneScroll(LessonDetail lesson) {
    if (!_musicScrollController.hasClients || lesson.exercise.lines.isEmpty) {
      return;
    }

    final targetOffset = _musicScrollOffset(lesson, _musicItemExtent).clamp(
      0.0,
      _musicScrollController.position.maxScrollExtent,
    );

    if ((targetOffset - _musicScrollController.offset).abs() < 1) {
      return;
    }

    _musicScrollController.jumpTo(targetOffset);
  }

  void _startFallbackPlayback(LessonDetail lesson, {int startMs = 0}) {
    _fallbackPlaybackTimer?.cancel();
    setState(() {
      _audioPlaying = true;
      _globalPlaybackMs = startMs;
      _currentLineIndex =
          _resolveCurrentLineIndex(lesson.exercise.lines, startMs);
    });

    _fallbackPlaybackTimer =
        Timer.periodic(const Duration(milliseconds: 140), (timer) async {
      final nextMs = _globalPlaybackMs + 140;
      final totalDurationMs = _totalMusicDurationMs(lesson);
      if (nextMs >= totalDurationMs) {
        timer.cancel();
        await _finishSession(lesson);
        return;
      }
      _handleMusicProgress(lesson, nextMs);
    });
  }

  void _pauseFallbackPlayback() {
    _fallbackPlaybackTimer?.cancel();
    if (mounted) {
      setState(() => _audioPlaying = false);
    }
  }

  Future<void> _startSession(LessonDetail lesson) async {
    _laneTimer?.cancel();
    _fallbackPlaybackTimer?.cancel();
    _results.clear();
    await _safeStopSpeech();
    setState(() {
      _sessionStarted = true;
      _showCoach = false;
      _laneProgress = 0;
      _speedMultiplier = 1;
      _currentLineIndex = 0;
      _currentPlaylistIndex = 0;
      _lastSettledLineIndex = -1;
      _lastVisualProgressMs = -1;
      _globalPlaybackMs = 0;
      _recognizedText = '';
      _coachMessage = '';
      _isListening = false;
    });
    _scheduleMusicLaneScrollSync(lesson);

    if (_isMusicLesson(lesson)) {
      final prepared = await _prepareMusicPlayer(lesson);
      if (!prepared) {
        _startFallbackPlayback(lesson);
        return;
      }
      _bindMusicStreams(lesson);
      try {
        await _audioPlayer.seek(Duration.zero, index: 0);
        await _audioPlayer.play();
      } catch (_) {
        _audioPluginAvailable = false;
        _startFallbackPlayback(lesson);
      }
      return;
    }

    _startLaneTimer(lesson);
  }

  Future<bool> _prepareMusicPlayer(LessonDetail lesson) async {
    if (_preparedAudioSlug == lesson.slug) {
      return _playlistForLesson(lesson).isNotEmpty;
    }

    final playlist = _playlistForLesson(lesson)
        .where((item) => item.audioUrl.trim().isNotEmpty)
        .toList();
    if (playlist.isEmpty) {
      return false;
    }

    final sources = playlist
        .map((item) => AudioSource.uri(Uri.parse(item.audioUrl), tag: item))
        .toList();
    final source = sources.length == 1
        ? sources.first
        : ConcatenatingAudioSource(
            useLazyPreparation: true,
            children: sources,
          );

    try {
      await _audioPlayer.setAudioSource(source);
    } on MissingPluginException {
      _audioPluginAvailable = false;
      return false;
    } catch (_) {
      _audioPluginAvailable = false;
      return false;
    }
    _preparedAudioSlug = lesson.slug;
    return true;
  }

  void _bindMusicStreams(LessonDetail lesson) {
    _audioPositionSubscription?.cancel();
    _audioIndexSubscription?.cancel();
    _audioStateSubscription?.cancel();

    _audioIndexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      if (!mounted) {
        return;
      }
      setState(() => _currentPlaylistIndex = index ?? 0);
    });

    _audioPositionSubscription = _audioPlayer.positionStream.listen((position) {
      if (!mounted || !_sessionStarted) {
        return;
      }

      final playbackItems = _playlistForLesson(lesson);
      final playlistIndex = _audioPlayer.currentIndex ?? _currentPlaylistIndex;
      final globalPlaybackMs =
          _playlistOffsetForIndex(playbackItems, playlistIndex) +
              position.inMilliseconds;
      _handleMusicProgress(lesson, globalPlaybackMs);
    });

    _audioStateSubscription =
        _audioPlayer.playerStateStream.listen((playerState) async {
      if (!mounted) {
        return;
      }
      setState(() => _audioPlaying = playerState.playing);
      if (_sessionStarted &&
          playerState.processingState == ProcessingState.completed) {
        await _finishSession(lesson);
      }
    });
  }

  int _playlistOffsetForIndex(List<MediaPlaylistItem> playlist, int index) {
    if (playlist.isEmpty || index <= 0) {
      return 0;
    }
    if (index < playlist.length) {
      return playlist[index].offsetMs;
    }

    var total = 0;
    for (final item in playlist) {
      total += item.durationMs;
    }
    return total;
  }

  int _resolveCurrentLineIndex(
      List<ExerciseLineItem> lines, int globalPlaybackMs) {
    if (lines.isEmpty) {
      return 0;
    }

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (globalPlaybackMs < line.referenceStartMs) {
        return index == 0 ? 0 : index - 1;
      }
      if (globalPlaybackMs <= line.referenceEndMs) {
        return index;
      }
    }
    return lines.length - 1;
  }

  bool _hasRecordedLine(ExerciseLineItem line) {
    return _results.any((item) => item.exerciseLineId == line.id);
  }

  void _upsertLineResult(PracticeLineResult result) {
    final existingIndex = _results
        .indexWhere((item) => item.exerciseLineId == result.exerciseLineId);
    if (existingIndex >= 0) {
      _results[existingIndex] = result;
      return;
    }
    _results.add(result);
  }

  bool _settleElapsedMusicLines(LessonDetail lesson, int globalPlaybackMs) {
    if (!_isMusicLesson(lesson) ||
        lesson.exercise.lines.isEmpty ||
        _showCoach) {
      return false;
    }

    while (_lastSettledLineIndex + 1 < lesson.exercise.lines.length) {
      final line = lesson.exercise.lines[_lastSettledLineIndex + 1];
      if (globalPlaybackMs <= line.referenceEndMs) {
        break;
      }

      if (!_hasRecordedLine(line)) {
        if (_recognizedText.trim().isNotEmpty &&
            line.id == lesson.exercise.lines[_currentLineIndex].id) {
          _pauseForCoaching(
            line,
            recognizedText: _recognizedText,
            wrongWords: _collectWrongWords(line, _recognizedText),
            fallbackMessage:
                'A fala saiu diferente da linha. Vamos ajustar a pronuncia em portugues antes de seguir.',
          );
          return true;
        }
        _recordMissedLine(line);
      }

      _lastSettledLineIndex += 1;
    }

    return false;
  }

  List<String> _collectWrongWords(
      ExerciseLineItem line, String recognizedText) {
    final targetWords = _normalizeWords(line.textEn);
    final spokenWords = _normalizeWords(recognizedText);
    final wrongWords = <String>[];
    for (var index = 0; index < targetWords.length; index++) {
      if (index >= spokenWords.length ||
          spokenWords[index] != targetWords[index]) {
        wrongWords.add(targetWords[index]);
      }
    }
    return wrongWords.take(3).toList();
  }

  void _recordMissedLine(ExerciseLineItem line) {
    _upsertLineResult(
      PracticeLineResult(
        exerciseLineId: line.id,
        transcriptEn: '',
        accuracyScore: 0,
        pronunciationScore: 0,
        wrongWords: const [],
        feedback: const {
          'coach_message':
              'A linha passou sem resposta. Continue ouvindo e tente a proxima.',
        },
        status: 'missed',
      ),
    );
  }

  String _buildPortuguesePronunciationHint(String text) {
    var hint = text.toLowerCase();
    const replacements = {
      'tion': 'xon',
      'th': 'd',
      'sh': 'x',
      'ch': 'tch',
      'ight': 'ait',
      'ee': 'i',
      'ea': 'i',
      'oo': 'u',
      'ou': 'au',
      'ow': 'ou',
      'ph': 'f',
      'ing': 'in',
      'wh': 'u',
      'qu': 'ku',
    };
    replacements.forEach((source, target) {
      hint = hint.replaceAll(source, target);
    });
    hint = hint.replaceAll(RegExp(r'[^a-z\s]'), '');
    return hint
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .join(' ');
  }

  String _buildCoachMessage(ExerciseLineItem line, String fallbackMessage) {
    final phoneticHint = line.phoneticHint.trim().isNotEmpty
        ? line.phoneticHint
        : _buildPortuguesePronunciationHint(line.textEn);
    final translationText =
        line.textPt.trim().isEmpty ? '' : ' Traducao: ${line.textPt}.';
    if (phoneticHint.trim().isEmpty) {
      return '$fallbackMessage$translationText';
    }
    return 'Pronuncia aproximada em portugues: $phoneticHint.$translationText';
  }

  double _buildFinalScoreOutOfTen(List<PracticeLineResult> results) {
    if (results.isEmpty) {
      return 0;
    }

    double total = 0;
    for (final result in results) {
      switch (result.status) {
        case 'matched':
          total += ((result.accuracyScore + result.pronunciationScore) / 20)
              .clamp(0, 10)
              .toDouble();
          break;
        case 'needs_coaching':
          total += 3;
          break;
        default:
          total += 0;
      }
    }
    return total / results.length;
  }

  Future<void> _showSessionSummary(
    LessonDetail lesson,
    SubmissionDispatchResult? dispatchResult,
  ) async {
    if (!mounted) {
      return;
    }

    final lineCount = lesson.exercise.lines.length;
    final matchedCount =
        _results.where((item) => item.status == 'matched').length;
    final coachingCount =
        _results.where((item) => item.status == 'needs_coaching').length;
    final missedCount =
        _results.where((item) => item.status == 'missed').length;
    final finalScore = _buildFinalScoreOutOfTen(_results);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.panel,
        title: const Text('Resultado da sessao'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nota final: ${finalScore.toStringAsFixed(1)}/10',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Linhas avaliadas: $lineCount'),
            Text('Acertos: $matchedCount'),
            Text('Corrigidas no coach: $coachingCount'),
            Text('Passaram sem fala: $missedCount'),
            if (dispatchResult != null) ...[
              const SizedBox(height: 12),
              Text(
                dispatchResult.queuedOffline
                    ? 'Sua tentativa foi salva offline para sincronizar depois.'
                    : 'Sua tentativa foi enviada ao backend com sucesso.',
                style: const TextStyle(color: AppPalette.muted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryCurrentLine(LessonDetail lesson) async {
    setState(() {
      _showCoach = false;
      _recognizedText = '';
      _laneProgress = 0;
    });

    if (_isMusicLesson(lesson)) {
      final currentLine = lesson.exercise.lines[_currentLineIndex];
      if (_audioPluginAvailable) {
        await _seekToGlobalPosition(lesson, currentLine.referenceStartMs);
        try {
          await _audioPlayer.play();
        } catch (_) {
          _audioPluginAvailable = false;
          _startFallbackPlayback(lesson, startMs: currentLine.referenceStartMs);
        }
      } else {
        _startFallbackPlayback(lesson, startMs: currentLine.referenceStartMs);
      }
      return;
    }

    _startLaneTimer(lesson);
  }

  Future<void> _seekToGlobalPosition(
      LessonDetail lesson, int globalPositionMs) async {
    final playlist = _playlistForLesson(lesson);
    if (playlist.isEmpty) {
      return;
    }

    for (var index = 0; index < playlist.length; index++) {
      final item = playlist[index];
      final segmentEnd = item.offsetMs + item.durationMs;
      if (globalPositionMs < segmentEnd || index == playlist.length - 1) {
        final localPositionMs =
            (globalPositionMs - item.offsetMs).clamp(0, item.durationMs);
        await _audioPlayer.seek(Duration(milliseconds: localPositionMs),
            index: index);
        setState(() => _currentPlaylistIndex = index);
        _scheduleMusicLaneScrollSync(lesson);
        return;
      }
    }
  }

  void _startLaneTimer(LessonDetail lesson) {
    _laneTimer?.cancel();
    _laneTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted ||
          _showCoach ||
          !_sessionStarted ||
          _isMusicLesson(lesson)) {
        return;
      }

      setState(() {
        _laneProgress = (_laneProgress + (0.02 * _speedMultiplier)).clamp(0, 1);
      });

      if (_laneProgress >= 1) {
        _pauseForCoaching(
          lesson.exercise.lines[_currentLineIndex],
          recognizedText: _recognizedText,
          wrongWords: const ['timing'],
          fallbackMessage:
              'A frase cruzou a linha de leitura. Respire, ouca a dica e tente novamente.',
        );
      }
    });
  }

  Future<void> _toggleAudioPlayback() async {
    if (!_audioPluginAvailable) {
      if (_audioPlaying) {
        _pauseFallbackPlayback();
      }
      return;
    }
    if (_audioPlaying) {
      try {
        await _audioPlayer.pause();
      } catch (_) {
        _audioPluginAvailable = false;
      }
      return;
    }
    try {
      await _audioPlayer.play();
    } catch (_) {
      _audioPluginAvailable = false;
    }
  }

  Future<void> _toggleListening(LessonDetail lesson) async {
    if (_isListening) {
      await _safeStopSpeech();
      setState(() => _isListening = false);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final available = await _safeInitializeSpeech();
    if (!available || !mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Nao foi possivel iniciar o reconhecimento de voz neste dispositivo. A musica continua normalmente sem microfone.'),
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        onResult: (result) {
          if (!mounted) {
            return;
          }
          setState(() => _recognizedText = result.recognizedWords);
          _evaluateTranscript(lesson, result.recognizedWords);
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isListening = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Este dispositivo nao conseguiu iniciar a captura de audio. A musica continua normalmente sem microfone.'),
        ),
      );
    }
  }

  List<String> _normalizeWords(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), '')
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  void _evaluateTranscript(LessonDetail lesson, String recognizedText) {
    if (lesson.exercise.lines.isEmpty) {
      return;
    }

    final currentLine = lesson.exercise.lines[_currentLineIndex];
    final targetWords = _normalizeWords(currentLine.textEn);
    final spokenWords = _normalizeWords(recognizedText);
    if (spokenWords.isEmpty) {
      return;
    }

    var leadingMatches = 0;
    while (leadingMatches < spokenWords.length &&
        leadingMatches < targetWords.length) {
      if (spokenWords[leadingMatches] != targetWords[leadingMatches]) {
        break;
      }
      leadingMatches += 1;
    }

    if (leadingMatches == targetWords.length) {
      _completeCurrentLine(lesson, currentLine, recognizedText, const []);
      return;
    }

    if (spokenWords.length >= targetWords.length &&
        leadingMatches < targetWords.length) {
      final wrongWord = targetWords[leadingMatches];
      _pauseForCoaching(
        currentLine,
        recognizedText: recognizedText,
        wrongWords: [wrongWord],
        fallbackMessage:
            'A IA detectou um desvio em "$wrongWord". Ajuste a pronuncia antes de continuar.',
      );
    }
  }

  void _completeCurrentLine(
    LessonDetail lesson,
    ExerciseLineItem line,
    String recognizedText,
    List<String> wrongWords,
  ) {
    final targetWords = _normalizeWords(line.textEn);
    final spokenWords = _normalizeWords(recognizedText);
    final score =
        ((spokenWords.length / targetWords.length) * 100).clamp(0, 100).round();

    _upsertLineResult(
      PracticeLineResult(
        exerciseLineId: line.id,
        transcriptEn: recognizedText,
        accuracyScore: score,
        pronunciationScore: score,
        wrongWords: wrongWords,
        feedback: {
          'coach_message': wrongWords.isEmpty
              ? 'Linha concluida com sucesso.'
              : _coachMessage,
        },
        status: wrongWords.isEmpty ? 'matched' : 'needs_coaching',
      ),
    );
    _lastSettledLineIndex = line.order - 1;
    _recognizedText = '';

    if (_currentLineIndex == lesson.exercise.lines.length - 1) {
      _finishSession(lesson);
      return;
    }

    if (_isMusicLesson(lesson)) {
      return;
    }

    setState(() {
      _currentLineIndex += 1;
      _recognizedText = '';
      _laneProgress = 0;
      _speedMultiplier += 0.15;
      _showCoach = false;
    });
  }

  void _pauseForCoaching(
    ExerciseLineItem line, {
    required String recognizedText,
    required List<String> wrongWords,
    required String fallbackMessage,
  }) {
    _laneTimer?.cancel();
    unawaited(_safeStopSpeech());
    if (_audioPluginAvailable) {
      unawaited(_audioPlayer.pause().catchError((_) {
        _audioPluginAvailable = false;
      }));
    } else {
      _pauseFallbackPlayback();
    }

    setState(() {
      _isListening = false;
      _showCoach = true;
      _coachMessage = _buildCoachMessage(line, fallbackMessage);
    });

    _upsertLineResult(
      PracticeLineResult(
        exerciseLineId: line.id,
        transcriptEn: recognizedText,
        accuracyScore: 55,
        pronunciationScore: 50,
        wrongWords: wrongWords,
        feedback: {'coach_message': _coachMessage},
        status: 'needs_coaching',
      ),
    );
  }

  Future<void> _finishSession(LessonDetail lesson) async {
    _laneTimer?.cancel();
    _fallbackPlaybackTimer?.cancel();
    await _safeStopSpeech();
    if (_audioPluginAvailable) {
      try {
        await _audioPlayer.stop();
      } catch (_) {
        _audioPluginAvailable = false;
      }
    }

    if (_isMusicLesson(lesson)) {
      for (final line in lesson.exercise.lines) {
        if (!_hasRecordedLine(line)) {
          _recordMissedLine(line);
        }
      }
    }

    setState(() {
      _isListening = false;
      _sessionStarted = false;
      _audioPlaying = false;
    });

    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      await _showSessionSummary(lesson, null);
      return;
    }

    SubmissionDispatchResult? dispatchResult;
    try {
      dispatchResult = await ref.read(feedRepositoryProvider).submitPractice(
            accessToken: session.accessToken,
            exerciseId: lesson.exercise.id,
            lineResults: _results,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dispatchResult.queuedOffline
                ? 'Sem conexao: tentativa salva offline e marcada para sincronizacao.'
                : 'Sessao enviada ao backend com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parseApiError(error))));
    }

    await _showSessionSummary(lesson, dispatchResult);
  }

  String _currentTrackLabel(LessonDetail lesson) {
    if (lesson.exercise.lines.isNotEmpty) {
      final line = lesson.exercise
          .lines[_currentLineIndex.clamp(0, lesson.exercise.lines.length - 1)];
      final pieces = [line.artistName, line.trackTitle]
          .where((item) => item.trim().isNotEmpty)
          .toList();
      if (pieces.isNotEmpty) {
        return pieces.join(' • ');
      }
    }

    final playlist = _playlistForLesson(lesson);
    if (playlist.isEmpty) {
      return lesson.title;
    }
    final current =
        playlist[_currentPlaylistIndex.clamp(0, playlist.length - 1)];
    final pieces = [current.artistName, current.title]
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return pieces.isEmpty ? lesson.title : pieces.join(' • ');
  }

  double _musicScrollOffset(LessonDetail lesson, double itemExtent) {
    final lines = lesson.exercise.lines;
    if (lines.isEmpty) {
      return 0;
    }

    final activeIndex = _currentLineIndex.clamp(0, lines.length - 1);
    final activeLine = lines[activeIndex];
    final lineDuration =
        (activeLine.referenceEndMs - activeLine.referenceStartMs)
            .clamp(1, 60000);
    final elapsedInLine = (_globalPlaybackMs - activeLine.referenceStartMs)
        .clamp(0, lineDuration);
    final progressInLine = elapsedInLine / lineDuration;
    final targetIndex = activeIndex + (progressInLine * 0.88);
    return targetIndex * itemExtent;
  }

  Widget _buildMusicLyricBlock(
      ExerciseLineItem line, int index, int activeIndex) {
    final result =
        _results.where((item) => item.exerciseLineId == line.id).firstOrNull;
    final distance = (index - activeIndex).abs();
    final isActive = index == activeIndex;
    final isMissed = result?.status == 'missed';
    final opacity = isActive
        ? 1.0
        : distance == 1
            ? 0.74
            : distance == 2
                ? 0.5
                : 0.22;

    final originalStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: isMissed
              ? AppPalette.neonPink.withValues(alpha: 0.92)
              : AppPalette.foreground.withValues(alpha: opacity),
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
          height: 1.02,
        );
    final translationStyle = TextStyle(
      color: isMissed
          ? AppPalette.neonPink.withValues(alpha: 0.72)
          : AppPalette.foreground.withValues(alpha: isActive ? 0.82 : opacity),
      fontSize: isActive ? 16 : 14,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
      height: 1.05,
    );

    return SizedBox(
      height: _musicItemExtent,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.textEn,
              style: originalStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (line.textPt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                line.textPt,
                style: translationStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMusicLane(LessonDetail lesson) {
    final lines = lesson.exercise.lines;
    if (lines.isEmpty) {
      return const Text('Essa lesson ainda nao possui linhas musicais.');
    }

    final activeIndex = _currentLineIndex.clamp(0, lines.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentTrackLabel(lesson),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Container(
          height: _musicViewportHeight,
          decoration: BoxDecoration(
            color: AppPalette.panelSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppPalette.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppPalette.panel.withValues(alpha: 0.98),
                            AppPalette.panelSoft.withValues(alpha: 0.94),
                            AppPalette.panel.withValues(alpha: 0.98),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ListView.builder(
                      controller: _musicScrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        22,
                        _musicTopPadding,
                        22,
                        _musicBottomPadding,
                      ),
                      itemCount: lines.length,
                      itemBuilder: (context, index) => _buildMusicLyricBlock(
                        lines[index],
                        index,
                        activeIndex,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppPalette.background.withValues(alpha: 0.92),
                              Colors.transparent,
                              Colors.transparent,
                              AppPalette.background.withValues(alpha: 0.92),
                            ],
                            stops: const [0, 0.14, 0.82, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    top: _musicTopPadding - 14,
                    child: Container(
                      height: 2,
                      color: AppPalette.neonCyan.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassicLane(LessonDetail lesson, ExerciseLineItem currentLine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KARAOKE_LANE'),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.panelSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.border),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.5),
                child: Container(
                  height: 2,
                  color: AppPalette.neonCyan.withValues(alpha: 0.8),
                ),
              ),
              Positioned(
                top: 12 + (_laneProgress * 180),
                left: 12,
                right: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.neonPink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppPalette.neonPink.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LINE ${_currentLineIndex + 1}/${lesson.exercise.lines.length}',
                        style: const TextStyle(color: AppPalette.neonCyan),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentLine.textEn,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (currentLine.textPt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          currentLine.textPt,
                          style: const TextStyle(color: AppPalette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (_normalizeWords(currentLine.textEn).isEmpty)
              ? 0
              : (_normalizeWords(_recognizedText).length /
                      _normalizeWords(currentLine.textEn).length)
                  .clamp(0, 1),
          color: AppPalette.neonPink,
          backgroundColor: AppPalette.panelSoft,
        ),
        const SizedBox(height: 10),
        Text(
          _recognizedText.isEmpty
              ? 'Microfone aguardando fala...'
              : _recognizedText,
          style: const TextStyle(color: AppPalette.foreground),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                label: _sessionStarted ? 'RESTART_RUN' : 'START_RUN',
                icon: Icons.play_arrow,
                onPressed: () => _startSession(lesson),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NeonButton(
                label: _isListening ? 'STOP_MIC' : 'ACTIVATE_MIC',
                icon: _isListening ? Icons.mic_off : Icons.mic,
                isPrimary: false,
                onPressed:
                    _sessionStarted ? () => _toggleListening(lesson) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMusicControls(LessonDetail lesson) {
    return Column(
      children: [
        NeonButton(
          label: _sessionStarted ? 'REINICIAR_MIX' : 'INICIAR_MIX',
          icon: Icons.play_arrow,
          onPressed: () => _startSession(lesson),
        ),
        const SizedBox(height: 12),
        NeonButton(
          label: _audioPlaying ? 'PAUSAR_AUDIO' : 'CONTINUAR_AUDIO',
          icon: _audioPlaying ? Icons.pause : Icons.play_circle_fill,
          isPrimary: false,
          onPressed: _sessionStarted ? _toggleAudioPlayback : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider(widget.lessonSlug));
    final session = ref.watch(sessionControllerProvider).session;
    final profileBundle = ref.watch(profileControllerProvider).valueOrNull;
    final avatarUrl = profileBundle?.profile.avatarUrl.isNotEmpty == true
        ? profileBundle!.profile.avatarUrl
        : (profileBundle?.user.avatarUrl ?? session?.user.avatarUrl ?? '');
    final avatarLabel =
        profileBundle?.user.displayName ?? session?.user.displayName ?? 'VS';
    final initials = avatarLabel
        .split(' ')
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .map((item) => item[0].toUpperCase())
        .join();

    return HudScaffold(
      title: 'PRACTICE_HUD',
      leading: [
        IconButton(
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go('/feed');
          },
          icon: const Icon(Icons.arrow_back, color: AppPalette.foreground),
        ),
      ],
      actions: [
        GestureDetector(
          onTap: () => context.push('/student-hub'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppPalette.neonCyan.withValues(alpha: 0.75),
              ),
              color: AppPalette.panel,
            ),
            child: ClipOval(
              child: avatarUrl.trim().isEmpty
                  ? Center(
                      child: Text(
                        initials.isEmpty ? 'VS' : initials,
                        style: const TextStyle(
                          color: AppPalette.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          initials.isEmpty ? 'VS' : initials,
                          style: const TextStyle(
                            color: AppPalette.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
      child: lessonAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppPalette.neonPink)),
        error: (error, _) =>
            Center(child: Text('Falha ao carregar lesson: $error')),
        data: (lesson) {
          final lines = lesson.exercise.lines;
          final currentLine = lines.isEmpty
              ? null
              : lines[_currentLineIndex.clamp(0, lines.length - 1)];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HudPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isMusicLesson(lesson))
                      _buildMusicLane(lesson)
                    else if (currentLine != null)
                      _buildClassicLane(lesson, currentLine)
                    else
                      const Text(
                          'Essa lesson ainda nao possui linhas para pratica.'),
                    if (_isMusicLesson(lesson)) ...[
                      const SizedBox(height: 16),
                      _buildMusicControls(lesson),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HudPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(lesson.exercise.instructionText),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HudTag(
                            label: lesson.contentType,
                            color: AppPalette.neonPink),
                        HudTag(
                            label: lesson.difficulty,
                            color: AppPalette.neonCyan),
                        HudTag(
                          label:
                              'speed x${_speedMultiplier.toStringAsFixed(2)}',
                          color: AppPalette.neonYellow,
                        ),
                        if (_isMusicLesson(lesson))
                          HudTag(
                            label: _currentTrackLabel(lesson),
                            color: AppPalette.neonCyan,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_showCoach) ...[
                const SizedBox(height: 16),
                HudPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI_COACH',
                        style: TextStyle(
                          color: AppPalette.neonYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_coachMessage),
                      const SizedBox(height: 12),
                      NeonButton(
                        label: 'TENTAR_NOVAMENTE',
                        icon: Icons.replay,
                        onPressed: () => _retryCurrentLine(lesson),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
