import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

enum OneHandModeHand {
  left,
  right;

  static OneHandModeHand fromString(String? raw) {
    return OneHandModeHand.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => OneHandModeHand.right,
    );
  }
}

@immutable
class UserSettings {
  const UserSettings({
    required this.dumbPhoneAutoStart25mTimebox,
    required this.soundsEnabled,
    required this.oneHandModeEnabled,
    required this.oneHandModeHand,
    required this.disableHorizontalScreenPadding,
  });

  final bool dumbPhoneAutoStart25mTimebox;
  final bool soundsEnabled;
  final bool oneHandModeEnabled;
  final OneHandModeHand oneHandModeHand;
  final bool disableHorizontalScreenPadding;

  UserSettings copyWith({
    bool? dumbPhoneAutoStart25mTimebox,
    bool? soundsEnabled,
    bool? oneHandModeEnabled,
    OneHandModeHand? oneHandModeHand,
    bool? disableHorizontalScreenPadding,
  }) {
    return UserSettings(
      dumbPhoneAutoStart25mTimebox:
          dumbPhoneAutoStart25mTimebox ?? this.dumbPhoneAutoStart25mTimebox,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      oneHandModeEnabled: oneHandModeEnabled ?? this.oneHandModeEnabled,
      oneHandModeHand: oneHandModeHand ?? this.oneHandModeHand,
      disableHorizontalScreenPadding:
          disableHorizontalScreenPadding ?? this.disableHorizontalScreenPadding,
    );
  }
}

final userSettingsControllerProvider =
    StateNotifierProvider<UserSettingsController, UserSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserSettingsController(prefs);
});

class UserSettingsController extends StateNotifier<UserSettings> {
  UserSettingsController(this._prefs)
      : super(
          UserSettings(
            dumbPhoneAutoStart25mTimebox:
                _prefs.getBool(_kDumbPhoneAutoStart25mTimebox) ?? false,
            soundsEnabled: _prefs.getBool(_kSoundsEnabled) ?? true,
            oneHandModeEnabled: _prefs.getBool(_kOneHandModeEnabled) ?? false,
            oneHandModeHand: OneHandModeHand.fromString(
              _prefs.getString(_kOneHandModeHand),
            ),
            disableHorizontalScreenPadding:
                _prefs.getBool(_kDisableHorizontalScreenPadding) ?? false,
          ),
        );

  final SharedPreferences _prefs;

  static const _kDumbPhoneAutoStart25mTimebox =
      'settings_dumb_phone_auto_start_25m_timebox';
  static const _kSoundsEnabled = 'settings_sounds_enabled_v1';
  static const _kOneHandModeEnabled = 'settings_one_hand_mode_enabled';
  static const _kOneHandModeHand = 'settings_one_hand_mode_hand';
  static const _kDisableHorizontalScreenPadding =
      'settings_disable_horizontal_screen_padding';

  Future<void> setDumbPhoneAutoStart25mTimebox(bool enabled) async {
    state = state.copyWith(dumbPhoneAutoStart25mTimebox: enabled);
    await _prefs.setBool(_kDumbPhoneAutoStart25mTimebox, enabled);
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    state = state.copyWith(soundsEnabled: enabled);
    await _prefs.setBool(_kSoundsEnabled, enabled);
  }

  Future<void> setOneHandModeEnabled(bool enabled) async {
    state = state.copyWith(oneHandModeEnabled: enabled);
    await _prefs.setBool(_kOneHandModeEnabled, enabled);
  }

  Future<void> setOneHandModeHand(OneHandModeHand hand) async {
    state = state.copyWith(oneHandModeHand: hand);
    await _prefs.setString(_kOneHandModeHand, hand.name);
  }

  Future<void> setDisableHorizontalScreenPadding(bool disabled) async {
    state = state.copyWith(disableHorizontalScreenPadding: disabled);
    await _prefs.setBool(_kDisableHorizontalScreenPadding, disabled);
  }
}
