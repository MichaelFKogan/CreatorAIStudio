-- ============================================
-- DATABASE MIGRATION: Add 'falai' Provider
-- ============================================
-- Run this SQL in your Supabase Dashboard SQL Editor
-- Dashboard > SQL Editor > New Query > Paste and Run
--
-- This migration updates the pending_jobs table to allow 'falai' as a valid provider
-- for fal.ai API integration

-- Step 1: Drop the existing check constraint
ALTER TABLE pending_jobs 
DROP CONSTRAINT IF EXISTS pending_jobs_provider_check;

-- Step 2: Add the new check constraint with 'falai' included
ALTER TABLE pending_jobs 
ADD CONSTRAINT pending_jobs_provider_check 
CHECK (provider IN ('runware', 'wavespeed', 'falai'));

-- ============================================
-- VERIFICATION
-- ============================================
-- Verify the constraint was updated:
-- SELECT conname, pg_get_constraintdef(oid) 
-- FROM pg_constraint 
-- WHERE conrelid = 'pending_jobs'::regclass 
-- AND conname = 'pending_jobs_provider_check';

