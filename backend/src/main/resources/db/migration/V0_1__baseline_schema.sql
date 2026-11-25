-- ==============================================================================
-- Aureli Money Manager - Baseline schema
--
-- Creates the core tables so an empty database (new Supabase project, local
-- Postgres, CI) can be built from the migrations alone. The existing production
-- database was baselined at version 3 (spring.flyway.baseline-version), so this
-- migration sits below the baseline there and never runs against it.
--
-- Every statement is idempotent and mirrors the JPA entities in
-- com.manager.money_manager.model.
-- ==============================================================================

-- Supabase provides auth.uid(); plain PostgreSQL does not. V1's RLS helper calls it,
-- so create a harmless stand-in only when the real function is absent.
DO $$
BEGIN
  IF to_regprocedure('auth.uid()') IS NULL THEN
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE FUNCTION auth.uid() RETURNS uuid
      LANGUAGE sql STABLE
      AS 'SELECT NULLIF(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.users (
    id BIGSERIAL PRIMARY KEY,
    firebase_uid VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    currency_code VARCHAR(255) NOT NULL DEFAULT 'LKR',
    onboarding_status VARCHAR(255) NOT NULL DEFAULT 'NOT_STARTED',
    onboarding_completed_at TIMESTAMP,
    savings_rate_percentage DOUBLE PRECISION NOT NULL DEFAULT 20.0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.user_devices (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    fcm_token VARCHAR(255) NOT NULL UNIQUE,
    platform VARCHAR(255),
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.categories (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    icon_key VARCHAR(255),
    color_key VARCHAR(255),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    is_system_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_categories_user_name_type UNIQUE (user_id, name, type)
);

CREATE TABLE IF NOT EXISTS public.category_budgets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    budget_month DATE NOT NULL,
    amount_limit NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_category_budgets_user_category_month UNIQUE (user_id, category_id, budget_month)
);

CREATE TABLE IF NOT EXISTS public.transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES public.categories(id),
    type VARCHAR(255) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    transaction_date DATE NOT NULL,
    note VARCHAR(255),
    payment_method VARCHAR(255) NOT NULL,
    is_savings_enabled BOOLEAN,
    savings_rate DOUBLE PRECISION,
    savings_amount NUMERIC(12, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.scheduled_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES public.categories(id),
    type VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    due_date DATE NOT NULL,
    payment_method VARCHAR(255) NOT NULL,
    note VARCHAR(255),
    recurring_frequency VARCHAR(255) NOT NULL DEFAULT 'ONCE',
    status VARCHAR(255) NOT NULL DEFAULT 'PENDING',
    reminder_days_before INTEGER NOT NULL DEFAULT 3,
    last_notified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body VARCHAR(1000) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- V3__performance_indexes.sql indexes public.debts(user_id, status), but the debt
-- module's real table is debt_records (created in V2). V3 cannot be edited safely
-- (it may already be recorded with a checksum in existing databases), so provide an
-- unused stand-in table that lets V3 run on a fresh database.
CREATE TABLE IF NOT EXISTS public.debts (
    user_id BIGINT,
    status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS public.budget_alert_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    budget_month DATE NOT NULL,
    threshold VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_budget_alert_logs_user_category_month_threshold
        UNIQUE (user_id, category_id, budget_month, threshold)
);
