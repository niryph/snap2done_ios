-- Complete SQL script to fix RLS issues and create helper functions
-- Run this in the Supabase SQL Editor

-- Check if the profiles table exists, create it if not
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE tablename = 'profiles') THEN
    CREATE TABLE profiles (
      id UUID PRIMARY KEY REFERENCES auth.users(id),
      username TEXT UNIQUE,
      full_name TEXT,
      avatar_url TEXT,
      provider TEXT,
      provider_id TEXT,
      provider_data JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  END IF;
END $$;

-- Check if the user_preferences table exists, create it if not
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE tablename = 'user_preferences') THEN
    CREATE TABLE user_preferences (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES auth.users(id) NOT NULL,
      theme TEXT DEFAULT 'system',
      notification_enabled BOOLEAN DEFAULT true,
      reminder_time TEXT DEFAULT '09:00:00',
      premium_tier TEXT DEFAULT 'free',
      scan_count INTEGER DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  END IF;
END $$;

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE images ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_responses ENABLE ROW LEVEL SECURITY;

-- Drop and recreate all policies for profiles table
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

CREATE POLICY "Users can view their own profile" 
ON profiles FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete their own profile" 
ON profiles FOR DELETE 
USING (auth.uid() = id);

-- Drop and recreate all policies for user_preferences table
DROP POLICY IF EXISTS "Users can view their own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can update their own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can insert their own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can delete their own preferences" ON user_preferences;

CREATE POLICY "Users can view their own preferences" 
ON user_preferences FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences" 
ON user_preferences FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own preferences" 
ON user_preferences FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own preferences" 
ON user_preferences FOR DELETE 
USING (auth.uid() = user_id);

-- Drop and recreate all policies for cards table
DROP POLICY IF EXISTS "Users can view their own cards" ON cards;
DROP POLICY IF EXISTS "Users can update their own cards" ON cards;
DROP POLICY IF EXISTS "Users can insert their own cards" ON cards;
DROP POLICY IF EXISTS "Users can delete their own cards" ON cards;

CREATE POLICY "Users can view their own cards" 
ON cards FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own cards" 
ON cards FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cards" 
ON cards FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cards" 
ON cards FOR DELETE 
USING (auth.uid() = user_id);

-- Create or replace helper functions (SECURITY DEFINER functions bypass RLS)

-- Function to create a user profile
CREATE OR REPLACE FUNCTION create_profile(
  user_id UUID,
  user_name TEXT,
  user_full_name TEXT DEFAULT NULL,
  user_provider TEXT DEFAULT 'email'
) RETURNS VOID AS $$
BEGIN
  -- First check if profile exists
  IF EXISTS (SELECT 1 FROM profiles WHERE id = user_id) THEN
    RETURN; -- Profile already exists, skip
  END IF;
  
  INSERT INTO profiles (id, username, full_name, provider)
  VALUES (user_id, user_name, user_full_name, user_provider);
  
  -- Also create default preferences
  PERFORM create_user_preferences(user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create user preferences
CREATE OR REPLACE FUNCTION create_user_preferences(
  user_id UUID,
  user_theme TEXT DEFAULT 'system',
  notification_enabled BOOLEAN DEFAULT true,
  reminder_time TEXT DEFAULT '09:00:00',
  premium_tier TEXT DEFAULT 'free',
  scan_count INT DEFAULT 0
) RETURNS VOID AS $$
BEGIN
  -- First check if preferences exists
  IF EXISTS (SELECT 1 FROM user_preferences WHERE user_id = user_id) THEN
    RETURN; -- Preferences already exist, skip
  END IF;
  
  INSERT INTO user_preferences (
    user_id, 
    theme, 
    notification_enabled, 
    reminder_time, 
    premium_tier, 
    scan_count
  )
  VALUES (
    user_id, 
    user_theme, 
    notification_enabled, 
    reminder_time, 
    premium_tier, 
    scan_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to test permissions
CREATE OR REPLACE FUNCTION test_permissions()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  result = json_build_object(
    'user_id', auth.uid(),
    'has_profile', EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()),
    'has_preferences', EXISTS (SELECT 1 FROM user_preferences WHERE user_id = auth.uid()),
    'card_count', (SELECT COUNT(*) FROM cards WHERE user_id = auth.uid())
  );
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION create_profile TO authenticated;
GRANT EXECUTE ON FUNCTION create_profile TO anon;
GRANT EXECUTE ON FUNCTION create_user_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_preferences TO anon;
GRANT EXECUTE ON FUNCTION test_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION test_permissions TO anon;

-- Create trigger to automatically create profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, provider)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', new.email),
    COALESCE(new.raw_app_meta_data->>'provider', 'email')
  );
  
  INSERT INTO public.user_preferences (user_id)
  VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger for new user sign-up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user(); 