import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final envProvider = Provider<Env>((ref) => Env.fromSources());

class Env {
  Env({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.demoMode,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool demoMode;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Env fromSources() {
    // Prefer compile-time defines, then dotenv.
    const urlDefine = String.fromEnvironment('SUPABASE_URL');
    const keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    const demoDefine = String.fromEnvironment('DEMO_MODE');

    String dotenvGet(String key) {
      try {
        return dotenv.maybeGet(key) ?? '';
      } catch (_) {
        // flutter_dotenv throws NotInitializedError if no dotenv file was loaded.
        return '';
      }
    }

    final supabaseUrl =
        urlDefine.isNotEmpty ? urlDefine : dotenvGet('SUPABASE_URL');
    final supabaseAnonKey =
        keyDefine.isNotEmpty ? keyDefine : dotenvGet('SUPABASE_ANON_KEY');

    final demoRaw = demoDefine.isNotEmpty
        ? demoDefine
        : (dotenvGet('DEMO_MODE').isEmpty ? 'false' : dotenvGet('DEMO_MODE'));
    final demoMode = demoRaw.toLowerCase().trim() == 'true';

    return Env(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      demoMode: demoMode,
    );
  }
}
