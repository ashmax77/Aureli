ALTER TABLE public.scheduled_transactions
  ADD COLUMN IF NOT EXISTS anchor_day INTEGER;

UPDATE public.scheduled_transactions
  SET anchor_day = EXTRACT(DAY FROM due_date)::INTEGER
  WHERE anchor_day IS NULL;
