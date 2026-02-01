-- Run this in Supabase SQL Editor so "Balance before" appears in Profile > Usage.
-- Add balance_after to credit_transactions so we can show "balance before deduction" in Usage view.
-- For deduction rows: balance_before = balance_after - amount (amount is negative).
ALTER TABLE credit_transactions
ADD COLUMN IF NOT EXISTS balance_after DOUBLE PRECISION;

COMMENT ON COLUMN credit_transactions.balance_after IS 'Balance after this transaction; set for deductions to derive balance before in usage UI.';
