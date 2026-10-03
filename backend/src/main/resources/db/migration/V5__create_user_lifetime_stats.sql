-- ==============================================================================
-- Aureli Money Manager - Create User Lifetime Stats Table and RLS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.user_lifetime_stats (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    total_earned DOUBLE PRECISION DEFAULT 0.0,
    total_spent DOUBLE PRECISION DEFAULT 0.0,
    total_saved DOUBLE PRECISION DEFAULT 0.0,
    achievements_unlocked TEXT,
    last_aggregated_at TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT fk_uls_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_lifetime_stats_user_id ON public.user_lifetime_stats (user_id);

-- Enable RLS
ALTER TABLE public.user_lifetime_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "User lifetime stats read policy" ON public.user_lifetime_stats;
CREATE POLICY "User lifetime stats read policy" ON public.user_lifetime_stats
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "User lifetime stats insert policy" ON public.user_lifetime_stats;
CREATE POLICY "User lifetime stats insert policy" ON public.user_lifetime_stats
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "User lifetime stats update policy" ON public.user_lifetime_stats;
CREATE POLICY "User lifetime stats update policy" ON public.user_lifetime_stats
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "User lifetime stats delete policy" ON public.user_lifetime_stats;
CREATE POLICY "User lifetime stats delete policy" ON public.user_lifetime_stats
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );
