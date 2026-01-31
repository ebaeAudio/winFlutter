# Notes System Implementation Prompt

## Context

You are implementing a comprehensive notes system for the Win the Year Flutter app. This system will transform the Projects tab into a powerful, cross-device notes workspace that seamlessly connects planning to execution.

## Prerequisites

1. **Read the architecture document**: `docs/NOTES_ARCHITECTURE.md` - This contains the complete technical specification, data model, and feature roadmap.

2. **Database migration**: The Supabase migration file `supabase/migrations/20260117_000001_notes_system.sql` has already been created. Apply it to your Supabase instance before starting implementation.

3. **Existing patterns**: Follow the codebase patterns:
   - Repository pattern in `lib/data/`
   - Riverpod for state management
   - Material 3 theme from `lib/app/theme.dart`
   - `AppScaffold` for screen layouts
   - Spacing from `lib/ui/spacing.dart`

## Implementation Phases

### Phase 1: Foundation (Sprint 1-2)

#### 1.1 Domain Models
Create domain models in `lib/data/notes/`:

```dart
// lib/data/notes/note.dart
class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final NoteType type;
  final ProjectData? projectData;
  final bool pinned;
  final bool archived;
  final DateTime? date; // For daily notes
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
}

enum NoteType {
  note,
  project,
  daily,
  inbox,
}

class ProjectData {
  final String? goal;
  final String? status; // active, on-hold, completed, archived
  final List<String> nextActions;
  final List<String> resources;
  
  // JSON serialization methods
}
```

**Acceptance Criteria:**
- [ ] All models have JSON serialization (toJson/fromJson)
- [ ] Models match the Supabase schema exactly
- [ ] Nullable fields are properly handled
- [ ] Date parsing handles timezone correctly

#### 1.2 Repository Interface
Create `lib/data/notes/notes_repository.dart`:

```dart
abstract class NotesRepository {
  // CRUD operations
  Future<List<Note>> listAll({
    NoteType? type,
    bool? pinned,
    bool? archived,
    DateTime? date,
  });
  
  Future<Note?> getById(String id);
  Future<Note> create(Note note);
  Future<Note> update(Note note);
  Future<void> delete(String id);
  
  // Daily notes
  Future<Note> getOrCreateDailyNote(String ymd);
  
  // Search
  Future<List<Note>> search(String query);
  
  // Special operations
  Future<void> togglePinned(String id);
  Future<void> archive(String id);
  Future<void> updateLastAccessed(String id);
}
```

**Acceptance Criteria:**
- [ ] Interface matches all required operations
- [ ] Methods have clear documentation
- [ ] Error handling is considered (throw appropriate exceptions)

#### 1.3 Supabase Repository Implementation
Create `lib/data/notes/supabase_notes_repository.dart`:

**Key Implementation Details:**
- Use `SupabaseClient` from `supabase_flutter`
- Handle RLS policies (all queries should work with authenticated user)
- Use the exact column names from the migration
- Handle missing columns gracefully (like other repositories in the codebase)
- Implement full-text search using PostgreSQL `to_tsvector`
- Handle daily note uniqueness constraint

**Acceptance Criteria:**
- [ ] All CRUD operations work correctly
- [ ] Daily notes are auto-created on first access
- [ ] Search uses PostgreSQL full-text search indexes
- [ ] Error messages are clear and actionable
- [ ] Handles offline scenarios gracefully (throws appropriate exceptions)

#### 1.4 Riverpod Providers
Create `lib/data/notes/notes_providers.dart`:

```dart
// Provider for repository
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  // Check if demo mode, return local implementation
  // Otherwise return Supabase implementation
});

// Provider for notes list (filtered)
final notesListProvider = FutureProvider.family<List<Note>, NotesFilter>((ref, filter) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.listAll(
    type: filter.type,
    pinned: filter.pinned,
    archived: filter.archived,
    date: filter.date,
  );
});

// Provider for single note
final noteProvider = FutureProvider.family<Note?, String>((ref, id) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getById(id);
});

// Provider for daily note
final dailyNoteProvider = FutureProvider.family<Note, String>((ref, ymd) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getOrCreateDailyNote(ymd);
});
```

**Acceptance Criteria:**
- [ ] Providers handle loading/error states
- [ ] Providers invalidate correctly on updates
- [ ] Demo mode support (local repository)
- [ ] Follows existing provider patterns in codebase

### Phase 2: Basic UI (Sprint 3-4)

#### 2.1 Notes List Screen
Create `lib/features/notes/notes_screen.dart`:

**Features:**
- List of notes (cards or list tiles)
- Filter by type (inbox, note, project, daily)
- Sort by: recent, updated, pinned, title
- Search bar with full-text search
- Empty states for each filter
- Pull-to-refresh

**UI Components:**
- `NoteCard` widget in `lib/ui/components/note_card.dart`
- `NoteSearchBar` widget
- `NoteFilters` widget (segmented control or chips)

**Acceptance Criteria:**
- [ ] Uses `AppScaffold` for layout
- [ ] Follows Material 3 design system
- [ ] Search is debounced (300ms)
- [ ] Filters update list immediately
- [ ] Empty states are helpful and actionable
- [ ] Loading states are shown appropriately
- [ ] Error states allow retry

#### 2.2 Note Editor Screen
Create `lib/features/notes/note_editor_screen.dart`:

**Features:**
- Markdown editor with preview toggle
- Formatting toolbar (reuse from `secret_notes_screen.dart`)
- Auto-save with debouncing (550ms)
- Title editing
- Type selector (note, project, inbox)
- Pin/archive actions
- Delete with confirmation

**For Project Notes:**
- Structured fields: Goal, Status, Next Actions, Resources
- Use form fields or expandable sections

**Acceptance Criteria:**
- [ ] Auto-save works correctly
- [ ] Shows "Unsaved..." / "Saved" indicator
- [ ] Preview mode renders markdown correctly
- [ ] Formatting toolbar works (reuse existing component)
- [ ] Navigation handles unsaved changes (confirm before leaving)
- [ ] Project note fields are properly structured

#### 2.3 Daily Scratchpad Screen
Create `lib/features/notes/daily_scratchpad_screen.dart`:

**Features:**
- Auto-creates note for today if it doesn't exist
- Shows date prominently
- Link to navigate to that date in Today screen
- Optional template support
- Same editor as regular notes

**Integration:**
- Add quick access button in Today screen
- Link from date navigation

**Acceptance Criteria:**
- [ ] Daily note is created on first access
- [ ] Date is clearly displayed
- [ ] Can navigate to linked date
- [ ] Template is applied if configured
- [ ] Works offline (creates locally, syncs later)

### Phase 3: Linking System (Sprint 5-6)

#### 3.1 Wiki-Link Parser
Create `lib/features/notes/wiki_link_parser.dart`:

**Features:**
- Parse `[[Note Name]]` syntax
- Parse `[[Note Name|Display Text]]` syntax
- Extract links from markdown content
- Generate backlinks (which notes link to this note)

**Implementation:**
- Use regex to find wiki links
- Store links in `note_links` table
- Update links when note content changes

**Acceptance Criteria:**
- [ ] Parses all wiki-link variations correctly
- [ ] Handles edge cases (nested brackets, special characters)
- [ ] Links are stored in database
- [ ] Backlinks are computed correctly

#### 3.2 Link Navigation
**Features:**
- Tap wiki links in preview to navigate
- Show link suggestions when typing `[[`
- Display backlinks in note editor
- Show "broken links" (links to non-existent notes)

**Acceptance Criteria:**
- [ ] Links are tappable in preview
- [ ] Navigation works correctly
- [ ] Autocomplete shows matching notes
- [ ] Backlinks update in real-time
- [ ] Broken links are visually distinct

#### 3.3 Task-Note Integration
**Features:**
- Link notes to tasks (from task details screen)
- Show linked notes in task details
- Convert note items to tasks
- Show which tasks reference a note

**Implementation:**
- Add "Link Note" action in task details
- Store links in `note_links` table with `source_type='task'`
- Display linked notes in task UI

**Acceptance Criteria:**
- [ ] Can link notes from task details
- [ ] Linked notes are visible in task UI
- [ ] Can navigate from task to note
- [ ] Backlinks show tasks that reference note

### Phase 4: Advanced Features (Sprint 7-8)

#### 4.1 Templates System
**Features:**
- Create custom templates
- Apply template when creating note
- Template variables (`{{date}}`, `{{title}}`)
- Default templates for daily/project notes

**Acceptance Criteria:**
- [ ] Templates are stored in `note_templates` table
- [ ] Variables are replaced correctly
- [ ] Can create/edit/delete templates
- [ ] Default templates are available

#### 4.2 Tags System
**Features:**
- Add tags to notes
- Filter by tag
- Tag autocomplete
- Tag management (rename, delete)

**Acceptance Criteria:**
- [ ] Tags are stored in `note_tags` table
- [ ] Can add multiple tags to a note
- [ ] Filtering by tag works
- [ ] Autocomplete suggests existing tags

#### 4.3 Export/Import
**Features:**
- Export note as Markdown file
- Export all notes as folder structure
- Import from Markdown files
- Obsidian vault compatibility

**Acceptance Criteria:**
- [ ] Export preserves wiki links
- [ ] File structure is organized
- [ ] Import handles conflicts
- [ ] Obsidian links are converted correctly

## Technical Requirements

### Code Quality
- Follow existing codebase patterns
- Use `AppScaffold` for screens
- Use spacing from `lib/ui/spacing.dart`
- Keep widgets small and composable
- Add proper error handling
- Write clear documentation

### Testing
- Unit tests for repository methods
- Widget tests for key UI components
- Integration tests for critical flows (create note, link notes, daily note)

### Performance
- Lazy load note content (list shows title + preview only)
- Debounce search (300ms) and auto-save (550ms)
- Cache daily note for current day
- Use database indexes for queries

### Offline Support
- All edits work offline
- Queue sync operations when offline
- Background sync when online
- Show sync status indicators
- Handle conflicts (last-write-wins with timestamps)

## Migration from Secret Notes

If migrating existing secret notes:
1. Detect local notes in SharedPreferences
2. Offer migration option in settings
3. Batch upload with progress indicator
4. Preserve note IDs and content
5. Keep local backup until confirmed

## Success Criteria

The implementation is complete when:
- [ ] All Phase 1-2 features work end-to-end
- [ ] Notes sync correctly across devices
- [ ] Daily scratchpad is accessible from Today screen
- [ ] Wiki-linking works between notes
- [ ] Search is fast and accurate
- [ ] Offline editing works seamlessly
- [ ] UI follows Material 3 design system
- [ ] Code follows existing patterns
- [ ] No critical bugs or performance issues

## Getting Started

1. Apply the database migration: `supabase/migrations/20260117_000001_notes_system.sql`
2. Start with Phase 1.1 (Domain Models)
3. Implement incrementally, testing each phase
4. Reference existing code patterns (e.g., `lib/data/tasks/` for repository pattern)
5. Use the architecture document as the source of truth for data model and features

## Questions to Resolve

Before starting, clarify:
- Should we migrate existing secret notes automatically or on-demand?
- What should happen to secret notes feature? (Keep as-is, deprecate, or integrate?)
- Should templates be user-created only or include system templates?
- What's the priority order if not implementing all phases?

## References

- Architecture: `docs/NOTES_ARCHITECTURE.md`
- Database Schema: `supabase/migrations/20260117_000001_notes_system.sql`
- Existing Patterns: `lib/data/tasks/`, `lib/data/trackers/`
- UI Patterns: `lib/features/projects/secret_notes_screen.dart`
- Frontend Spec: `docs/FRONTEND_SPEC.md`
