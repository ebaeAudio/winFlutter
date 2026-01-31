import 'package:supabase_flutter/supabase_flutter.dart';

import 'note.dart';
import 'notes_repository.dart';

class SupabaseNotesRepository implements NotesRepository {
  SupabaseNotesRepository(this._client);

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
      'supabase/migrations/20260117_000001_notes_system.sql (or run it in the SQL editor), then restart the app.',
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

  static const _selectBase =
      'id,user_id,title,content,note_type,project_data,pinned,archived,date,template_id,created_at,updated_at,last_accessed_at';

  Note _fromRow(Map<String, Object?> row) {
    return Note.fromDbJson(row);
  }

  @override
  Future<List<Note>> listAll({
    NoteType? type,
    bool? pinned,
    bool? archived,
    String? date,
  }) async {
    final uid = _requireUserId();
    try {
      var query = _client
          .from('notes')
          .select(_selectBase)
          .eq('user_id', uid);

      if (type != null) {
        query = query.eq('note_type', type.dbValue);
      }

      if (pinned != null) {
        query = query.eq('pinned', pinned);
      }

      if (archived != null) {
        query = query.eq('archived', archived);
      }

      if (date != null) {
        query = query.eq('date', date);
      }

      final rows = await query.order('updated_at', ascending: false);
      final list = rows as List;
      return [
        for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        // Avoid breaking the whole UI; show empty list and let the UI surface a clearer error on create.
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<Note?> getById(String id) async {
    final uid = _requireUserId();
    try {
      final row = await _client
          .from('notes')
          .select(_selectBase)
          .eq('user_id', uid)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) return null;
      rethrow;
    }
  }

  @override
  Future<Note> create(Note note) async {
    final uid = _requireUserId();
    final trimmedTitle = note.title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(note.title, 'title', 'Note title cannot be empty');
    }

    // Validate daily note uniqueness (database constraint will also enforce this)
    if (note.type == NoteType.daily && note.date == null) {
      throw ArgumentError('Daily notes must have a date');
    }

    final insertData = <String, Object?>{
      'user_id': uid,
      'title': trimmedTitle,
      'content': note.content,
      'note_type': note.type.dbValue,
      'pinned': note.pinned,
      'archived': note.archived,
    };

    if (note.projectData != null) {
      insertData['project_data'] = note.projectData!.toJson();
    }

    if (note.date != null) {
      insertData['date'] = note.date;
    }

    if (note.templateId != null) {
      insertData['template_id'] = note.templateId;
    }

    try {
      final row = await _client
          .from('notes')
          .insert(insertData)
          .select(_selectBase)
          .single();

      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      // Check for unique constraint violation (daily note duplicate)
      if (e is PostgrestException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('daily note') && msg.contains('already exists')) {
          throw StateError('A daily note already exists for this date');
        }
      }
      rethrow;
    }
  }

  @override
  Future<Note> update(Note note) async {
    final uid = _requireUserId();
    final trimmedTitle = note.title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(note.title, 'title', 'Note title cannot be empty');
    }

    final patch = <String, Object?>{
      'title': trimmedTitle,
      'content': note.content,
      'note_type': note.type.dbValue,
      'pinned': note.pinned,
      'archived': note.archived,
    };

    if (note.projectData != null) {
      patch['project_data'] = note.projectData!.toJson();
    } else {
      // Explicitly set to null if projectData should be cleared
      patch['project_data'] = null;
    }

    if (note.date != null) {
      patch['date'] = note.date;
    } else if (note.type != NoteType.daily) {
      // Clear date for non-daily notes
      patch['date'] = null;
    }

    if (note.templateId != null) {
      patch['template_id'] = note.templateId;
    }

    try {
      final row = await _client
          .from('notes')
          .update(patch)
          .eq('id', note.id)
          .eq('user_id', uid)
          .select(_selectBase)
          .single();

      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    final uid = _requireUserId();
    try {
      await _client
          .from('notes')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      rethrow;
    }
  }

  @override
  Future<Note> getOrCreateDailyNote(String ymd) async {
    final uid = _requireUserId();
    try {
      // Try to get existing daily note for this date
      final existing = await _client
          .from('notes')
          .select(_selectBase)
          .eq('user_id', uid)
          .eq('note_type', NoteType.daily.dbValue)
          .eq('date', ymd)
          .maybeSingle();

      if (existing != null) {
        return _fromRow(Map<String, Object?>.from(existing));
      }

      // Create new daily note
      final row = await _client
          .from('notes')
          .insert({
            'user_id': uid,
            'title': ymd, // Default title is the date
            'content': '',
            'note_type': NoteType.daily.dbValue,
            'date': ymd,
            'pinned': false,
            'archived': false,
          })
          .select(_selectBase)
          .single();

      return _fromRow(Map<String, Object?>.from(row));
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      // Check for unique constraint violation (shouldn't happen due to transaction, but handle gracefully)
      if (e is PostgrestException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('daily note') && msg.contains('already exists')) {
          // Race condition: another request created it, fetch it
          final existing = await _client
              .from('notes')
              .select(_selectBase)
              .eq('user_id', uid)
              .eq('note_type', NoteType.daily.dbValue)
              .eq('date', ymd)
              .maybeSingle();
          if (existing != null) {
            return _fromRow(Map<String, Object?>.from(existing));
          }
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<Note>> search(String query) async {
    final uid = _requireUserId();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return listAll();
    }

    try {
      // Use PostgreSQL full-text search
      // The search_vector column is generated from title and content
      final rows = await _client
          .from('notes')
          .select(_selectBase)
          .eq('user_id', uid)
          .textSearch('search_vector', trimmedQuery, config: 'english')
          .order('updated_at', ascending: false);

      final list = rows as List;
      return [
        for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
      ];
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        return const [];
      }
      // If full-text search isn't available, fall back to simple LIKE search
      try {
        final rows = await _client
            .from('notes')
            .select(_selectBase)
            .eq('user_id', uid)
            .or('title.ilike.%$trimmedQuery%,content.ilike.%$trimmedQuery%')
            .order('updated_at', ascending: false);

        final list = rows as List;
        return [
          for (final row in list) _fromRow(Map<String, Object?>.from(row as Map)),
        ];
      } catch (_) {
        rethrow;
      }
    }
  }

  @override
  Future<void> togglePinned(String id) async {
    final uid = _requireUserId();
    try {
      // Get current pinned status
      final current = await _client
          .from('notes')
          .select('pinned')
          .eq('id', id)
          .eq('user_id', uid)
          .maybeSingle();

      if (current == null) {
        throw StateError('Note not found');
      }

      final currentPinned = (current['pinned'] as bool?) ?? false;

      await _client
          .from('notes')
          .update({'pinned': !currentPinned})
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      rethrow;
    }
  }

  @override
  Future<void> archive(String id) async {
    final uid = _requireUserId();
    try {
      await _client
          .from('notes')
          .update({'archived': true})
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        _throwMissingTable(tableName: 'notes');
      }
      rethrow;
    }
  }

  @override
  Future<void> updateLastAccessed(String id) async {
    final uid = _requireUserId();
    try {
      await _client
          .from('notes')
          .update({'last_accessed_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      if (_isMissingTable(e, tableName: 'notes')) {
        // Silently fail if table doesn't exist
        return;
      }
      // Silently fail for last_accessed_at updates (non-critical)
    }
  }
}
