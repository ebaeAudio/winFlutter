import '../../domain/focus/app_identifier.dart';
import '../../domain/focus/focus_friction.dart';

class RestrictionPermissions {
  const RestrictionPermissions({
    required this.isSupported,
    required this.isAuthorized,
    required this.needsOnboarding,
    required this.platformDetails,
  });

  final bool isSupported;
  final bool isAuthorized;
  final bool needsOnboarding;
  final String platformDetails;
}

/// Abstraction over platform restrictions enforcement.
///
/// iOS: Screen Time APIs (FamilyControls / ManagedSettings / DeviceActivity)
/// Android: AccessibilityService + blocking screen
abstract class RestrictionEngine {
  Future<RestrictionPermissions> getPermissions();
  Future<void> requestPermissions();

  /// Optional: configure platform-native app selection for restrictions.
  ///
  /// iOS requires a native picker (FamilyControls) to produce the tokens needed to
  /// apply Screen Time shields. On Android this is a no-op.
  Future<void> configureApps();

  /// Apply restrictions for the duration of the current session.
  ///
  /// The product model is allowlist-based (allowed apps), plus friction settings
  /// which are used for early-exit UX.
  Future<void> startSession({
    required DateTime endsAt,
    required List<AppIdentifier> allowedApps,
    required FocusFrictionSettings friction,
  });

  /// Clear all restrictions applied by `startSession`.
  Future<void> endSession();

  /// Optional: record a short emergency exception window.
  Future<void> startEmergencyException({required Duration duration});
}
