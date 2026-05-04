import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/core/models.dart';
import 'package:vibe_studying_mobile/core/repositories.dart';
import 'package:vibe_studying_mobile/core/state.dart';
import 'package:vibe_studying_mobile/shared/hud.dart';

Future<String> _resolvePostAuthRoute(
  WidgetRef ref,
  AuthSession session,
  ProfileBundle bundle,
) async {
  if (!bundle.profile.onboardingCompleted) {
    return '/onboarding';
  }

  try {
    final status = await ref
        .read(feedRepositoryProvider)
        .getFeedBootstrapStatus(session.accessToken);
    if (status.isDone || status.readyItems > 0) {
      return '/feed';
    }
    return '/feed/bootstrap';
  } catch (_) {
    return '/feed/bootstrap';
  }
}

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
      final bundle = await ref
          .read(profileControllerProvider.notifier)
          .load(session.accessToken);
      if (!mounted) {
        return;
      }

      context.go(await _resolvePostAuthRoute(ref, session, bundle));
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _showPassword = false;

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
      final bundle = await ref
          .read(profileControllerProvider.notifier)
          .load(session.accessToken);
      if (!mounted) {
        return;
      }
      context.go(await _resolvePostAuthRoute(ref, session, bundle));
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
    return HudScaffold(
      title: 'Entrar na vibe',
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
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
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
  bool _showPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(passwordError)));
      return;
    }

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

  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'A senha precisa ter pelo menos 8 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'A senha precisa ter pelo menos 1 letra maiuscula.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return HudScaffold(
      title: 'INITIALIZE_USER',
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
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText:
                          'Use pelo menos 8 caracteres e 1 letra maiuscula.',
                      helperMaxLines: 3,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
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
