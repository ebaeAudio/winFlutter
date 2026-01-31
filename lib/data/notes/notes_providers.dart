import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import 'note.dart';
import 'notes_repository.dart';
import 'supabase_notes_repository.dart';

/// Filter parameters for listing notes.
class NotesFilter {
  const NotesFilter({
    this.type,
    this.pinned,
    this.archived,
    this.date, // YYYY-MM-DD for daily notes
  });

  final NoteType? type;
  final bool? pinned;
  final bool? archived;
  final String? date;

  NotesFilter copyWith({
    NoteType? type,
    bool? pinned,
    bool? archived,
    String? date,
    bool clearType = false,
    bool clearPinned = false,
    bool clearArchived = false,
    bool clearDate = false,
  }) {
    return NotesFilter(
      type: clearType ? null : (type ?? this.type),
      pinned: clearPinned ? null : (pinned ?? this.pinned),
      archived: clearArchived ? null : (archived ?? this.archived),
      date: clearDate ? null : (date ?? this.date),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotesFilter &&
        other.type == type &&
        other.pinned == pinned &&
        other.archived == archived &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(type, pinned, archived, date);
}

/// Provider for the notes repository.
///
/// Returns null in demo mode or if Supabase is not initialized.
/// For demo mode, a local repository could be implemented later.
final notesRepositoryProvider = Provider<NotesRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) return null;
  if (!supabase.isInitialized) return null;

  return SupabaseNotesRepository(Supabase.instance.client);
});

/// Provider for a filtered list of notes.
///
/// Automatically handles loading and error states.
/// Returns empty list if repository is null (demo mode or not initialized).
final notesListProvider =
    FutureProvider.family<List<Note>, NotesFilter>((ref, filter) async {
  final repo = ref.watch(notesRepositoryProvider);
  if (repo == null) return const [];

  return repo.listAll(
    type: filter.type,
    pinned: filter.pinned,
    archived: filter.archived,
    date: filter.date,
  );
});

/// Provider for a single note by ID.
///
/// Returns null if the note doesn't exist or repository is unavailable.
final noteProvider = FutureProvider.family<Note?, String>((ref, id) async {
  final repo = ref.watch(notesRepositoryProvider);
  if (repo == null) return null;

  return repo.getById(id);
});

/// Provider for a daily note by date (YYYY-MM-DD).
///
/// Automatically creates the daily note if it doesn't exist.
/// Throws an error if repository is unavailable.
final dailyNoteProvider = FutureProvider.family<Note, String>((ref, ymd) async {
  final repo = ref.watch(notesRepositoryProvider);
  if (repo == null) {
    throw StateError(
      'Notes repository unavailable. Ensure Supabase is configured and initialized.',
    );
  }

  return repo.getOrCreateDailyNote(ymd);
});

/// Provider for search results.
///
/// Returns empty list if query is empty or repository is unavailable.
final notesSearchProvider =
    FutureProvider.family<List<Note>, String>((ref, query) async {
  final repo = ref.watch(notesRepositoryProvider);
  if (repo == null) return const [];

  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  return repo.search(trimmed);
});
