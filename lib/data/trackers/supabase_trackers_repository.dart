import 'package:supabase_flutter/supabase_flutter.dart';

import 'tracker_models.dart';
import 'trackers_repository.dart';

class SupabaseTrackersRepository implements TrackersRepository {
  SupabaseTrackersRepository(this._client);

  final SupabaseClient _client;

  static bool _isMissingTable(Object e, {required String tableName}) {
    if (e is! PostgrestException) return false;
    final msg = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final hint = (e.hint?.toString() ?? '').toLowerCase();
    final combined = '$msg $details $hint';
    if (!combined.contains(tableName.toLowerCase())) return false;
    return combined.contains('could not find the table') ||
        combined.contains('relation') && combined.contains('does not exist') ||
        combined.contains('not found');
  }

  Never _throwMissingTable({required String tableName}) {
    throw StateError(
      'Missing Supabase table "$tableName". Apply the migration in '
      'supabase/migrations/20260106_000001_trackers.sql (or run supabase/trackers_schema.sql in the SQL editor), then restart the app.',
    );
  }

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  Tracker _fromRow(Map<String, Object?> row) {
    final createdAtRaw = (row['created_at'] as String?) ?? '';
    final updatedAtRaw = (row['updated_at'] as String?) ?? '';
    return Tracker(
      id: (row['id'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      items: decodeItemsJson(row['items']),
      archived: (row['archived'] as bool?) ?? false,
      createdAtMs: DateTime.tryParse(createdAtRaw)?.millisecondsSinceEpoch ?? 0,
      updatedAtMs: DateTime.tryParse(updatedAtRaw)?.millisecondsSinceEpoch ?? 0,
    );
  }

  @override
  Future<List<Tracker>> listAll() async {
    final uid = _requireUserId();
    try {
      final rows = await _client
          .from('trackers')
          .select('id,user_id,name,items,archived,created_at,updated_at')
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      final list = rows as List;
      return [
        for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      if (_isMissingTable(e, tableName: 'trackers')) {
        // Avoid breaking the whole UI; show empty list and let the UI surface a clearer error on create.
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<Tracker?> getById({required String id}) async {
    final uid = _requireUserId();
    try {
      final row = await _client
          .from('trackers')
          .select('id,user_id,name,items,archived,created_at,updated_at')
          .eq('user_id', uid)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'trackers')) return null;
      rethrow;
    }
  }

  void _validateItems(List<TrackerItem> items) {
    if (items.isEmpty || items.length > 3) {
      throw ArgumentError.value(items.length, 'items', 'Must have 1–3 items');
    }
    for (final it in items) {
      if (it.key.trim().isEmpty) {
        throw ArgumentError('Item key cannot be empty');
      }
      if (it.emoji.trim().isEmpty) {
        throw ArgumentError('Item emoji cannot be empty');
      }
      if (it.description.trim().isEmpty) {
        throw ArgumentError('Item description cannot be empty');
      }
      if (it.targetValue != null && it.targetValue! < 0) {
        throw ArgumentError('Target value cannot be negative');
      }
    }

    final keys = items.map((i) => i.key.trim()).toList();
    if (keys.toSet().length != keys.length) {
      throw ArgumentError('Item keys must be unique');
    }
  }

  @override
  Future<Tracker> create({
    required String name,
    required List<TrackerItem> items,
  }) async {
    final uid = _requireUserId();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tracker name cannot be empty');
    }
    _validateItems(items);

    try {
      final row = await _client
          .from('trackers')
          .insert({
            'user_id': uid,
            'name': trimmed,
            'items': [for (final i in items) i.toJson()],
            'archived': false,
          })
          .select('id,user_id,name,items,archived,created_at,updated_at')
          .single();

      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'trackers')) {
        _throwMissingTable(tableName: 'trackers');
      }
      rethrow;
    }
  }

  @override
  Future<Tracker> update({
    required String id,
    String? name,
    List<TrackerItem>? items,
    bool? archived,
  }) async {
    final uid = _requireUserId();
    final patch = <String, Object?>{};
    final trimmed = name?.trim();
    if (trimmed != null) {
      if (trimmed.isEmpty) throw ArgumentError('name cannot be empty');
      patch['name'] = trimmed;
    }
    if (items != null) {
      _validateItems(items);
      patch['items'] = [for (final i in items) i.toJson()];
    }
    if (archived != null) patch['archived'] = archived;

    try {
      final row = await _client
          .from('trackers')
          .update(patch)
          .eq('id', id)
          .eq('user_id', uid)
          .select('id,user_id,name,items,archived,created_at,updated_at')
          .single();
      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'trackers')) {
        _throwMissingTable(tableName: 'trackers');
      }
      rethrow;
    }
  }
}
