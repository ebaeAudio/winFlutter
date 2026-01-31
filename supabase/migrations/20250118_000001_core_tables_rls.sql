-- Migration: Core Tables RLS Policies
--
-- CRITICAL SECURITY FIX: Enable Row Level Security on core user data tables
--
-- This migration adds RLS policies for:
-- - tasks
-- - habits
-- - habit_completions
-- - daily_reflections
-- - scoring_settings
--
-- Apply with Supabase CLI:
--   supabase db push
--
-- IMPORTANT: Verify these tables exist before applying. If tables don't exist,
-- this migration will fail. Create tables first if needed.

-- ============================================================================
-- TASKS TABLE
-- ============================================================================

-- Enable RLS on tasks table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tasks') THEN
    ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
    
    -- Drop existing policies if they exist (idempotent)
    DROP POLICY IF EXISTS "tasks_select_own" ON public.tasks;
    DROP POLICY IF EXISTS "tasks_insert_own" ON public.tasks;
    DROP POLICY IF EXISTS "tasks_update_own" ON public.tasks;
    DROP POLICY IF EXISTS "tasks_delete_own" ON public.tasks;
    
    -- Users can only select their own tasks
    CREATE POLICY "tasks_select_own"
    ON public.tasks
    FOR SELECT
    USING (auth.uid() = user_id);
    
    -- Users can only insert tasks for themselves
    CREATE POLICY "tasks_insert_own"
    ON public.tasks
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
    
    -- Users can only update their own tasks
    CREATE POLICY "tasks_update_own"
    ON public.tasks
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
    
    -- Users can only delete their own tasks
    CREATE POLICY "tasks_delete_own"
    ON public.tasks
    FOR DELETE
    USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- HABITS TABLE
-- ============================================================================

-- Enable RLS on habits table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'habits') THEN
    ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "habits_select_own" ON public.habits;
    DROP POLICY IF EXISTS "habits_insert_own" ON public.habits;
    DROP POLICY IF EXISTS "habits_update_own" ON public.habits;
    DROP POLICY IF EXISTS "habits_delete_own" ON public.habits;
    
    CREATE POLICY "habits_select_own"
    ON public.habits
    FOR SELECT
    USING (auth.uid() = user_id);
    
    CREATE POLICY "habits_insert_own"
    ON public.habits
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "habits_update_own"
    ON public.habits
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "habits_delete_own"
    ON public.habits
    FOR DELETE
    USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- HABIT_COMPLETIONS TABLE
-- ============================================================================

-- Enable RLS on habit_completions table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'habit_completions') THEN
    ALTER TABLE public.habit_completions ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "habit_completions_select_own" ON public.habit_completions;
    DROP POLICY IF EXISTS "habit_completions_insert_own" ON public.habit_completions;
    DROP POLICY IF EXISTS "habit_completions_update_own" ON public.habit_completions;
    DROP POLICY IF EXISTS "habit_completions_delete_own" ON public.habit_completions;
    
    -- Users can only access completions for their own habits
    -- This requires a join check since habit_completions references habits, not users directly
    CREATE POLICY "habit_completions_select_own"
    ON public.habit_completions
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM public.habits
        WHERE habits.id = habit_completions.habit_id
        AND habits.user_id = auth.uid()
      )
    );
    
    CREATE POLICY "habit_completions_insert_own"
    ON public.habit_completions
    FOR INSERT
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.habits
        WHERE habits.id = habit_completions.habit_id
        AND habits.user_id = auth.uid()
      )
    );
    
    CREATE POLICY "habit_completions_update_own"
    ON public.habit_completions
    FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.habits
        WHERE habits.id = habit_completions.habit_id
        AND habits.user_id = auth.uid()
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.habits
        WHERE habits.id = habit_completions.habit_id
        AND habits.user_id = auth.uid()
      )
    );
    
    CREATE POLICY "habit_completions_delete_own"
    ON public.habit_completions
    FOR DELETE
    USING (
      EXISTS (
        SELECT 1 FROM public.habits
        WHERE habits.id = habit_completions.habit_id
        AND habits.user_id = auth.uid()
      )
    );
  END IF;
END $$;

-- ============================================================================
-- DAILY_REFLECTIONS TABLE
-- ============================================================================

-- Enable RLS on daily_reflections table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'daily_reflections') THEN
    ALTER TABLE public.daily_reflections ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "daily_reflections_select_own" ON public.daily_reflections;
    DROP POLICY IF EXISTS "daily_reflections_insert_own" ON public.daily_reflections;
    DROP POLICY IF EXISTS "daily_reflections_update_own" ON public.daily_reflections;
    DROP POLICY IF EXISTS "daily_reflections_delete_own" ON public.daily_reflections;
    
    CREATE POLICY "daily_reflections_select_own"
    ON public.daily_reflections
    FOR SELECT
    USING (auth.uid() = user_id);
    
    CREATE POLICY "daily_reflections_insert_own"
    ON public.daily_reflections
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "daily_reflections_update_own"
    ON public.daily_reflections
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "daily_reflections_delete_own"
    ON public.daily_reflections
    FOR DELETE
    USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- SCORING_SETTINGS TABLE
-- ============================================================================

-- Enable RLS on scoring_settings table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'scoring_settings') THEN
    ALTER TABLE public.scoring_settings ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "scoring_settings_select_own" ON public.scoring_settings;
    DROP POLICY IF EXISTS "scoring_settings_insert_own" ON public.scoring_settings;
    DROP POLICY IF EXISTS "scoring_settings_update_own" ON public.scoring_settings;
    DROP POLICY IF EXISTS "scoring_settings_delete_own" ON public.scoring_settings;
    
    CREATE POLICY "scoring_settings_select_own"
    ON public.scoring_settings
    FOR SELECT
    USING (auth.uid() = user_id);
    
    CREATE POLICY "scoring_settings_insert_own"
    ON public.scoring_settings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "scoring_settings_update_own"
    ON public.scoring_settings
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "scoring_settings_delete_own"
    ON public.scoring_settings
    FOR DELETE
    USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION QUERY (for manual check)
-- ============================================================================
-- Run this after applying the migration to verify RLS is enabled:
--
-- SELECT 
--   schemaname,
--   tablename,
--   rowsecurity as rls_enabled
-- FROM pg_tables
-- WHERE schemaname = 'public'
--   AND tablename IN ('tasks', 'habits', 'habit_completions', 'daily_reflections', 'scoring_settings')
-- ORDER BY tablename;
--
-- All should show rls_enabled = true
