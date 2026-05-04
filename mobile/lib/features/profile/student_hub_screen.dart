import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

enum _PreferenceField {
  favoriteSongs,
  favoriteMovies,
  favoriteSeries,
  favoriteAnime,
  favoriteArtists,
  favoriteGenres,
}

class _PreferenceConfig {
  const _PreferenceConfig({
    required this.field,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final _PreferenceField field;
  final String label;
  final String hint;
  final IconData icon;
}

const List<_PreferenceConfig> _preferenceConfigs = [
  _PreferenceConfig(
    field: _PreferenceField.favoriteSongs,
    label: 'Musicas favoritas',
    hint: 'Uma musica por vez. Ex.: Numb, Yellow',
    icon: Icons.music_note_outlined,
  ),
  _PreferenceConfig(
    field: _PreferenceField.favoriteMovies,
    label: 'Filmes favoritos',
    hint: 'Ex.: Interstellar, Your Name',
    icon: Icons.movie_outlined,
  ),
  _PreferenceConfig(
    field: _PreferenceField.favoriteSeries,
    label: 'Series favoritas',
    hint: 'Ex.: Dark, Arcane',
    icon: Icons.tv_outlined,
  ),
  _PreferenceConfig(
    field: _PreferenceField.favoriteAnime,
    label: 'Animes favoritos',
    hint: 'Ex.: Naruto, One Piece',
    icon: Icons.auto_awesome_outlined,
  ),
  _PreferenceConfig(
    field: _PreferenceField.favoriteArtists,
    label: 'Artistas e bandas',
    hint: 'Ex.: Linkin Park, YOASOBI',
    icon: Icons.album_outlined,
  ),
  _PreferenceConfig(
    field: _PreferenceField.favoriteGenres,
    label: 'Generos favoritos',
    hint: 'Ex.: rock, sci-fi, romance',
    icon: Icons.local_offer_outlined,
  ),
];

class StudentHubScreen extends ConsumerStatefulWidget {
  const StudentHubScreen({super.key});

  @override
  ConsumerState<StudentHubScreen> createState() => _StudentHubScreenState();
}

class _StudentHubScreenState extends ConsumerState<StudentHubScreen> {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _newPostController = TextEditingController();
  final TextEditingController _editingPostController = TextEditingController();

  final Map<_PreferenceField, TextEditingController> _tagControllers = {
    for (final config in _preferenceConfigs)
      config.field: TextEditingController(),
  };

  final Map<int, TextEditingController> _commentControllers = {};

  ProfileBundle? _bundle;
  List<StudentPost> _posts = const [];
  String _englishLevel = 'beginner';
  List<String> _favoriteSongs = <String>[];
  List<String> _favoriteMovies = <String>[];
  List<String> _favoriteSeries = <String>[];
  List<String> _favoriteAnime = <String>[];
  List<String> _favoriteArtists = <String>[];
  List<String> _favoriteGenres = <String>[];
  String? _errorMessage;
  bool _loading = true;
  bool _savingProfile = false;
  bool _avatarBusy = false;
  bool _publishingPost = false;
  int? _editingPostId;
  int? _busyPostId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadHub());
  }

  @override
  void dispose() {
    _bioController.dispose();
    _newPostController.dispose();
    _editingPostController.dispose();
    for (final controller in _tagControllers.values) {
      controller.dispose();
    }
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _commentControllerFor(int postId) {
    return _commentControllers.putIfAbsent(postId, TextEditingController.new);
  }

  Future<void> _loadHub({bool showLoader = true}) async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      final results = await Future.wait<dynamic>([
        ref.read(profileControllerProvider.notifier).load(session.accessToken),
        profileRepository.getStudentPosts(session.accessToken),
      ]);
      if (!mounted) {
        return;
      }

      final bundle = results[0] as ProfileBundle;
      final posts = results[1] as List<StudentPost>;
      setState(() {
        _bundle = bundle;
        _posts = posts;
        _errorMessage = null;
        _loading = false;
        _syncFieldsFromProfile(bundle.profile);
      });
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

  void _syncFieldsFromProfile(StudentProfile profile) {
    _englishLevel = profile.englishLevel;
    _bioController.text = profile.bio;
    _favoriteSongs = List<String>.from(profile.favoriteSongs);
    _favoriteMovies = List<String>.from(profile.favoriteMovies);
    _favoriteSeries = List<String>.from(profile.favoriteSeries);
    _favoriteAnime = List<String>.from(profile.favoriteAnime);
    _favoriteArtists = List<String>.from(profile.favoriteArtists);
    _favoriteGenres = List<String>.from(profile.favoriteGenres);
  }

  List<String> _valuesFor(_PreferenceField field) {
    switch (field) {
      case _PreferenceField.favoriteSongs:
        return _favoriteSongs;
      case _PreferenceField.favoriteMovies:
        return _favoriteMovies;
      case _PreferenceField.favoriteSeries:
        return _favoriteSeries;
      case _PreferenceField.favoriteAnime:
        return _favoriteAnime;
      case _PreferenceField.favoriteArtists:
        return _favoriteArtists;
      case _PreferenceField.favoriteGenres:
        return _favoriteGenres;
    }
  }

  void _replaceValuesFor(_PreferenceField field, List<String> nextValues) {
    switch (field) {
      case _PreferenceField.favoriteSongs:
        _favoriteSongs = nextValues;
        break;
      case _PreferenceField.favoriteMovies:
        _favoriteMovies = nextValues;
        break;
      case _PreferenceField.favoriteSeries:
        _favoriteSeries = nextValues;
        break;
      case _PreferenceField.favoriteAnime:
        _favoriteAnime = nextValues;
        break;
      case _PreferenceField.favoriteArtists:
        _favoriteArtists = nextValues;
        break;
      case _PreferenceField.favoriteGenres:
        _favoriteGenres = nextValues;
        break;
    }
  }

  void _addTag(_PreferenceField field) {
    final controller = _tagControllers[field]!;
    final rawValue = controller.text.trim();
    if (rawValue.isEmpty) {
      return;
    }

    final currentValues = _valuesFor(field);
    final alreadyExists = currentValues
        .any((item) => item.toLowerCase() == rawValue.toLowerCase());
    controller.clear();
    if (alreadyExists) {
      setState(() {});
      return;
    }

    setState(() {
      _replaceValuesFor(field, [...currentValues, rawValue]);
    });
  }

  void _removeTag(_PreferenceField field, String value) {
    setState(() {
      _replaceValuesFor(
        field,
        _valuesFor(field).where((item) => item != value).toList(),
      );
    });
  }

  void _commitPendingTags() {
    for (final config in _preferenceConfigs) {
      final controller = _tagControllers[config.field]!;
      final pendingValue = controller.text.trim();
      if (pendingValue.isEmpty) {
        continue;
      }
      final currentValues = _valuesFor(config.field);
      final alreadyExists = currentValues
          .any((item) => item.toLowerCase() == pendingValue.toLowerCase());
      controller.clear();
      if (!alreadyExists) {
        _replaceValuesFor(config.field, [...currentValues, pendingValue]);
      }
    }
  }

  Future<void> _saveProfile() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    setState(() {
      _savingProfile = true;
      _commitPendingTags();
    });

    try {
      final bundle = await ref.read(profileRepositoryProvider).updateMyProfile(
            accessToken: session.accessToken,
            englishLevel: _englishLevel,
            bio: _bioController.text.trim(),
            favoriteSongs: _favoriteSongs,
            favoriteMovies: _favoriteMovies,
            favoriteSeries: _favoriteSeries,
            favoriteAnime: _favoriteAnime,
            favoriteArtists: _favoriteArtists,
            favoriteGenres: _favoriteGenres,
          );

      ref.read(profileControllerProvider.notifier).setBundle(bundle);
      ref.invalidate(personalizedFeedProvider);
      ref.invalidate(feedBootstrapStatusProvider);
      try {
        await ref.read(feedRepositoryProvider).startFeedBootstrap(
              session.accessToken,
            );
      } catch (_) {
        // Existing feed still works even if regeneration cannot start now.
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _bundle = bundle;
        _syncFieldsFromProfile(bundle.profile);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil sincronizado. O feed sera recalculado.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    const imageGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [imageGroup]);
    if (file == null) {
      return;
    }

    setState(() => _avatarBusy = true);
    try {
      final bundle = await ref.read(profileRepositoryProvider).uploadAvatar(
            accessToken: session.accessToken,
            bytes: await file.readAsBytes(),
            fileName: file.name.isEmpty ? 'avatar.png' : file.name,
          );
      ref.read(profileControllerProvider.notifier).setBundle(bundle);
      if (!mounted) {
        return;
      }
      setState(() => _bundle = bundle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar atualizado.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _avatarBusy = false);
      }
    }
  }

  Future<void> _deleteAvatar() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    setState(() => _avatarBusy = true);
    try {
      final bundle = await ref.read(profileRepositoryProvider).deleteAvatar(
            session.accessToken,
          );
      ref.read(profileControllerProvider.notifier).setBundle(bundle);
      if (!mounted) {
        return;
      }
      setState(() => _bundle = bundle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removido.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _avatarBusy = false);
      }
    }
  }

  Future<void> _publishPost() async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    final content = _newPostController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo antes de publicar.')),
      );
      return;
    }

    setState(() => _publishingPost = true);
    try {
      final post = await ref.read(profileRepositoryProvider).createStudentPost(
            accessToken: session.accessToken,
            content: content,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _newPostController.clear();
        _posts = [post, ..._posts.where((item) => item.id != post.id)];
      });
      await _refreshProfileSnapshot(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _publishingPost = false);
      }
    }
  }

  Future<void> _updatePost(StudentPost post) async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    final content = _editingPostController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O post nao pode ficar vazio.')),
      );
      return;
    }

    setState(() => _busyPostId = post.id);
    try {
      final updatedPost =
          await ref.read(profileRepositoryProvider).updateStudentPost(
                accessToken: session.accessToken,
                postId: post.id,
                content: content,
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _replacePost(updatedPost);
        _editingPostId = null;
        _editingPostController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPostId = null);
      }
    }
  }

  Future<void> _deletePost(StudentPost post) async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    setState(() => _busyPostId = post.id);
    try {
      await ref.read(profileRepositoryProvider).deleteStudentPost(
            accessToken: session.accessToken,
            postId: post.id,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = _posts.where((item) => item.id != post.id).toList();
        _commentControllers.remove(post.id)?.dispose();
      });
      await _refreshProfileSnapshot(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPostId = null);
      }
    }
  }

  Future<void> _toggleEnergy(StudentPost post) async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    setState(() => _busyPostId = post.id);
    try {
      final repository = ref.read(profileRepositoryProvider);
      final updatedPost = post.energizedByMe
          ? await repository.removeEnergyFromStudentPost(
              accessToken: session.accessToken,
              postId: post.id,
            )
          : await repository.energizeStudentPost(
              accessToken: session.accessToken,
              postId: post.id,
            );
      if (!mounted) {
        return;
      }
      setState(() => _replacePost(updatedPost));
      await _refreshProfileSnapshot(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPostId = null);
      }
    }
  }

  Future<void> _commentOnPost(StudentPost post) async {
    final session = ref.read(sessionControllerProvider).session;
    if (session == null) {
      context.go('/login');
      return;
    }

    final controller = _commentControllerFor(post.id);
    final content = controller.text.trim();
    if (content.isEmpty) {
      return;
    }

    setState(() => _busyPostId = post.id);
    try {
      final updatedPost =
          await ref.read(profileRepositoryProvider).createStudentPostComment(
                accessToken: session.accessToken,
                postId: post.id,
                content: content,
              );
      if (!mounted) {
        return;
      }
      setState(() {
        controller.clear();
        _replacePost(updatedPost);
      });
      await _refreshProfileSnapshot(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPostId = null);
      }
    }
  }

  Future<void> _refreshProfileSnapshot(String accessToken) async {
    try {
      final bundle = await ref.read(profileControllerProvider.notifier).load(
            accessToken,
          );
      if (!mounted) {
        return;
      }
      setState(() => _bundle = bundle);
    } catch (_) {
      return;
    }
  }

  void _replacePost(StudentPost updatedPost) {
    _posts = _posts
        .map((item) => item.id == updatedPost.id ? updatedPost : item)
        .toList();
  }

  Future<void> _logout() async {
    await ref.read(sessionControllerProvider.notifier).logout();
    ref.read(profileControllerProvider.notifier).clear();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  String _formatDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final bundle = _bundle;
    final profile = bundle?.profile;
    final user = bundle?.user ?? session?.user;

    return HudScaffold(
      title: 'VIBERSTUDANT',
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
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: AppPalette.foreground),
        ),
      ],
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.neonPink),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: HudPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Falha ao sincronizar o hub do aluno.',
                            style: TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppPalette.muted),
                          ),
                          const SizedBox(height: 16),
                          NeonButton(
                            label: 'TENTAR_NOVAMENTE',
                            icon: Icons.refresh,
                            onPressed: () => _loadHub(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppPalette.neonPink,
                  onRefresh: () => _loadHub(showLoader: false),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      HudPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _StudentAvatar(
                                  imageUrl: profile?.avatarUrl ??
                                      user?.avatarUrl ??
                                      '',
                                  label: user?.displayName ?? 'Student',
                                  size: 84,
                                ),
                                SizedBox(
                                  width: 260,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.displayName ?? 'Student',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        user?.email ?? '',
                                        style: const TextStyle(
                                          color: AppPalette.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          HudTag(
                                            label: user?.role ?? 'student',
                                            color: AppPalette.neonCyan,
                                          ),
                                          HudTag(
                                            label:
                                                'posts ${profile?.postsCount ?? 0}',
                                            color: AppPalette.neonPink,
                                          ),
                                          HudTag(
                                            label:
                                                'energia ${profile?.energyReceivedCount ?? 0}',
                                            color: AppPalette.neonYellow,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              profile?.bio.trim().isNotEmpty == true
                                  ? profile!.bio
                                  : 'Sua identidade sincronizada com a web aparece aqui. Atualize musicas, filmes, series e animes para remodelar o feed.',
                              style:
                                  const TextStyle(color: AppPalette.foreground),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: NeonButton(
                                    label: _avatarBusy
                                        ? 'ENVIANDO_FOTO...'
                                        : 'TROCAR_FOTO',
                                    icon: Icons.photo_camera_outlined,
                                    onPressed: _avatarBusy
                                        ? null
                                        : _pickAndUploadAvatar,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: NeonButton(
                                    label: 'REMOVER_FOTO',
                                    icon: Icons.delete_outline,
                                    isPrimary: false,
                                    onPressed: _avatarBusy ||
                                            (profile?.avatarUrl
                                                    .trim()
                                                    .isEmpty ??
                                                true)
                                        ? null
                                        : _deleteAvatar,
                                  ),
                                ),
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
                            Text(
                              'Sincronizar identidade e feed',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Essa tela usa o mesmo perfil do /viberstudant da web. Tudo o que voce mudar aqui volta para o backend e reaparece nos dois lados.',
                              style: TextStyle(color: AppPalette.muted),
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              initialValue: _englishLevel,
                              items: const [
                                DropdownMenuItem(
                                  value: 'beginner',
                                  child: Text('Beginner'),
                                ),
                                DropdownMenuItem(
                                  value: 'intermediate',
                                  child: Text('Intermediate'),
                                ),
                                DropdownMenuItem(
                                  value: 'advanced',
                                  child: Text('Advanced'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _englishLevel = value ?? 'beginner',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Nivel de ingles',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _bioController,
                              maxLength: 280,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Bio',
                                hintText:
                                    'Descreva sua vibe: estilos, universos e o que mais prende sua atencao.',
                              ),
                            ),
                            const SizedBox(height: 18),
                            for (final config in _preferenceConfigs) ...[
                              _PreferenceEditor(
                                controller: _tagControllers[config.field]!,
                                label: config.label,
                                hint: config.hint,
                                icon: config.icon,
                                values: _valuesFor(config.field),
                                onAdd: () => _addTag(config.field),
                                onRemove: (value) =>
                                    _removeTag(config.field, value),
                              ),
                              const SizedBox(height: 14),
                            ],
                            NeonButton(
                              label: _savingProfile
                                  ? 'SALVANDO_IDENTIDADE...'
                                  : 'SALVAR_IDENTIDADE',
                              icon: Icons.save_outlined,
                              onPressed: _savingProfile ? null : _saveProfile,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      HudPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mural de energia',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Publique referencias, sensacoes e recortes da semana. O mural acompanha o mesmo backend da web.',
                              style: TextStyle(color: AppPalette.muted),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _newPostController,
                              maxLines: 4,
                              maxLength: 1200,
                              decoration: const InputDecoration(
                                labelText: 'Novo post',
                                hintText:
                                    'Ex.: Hoje eu entrei em modo foco total com trilha sci-fi e opening de anime.',
                              ),
                            ),
                            NeonButton(
                              label: _publishingPost
                                  ? 'PUBLICANDO...'
                                  : 'PUBLICAR_NO_MURAL',
                              icon: Icons.add_comment_outlined,
                              onPressed: _publishingPost ? null : _publishPost,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      HudPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Posts sincronizados',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_posts.length} posts carregados',
                              style: const TextStyle(color: AppPalette.muted),
                            ),
                            const SizedBox(height: 14),
                            if (_posts.isEmpty)
                              const Text(
                                'Ainda nao ha posts no mural. Publique o primeiro sinal da sua vibe.',
                                style: TextStyle(color: AppPalette.muted),
                              ),
                            for (final post in _posts) ...[
                              _StudentPostCard(
                                post: post,
                                busy: _busyPostId == post.id,
                                isEditing: _editingPostId == post.id,
                                editingController: _editingPostController,
                                commentController:
                                    _commentControllerFor(post.id),
                                formatDateTime: _formatDateTime,
                                onStartEditing: () {
                                  setState(() {
                                    _editingPostId = post.id;
                                    _editingPostController.text = post.content;
                                  });
                                },
                                onCancelEditing: () {
                                  setState(() {
                                    _editingPostId = null;
                                    _editingPostController.clear();
                                  });
                                },
                                onSaveEditing: () => _updatePost(post),
                                onDelete: () => _deletePost(post),
                                onToggleEnergy: () => _toggleEnergy(post),
                                onComment: () => _commentOnPost(post),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.imageUrl,
    required this.label,
    this.size = 42,
  });

  final String imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(' ')
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .map((item) => item[0].toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.neonCyan.withValues(alpha: 0.7)),
        color: AppPalette.panelSoft,
      ),
      child: ClipOval(
        child: imageUrl.trim().isEmpty
            ? Center(
                child: Text(
                  initials.isEmpty ? 'VS' : initials,
                  style: TextStyle(
                    color: AppPalette.foreground,
                    fontSize: size * 0.26,
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
                    style: TextStyle(
                      color: AppPalette.foreground,
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PreferenceEditor extends StatelessWidget {
  const _PreferenceEditor({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.values,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
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
          onSubmitted: (_) => onAdd(),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: AppPalette.neonCyan),
            suffixIcon: IconButton(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppPalette.neonPink,
              ),
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
                      fontWeight: FontWeight.w600,
                    ),
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

class _StudentPostCard extends StatelessWidget {
  const _StudentPostCard({
    required this.post,
    required this.busy,
    required this.isEditing,
    required this.editingController,
    required this.commentController,
    required this.formatDateTime,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSaveEditing,
    required this.onDelete,
    required this.onToggleEnergy,
    required this.onComment,
  });

  final StudentPost post;
  final bool busy;
  final bool isEditing;
  final TextEditingController editingController;
  final TextEditingController commentController;
  final String Function(String) formatDateTime;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final VoidCallback onSaveEditing;
  final VoidCallback onDelete;
  final VoidCallback onToggleEnergy;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentAvatar(
                imageUrl: post.author.avatarUrl,
                label: post.author.displayName,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.author.role} • ${formatDateTime(post.createdAt)}',
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isEditing)
            Column(
              children: [
                TextField(
                  controller: editingController,
                  maxLines: 4,
                  maxLength: 1200,
                  decoration: const InputDecoration(labelText: 'Editar post'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: NeonButton(
                        label: busy ? 'SALVANDO...' : 'SALVAR_POST',
                        icon: Icons.save_outlined,
                        onPressed: busy ? null : onSaveEditing,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeonButton(
                        label: 'CANCELAR',
                        icon: Icons.close,
                        isPrimary: false,
                        onPressed: busy ? null : onCancelEditing,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(post.content),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onToggleEnergy,
                icon: Icon(
                  post.energizedByMe ? Icons.bolt : Icons.bolt_outlined,
                  color: post.energizedByMe
                      ? AppPalette.neonPink
                      : AppPalette.foreground,
                ),
                label: Text('Energia ${post.energyCount}'),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text('Comentarios ${post.commentCount}'),
              ),
              if (post.isOwner && !isEditing)
                OutlinedButton.icon(
                  onPressed: busy ? null : onStartEditing,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              if (post.isOwner && !isEditing)
                OutlinedButton.icon(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
            ],
          ),
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final comment in post.comments) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${comment.author.displayName} • ${formatDateTime(comment.createdAt)}',
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(comment.content),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            onSubmitted: (_) => onComment(),
            decoration: InputDecoration(
              labelText: 'Adicionar comentario',
              suffixIcon: IconButton(
                onPressed: busy ? null : onComment,
                icon: const Icon(Icons.send_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
