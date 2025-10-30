-- Add media_urls column to marketplace_listings table
-- Run this in Supabase SQL Editor

ALTER TABLE public.marketplace_listings
ADD COLUMN IF NOT EXISTS media_urls text[] DEFAULT '{}';
