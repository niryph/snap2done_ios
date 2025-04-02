-- SQL to check the database tables and structure
-- Run this in the Supabase SQL Editor

-- Check if profiles table exists and its structure
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM 
  information_schema.columns
WHERE 
  table_name = 'profiles'
ORDER BY 
  ordinal_position;

-- Check if user_preferences table exists and its structure
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM 
  information_schema.columns
WHERE 
  table_name = 'user_preferences'
ORDER BY 
  ordinal_position;

-- Check if cards table exists and its structure
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM 
  information_schema.columns
WHERE 
  table_name = 'cards'
ORDER BY 
  ordinal_position;

-- Check existing RLS policies
SELECT 
  tablename, 
  policyname, 
  permissive,
  cmd
FROM 
  pg_policies
WHERE 
  tablename IN ('profiles', 'user_preferences', 'cards');

-- Check existing users
SELECT 
  id, 
  email, 
  role,
  created_at
FROM 
  auth.users
ORDER BY 
  created_at DESC
LIMIT 10; 