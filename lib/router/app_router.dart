import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/main_shell.dart';
import '../features/chat/bloc/chat_bloc.dart';
import '../features/chat/chat_screen.dart';
import '../features/compare/compare_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/recognize/bloc/recognize_bloc.dart';
import '../features/recognize/recognize_screen.dart';
import '../features/result/result_screen.dart';
import '../features/scan/bloc/scan_bloc.dart';
import '../features/scan/scan_screen.dart';
import '../features/search/bloc/search_bloc.dart';
import '../features/search/search_screen.dart';
import '../features/settings/allergy_profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../services/storage_service.dart';

class AppRouter {
  final StorageService storageService;

  AppRouter({required this.storageService});

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            SplashScreen(storageService: storageService),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(storageService: storageService),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  HomeScreen(storageService: storageService),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => BlocProvider(
                create: (_) => SearchBloc(storageService: storageService),
                child: const SearchScreen(),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) =>
                  HistoryScreen(storageService: storageService),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  SettingsScreen(storageService: storageService),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => BlocProvider(
          create: (_) => ScanBloc(storageService: storageService),
          child: const ScanScreen(),
        ),
      ),
      GoRoute(
        path: '/recognize',
        builder: (context, state) => BlocProvider(
          create: (_) => RecognizeBloc(storageService: storageService),
          child: const RecognizeScreen(),
        ),
      ),
      GoRoute(
        path: '/result/:id',
        builder: (context, state) => ResultScreen(
          resultId: state.pathParameters['id']!,
          storageService: storageService,
        ),
      ),
      GoRoute(
        path: '/result/:id/chat',
        builder: (context, state) {
          final result =
              storageService.getResultById(state.pathParameters['id']!);
          if (result == null) {
            return const Scaffold(
              body: Center(child: Text('Hasil tidak ditemukan')),
            );
          }
          return BlocProvider(
            create: (_) => ChatBloc(
              storageService: storageService,
              result: result,
            ),
            child: ChatScreen(result: result),
          );
        },
      ),
      GoRoute(
        path: '/allergy-profile',
        builder: (context, state) =>
            AllergyProfileScreen(storageService: storageService),
      ),
      GoRoute(
        path: '/compare/:idA/:idB',
        builder: (context, state) => CompareScreen(
          idA: state.pathParameters['idA']!,
          idB: state.pathParameters['idB']!,
          storageService: storageService,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Halaman tidak ditemukan: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    ),
  );
}
