-- ==============================================================================
-- Aureli Money Manager - Loan & Debt Management Module Migration & RLS
-- ==============================================================================

-- 1. Create debt_records table
CREATE TABLE IF NOT EXISTS public.debt_records (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,
    counterparty_name VARCHAR(150) NOT NULL,
    counterparty_contact VARCHAR(100),
    principal_amount NUMERIC(12, 2) NOT NULL,
    interest_rate NUMERIC(5, 2),
    total_amount_due NUMERIC(12, 2) NOT NULL,
    amount_repaid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    remaining_amount NUMERIC(12, 2) NOT NULL,
    start_date DATE NOT NULL,
    due_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    reminder_days_before INT NOT NULL DEFAULT 3,
    last_notified_at TIMESTAMP,
    note VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_debt_records_user_id ON public.debt_records(user_id);
CREATE INDEX IF NOT EXISTS idx_debt_records_type ON public.debt_records(type);
CREATE INDEX IF NOT EXISTS idx_debt_records_status ON public.debt_records(status);
CREATE INDEX IF NOT EXISTS idx_debt_records_due_date ON public.debt_records(due_date);

-- 2. Create debt_repayments table
CREATE TABLE IF NOT EXISTS public.debt_repayments (
    id BIGSERIAL PRIMARY KEY,
    debt_record_id BIGINT NOT NULL REFERENCES public.debt_records(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    repayment_date DATE NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    note VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_debt_repayments_debt_record_id ON public.debt_repayments(debt_record_id);
CREATE INDEX IF NOT EXISTS idx_debt_repayments_user_id ON public.debt_repayments(user_id);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.debt_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_repayments ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for debt_records
DROP POLICY IF EXISTS "Debt records read policy" ON public.debt_records;
CREATE POLICY "Debt records read policy" ON public.debt_records
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt records write policy" ON public.debt_records;
CREATE POLICY "Debt records write policy" ON public.debt_records
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt records update policy" ON public.debt_records;
CREATE POLICY "Debt records update policy" ON public.debt_records
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt records delete policy" ON public.debt_records;
CREATE POLICY "Debt records delete policy" ON public.debt_records
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

-- 5. RLS Policies for debt_repayments
DROP POLICY IF EXISTS "Debt repayments read policy" ON public.debt_repayments;
CREATE POLICY "Debt repayments read policy" ON public.debt_repayments
  FOR SELECT USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt repayments write policy" ON public.debt_repayments;
CREATE POLICY "Debt repayments write policy" ON public.debt_repayments
  FOR INSERT WITH CHECK (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt repayments update policy" ON public.debt_repayments;
CREATE POLICY "Debt repayments update policy" ON public.debt_repayments
  FOR UPDATE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );

DROP POLICY IF EXISTS "Debt repayments delete policy" ON public.debt_repayments;
CREATE POLICY "Debt repayments delete policy" ON public.debt_repayments
  FOR DELETE USING (
    user_id::text = current_app_user_id() 
    OR user_id IN (SELECT id FROM public.users WHERE firebase_uid = current_app_user_id())
  );
