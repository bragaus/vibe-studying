import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

enum _HeaderMenuAction { settings, github, logout }

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  Timer? _bootstrapPollTimer;
  bool _attemptedBootstrapRecovery = false;

  static final Uri _projectGithubUri =
      Uri.parse('https://github.com/bragaus/vibe-studying');

  @override
  void initState() {
    super.initState();
    _bootstrapPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollBootstrapStatus(),
    );
    Future<void>.microtask(_pollBootstrapStatus);
  }

  @override
  void dispose() {
    _bootstrapPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollBootstrapStatus() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      return;
    }

    try {
      final status = await ref
          .read(feedRepositoryProvider)
          .getFeedBootstrapStatus(session.accessToken);
      if (!mounted) {
        return;
      }

      ref.invalidate(feedBootstrapStatusProvider);
      if (status.isDone || status.readyItems > 0) {
        ref.invalidate(personalizedFeedProvider);
        return;
      }

      if (status.hasFailed && !_attemptedBootstrapRecovery) {
        _attemptedBootstrapRecovery = true;
        await ref
            .read(feedRepositoryProvider)
            .startFeedBootstrap(session.accessToken);
        ref.invalidate(feedBootstrapStatusProvider);
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _openExternalUrl(
    BuildContext context,
    Uri uri,
    String errorMessage,
  ) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  Future<void> _openProjectGithub(BuildContext context) {
    return _openExternalUrl(
      context,
      _projectGithubUri,
      'Nao foi possivel abrir o GitHub do projeto.',
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionControllerProvider.notifier).logout();
    ref.read(profileControllerProvider.notifier).clear();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _handleMenuAction(
    _HeaderMenuAction action,
    BuildContext context,
    WidgetRef ref,
  ) async {
    switch (action) {
      case _HeaderMenuAction.settings:
        context.push('/student-hub');
        return;
      case _HeaderMenuAction.github:
        await _openProjectGithub(context);
        return;
      case _HeaderMenuAction.logout:
        await _logout(context, ref);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final profileAsync = ref.watch(profileControllerProvider);
    final bootstrapStatusAsync = ref.watch(feedBootstrapStatusProvider);

    if (!sessionState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const SizedBox.shrink();
    }

    final session = sessionState.session!;
    final feedAsync = ref.watch(personalizedFeedProvider);
    final profileBundle = profileAsync.valueOrNull;
    final avatarUrl = profileBundle?.profile.avatarUrl.isNotEmpty == true
        ? profileBundle!.profile.avatarUrl
        : (profileBundle?.user.avatarUrl ?? session.user.avatarUrl);
    final avatarLabel =
        profileBundle?.user.displayName ?? session.user.displayName;

    return HudScaffold(
      child: Column(
        children: [
          HudHeaderBar(
            title: 'Vibe_Studying',
            leading: [
              PopupMenuButton<_HeaderMenuAction>(
                tooltip: 'Menu',
                color: AppPalette.panel,
                surfaceTintColor: Colors.transparent,
                icon: const Icon(Icons.menu, color: AppPalette.foreground),
                onSelected: (action) => _handleMenuAction(action, context, ref),
                itemBuilder: (context) => [
                  PopupMenuItem<_HeaderMenuAction>(
                    value: _HeaderMenuAction.settings,
                    child: Text(
                      'Configuracao',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  PopupMenuItem<_HeaderMenuAction>(
                    value: _HeaderMenuAction.github,
                    child: Text(
                      'GitHub do projeto',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  PopupMenuItem<_HeaderMenuAction>(
                    value: _HeaderMenuAction.logout,
                    child: Text(
                      'Deslogar',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            actions: [
              _ProfilePhotoButton(
                imageUrl: avatarUrl,
                label: avatarLabel,
                onPressed: () => context.push('/student-hub'),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppPalette.neonPink,
              onRefresh: () async {
                ref.invalidate(personalizedFeedProvider);
                ref.invalidate(feedBootstrapStatusProvider);
                await ref
                    .read(profileControllerProvider.notifier)
                    .load(session.accessToken);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  bootstrapStatusAsync.when(
                    data: (status) => _BootstrapStatusBanner(status: status),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  feedAsync.when(
                    data: (page) {
                      if (page.items.isEmpty) {
                        final status = bootstrapStatusAsync.valueOrNull;
                        if (bootstrapStatusAsync.isLoading ||
                            (status?.isRunning ?? false)) {
                          return const _FeedGeneratingPlaceholder();
                        }

                        return HudPanel(
                          child: Text(
                            status?.hasFailed ?? false
                                ? 'Sua selecao ainda nao apareceu. Tente puxar para atualizar ou regenerar o bootstrap pelo menu.'
                                : 'Seu feed ainda esta ficando pronto. Continue explorando que as proximas lessons vao entrar aqui.',
                          ),
                        );
                      }

                      return Column(
                        children: page.items
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _FeedCard(item: item),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const _FeedGeneratingPlaceholder(),
                    error: (error, _) =>
                        HudPanel(child: Text('Falha ao carregar feed: $error')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedGeneratingPlaceholder extends StatelessWidget {
  const _FeedGeneratingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: HudPanel(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.32, end: 0.82),
                duration: Duration(milliseconds: 900 + (index * 140)),
                curve: Curves.easeInOut,
                builder: (context, opacity, _) {
                  return Opacity(
                    opacity: opacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppPalette.panelSoft,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 24,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppPalette.panelSoft,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppPalette.panelSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppPalette.panelSoft,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _BootstrapStatusBanner extends StatelessWidget {
  const _BootstrapStatusBanner({required this.status});

  final FeedBootstrapStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isDone || status.readyItems > 0) {
      return const SizedBox.shrink();
    }

    if (status.hasFailed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: HudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sua selecao personalizada ainda nao ficou pronta.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Nao conseguimos montar sua selecao personalizada agora. Enquanto isso, voce pode navegar pelo feed normalmente e tentar de novo mais tarde.',
                style: TextStyle(color: AppPalette.muted),
              ),
            ],
          ),
        ),
      );
    }

    if (!status.isRunning) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HudPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estamos montando sua selecao musical personalizada.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Voce ja pode usar o feed enquanto a IA prepara as proximas lessons.',
              style: TextStyle(color: AppPalette.muted),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status.targetItems == 0
                  ? null
                  : (status.readyItems / status.targetItems).clamp(0, 1),
              color: AppPalette.neonPink,
              backgroundColor: AppPalette.panelSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoButton extends StatelessWidget {
  const _ProfilePhotoButton({
    required this.imageUrl,
    required this.label,
    required this.onPressed,
  });

  final String imageUrl;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(' ')
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .map((item) => item[0].toUpperCase())
        .join();

    return Tooltip(
      message: 'Abrir perfil do aluno',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppPalette.neonCyan.withValues(alpha: 0.75),
            ),
            color: AppPalette.panel,
          ),
          child: ClipOval(
            child: imageUrl.trim().isEmpty
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
                    imageUrl,
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
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.coverImageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppPalette.panelSoft,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppPalette.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.isPersonalized)
                const HudTag(
                  label: 'personalized',
                  color: AppPalette.neonYellow,
                ),
              HudTag(label: item.contentType, color: AppPalette.neonPink),
              HudTag(label: item.difficulty, color: AppPalette.neonCyan),
              if (item.matchReason != null)
                HudTag(label: item.matchReason!, color: AppPalette.neonYellow),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(item.description),
          if (item.sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.sourceUrl,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.tags.map((tag) => HudTag(label: tag)).toList(),
            ),
          ],
          const SizedBox(height: 14),
          NeonButton(
            label: 'PRATICAR_AGORA',
            icon: Icons.graphic_eq,
            onPressed: () => context.push('/practice/${item.slug}'),
          ),
        ],
      ),
    );
  }
}
