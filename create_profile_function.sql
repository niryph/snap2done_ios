-- Function to create a user profile bypassing RLS
-- This should be run in the Supabase SQL editor

-- First, create the function
CREATE OR REPLACE FUNCTION create_profile(
  user_id UUID,
  user_name TEXT,
  user_full_name TEXT DEFAULT NULL,
  user_provider TEXT DEFAULT 'email'
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, provider)
  VALUES (user_id, user_name, user_full_name, user_provider);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions on the function
GRANT EXECUTE ON FUNCTION create_profile TO authenticated;
GRANT EXECUTE ON FUNCTION create_profile TO anon;

-- Check the RLS policies on the profiles table
SELECT *
FROM pg_policies
WHERE tablename = 'profiles';

-- If you need to enable RLS on the profiles table
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;

-- Set up proper RLS policies for the profiles table
DROP POLICY IF EXISTS "Allow users to view their own profile" ON public.profiles;
CREATE POLICY "Allow users to view their own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Allow users to update their own profile" ON public.profiles;
CREATE POLICY "Allow users to update their own profile"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.profiles;
CREATE POLICY "Allow users to insert their own profile"
ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Do the same for user_preferences table
ALTER TABLE IF EXISTS public.user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users to view their own preferences" ON public.user_preferences;
CREATE POLICY "Allow users to view their own preferences"
ON public.user_preferences
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to update their own preferences" ON public.user_preferences;
CREATE POLICY "Allow users to update their own preferences"
ON public.user_preferences
FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to insert their own preferences" ON public.user_preferences;
CREATE POLICY "Allow users to insert their own preferences"
ON public.user_preferences
FOR INSERT
WITH CHECK (auth.uid() = user_id); 