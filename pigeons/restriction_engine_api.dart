// Optional future migration target:
// Use Pigeon to generate strongly-typed platform channels.
//
// This file is intentionally not wired into build_runner yet; today we use a
// MethodChannel in `lib/platform/restriction_engine/restriction_engine_channel.dart`.

class PigeonAppIdentifier {
  PigeonAppIdentifier({
    required this.platform,
    required this.id,
    this.displayName,
  });

  final String platform; // 'ios' | 'android'
  final String id;
  final String? displayName;
}

class PigeonFrictionSettings {
  PigeonFrictionSettings({
    required this.holdToUnlockSeconds,
    required this.unlockDelaySeconds,
    required this.emergencyUnlockMinutes,
    required this.maxEmergencyUnlocksPerSession,
  });

  final int holdToUnlockSeconds;
  final int unlockDelaySeconds;
  final int emergencyUnlockMinutes;
  final int maxEmergencyUnlocksPerSession;
}

class PigeonRestrictionPermissions {
  PigeonRestrictionPermissions({
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

// @HostApi()
abstract class RestrictionEngineHostApi {
  PigeonRestrictionPermissions getPermissions();
  void requestPermissions();

  void startSession({
    required int endsAtMillis,
    required List<PigeonAppIdentifier> allowedApps,
    required PigeonFrictionSettings friction,
  });

  void endSession();
  void startEmergencyException({required int durationMillis});
}


