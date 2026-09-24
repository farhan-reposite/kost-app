import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/db/database.dart';
import 'core/theme.dart';
import 'core/utils/photo_store.dart';
import 'data/repository.dart';
import 'features/home_shell.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await PhotoStore.init();

  // Load the saved appearance setting before the first frame so the app
  // never flashes the wrong theme on launch.
  final repo = KostRepository(AppDatabase.instance);
  final savedThemeMode = themeModeFromSetting(await repo.getThemeModeSetting());

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => savedThemeMode),
      ],
      child: const KostApp(),
    ),
  );
}

class KostApp extends ConsumerWidget {
  const KostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Kost Manager',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const HomeShell(),
    );
  }
}
