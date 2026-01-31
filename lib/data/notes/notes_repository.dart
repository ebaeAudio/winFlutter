import 'note.dart';

/// Repository interface for notes operations.
abstract interface class NotesRepository {
  /// List all notes with optional filters.
  ///
  /// Returns notes matching the provided filters, ordered by most recently updated.
  Future<List<Note>> listAll({
    NoteType? type,
    bool? pinned,
    bool? archived,
    String? date, // YYYY-MM-DD for daily notes
  });

  /// Get a note by ID.
  ///
  /// Returns null if the note doesn't exist or the user doesn't have access.
  Future<Note?> getById(String id);

  /// Create a new note.
  ///
  /// Throws an exception if creation fails (e.g., duplicate daily note for same date).
  Future<Note> create(Note note);

  /// Update an existing note.
  ///
  /// Throws an exception if the note doesn't exist or update fails.
  Future<Note> update(Note note);

  /// Delete a note by ID.
  ///
  /// Throws an exception if deletion fails.
  Future<void> delete(String id);

  /// Get or create a daily note for the given date (YYYY-MM-DD).
  ///
  /// If a daily note already exists for this date, returns it.
  /// Otherwise, creates a new daily note with the given date.
  /// Throws an exception if creation fails.
  Future<Note> getOrCreateDailyNote(String ymd);

  /// Search notes using full-text search.
  ///
  /// Searches across title and content using PostgreSQL full-text search.
  /// Returns notes matching the query, ordered by relevance.
  Future<List<Note>> search(String query);

  /// Toggle the pinned status of a note.
  ///
  /// Throws an exception if the note doesn't exist or update fails.
  Future<void> togglePinned(String id);

  /// Archive a note.
  ///
  /// Sets archived to true. Throws an exception if the note doesn't exist or update fails.
  Future<void> archive(String id);

  /// Update the last accessed timestamp for a note.
  ///
  /// Used to track which notes are accessed most frequently.
  /// Throws an exception if the note doesn't exist or update fails.
  Future<void> updateLastAccessed(String id);
}
