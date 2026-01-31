import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';

@immutable
class PrdGenerationResult {
  const PrdGenerationResult({
    required this.path,
    required this.url,
    required this.sha,
  });

  final String path;
  final String url;
  final String sha;

  factory PrdGenerationResult.fromJson(Map<String, Object?> json) {
    return PrdGenerationResult(
      path: (json['path'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      sha: (json['sha'] as String?) ?? '',
    );
  }

  bool get isValid => path.trim().isNotEmpty && url.trim().isNotEmpty;
}

final prdGenerationControllerProvider = AutoDisposeAsyncNotifierProvider<
    PrdGenerationController, PrdGenerationResult?>(
  PrdGenerationController.new,
);

class PrdGenerationController extends AutoDisposeAsyncNotifier<PrdGenerationResult?> {
  @override
  Future<PrdGenerationResult?> build() async => null;

  Future<PrdGenerationResult> generate({
    required String title,
    required String description,
  }) async {
    final env = ref.read(envProvider);
    final supabase = ref.read(supabaseProvider);
    final client = supabase.client;

    if (env.demoMode || client == null) {
      throw StateError('PRD generation is not configured (demo mode or missing Supabase).');
    }
    if (client.auth.currentSession == null) {
      throw StateError('You must be signed in to generate a PRD.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await client.functions.invoke(
        'generate-prd',
        body: {
          'title': title.trim(),
          'description': description.trim(),
        },
      );

      final data = res.data;
      if (data is Map) {
        final parsed = PrdGenerationResult.fromJson(Map<String, Object?>.from(data));
        if (!parsed.isValid) {
          throw StateError('PRD generation returned an invalid response.');
        }
        return parsed;
      }
      throw StateError('PRD generation returned an unexpected response.');
    });

    final out = state.valueOrNull;
    if (out == null) throw StateError('PRD generation failed.');
    return out;
  }

  void reset() {
    state = const AsyncData(null);
  }
}

