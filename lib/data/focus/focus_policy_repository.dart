import '../../domain/focus/focus_policy.dart';

abstract class FocusPolicyRepository {
  Future<List<FocusPolicy>> listPolicies();
  Future<FocusPolicy?> getPolicy(String id);
  Future<void> upsertPolicy(FocusPolicy policy);
  Future<void> deletePolicy(String id);
}
