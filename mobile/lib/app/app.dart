import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibe_studying_mobile/app/theme.dart';
import 'package:vibe_studying_mobile/features/auth/auth_screens.dart';
import 'package:vibe_studying_mobile/features/feed/feed_screen.dart';
import 'package:vibe_studying_mobile/features/onboarding/onboarding_screen.dart';
import 'package:vibe_studying_mobile/features/practice/practice_screen.dart';

class VibeStudyingApp extends StatelessWidget {
  const VibeStudyingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(
          path: '/practice/:slug',
          builder: (context, state) => PracticeScreen(lessonSlug: state.pathParameters['slug']!),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Vibe Studying',
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
