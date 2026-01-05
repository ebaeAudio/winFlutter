import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional env loading from assets.
  // We skip this on Flutter Web because missing assets surface as noisy console
  // errors (404 + rejected promise). On web prefer `--dart-define`.
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: 'assets/env');
    } catch (_) {
      // Intentionally ignore (local env file is git-ignored).
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  await bootstrap(container);
  runApp(
      UncontrolledProviderScope(container: container, child: const AppRoot()));
}
