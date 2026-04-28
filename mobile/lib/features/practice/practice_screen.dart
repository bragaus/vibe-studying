import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<PracticeLineResult> _results = [];

  Timer? _laneTimer;
  bool _sessionStarted = false;
  bool _isListening = false;
  bool _showCoach = false;
  double _laneProgress = 0;
  double _speedMultiplier = 1;
  int _currentLineIndex = 0;
  String _recognizedText = '';
  String _coachMessage = '';

  @override
  void dispose() {
    _laneTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  void _startSession(LessonDetail lesson) {
    _laneTimer?.cancel();
    _results.clear();
    setState(() {
      _sessionStarted = true;
      _showCoach = false;
      _laneProgress = 0;
      _speedMultiplier = 1;
      _currentLineIndex = 0;
      _recognizedText = '';
      _coachMessage = '';
    });
    _startLaneTimer(lesson);
  }

  void _startLaneTimer(LessonDetail lesson) {
    _laneTimer?.cancel();
    _laneTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted || _showCoach || !_sessionStarted) {
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
          fallbackMessage: 'A frase cruzou a linha de leitura. Respire, ouça a dica e tente novamente.',
        );
      }
    });
  }

  Future<void> _toggleListening(LessonDetail lesson) async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel iniciar o reconhecimento de voz neste dispositivo.')),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      partialResults: true,
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() => _recognizedText = result.recognizedWords);
        _evaluateTranscript(lesson, result.recognizedWords);
      },
    );
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
    final currentLine = lesson.exercise.lines[_currentLineIndex];
    final targetWords = _normalizeWords(currentLine.textEn);
    final spokenWords = _normalizeWords(recognizedText);
    if (spokenWords.isEmpty) {
      return;
    }

    var leadingMatches = 0;
    while (leadingMatches < spokenWords.length && leadingMatches < targetWords.length) {
      if (spokenWords[leadingMatches] != targetWords[leadingMatches]) {
        break;
      }
      leadingMatches += 1;
    }

    if (leadingMatches == targetWords.length) {
      _completeCurrentLine(lesson, currentLine, recognizedText, const []);
      return;
    }

    if (spokenWords.length >= targetWords.length && leadingMatches < targetWords.length) {
      final wrongWord = targetWords[leadingMatches];
      _pauseForCoaching(
        currentLine,
        recognizedText: recognizedText,
        wrongWords: [wrongWord],
        fallbackMessage: 'A IA detectou um desvio em "$wrongWord". Ajuste a pronuncia antes de continuar.',
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
    final score = ((spokenWords.length / targetWords.length) * 100).clamp(0, 100).round();

    _results.add(
      PracticeLineResult(
        exerciseLineId: line.id,
        transcriptEn: recognizedText,
        accuracyScore: score,
        pronunciationScore: score,
        wrongWords: wrongWords,
        feedback: {'coach_message': wrongWords.isEmpty ? 'Linha concluida com sucesso.' : _coachMessage},
        status: wrongWords.isEmpty ? 'matched' : 'needs_coaching',
      ),
    );

    if (_currentLineIndex == lesson.exercise.lines.length - 1) {
      _finishSession(lesson);
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
    _speech.stop();

    setState(() {
      _isListening = false;
      _showCoach = true;
      _coachMessage = line.phoneticHint.isNotEmpty
          ? 'Dica: ${line.phoneticHint}. ${line.textPt.isNotEmpty ? 'Traducao: ${line.textPt}.' : ''}'
          : fallbackMessage;
    });

    _results.add(
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
    await _speech.stop();
    setState(() {
      _isListening = false;
      _sessionStarted = false;
    });

    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      return;
    }

    try {
      await ref.read(feedRepositoryProvider).submitPractice(
            accessToken: session.accessToken,
            exerciseId: lesson.exercise.id,
            lineResults: _results,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessao enviada ao backend com sucesso.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider(widget.lessonSlug));

    return HudScaffold(
      title: 'PRACTICE_HUD',
      actions: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close, color: AppPalette.foreground),
        ),
      ],
      child: lessonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppPalette.neonPink)),
        error: (error, _) => Center(child: Text('Falha ao carregar lesson: $error')),
        data: (lesson) {
          final currentLine = lesson.exercise.lines[_currentLineIndex];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HudPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(lesson.exercise.instructionText),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HudTag(label: lesson.contentType, color: AppPalette.neonPink),
                        HudTag(label: lesson.difficulty, color: AppPalette.neonCyan),
                        HudTag(label: 'speed x${_speedMultiplier.toStringAsFixed(2)}', color: AppPalette.neonYellow),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HudPanel(
                child: Column(
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
                            child: Container(height: 2, color: AppPalette.neonCyan.withOpacity(0.8)),
                          ),
                          Positioned(
                            top: 12 + (_laneProgress * 180),
                            left: 12,
                            right: 12,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppPalette.neonPink.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppPalette.neonPink.withOpacity(0.55)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('LINE ${_currentLineIndex + 1}/${lesson.exercise.lines.length}', style: const TextStyle(color: AppPalette.neonCyan)),
                                  const SizedBox(height: 8),
                                  Text(currentLine.textEn, style: Theme.of(context).textTheme.titleLarge),
                                  if (currentLine.textPt.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(currentLine.textPt, style: const TextStyle(color: AppPalette.muted)),
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
                          : (_normalizeWords(_recognizedText).length / _normalizeWords(currentLine.textEn).length).clamp(0, 1),
                      color: AppPalette.neonPink,
                      backgroundColor: AppPalette.panelSoft,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recognizedText.isEmpty ? 'Microfone aguardando fala...' : _recognizedText,
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
                            onPressed: _sessionStarted ? () => _toggleListening(lesson) : null,
                          ),
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
                      const Text('AI_COACH', style: TextStyle(color: AppPalette.neonYellow, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_coachMessage),
                      const SizedBox(height: 12),
                      NeonButton(
                        label: 'TENTAR_NOVAMENTE',
                        icon: Icons.replay,
                        onPressed: () {
                          setState(() {
                            _showCoach = false;
                            _recognizedText = '';
                            _laneProgress = 0;
                          });
                          _startLaneTimer(lesson);
                        },
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
