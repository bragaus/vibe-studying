import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _songsController = TextEditingController();
  final _moviesController = TextEditingController();
  final _seriesController = TextEditingController();
  final _animeController = TextEditingController();
  final _artistsController = TextEditingController();
  final _genresController = TextEditingController();
  String _englishLevel = 'beginner';
  bool _submitting = false;

  @override
  void dispose() {
    _songsController.dispose();
    _moviesController.dispose();
    _seriesController.dispose();
    _animeController.dispose();
    _artistsController.dispose();
    _genresController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(profileControllerProvider.notifier).completeOnboarding(
            accessToken: session.accessToken,
            englishLevel: _englishLevel,
            favoriteSongs: _splitCsv(_songsController.text),
            favoriteMovies: _splitCsv(_moviesController.text),
            favoriteSeries: _splitCsv(_seriesController.text),
            favoriteAnime: _splitCsv(_animeController.text),
            favoriteArtists: _splitCsv(_artistsController.text),
            favoriteGenres: _splitCsv(_genresController.text),
          );
      if (!mounted) {
        return;
      }
      context.go('/feed');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HudScaffold(
      title: 'TASTE_MAPPING',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const HudPanel(
            child: Text('Precisamos conhecer o aluno. Esse onboarding alimenta o ranking do feed personalizado e escolhe as frases que vao descer na pratica.'),
          ),
          const SizedBox(height: 16),
          HudPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _englishLevel,
                  items: const [
                    DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                    DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  ],
                  onChanged: (value) => setState(() => _englishLevel = value ?? 'beginner'),
                  decoration: const InputDecoration(labelText: 'Nivel de ingles'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _songsController,
                  decoration: const InputDecoration(labelText: 'Musicas favoritas (separadas por virgula)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _moviesController,
                  decoration: const InputDecoration(labelText: 'Filmes favoritos'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _seriesController,
                  decoration: const InputDecoration(labelText: 'Series favoritas'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _animeController,
                  decoration: const InputDecoration(labelText: 'Animes favoritos'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _artistsController,
                  decoration: const InputDecoration(labelText: 'Artistas / bandas favoritas'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _genresController,
                  decoration: const InputDecoration(labelText: 'Generos favoritos'),
                ),
                const SizedBox(height: 20),
                NeonButton(
                  label: _submitting ? 'SINCRONIZANDO...' : 'ATIVAR_FEED_PERSONALIZADO',
                  icon: Icons.auto_awesome,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
