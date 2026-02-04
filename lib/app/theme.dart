import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final themeControllerProvider =
    StateNotifierProvider<ThemeController, AppThemeSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeController(prefs);
});

enum AppThemeMode {
  slate,
  forest,
  sunset,
  grape;

  static AppThemeMode fromString(String? raw) {
    return AppThemeMode.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AppThemeMode.slate,
    );
  }
}

@immutable
class AppThemeSettings {
  const AppThemeSettings({
    required this.palette,
    required this.themeMode,
  });

  final AppThemeMode palette;
  final ThemeMode themeMode;

  AppThemeSettings copyWith({
    AppThemeMode? palette,
    ThemeMode? themeMode,
  }) {
    return AppThemeSettings(
      palette: palette ?? this.palette,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeController extends StateNotifier<AppThemeSettings> {
  ThemeController(this._prefs)
      : super(
          AppThemeSettings(
            palette: AppThemeMode.fromString(_prefs.getString(_paletteKey)),
            themeMode: _themeModeFromString(_prefs.getString(_themeModeKey)),
          ),
        );

  // Back-compat: this key previously stored the palette enum name.
  static const _paletteKey = 'app_theme_mode';
  static const _themeModeKey = 'app_theme_brightness';
  final SharedPreferences _prefs;

  Future<void> setPalette(AppThemeMode palette) async {
    state = state.copyWith(palette: palette);
    await _prefs.setString(_paletteKey, palette.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeModeKey, mode.name);
  }
}

ThemeMode _themeModeFromString(String? raw) {
  return switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// Design system radius constants.
/// See `lib/ui/design_system.dart` for documentation.
///
/// - `kRadiusSmall` (8px): Pills, tags, small buttons
/// - `kRadiusMedium` (12px): Cards, containers, modals, inputs
const double kRadiusSmall = 8;
const double kRadiusMedium = 12;

/// Design system elevation constants.
/// - `kElevationNone` (0): Default flat surfaces
/// - `kElevationRaised` (2): Floating elements (modals, FABs)
const double kElevationNone = 0;
const double kElevationRaised = 2;

ThemeData themeFor(AppThemeMode mode, Brightness brightness) {
  final seed = seedFor(mode);

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  ).copyWith(
    // A slightly calmer surface palette than the default seed surfaces.
    surface: brightness == Brightness.dark
        ? const Color(0xFF0B0F14)
        : const Color(0xFFF7F7F9),
  );

  // Design system radii — see design_system.dart
  final radiusMedium = BorderRadius.circular(kRadiusMedium);
  final radiusSmall = BorderRadius.circular(kRadiusSmall);

  final baseText = Typography.material2021().englishLike;
  final textTheme = baseText
      .copyWith(
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium:
            baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      )
      .apply(
        // Ensure readable text colors across light/dark, and avoid low-contrast defaults.
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: kElevationNone,
      scrolledUnderElevation: kElevationNone,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant
          .withOpacity(brightness == Brightness.dark ? 0.35 : 0.55),
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardTheme(
      elevation: kElevationNone,
      color: scheme.surfaceContainerHighest
          .withOpacity(brightness == Brightness.dark ? 0.35 : 0.7),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radiusMedium),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest
          .withOpacity(brightness == Brightness.dark ? 0.35 : 0.7),
      // Make sure input text + labels/hints remain accessible against the filled background.
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.90)),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.95)),
      floatingLabelStyle: TextStyle(color: scheme.onSurface),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.90)),
      errorStyle: TextStyle(color: scheme.error),
      border: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: scheme.outlineVariant),),
      enabledBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: scheme.outlineVariant),),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary
          .withOpacity(brightness == Brightness.dark ? 0.35 : 0.25),
      selectionHandleColor: scheme.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: radiusSmall),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: radiusSmall),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radiusSmall),),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: radiusMedium),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: radiusSmall),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

Color seedFor(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.slate => const Color(0xFF1F2937),
    AppThemeMode.forest => const Color(0xFF14532D),
    AppThemeMode.sunset => const Color(0xFF9A3412),
    AppThemeMode.grape => const Color(0xFF4C1D95),
  };
}
