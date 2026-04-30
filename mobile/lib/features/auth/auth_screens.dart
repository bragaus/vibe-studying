import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(apiBaseUrlControllerProvider.notifier).load();
    final session =
        await ref.read(sessionControllerProvider.notifier).bootstrap();
    if (!mounted) {
      return;
    }

    if (session == null) {
      context.go('/login');
      return;
    }

    await _routeAfterAuth(session);
  }

  Future<void> _routeAfterAuth(AuthSession session) async {
    try {
      final profile = await ref
          .read(profileControllerProvider.notifier)
          .load(session.accessToken);
      if (!mounted) {
        return;
      }

      context.go(profile.profile.onboardingCompleted ? '/feed' : '/onboarding');
    } catch (_) {
      if (!mounted) {
        return;
      }
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HudScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VIBE_STUDYING',
                style: TextStyle(
                    fontSize: 28,
                    color: AppPalette.foreground,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 18),
            CircularProgressIndicator(color: AppPalette.neonPink),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBackendUrlDialog(BuildContext context, WidgetRef ref) async {
  final currentBaseUrl = ref.read(apiBaseUrlControllerProvider);
  final controller = TextEditingController(text: currentBaseUrl);

  Future<void> save() async {
    await ref
        .read(apiBaseUrlControllerProvider.notifier)
        .update(controller.text);
    await ref.read(sessionControllerProvider.notifier).logout();
    ref.read(profileControllerProvider.notifier).clear();
  }

  Future<void> reset() async {
    await ref.read(apiBaseUrlControllerProvider.notifier).reset();
    await ref.read(sessionControllerProvider.notifier).logout();
    ref.read(profileControllerProvider.notifier).clear();
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppPalette.panel,
      title: const Text('Backend URL'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'API base URL',
                hintText: 'http://192.168.0.10:8000/api',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pode ser localhost, IP da rede ou dominio. Se faltar /api, o app completa automaticamente.',
              style: TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            await reset();
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Backend padrao restaurado: ${ref.read(apiBaseUrlControllerProvider)}',
                  ),
                ),
              );
            }
          },
          child: const Text('Padrao'),
        ),
        FilledButton(
          onPressed: () async {
            await save();
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Backend atualizado para ${ref.read(apiBaseUrlControllerProvider)}',
                  ),
                ),
              );
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );

  controller.dispose();
}

class _BackendConfigButton extends ConsumerWidget {
  const _BackendConfigButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Configurar backend',
      onPressed: () => _showBackendUrlDialog(context, ref),
      icon: const Icon(Icons.dns_outlined, color: AppPalette.foreground),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final session = await ref.read(sessionControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);
    if (session == null) {
      final error = ref.read(sessionControllerProvider).errorMessage ??
          'Falha ao autenticar.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    await _routeAfterAuth(session);
  }

  Future<void> _routeAfterAuth(AuthSession session) async {
    try {
      final profile = await ref
          .read(profileControllerProvider.notifier)
          .load(session.accessToken);
      if (!mounted) {
        return;
      }
      context.go(profile.profile.onboardingCompleted ? '/feed' : '/onboarding');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parseApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = ref.watch(apiBaseUrlControllerProvider);

    return HudScaffold(
      title: 'Entrar na vibe',
      actions: const [_BackendConfigButton()],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: HudPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Acesse o hub do aluno e sincronize seu feed personalizado.'),
                  const SizedBox(height: 8),
                  Text(
                    'Backend atual: $apiBaseUrl',
                    style:
                        const TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                  ),
                  const SizedBox(height: 20),
                  NeonButton(
                    label: _submitting ? 'PROCESSANDO...' : 'ENTRAR_NA_VIBE',
                    icon: Icons.login,
                    onPressed: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Nao tem conta? Inicialize seu cadastro'),
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final session = await ref.read(sessionControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );
    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);
    if (session == null) {
      final error = ref.read(sessionControllerProvider).errorMessage ??
          'Falha ao cadastrar.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    try {
      await ref
          .read(profileControllerProvider.notifier)
          .load(session.accessToken);
      if (!mounted) {
        return;
      }
      context.go('/onboarding');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parseApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBaseUrl = ref.watch(apiBaseUrlControllerProvider);

    return HudScaffold(
      title: 'INITIALIZE_USER',
      actions: const [_BackendConfigButton()],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: HudPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Crie seu perfil de aluno para montar um feed baseado nos seus gostos.'),
                  const SizedBox(height: 8),
                  Text(
                    'Backend atual: $apiBaseUrl',
                    style:
                        const TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 14),
                  TextField(
                      controller: _lastNameController,
                      decoration:
                          const InputDecoration(labelText: 'Sobrenome')),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      helperText: 'Use pelo menos 8 caracteres.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: _submitting ? 'CRIANDO...' : 'CRIAR_CONTA',
                    icon: Icons.person_add_alt_1,
                    onPressed: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Ja possui acesso? Iniciar sessao'),
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
