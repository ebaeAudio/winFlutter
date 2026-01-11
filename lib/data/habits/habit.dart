class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
      };

  static Habit fromJson(Map<String, Object?> json) {
    return Habit(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
