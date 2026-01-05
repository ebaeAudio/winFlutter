import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/focus/focus_policy_repository.dart';
import '../../domain/focus/focus_friction.dart';
import '../../domain/focus/focus_policy.dart';
import 'focus_providers.dart';

final focusPolicyListProvider =
    AsyncNotifierProvider<FocusPolicyListController, List<FocusPolicy>>(
  FocusPolicyListController.new,
);

class FocusPolicyListController extends AsyncNotifier<List<FocusPolicy>> {
  FocusPolicyRepository get _repo => ref.read(focusPolicyRepositoryProvider);

  @override
  Future<List<FocusPolicy>> build() async {
    return _repo.listPolicies();
  }

  Future<FocusPolicy> createDefault() async {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    final policy = FocusPolicy(
      id: id,
      name: 'Focus',
      allowedApps: const [],
      friction: FocusFrictionSettings.defaults,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.upsertPolicy(policy);
    state = AsyncData(await _repo.listPolicies());
    return policy;
  }

  Future<void> upsert(FocusPolicy policy) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.upsertPolicy(policy);
      return _repo.listPolicies();
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deletePolicy(id);
      return _repo.listPolicies();
    });
  }
}


