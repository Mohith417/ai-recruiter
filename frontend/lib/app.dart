import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recruitment_app/core/router/app_router.dart';
import 'package:recruitment_app/core/theme/app_theme.dart';
import 'package:recruitment_app/core/theme/theme_provider.dart';

class RecruitmentApp extends ConsumerWidget {
  const RecruitmentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'AI Recruiter',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
