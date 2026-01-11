import 'package:supabase_flutter/supabase_flutter.dart';

import 'assistant_heuristics.dart';
import 'assistant_models.dart';

class AssistantClient {
  const AssistantClient({
    required this.supabase,
    required this.enableRemote,
  });

  final SupabaseClient? supabase;
  final bool enableRemote;

  Future<AssistantTranslation> translate({
    required String transcript,
    required String baseDateYmd,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const AssistantTranslation(say: '', commands: []);
    }

    // Remote translation only when signed-in, configured, and not in demo mode.
    final session = supabase?.auth.currentSession;
    if (enableRemote && supabase != null && session != null) {
      try {
        final res = await supabase!.functions.invoke(
          'assistant',
          body: {
            'transcript': trimmed,
            'baseDateYmd': baseDateYmd,
          },
        );

        final data = res.data;
        if (data is Map) {
          return AssistantTranslation.fromJson(Map<String, Object?>.from(data));
        }
      } catch (_) {
        // Fall through to heuristics.
      }
    }

    return heuristicTranslate(transcript: trimmed, baseDateYmd: baseDateYmd);
  }
}
