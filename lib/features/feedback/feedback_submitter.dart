import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth.dart';
import '../../app/env.dart';
import '../../app/supabase.dart';
import 'feedback_models.dart';

abstract class FeedbackSubmitter {
  Future<void> submit(FeedbackDraft draft);
}

final feedbackSubmitterProvider = Provider<FeedbackSubmitter?>((ref) {
  final env = ref.watch(envProvider);
  final auth = ref.watch(authStateProvider).valueOrNull;
  final supabase = ref.watch(supabaseProvider);
  final client = supabase.client;

  if (env.demoMode) return null;
  if (client == null) return null;
  if (auth?.isSignedIn != true) return null;
  if (auth?.isDemo == true) return null;

  return SupabaseFeedbackSubmitter(client);
});

class SupabaseFeedbackSubmitter implements FeedbackSubmitter {
  SupabaseFeedbackSubmitter(this._client);

  final SupabaseClient _client;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  Map<String, Object?> _buildContext() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return <String, Object?>{
      'appVersion': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: 'unknown',
      ),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'locale': locale.toLanguageTag(),
      'timestampUtc': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<void> submit(FeedbackDraft draft) async {
    final uid = _requireUserId();

    final description = draft.description.trim();
    final details = draft.details?.trim();
    final cleanedDetails = (details == null || details.isEmpty) ? null : details;

    await _client.from('user_feedback').insert({
      'user_id': uid,
      'kind': draft.kind.dbValue,
      'description': description,
      'details': cleanedDetails,
      'entry_point': draft.entryPoint,
      'context': draft.includeContext ? _buildContext() : null,
    });
  }
}

