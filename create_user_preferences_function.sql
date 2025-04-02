-- Function to create user preferences bypassing RLS
-- This should be run in the Supabase SQL editor

-- First, create the function
CREATE OR REPLACE FUNCTION create_user_preferences(
  user_id UUID,
  user_theme TEXT DEFAULT 'system',
  notification_enabled BOOLEAN DEFAULT true,
  reminder_time TEXT DEFAULT '09:00:00',
  premium_tier TEXT DEFAULT 'free',
  scan_count INT DEFAULT 0
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.user_preferences (
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

-- Grant execution permissions on the function
GRANT EXECUTE ON FUNCTION create_user_preferences TO authenticated;
GRANT EXECUTE ON FUNCTION create_user_preferences TO anon; 