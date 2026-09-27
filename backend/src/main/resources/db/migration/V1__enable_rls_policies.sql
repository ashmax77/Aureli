-- ==============================================================================
-- Aureli Money Manager - Supabase Row Level Security (RLS) Policies Migration
-- ==============================================================================

-- 1. Helper function to resolve active user identity across Spring Boot session & Supabase JWT
CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS text AS $$
BEGIN
  RETURN COALESCE(
    NULLIF(current_setting('app.current_user_id', true), ''),
    NULLIF(auth.uid()::text, ''),
    NULLIF((current_setting('request.jwt.claims', true)::json ->> 'sub'), '')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2. Enable Row Level Security (RLS) on all application tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.category_budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_alert_logs ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 3. RLS Policies for `users` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
CREATE POLICY "Users can read own profile" ON public.users
  FOR SELECT USING (firebase_uid = current_app_user_id() OR id::text = current_app_user_id());

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (firebase_uid = current_app_user_id() OR id::text = current_app_user_id());

DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (firebase_uid = current_app_user_id() OR id::text = current_app_user_id());

-- ==============================================================================
-- 4. RLS Policies for `categories` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Categories read policy" ON public.categories;
CREATE POLICY "Categories read policy" ON public.categories
  FOR SELECT USING (
    user_id IS NULL 
    OR user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Categories write policy" ON public.categories;
CREATE POLICY "Categories write policy" ON public.categories
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Categories update policy" ON public.categories;
CREATE POLICY "Categories update policy" ON public.categories
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Categories delete policy" ON public.categories;
CREATE POLICY "Categories delete policy" ON public.categories
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 5. RLS Policies for `transactions` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Transactions read policy" ON public.transactions;
CREATE POLICY "Transactions read policy" ON public.transactions
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Transactions insert policy" ON public.transactions;
CREATE POLICY "Transactions insert policy" ON public.transactions
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Transactions update policy" ON public.transactions;
CREATE POLICY "Transactions update policy" ON public.transactions
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Transactions delete policy" ON public.transactions;
CREATE POLICY "Transactions delete policy" ON public.transactions
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 6. RLS Policies for `scheduled_transactions` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Scheduled transactions read policy" ON public.scheduled_transactions;
CREATE POLICY "Scheduled transactions read policy" ON public.scheduled_transactions
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Scheduled transactions write policy" ON public.scheduled_transactions;
CREATE POLICY "Scheduled transactions write policy" ON public.scheduled_transactions
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Scheduled transactions update policy" ON public.scheduled_transactions;
CREATE POLICY "Scheduled transactions update policy" ON public.scheduled_transactions
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Scheduled transactions delete policy" ON public.scheduled_transactions;
CREATE POLICY "Scheduled transactions delete policy" ON public.scheduled_transactions
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 7. RLS Policies for `category_budgets` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Category budgets read policy" ON public.category_budgets;
CREATE POLICY "Category budgets read policy" ON public.category_budgets
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Category budgets write policy" ON public.category_budgets;
CREATE POLICY "Category budgets write policy" ON public.category_budgets
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Category budgets update policy" ON public.category_budgets;
CREATE POLICY "Category budgets update policy" ON public.category_budgets
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 8. RLS Policies for `notifications` Table
-- ==============================================================================
DROP POLICY IF EXISTS "App notifications read policy" ON public.notifications;
CREATE POLICY "App notifications read policy" ON public.notifications
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "App notifications write policy" ON public.notifications;
CREATE POLICY "App notifications write policy" ON public.notifications
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "App notifications update policy" ON public.notifications;
CREATE POLICY "App notifications update policy" ON public.notifications
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 9. RLS Policies for `budget_alert_logs` Table
-- ==============================================================================
DROP POLICY IF EXISTS "Budget alert log read policy" ON public.budget_alert_logs;
CREATE POLICY "Budget alert log read policy" ON public.budget_alert_logs
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Budget alert log write policy" ON public.budget_alert_logs;
CREATE POLICY "Budget alert log write policy" ON public.budget_alert_logs
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- ==============================================================================
-- 10. RLS Policies for `user_devices` Table
-- ==============================================================================
DROP POLICY IF EXISTS "User devices read policy" ON public.user_devices;
CREATE POLICY "User devices read policy" ON public.user_devices
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "User devices write policy" ON public.user_devices;
CREATE POLICY "User devices write policy" ON public.user_devices
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "User devices update policy" ON public.user_devices;
CREATE POLICY "User devices update policy" ON public.user_devices
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );
