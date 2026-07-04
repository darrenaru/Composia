import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/storage_service.dart';

class ComposiaApp extends StatelessWidget {
  final StorageService storageService;

  const ComposiaApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(storageService: storageService);

    return MaterialApp.router(
      title: 'Composia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter.router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
