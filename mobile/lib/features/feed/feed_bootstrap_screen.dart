import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class FeedBootstrapScreen extends ConsumerStatefulWidget {
  const FeedBootstrapScreen({super.key});

  @override
  ConsumerState<FeedBootstrapScreen> createState() =>
      _FeedBootstrapScreenState();
}

class _FeedBootstrapScreenState extends ConsumerState<FeedBootstrapScreen> {
  FeedBootstrapStatus? _status;
  String? _errorMessage;
  bool _loading = true;
  Timer? _pollTimer;
  Timer? _copyTimer;
  int _loadingStep = 0;

  static const _loadingMessages = [
    (
      'Why do programmers prefer dark mode?',
      'Por que programadores preferem modo escuro?'
    ),
    ('Because light attracts bugs.', 'Porque a luz atrai bugs.'),
    (
      'Why did the English student bring a ladder?',
      'Por que o aluno de ingles levou uma escada?'
    ),
    ('To reach the next level.', 'Para alcancar o proximo nivel.'),
  ];

  @override
  void initState() {
    super.initState();
    _copyTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!mounted) {
          return;
        }
        setState(() => _loadingStep = (_loadingStep + 1) % 4);
      },
    );
    Future<void>.microtask(_ensureBootstrapStarted);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _copyTimer?.cancel();
    super.dispose();
  }

  void _openFeed() {
    if (!mounted) {
      return;
    }
    ref.invalidate(personalizedFeedProvider);
    ref.invalidate(feedBootstrapStatusProvider);
    context.go('/feed');
  }

  Future<void> _ensureBootstrapStarted() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    final repository = ref.read(feedRepositoryProvider);
    try {
      var nextStatus =
          await repository.getFeedBootstrapStatus(session.accessToken);
      if (nextStatus.status == 'idle' || nextStatus.hasFailed) {
        nextStatus = await repository.startFeedBootstrap(session.accessToken);
      }
      _applyStatus(nextStatus);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = parseApiError(error);
      });
    }
  }

  Future<void> _retryBootstrap() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final status = await ref
          .read(feedRepositoryProvider)
          .startFeedBootstrap(session.accessToken);
      _applyStatus(status);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = parseApiError(error);
      });
    }
  }

  Future<void> _pollStatus() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      _pollTimer?.cancel();
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final status = await ref
          .read(feedRepositoryProvider)
          .getFeedBootstrapStatus(session.accessToken);
      _applyStatus(status);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = parseApiError(error);
      });
    }
  }

  void _applyStatus(FeedBootstrapStatus status) {
    _pollTimer?.cancel();

    if (!mounted) {
      return;
    }

    if (status.isDone || status.readyItems > 0) {
      _openFeed();
      return;
    }

    if (status.hasFailed) {
      // Even without private lessons, the regular feed is still usable.
      _openFeed();
      return;
    }

    setState(() {
      _status = status;
      _loading = false;
      _errorMessage = status.hasFailed ? status.lastError : null;
    });

    if (status.isRunning) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _pollStatus(),
      );
    }
  }

  double _progressValue() {
    final status = _status;
    if (status == null) {
      return 0.08;
    }

    if (status.targetItems > 0 && status.readyItems > 0) {
      return (status.readyItems / status.targetItems).clamp(0, 1);
    }

    if (status.startedAt != null) {
      final elapsedSeconds =
          DateTime.now().difference(status.startedAt!.toLocal()).inSeconds;
      return (0.12 + (elapsedSeconds / 90)).clamp(0.12, 0.9);
    }

    if (status.isRunning) {
      return 0.16;
    }

    return 0.08;
  }

  int _progressPercent() => (_progressValue() * 100).round().clamp(0, 100);

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).valueOrNull?.profile;
    final status = _status;

    return HudScaffold(
      title: 'PROCURANDO SUA VIBE',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: HudPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...profile.favoriteSongs.take(2).map(
                              (item) => HudTag(
                                  label: item, color: AppPalette.neonPink),
                            ),
                        ...profile.favoriteMovies.take(2).map(
                              (item) => HudTag(
                                  label: item, color: AppPalette.neonCyan),
                            ),
                        ...profile.favoriteArtists.take(2).map(
                              (item) => HudTag(
                                  label: item, color: AppPalette.neonYellow),
                            ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_loading || (status?.isRunning ?? false))
                    _BootstrapLoadingPanel(
                      progressValue: _progressValue(),
                      progressPercent: _progressPercent(),
                      jokeEn: _loadingMessages[
                              _loadingStep % _loadingMessages.length]
                          .$1,
                      jokePt: _loadingMessages[
                              _loadingStep % _loadingMessages.length]
                          .$2,
                    )
                  else if (_errorMessage != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: NeonButton(
                                label: 'TENTAR_NOVAMENTE',
                                icon: Icons.refresh,
                                onPressed: _retryBootstrap,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.go('/login'),
                                child: const Text('Voltar ao login'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else if (status != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.hasFailed
                              ? 'Ainda estamos tentando montar sua selecao.'
                              : 'Status atual: ${status.status.toUpperCase()}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Itens prontos: ${status.readyItems}/${status.targetItems}',
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: status.targetItems == 0
                              ? null
                              : status.readyItems / status.targetItems,
                          backgroundColor: AppPalette.panelSoft,
                          color: AppPalette.neonPink,
                        ),
                        if (status.lastError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            status.lastError!,
                            style: const TextStyle(color: AppPalette.muted),
                          ),
                        ],
                        if (status.hasFailed) ...[
                          const SizedBox(height: 18),
                          NeonButton(
                            label: 'TENTAR_DE_NOVO',
                            icon: Icons.auto_awesome,
                            onPressed: _retryBootstrap,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapLoadingPanel extends StatelessWidget {
  const _BootstrapLoadingPanel({
    required this.progressValue,
    required this.progressPercent,
    required this.jokeEn,
    required this.jokePt,
  });

  final double progressValue;
  final int progressPercent;
  final String jokeEn;
  final String jokePt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanning references... $progressPercent%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progressValue,
                  color: AppPalette.neonPink,
                  backgroundColor: AppPalette.panelSoft,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(100 - progressPercent).clamp(0, 100)}% faltando',
                  style: const TextStyle(color: AppPalette.muted),
                ),
                const SizedBox(height: 18),
                Text(
                  jokeEn,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  jokePt,
                  style: const TextStyle(color: AppPalette.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
