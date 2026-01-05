import 'dart:convert';

enum AppPlatform {
  ios,
  android;

  static AppPlatform fromString(String raw) => switch (raw) {
        'ios' => AppPlatform.ios,
        'android' => AppPlatform.android,
        _ => AppPlatform.android,
      };
}

/// Platform app identifier:
/// - iOS: bundle id (e.g. "com.apple.Maps" or "com.myapp.app")
/// - Android: package name (e.g. "com.google.android.youtube")
class AppIdentifier {
  const AppIdentifier({
    required this.platform,
    required this.id,
    this.displayName,
  });

  final AppPlatform platform;
  final String id;
  final String? displayName;

  Map<String, Object?> toJson() => {
        'platform': platform.name,
        'id': id,
        if (displayName != null) 'displayName': displayName,
      };

  static AppIdentifier fromJson(Map<String, Object?> json) => AppIdentifier(
        platform: AppPlatform.fromString((json['platform'] as String?) ?? ''),
        id: (json['id'] as String?) ?? '',
        displayName: json['displayName'] as String?,
      );

  static List<AppIdentifier> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => AppIdentifier.fromJson(m.cast<String, Object?>()))
        .toList(growable: false);
  }

  static String listToJsonString(List<AppIdentifier> apps) =>
      jsonEncode(apps.map((a) => a.toJson()).toList(growable: false));
}


