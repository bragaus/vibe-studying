import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<void> _pickProfilePhoto(BuildContext context, WidgetRef ref) async {
    const imageGroup =
        XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);

    try {
      final file = await openFile(acceptedTypeGroups: const [imageGroup]);
      if (file == null) {
        return;
      }

      ref.read(profilePhotoPathProvider.notifier).state = file.path;
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nao foi possivel abrir o seletor de imagem.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionControllerProvider);
    final profilePhotoPath = ref.watch(profilePhotoPathProvider);

    if (!sessionState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const SizedBox.shrink();
    }

    final session = sessionState.session!;
    final feedAsync = ref.watch(personalizedFeedProvider);

    return HudScaffold(
      child: Column(
        children: [
          HudHeaderBar(
            title: 'Vibe_Studying',
            actions: [
              _ProfilePhotoButton(
                imagePath: profilePhotoPath,
                onPressed: () => _pickProfilePhoto(context, ref),
              ),
              const SizedBox(width: 8),
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
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppPalette.neonPink,
              onRefresh: () async {
                ref.invalidate(personalizedFeedProvider);
                await ref
                    .read(profileControllerProvider.notifier)
                    .load(session.accessToken);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  feedAsync.when(
                    data: (page) {
                      if (page.items.isEmpty) {
                        return const HudPanel(
                          child: Text(
                              'Nenhuma lesson publicada ainda. Crie conteúdo no backend professor para alimentar o feed.'),
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
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppPalette.neonPink)),
                    ),
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

class _ProfilePhotoButton extends StatelessWidget {
  const _ProfilePhotoButton({required this.imagePath, required this.onPressed});

  final String? imagePath;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Escolher foto do perfil',
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppPalette.neonCyan.withValues(alpha: 0.75)),
                color: AppPalette.panel,
              ),
              child: ClipOval(
                child: imagePath == null
                    ? const Icon(Icons.person, color: AppPalette.foreground)
                    : Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: AppPalette.foreground),
                      ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.neonPink,
                ),
                child: const Icon(Icons.add,
                    size: 12, color: AppPalette.background),
              ),
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
