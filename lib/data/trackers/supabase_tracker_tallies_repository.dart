import 'package:supabase_flutter/supabase_flutter.dart';

import 'tracker_models.dart';
import 'tracker_tallies_repository.dart';

class SupabaseTrackerTalliesRepository implements TrackerTalliesRepository {
  SupabaseTrackerTalliesRepository(this._client);

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

  TrackerTally _fromRow(Map<String, Object?> row) {
    return TrackerTally(
      trackerId: (row['tracker_id'] as String?) ?? '',
      itemKey: (row['item_key'] as String?) ?? '',
      ymd: (row['date'] as String?) ?? '',
      count: (row['count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<TrackerTally>> listForDate({required String ymd}) async {
    final uid = _requireUserId();
    try {
      final rows = await _client
          .from('tracker_tallies')
          .select('tracker_id,item_key,date,count')
          .eq('user_id', uid)
          .eq('date', ymd);
      final list = rows as List;
      return [
        for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      if (_isMissingTable(e, tableName: 'tracker_tallies')) return const [];
      rethrow;
    }
  }

  @override
  Future<List<TrackerTally>> listForDateRange({
    required String startYmd,
    required String endYmd,
    List<String>? trackerIds,
  }) async {
    final uid = _requireUserId();
    try {
      var q = _client
          .from('tracker_tallies')
          .select('tracker_id,item_key,date,count')
          .eq('user_id', uid)
          .gte('date', startYmd)
          .lte('date', endYmd);
      if (trackerIds != null && trackerIds.isNotEmpty) {
        q = q.inFilter('tracker_id', trackerIds);
      }
      final rows = await q;
      final list = rows as List;
      return [
        for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      if (_isMissingTable(e, tableName: 'tracker_tallies')) return const [];
      rethrow;
    }
  }

  @override
  Future<int> applyDelta({
    required String ymd,
    required String trackerId,
    required String itemKey,
    required int delta,
  }) async {
    final uid = _requireUserId();
    final tid = trackerId.trim();
    final ik = itemKey.trim();
    if (tid.isEmpty || ik.isEmpty) return 0;
    if (delta == 0) return 0;

    Map<String, dynamic>? existing;
    try {
      existing = await _client
          .from('tracker_tallies')
          .select('id,count')
          .eq('user_id', uid)
          .eq('tracker_id', tid)
          .eq('item_key', ik)
          .eq('date', ymd)
          .maybeSingle();
    } catch (e) {
      if (_isMissingTable(e, tableName: 'tracker_tallies')) {
        _throwMissingTable(tableName: 'tracker_tallies');
      }
      rethrow;
    }

    final current = (existing?['count'] as num?)?.toInt() ?? 0;
    final next = current + delta;
    final clamped = next < 0 ? 0 : next;

    if (existing == null) {
      try {
        await _client.from('tracker_tallies').insert({
          'user_id': uid,
          'tracker_id': tid,
          'item_key': ik,
          'date': ymd,
          'count': clamped,
        });
      } catch (e) {
        if (_isMissingTable(e, tableName: 'tracker_tallies')) {
          _throwMissingTable(tableName: 'tracker_tallies');
        }
        rethrow;
      }
      return clamped;
    }

    final id = (existing['id'] as String?) ?? '';
    if (id.isEmpty) return clamped;

    try {
      await _client
          .from('tracker_tallies')
          .update({'count': clamped})
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      if (_isMissingTable(e, tableName: 'tracker_tallies')) {
        _throwMissingTable(tableName: 'tracker_tallies');
      }
      rethrow;
    }
    return clamped;
  }
}
