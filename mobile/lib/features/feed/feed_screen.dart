import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionControllerProvider);
    final profileState = ref.watch(profileControllerProvider);

    if (!sessionState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const SizedBox.shrink();
    }

    final session = sessionState.session!;
    final feedAsync = ref.watch(personalizedFeedProvider);

    return HudScaffold(
      title: 'PERSONAL_FEED',
      actions: [
        IconButton(
          onPressed: () async {
            await ref.read(sessionControllerProvider.notifier).logout();
            ref.read(profileControllerProvider.notifier).clear();
            if (context.mounted) {
              context.go('/login');
            }
          },
          icon: const Icon(Icons.logout, color: AppPalette.foreground),
        ),
      ],
      child: RefreshIndicator(
        color: AppPalette.neonPink,
        onRefresh: () async {
          ref.invalidate(personalizedFeedProvider);
          await ref.read(profileControllerProvider.notifier).load(session.accessToken);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            HudPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bem-vindo, ${session.user.displayName}.', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    profileState.valueOrNull == null
                        ? 'Carregando preferências do aluno...'
                        : 'Seu feed agora prioriza música, filmes, séries e animes alinhados com o seu onboarding.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            feedAsync.when(
              data: (page) {
                if (page.items.isEmpty) {
                  return const HudPanel(child: Text('Nenhuma lesson publicada ainda. Crie conteúdo no backend professor para alimentar o feed.'));
                }

                return Column(
                  children: page.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeedCard(item: item),
                  )).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppPalette.neonPink)),
              ),
              error: (error, _) => HudPanel(child: Text('Falha ao carregar feed: $error')),
            ),
          ],
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HudTag(label: item.contentType, color: AppPalette.neonPink),
              HudTag(label: item.difficulty, color: AppPalette.neonCyan),
              if (item.matchReason != null) HudTag(label: item.matchReason!, color: AppPalette.neonYellow),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(item.description),
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
            onPressed: () => context.go('/practice/${item.slug}'),
          ),
        ],
      ),
    );
  }
}
