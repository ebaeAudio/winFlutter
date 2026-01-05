import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeSettings = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'Win the Year',
      theme: themeFor(themeSettings.palette, Brightness.light),
      darkTheme: themeFor(themeSettings.palette, Brightness.dark),
      themeMode: themeSettings.themeMode,
      routerConfig: router,
    );
  }
}
