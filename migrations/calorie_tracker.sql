-- Create calorie_tracker_settings table
CREATE TABLE IF NOT EXISTS calorie_tracker_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_goal DECIMAL NOT NULL DEFAULT 2000.0,
    macro_goals JSONB NOT NULL DEFAULT '{"carbs": 50.0, "protein": 30.0, "fat": 20.0}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id)
);

-- Create calorie_entries table
CREATE TABLE IF NOT EXISTS calorie_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    calories DECIMAL NOT NULL,
    carbs DECIMAL NOT NULL DEFAULT 0,
    protein DECIMAL NOT NULL DEFAULT 0,
    fat DECIMAL NOT NULL DEFAULT 0,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_calorie_entries_user_timestamp ON calorie_entries(user_id, timestamp);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER set_timestamp_calorie_tracker_settings
    BEFORE UPDATE ON calorie_tracker_settings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_calorie_entries
    BEFORE UPDATE ON calorie_entries
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp(); 