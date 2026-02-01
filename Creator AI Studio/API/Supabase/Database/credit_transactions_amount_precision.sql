-- Fix Z-Image-Turbo (and other sub-cent) amounts showing as -0.01 instead of -0.005.
-- If credit_transactions.amount is numeric(10,2) or similar, Postgres rounds -0.005 to -0.01 on insert.
-- Run this in Supabase SQL Editor so amounts like -0.005 are stored correctly.

-- Alter amount to support at least 4 decimal places (e.g. 0.005 for $0.005)
ALTER TABLE credit_transactions
  ALTER COLUMN amount TYPE numeric(12, 4);

COMMENT ON COLUMN credit_transactions.amount IS 'Transaction amount (positive = credit added, negative = deduction). Use 4 decimal places for sub-cent pricing (e.g. 0.005).';

-- Optional: ensure user_credits.balance also supports 4 decimal places
-- ALTER TABLE user_credits
--   ALTER COLUMN balance TYPE numeric(12, 4);
