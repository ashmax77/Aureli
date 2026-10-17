ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS client_request_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS uk_transactions_user_client_request
  ON public.transactions(user_id, client_request_id)
  WHERE client_request_id IS NOT NULL;