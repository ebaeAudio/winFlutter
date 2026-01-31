-- Notes System Migration
-- Creates tables for notes, note links, note templates, and note tags
-- Supports: inbox notes, project notes, daily scratchpads, wiki-style linking

-- 1) Create `notes` table
CREATE TABLE IF NOT EXISTS public.notes (
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
  template_id uuid, -- Will reference note_templates(id) after that table is created
  
  -- Daily scratchpad link
  date date, -- For daily notes: YYYY-MM-DD
  
  -- Timestamps
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_accessed_at timestamptz,
  
  -- Constraints
  CONSTRAINT notes_type_check CHECK (note_type IN ('note', 'project', 'daily', 'inbox')),
  CONSTRAINT notes_daily_date_check CHECK (
    (note_type = 'daily' AND date IS NOT NULL) OR
    (note_type != 'daily')
  )
);

-- Indexes for notes
CREATE INDEX IF NOT EXISTS notes_user_id_idx ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS notes_type_idx ON public.notes(user_id, note_type);
CREATE INDEX IF NOT EXISTS notes_date_idx ON public.notes(user_id, date) WHERE date IS NOT NULL;
CREATE INDEX IF NOT EXISTS notes_pinned_idx ON public.notes(user_id, pinned) WHERE pinned = true;
CREATE INDEX IF NOT EXISTS notes_updated_at_idx ON public.notes(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS notes_archived_idx ON public.notes(user_id, archived) WHERE archived = false;

-- Full-text search index (single line so migration runner does not split the expression)
CREATE INDEX IF NOT EXISTS notes_search_idx ON public.notes USING gin((setweight(to_tsvector('english', coalesce(title, '')), 'A') || setweight(to_tsvector('english', coalesce(content, '')), 'B')));

-- 2) Create `note_links` table for bidirectional linking
CREATE TABLE IF NOT EXISTS public.note_links (
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
  
  -- Constraints
  CONSTRAINT note_links_source_type_check CHECK (source_type IN ('note', 'task', 'date', 'habit')),
  CONSTRAINT note_links_target_type_check CHECK (target_type IN ('note', 'task', 'date', 'habit')),
  
  -- Prevent duplicates
  UNIQUE(user_id, source_type, source_id, target_type, target_id)
);

-- Indexes for note_links
CREATE INDEX IF NOT EXISTS note_links_source_idx ON public.note_links(user_id, source_type, source_id);
CREATE INDEX IF NOT EXISTS note_links_target_idx ON public.note_links(user_id, target_type, target_id);
CREATE INDEX IF NOT EXISTS note_links_user_id_idx ON public.note_links(user_id);

-- 3) Create `note_templates` table
CREATE TABLE IF NOT EXISTS public.note_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  name text NOT NULL,
  content text NOT NULL,
  note_type text NOT NULL DEFAULT 'note',
  
  is_system boolean NOT NULL DEFAULT false, -- Built-in templates
  is_default boolean NOT NULL DEFAULT false, -- Default for note_type
  
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  CONSTRAINT note_templates_type_check CHECK (note_type IN ('note', 'project', 'daily', 'inbox')),
  UNIQUE(user_id, name)
);

-- Indexes for note_templates
CREATE INDEX IF NOT EXISTS note_templates_user_id_idx ON public.note_templates(user_id);
CREATE INDEX IF NOT EXISTS note_templates_type_idx ON public.note_templates(user_id, note_type);

-- 4) Add foreign key from notes to note_templates (now that templates table exists)
ALTER TABLE public.notes
  ADD CONSTRAINT notes_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES public.note_templates(id) ON DELETE SET NULL;

-- 5) Create `note_tags` table (optional tagging system)
CREATE TABLE IF NOT EXISTS public.note_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  note_id uuid NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  tag text NOT NULL,
  
  created_at timestamptz NOT NULL DEFAULT now(),
  
  UNIQUE(note_id, tag)
);

-- Indexes for note_tags
CREATE INDEX IF NOT EXISTS note_tags_note_id_idx ON public.note_tags(note_id);
CREATE INDEX IF NOT EXISTS note_tags_tag_idx ON public.note_tags(user_id, tag);

-- 6) Enable RLS on all tables
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.note_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.note_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.note_tags ENABLE ROW LEVEL SECURITY;

-- 7) RLS Policies for `notes`
-- Users can only access their own notes
DROP POLICY IF EXISTS "notes_select_own" ON public.notes;
CREATE POLICY "notes_select_own"
ON public.notes
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notes_insert_own" ON public.notes;
CREATE POLICY "notes_insert_own"
ON public.notes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notes_update_own" ON public.notes;
CREATE POLICY "notes_update_own"
ON public.notes
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notes_delete_own" ON public.notes;
CREATE POLICY "notes_delete_own"
ON public.notes
FOR DELETE
USING (auth.uid() = user_id);

-- 8) RLS Policies for `note_links`
DROP POLICY IF EXISTS "note_links_select_own" ON public.note_links;
CREATE POLICY "note_links_select_own"
ON public.note_links
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_links_insert_own" ON public.note_links;
CREATE POLICY "note_links_insert_own"
ON public.note_links
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_links_update_own" ON public.note_links;
CREATE POLICY "note_links_update_own"
ON public.note_links
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_links_delete_own" ON public.note_links;
CREATE POLICY "note_links_delete_own"
ON public.note_links
FOR DELETE
USING (auth.uid() = user_id);

-- 9) RLS Policies for `note_templates`
DROP POLICY IF EXISTS "note_templates_select_own" ON public.note_templates;
CREATE POLICY "note_templates_select_own"
ON public.note_templates
FOR SELECT
USING (auth.uid() = user_id OR is_system = true);

DROP POLICY IF EXISTS "note_templates_insert_own" ON public.note_templates;
CREATE POLICY "note_templates_insert_own"
ON public.note_templates
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_templates_update_own" ON public.note_templates;
CREATE POLICY "note_templates_update_own"
ON public.note_templates
FOR UPDATE
USING (auth.uid() = user_id AND is_system = false)
WITH CHECK (auth.uid() = user_id AND is_system = false);

DROP POLICY IF EXISTS "note_templates_delete_own" ON public.note_templates;
CREATE POLICY "note_templates_delete_own"
ON public.note_templates
FOR DELETE
USING (auth.uid() = user_id AND is_system = false);

-- 10) RLS Policies for `note_tags`
DROP POLICY IF EXISTS "note_tags_select_own" ON public.note_tags;
CREATE POLICY "note_tags_select_own"
ON public.note_tags
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_tags_insert_own" ON public.note_tags;
CREATE POLICY "note_tags_insert_own"
ON public.note_tags
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_tags_update_own" ON public.note_tags;
CREATE POLICY "note_tags_update_own"
ON public.note_tags
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "note_tags_delete_own" ON public.note_tags;
CREATE POLICY "note_tags_delete_own"
ON public.note_tags
FOR DELETE
USING (auth.uid() = user_id);

-- 11) Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS notes_updated_at_trigger ON public.notes;
CREATE TRIGGER notes_updated_at_trigger
  BEFORE UPDATE ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION update_notes_updated_at();

-- 12) Function to update note_templates updated_at timestamp
CREATE OR REPLACE FUNCTION update_note_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS note_templates_updated_at_trigger ON public.note_templates;
CREATE TRIGGER note_templates_updated_at_trigger
  BEFORE UPDATE ON public.note_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_note_templates_updated_at();

-- 13) Function to ensure only one daily note per user per date
CREATE OR REPLACE FUNCTION ensure_unique_daily_note()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.note_type = 'daily' AND NEW.date IS NOT NULL THEN
    -- Check if another daily note exists for this user and date
    IF EXISTS (
      SELECT 1 FROM public.notes
      WHERE user_id = NEW.user_id
        AND note_type = 'daily'
        AND date = NEW.date
        AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'A daily note already exists for this date';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce unique daily notes
DROP TRIGGER IF EXISTS notes_unique_daily_trigger ON public.notes;
CREATE TRIGGER notes_unique_daily_trigger
  BEFORE INSERT OR UPDATE ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION ensure_unique_daily_note();

-- 14) Default system templates: not inserted here because note_templates.user_id
--     references auth.users(id). The app can create per-user default templates on first use.
