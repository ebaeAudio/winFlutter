# Notes Architecture — Long-term Solution

## Vision

Transform the Projects tab into a powerful, cross-device notes workspace that seamlessly connects planning to execution. The notes system should feel fast, frictionless, and deeply integrated with the daily execution workflow (tasks, habits, dates).

---

## Core Principles

### 1. **Zero Friction Capture**
- Ideas should be captured instantly, without context switching
- Daily scratchpad is always available (auto-created)
- Quick capture from anywhere in the app

### 2. **Structure When Needed, Freedom When Not**
- Simple notes for quick thoughts
- Structured project notes for active work
- Templates for common patterns (daily review, project planning, meeting notes)

### 3. **Deep Integration with Execution**
- Link notes to tasks, dates, and habits
- See backlinks: which tasks/days reference this note
- Convert notes into actionable tasks
- View note context from task details

### 4. **Offline-First, Sync When Ready**
- All edits work offline
- Background sync when online
- Clear conflict resolution (last-write-wins with timestamps)
- Visual indicators for sync status

### 5. **Privacy & Control**
- User owns their data
- Export to Markdown (Obsidian-compatible)
- Import from external sources
- Clear data retention policies

---

## Data Model

### Core Tables

#### `notes`
Primary storage for all notes (inbox, projects, daily scratchpads).

```sql
CREATE TABLE public.notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Core fields
  title text NOT NULL,
  content text NOT NULL DEFAULT '',
  note_type text NOT NULL DEFAULT 'note', -- 'note', 'project', 'daily', 'inbox'
  
  -- Project-specific structure (JSONB for flexibility)
  project_data jsonb, -- { goal, status, next_actions[], resources[] }
  
  -- Metadata
  pinned boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  template_id uuid REFERENCES public.note_templates(id),
  
  -- Daily scratchpad link
  date date, -- For daily notes: YYYY-MM-DD
  
  -- Timestamps
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_accessed_at timestamptz,
  
  -- Full-text search
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(content, '')), 'B')
  ) STORED
);

CREATE INDEX notes_user_id_idx ON public.notes(user_id);
CREATE INDEX notes_type_idx ON public.notes(user_id, note_type);
CREATE INDEX notes_date_idx ON public.notes(user_id, date) WHERE date IS NOT NULL;
CREATE INDEX notes_pinned_idx ON public.notes(user_id, pinned) WHERE pinned = true;
CREATE INDEX notes_search_idx ON public.notes USING gin(search_vector);
CREATE INDEX notes_updated_at_idx ON public.notes(user_id, updated_at DESC);
```

#### `note_links`
Bidirectional linking between notes, tasks, dates, and habits.

```sql
CREATE TABLE public.note_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Source (what contains the link)
  source_type text NOT NULL, -- 'note', 'task', 'date', 'habit'
  source_id uuid NOT NULL,
  
  -- Target (what is linked to)
  target_type text NOT NULL, -- 'note', 'task', 'date', 'habit'
  target_id uuid NOT NULL,
  
  -- Context
  context text, -- Optional: where in source the link appears (e.g., line number, section)
  link_text text, -- The text that was linked (e.g., "[[Project X]]" or task title)
  
  created_at timestamptz NOT NULL DEFAULT now(),
  
  -- Prevent duplicates
  UNIQUE(user_id, source_type, source_id, target_type, target_id)
);

CREATE INDEX note_links_source_idx ON public.note_links(user_id, source_type, source_id);
CREATE INDEX note_links_target_idx ON public.note_links(user_id, target_type, target_id);
```

#### `note_templates`
Reusable templates for common note patterns.

```sql
CREATE TABLE public.note_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  name text NOT NULL,
  content text NOT NULL,
  note_type text NOT NULL DEFAULT 'note',
  
  is_system boolean NOT NULL DEFAULT false, -- Built-in templates
  is_default boolean NOT NULL DEFAULT false, -- Default for note_type
  
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  UNIQUE(user_id, name)
);

CREATE INDEX note_templates_user_id_idx ON public.note_templates(user_id);
```

#### `note_tags`
Simple tagging system (optional, can be added later).

```sql
CREATE TABLE public.note_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  note_id uuid NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  tag text NOT NULL,
  
  created_at timestamptz NOT NULL DEFAULT now(),
  
  UNIQUE(note_id, tag)
);

CREATE INDEX note_tags_note_id_idx ON public.note_tags(note_id);
CREATE INDEX note_tags_tag_idx ON public.note_tags(user_id, tag);
```

### RLS Policies

All tables use Row Level Security:

- Users can only access their own notes
- Notes are private by default
- Links respect source/target ownership

---

## Feature Set

### Phase 1: Foundation (MVP)

#### 1.1 Core Note Types
- **Inbox Notes**: Quick capture, zero structure
- **Regular Notes**: Free-form markdown
- **Daily Scratchpad**: Auto-created per day, linked to date
- **Project Notes**: Structured with goal, status, next actions

#### 1.2 Basic CRUD
- Create, read, update, delete notes
- Markdown editor with preview
- Auto-save with debouncing (550ms)
- Formatting toolbar (bold, italic, headings, links, etc.)

#### 1.3 Daily Scratchpad
- Auto-create on first access each day
- Link to date (YYYY-MM-DD)
- Optional template (user-configurable)
- Quick access from Today screen

#### 1.4 Search & Filters
- Full-text search across title and content
- Filter by type (inbox, project, daily, all)
- Sort by: recent, updated, pinned, title
- Quick filters: pinned, active projects

### Phase 2: Linking & Integration

#### 2.1 Wiki-Style Links
- `[[Note Name]]` syntax (Obsidian-style)
- `[[Note Name|Display Text]]` for custom labels
- Auto-complete when typing `[[`
- Navigate by tapping links in preview

#### 2.2 Task Integration
- Link notes to tasks (from note or from task)
- View linked notes in task details
- Convert note items to tasks
- See which tasks reference a note (backlinks)

#### 2.3 Date Integration
- Link notes to specific dates
- Daily scratchpad auto-links to today
- View notes for a date from Today screen
- Navigate from date to daily scratchpad

#### 2.4 Backlinks View
- Show all notes/tasks/dates that link to current note
- Visual graph of connections
- Quick navigation to linked items

### Phase 3: Project Structure

#### 3.1 Project Notes
- Structured fields: goal, status, next actions, resources
- Status options: active, on-hold, completed, archived
- Next actions as checkable list
- Resources as links or text

#### 3.2 Project Templates
- Default project template
- Custom templates per user
- Template variables (e.g., `{{date}}`, `{{project_name}}`)

#### 3.3 Project Dashboard
- List all active projects
- Filter by status
- Quick actions: pin, archive, convert to note

### Phase 4: Advanced Features

#### 4.1 Templates System
- Create custom templates
- Apply template when creating note
- Template library (meeting notes, project kickoff, daily review, etc.)

#### 4.2 Tags & Organization
- Add tags to notes
- Filter by tag
- Tag autocomplete

#### 4.3 Export & Import
- Export notes as Markdown files (one per note)
- Export entire workspace as folder structure
- Import from Obsidian vault
- Import from Markdown files

#### 4.4 Advanced Search
- Search by tag
- Search by date range
- Search by linked items
- Saved searches

#### 4.5 Collaboration (Future)
- Share notes with other users
- Comments on notes
- Real-time collaboration

---

## Technical Architecture

### Data Layer

#### Repository Pattern
```
lib/data/notes/
  ├── note.dart (domain model)
  ├── notes_repository.dart (interface)
  ├── supabase_notes_repository.dart (Supabase implementation)
  └── local_notes_repository.dart (local/demo implementation)
```

#### Domain Models
```dart
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
}
```

### UI Layer

#### Screen Structure
```
lib/features/notes/
  ├── notes_screen.dart (main list view)
  ├── note_editor_screen.dart (edit/create note)
  ├── daily_scratchpad_screen.dart (daily note)
  ├── project_note_screen.dart (structured project view)
  └── components/
      ├── note_card.dart
      ├── note_search_bar.dart
      ├── note_filters.dart
      ├── markdown_editor.dart
      ├── markdown_preview.dart
      └── backlinks_view.dart
```

#### State Management
- Use Riverpod for state
- Providers for:
  - Notes list (filtered, sorted)
  - Current note (editor state)
  - Search query
  - Active filters
  - Daily scratchpad (cached)

### Sync Strategy

#### Offline-First
1. All edits write to local storage immediately
2. Queue sync operations when offline
3. Background sync when online
4. Conflict resolution: last-write-wins (with timestamp)

#### Sync Queue
```dart
class SyncQueue {
  Future<void> syncPending();
  Future<void> enqueueCreate(Note note);
  Future<void> enqueueUpdate(Note note);
  Future<void> enqueueDelete(String noteId);
}
```

#### Conflict Resolution
- Show "Updated just now" indicator
- If conflict detected, show diff view
- User chooses: keep local, keep remote, merge

### Performance Considerations

#### Lazy Loading
- Load note content only when opened
- List view shows title + preview only
- Full-text search uses database indexes

#### Caching
- Cache daily scratchpad for current day
- Cache recently accessed notes (LRU, max 10)
- Invalidate on sync

#### Debouncing
- Auto-save: 550ms after typing stops
- Search: 300ms after typing stops
- Sync: batch operations every 5 seconds when online

---

## Migration Path

### From Secret Notes
1. Migrate existing secret notes from SharedPreferences to Supabase
2. Preserve note IDs and content
3. Convert to new note structure
4. Maintain backward compatibility during transition

### From Local to Supabase
1. Detect local notes on first Supabase login
2. Offer migration option
3. Batch upload with progress indicator
4. Keep local backup until confirmed

---

## Security & Privacy

### Data Protection
- All notes encrypted at rest (Supabase default)
- RLS policies ensure user isolation
- No sharing by default
- Export gives user full control

### Access Control
- Notes are private to user
- No admin access to note content
- Audit log for sensitive operations (optional)

---

## Future Enhancements

### AI Integration
- Summarize long notes
- Extract action items
- Suggest related notes
- Auto-tag based on content

### Mobile-Specific
- Voice notes (transcribe to text)
- Quick capture widget
- Siri shortcuts
- Share extension

### Desktop-Specific
- Keyboard shortcuts
- Command palette integration
- Drag-and-drop attachments
- Multi-window support

### Integrations
- Calendar integration (notes for events)
- Email integration (save emails as notes)
- Web clipper (save web pages)
- API for third-party tools

---

## Success Metrics

### User Engagement
- Daily active users of notes feature
- Average notes created per user per week
- Notes linked to tasks/dates
- Search usage frequency

### Performance
- Time to create note: < 2 seconds
- Search results: < 500ms
- Sync latency: < 5 seconds
- Offline reliability: 100%

### Quality
- Note retention rate
- Project completion rate (projects with notes vs without)
- User satisfaction (feedback)

---

## Implementation Roadmap

### Sprint 1: Foundation
- [ ] Database schema (migration)
- [ ] Domain models
- [ ] Repository interface + Supabase implementation
- [ ] Basic note CRUD
- [ ] Simple list view

### Sprint 2: Editor
- [ ] Markdown editor with preview
- [ ] Formatting toolbar
- [ ] Auto-save
- [ ] Note editor screen

### Sprint 3: Daily Scratchpad
- [ ] Auto-create daily notes
- [ ] Link to dates
- [ ] Quick access from Today screen
- [ ] Daily scratchpad screen

### Sprint 4: Linking
- [ ] Wiki-link syntax (`[[Note]]`)
- [ ] Link parsing and storage
- [ ] Navigation via links
- [ ] Backlinks view

### Sprint 5: Projects
- [ ] Project note type
- [ ] Structured project fields
- [ ] Project templates
- [ ] Project list view

### Sprint 6: Search & Filters
- [ ] Full-text search
- [ ] Filters (type, pinned, date)
- [ ] Sort options
- [ ] Search UI

### Sprint 7: Integration
- [ ] Link notes to tasks
- [ ] Link notes to dates
- [ ] View links in task details
- [ ] Convert notes to tasks

### Sprint 8: Polish
- [ ] Offline sync queue
- [ ] Conflict resolution UI
- [ ] Export to Markdown
- [ ] Performance optimization

---

## Open Questions

1. **Attachments**: Should notes support images/files? (Phase 2+)
2. **Versioning**: Should we track note history? (Phase 3+)
3. **Sharing**: When should notes be shareable? (Phase 4+)
4. **AI**: What AI features add most value? (Phase 4+)
5. **Mobile vs Desktop**: Different UX patterns needed? (Ongoing)

---

## References

- Obsidian: Wiki-link syntax, daily notes, backlinks
- NotePlan: Project structure, date linking
- Amplenote: Task-note integration, lightweight structure
- Notion: Templates, structured data (but too heavy for MVP)
