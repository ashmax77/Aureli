-- ==============================================================================
-- Aureli Money Manager - High-Performance Database Indexes Migration
-- Speeds up analytical aggregation, RLS checks, and prevents 504 query timeouts
-- ==============================================================================

-- 1. Fast lookup for Firebase User mapping & RLS identity verification
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid 
  ON public.users(firebase_uid);

-- 2. Transaction analytical queries (monthly summary, cash flow, date-range filters)
CREATE INDEX IF NOT EXISTS idx_transactions_user_date 
  ON public.transactions(user_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_user_type_date 
  ON public.transactions(user_id, type, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_user_type_cat 
  ON public.transactions(user_id, type, category_id);

CREATE INDEX IF NOT EXISTS idx_transactions_user_payment 
  ON public.transactions(user_id, payment_method, transaction_date);

-- 3. Category Budgets fast monthly lookups
CREATE INDEX IF NOT EXISTS idx_category_budgets_user_month 
  ON public.category_budgets(user_id, budget_month);

-- 4. Scheduled Transactions pending queries & due date cron scans
CREATE INDEX IF NOT EXISTS idx_scheduled_transactions_user_due 
  ON public.scheduled_transactions(user_id, due_date, status);

-- 5. Debt summary & status queries
CREATE INDEX IF NOT EXISTS idx_debts_user_status 
  ON public.debts(user_id, status);

-- 6. Notifications unread counter lookup
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
  ON public.notifications(user_id, is_read);
