import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
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
  List<String> _favoriteSongs = <String>[];
  List<String> _favoriteMovies = <String>[];
  List<String> _favoriteSeries = <String>[];
  List<String> _favoriteAnime = <String>[];
  List<String> _favoriteArtists = <String>[];
  List<String> _favoriteGenres = <String>[];
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

  List<String> _appendTag(
      TextEditingController controller, List<String> currentValues) {
    final rawValue = controller.text.trim();
    if (rawValue.isEmpty) {
      return currentValues;
    }

    final alreadyExists = currentValues
        .any((item) => item.toLowerCase() == rawValue.toLowerCase());
    controller.clear();
    if (alreadyExists) {
      return currentValues;
    }

    return <String>[...currentValues, rawValue];
  }

  void _addTag(TextEditingController controller, List<String> currentValues,
      ValueSetter<List<String>> updater) {
    final nextValues = _appendTag(controller, currentValues);
    if (nextValues == currentValues) {
      setState(() {});
      return;
    }

    setState(() => updater(nextValues));
  }

  void _commitPendingTags() {
    setState(() {
      _favoriteSongs = _appendTag(_songsController, _favoriteSongs);
      _favoriteMovies = _appendTag(_moviesController, _favoriteMovies);
      _favoriteSeries = _appendTag(_seriesController, _favoriteSeries);
      _favoriteAnime = _appendTag(_animeController, _favoriteAnime);
      _favoriteArtists = _appendTag(_artistsController, _favoriteArtists);
      _favoriteGenres = _appendTag(_genresController, _favoriteGenres);
    });
  }

  void _removeTag(String value, List<String> currentValues,
      ValueSetter<List<String>> updater) {
    setState(
        () => updater(currentValues.where((item) => item != value).toList()));
  }

  Future<void> _submit() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    _commitPendingTags();
    setState(() => _submitting = true);
    try {
      await ref.read(profileControllerProvider.notifier).completeOnboarding(
            accessToken: session.accessToken,
            englishLevel: _englishLevel,
            favoriteSongs: _favoriteSongs,
            favoriteMovies: _favoriteMovies,
            favoriteSeries: _favoriteSeries,
            favoriteAnime: _favoriteAnime,
            favoriteArtists: _favoriteArtists,
            favoriteGenres: _favoriteGenres,
          );
      if (!mounted) {
        return;
      }
      context.go('/feed');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HudScaffold(
      title: 'Qual a sua vibe?',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const HudPanel(
            child: Text(
                'Precisamos conhecer o aluno. Esse onboarding alimenta o ranking do feed personalizado e escolhe as frases que vao descer na pratica.'),
          ),
          const SizedBox(height: 16),
          HudPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _englishLevel,
                  items: const [
                    DropdownMenuItem(
                        value: 'beginner', child: Text('Beginner')),
                    DropdownMenuItem(
                        value: 'intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(
                        value: 'advanced', child: Text('Advanced')),
                  ],
                  onChanged: (value) =>
                      setState(() => _englishLevel = value ?? 'beginner'),
                  decoration:
                      const InputDecoration(labelText: 'Nivel de ingles'),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _songsController,
                  labelText: 'Musicas favoritas',
                  values: _favoriteSongs,
                  onAdd: () => _addTag(_songsController, _favoriteSongs,
                      (values) => _favoriteSongs = values),
                  onRemove: (value) => _removeTag(value, _favoriteSongs,
                      (values) => _favoriteSongs = values),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _moviesController,
                  labelText: 'Filmes favoritos',
                  values: _favoriteMovies,
                  onAdd: () => _addTag(_moviesController, _favoriteMovies,
                      (values) => _favoriteMovies = values),
                  onRemove: (value) => _removeTag(value, _favoriteMovies,
                      (values) => _favoriteMovies = values),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _seriesController,
                  labelText: 'Series favoritas',
                  values: _favoriteSeries,
                  onAdd: () => _addTag(_seriesController, _favoriteSeries,
                      (values) => _favoriteSeries = values),
                  onRemove: (value) => _removeTag(value, _favoriteSeries,
                      (values) => _favoriteSeries = values),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _animeController,
                  labelText: 'Animes favoritos',
                  values: _favoriteAnime,
                  onAdd: () => _addTag(_animeController, _favoriteAnime,
                      (values) => _favoriteAnime = values),
                  onRemove: (value) => _removeTag(value, _favoriteAnime,
                      (values) => _favoriteAnime = values),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _artistsController,
                  labelText: 'Artistas / bandas favoritas',
                  values: _favoriteArtists,
                  onAdd: () => _addTag(_artistsController, _favoriteArtists,
                      (values) => _favoriteArtists = values),
                  onRemove: (value) => _removeTag(value, _favoriteArtists,
                      (values) => _favoriteArtists = values),
                ),
                const SizedBox(height: 14),
                _PreferenceTagField(
                  controller: _genresController,
                  labelText: 'Generos favoritos',
                  values: _favoriteGenres,
                  onAdd: () => _addTag(_genresController, _favoriteGenres,
                      (values) => _favoriteGenres = values),
                  onRemove: (value) => _removeTag(value, _favoriteGenres,
                      (values) => _favoriteGenres = values),
                ),
                const SizedBox(height: 20),
                NeonButton(
                  label: _submitting
                      ? 'SINCRONIZANDO...'
                      : 'ATIVAR_FEED_PERSONALIZADO',
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

class _PreferenceTagField extends StatelessWidget {
  const _PreferenceTagField({
    required this.controller,
    required this.labelText,
    required this.values,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> values;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: 'Digite um item por vez',
            suffixIcon: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline,
                  color: AppPalette.neonCyan),
            ),
          ),
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (value) => InputChip(
                    label: Text(value),
                    onDeleted: () => onRemove(value),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    labelStyle: const TextStyle(
                        color: AppPalette.foreground,
                        fontWeight: FontWeight.w600),
                    backgroundColor: AppPalette.panelSoft,
                    side: const BorderSide(color: AppPalette.border),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
