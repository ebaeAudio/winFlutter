class FocusFrictionSettings {
  const FocusFrictionSettings({
    required this.holdToUnlockSeconds,
    required this.unlockDelaySeconds,
    required this.emergencyUnlockMinutes,
    required this.maxEmergencyUnlocksPerSession,
  });

  /// How long the user must press-and-hold to early-exit.
  final int holdToUnlockSeconds;

  /// After holding, how long we wait before applying the unlock.
  /// (Gives the brain a chance to reconsider.)
  final int unlockDelaySeconds;

  /// Temporary exception duration for "I really need this right now".
  final int emergencyUnlockMinutes;

  /// Max emergency exceptions allowed in one session.
  final int maxEmergencyUnlocksPerSession;

  static const defaults = FocusFrictionSettings(
    holdToUnlockSeconds: 3,
    unlockDelaySeconds: 10,
    emergencyUnlockMinutes: 3,
    maxEmergencyUnlocksPerSession: 1,
  );

  FocusFrictionSettings copyWith({
    int? holdToUnlockSeconds,
    int? unlockDelaySeconds,
    int? emergencyUnlockMinutes,
    int? maxEmergencyUnlocksPerSession,
  }) {
    return FocusFrictionSettings(
      holdToUnlockSeconds: holdToUnlockSeconds ?? this.holdToUnlockSeconds,
      unlockDelaySeconds: unlockDelaySeconds ?? this.unlockDelaySeconds,
      emergencyUnlockMinutes:
          emergencyUnlockMinutes ?? this.emergencyUnlockMinutes,
      maxEmergencyUnlocksPerSession:
          maxEmergencyUnlocksPerSession ?? this.maxEmergencyUnlocksPerSession,
    );
  }

  Map<String, Object?> toJson() => {
        'holdToUnlockSeconds': holdToUnlockSeconds,
        'unlockDelaySeconds': unlockDelaySeconds,
        'emergencyUnlockMinutes': emergencyUnlockMinutes,
        'maxEmergencyUnlocksPerSession': maxEmergencyUnlocksPerSession,
      };

  static FocusFrictionSettings fromJson(Map<String, Object?> json) =>
      FocusFrictionSettings(
        holdToUnlockSeconds: (json['holdToUnlockSeconds'] as num?)?.toInt() ??
            defaults.holdToUnlockSeconds,
        unlockDelaySeconds: (json['unlockDelaySeconds'] as num?)?.toInt() ??
            defaults.unlockDelaySeconds,
        emergencyUnlockMinutes:
            (json['emergencyUnlockMinutes'] as num?)?.toInt() ??
                defaults.emergencyUnlockMinutes,
        maxEmergencyUnlocksPerSession:
            (json['maxEmergencyUnlocksPerSession'] as num?)?.toInt() ??
                defaults.maxEmergencyUnlocksPerSession,
      );
}
