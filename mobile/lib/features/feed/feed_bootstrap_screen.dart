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

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_ensureBootstrapStarted);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
      if (nextStatus.status == 'idle') {
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

    if (status.isDone) {
      ref.invalidate(personalizedFeedProvider);
      context.go('/feed');
      return;
    }

    setState(() {
      _status = status;
      _loading = false;
      _errorMessage = null;
    });

    if (status.isRunning) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _pollStatus(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).valueOrNull?.profile;
    final status = _status;

    return HudScaffold(
      title: 'Montando sua previa',
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
                  const Text(
                    'A IA esta buscando frases, referencias e imagens na web para transformar seus gostos em lessons praticaveis.',
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 14),
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
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(
                            color: AppPalette.neonPink),
                      ),
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
                                onPressed: () => context.go('/feed'),
                                child: const Text('Ir para feed'),
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
                              ? 'A geracao falhou, mas voce pode tentar de novo.'
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
                        const SizedBox(height: 18),
                        if (status.hasFailed)
                          Row(
                            children: [
                              Expanded(
                                child: NeonButton(
                                  label: 'REGERAR_PREVIA',
                                  icon: Icons.auto_awesome,
                                  onPressed: _retryBootstrap,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.go('/feed'),
                                  child: const Text('Continuar assim mesmo'),
                                ),
                              ),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => context.go('/feed'),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Abrir feed agora'),
                          ),
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
