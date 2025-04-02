-- Create hydration_settings table
CREATE TABLE IF NOT EXISTS hydration_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_goal DECIMAL NOT NULL DEFAULT 2000.0, -- Default 2000ml daily goal
    unit VARCHAR(10) NOT NULL DEFAULT 'ml',      -- Unit of measurement (ml, oz, etc.)
    reminder_interval INTEGER DEFAULT 60,         -- Reminder interval in minutes
    start_time TIME DEFAULT '08:00',             -- Start time for reminders
    end_time TIME DEFAULT '22:00',               -- End time for reminders
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id)
);

-- Create hydration_entries table
CREATE TABLE IF NOT EXISTS hydration_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL NOT NULL,
    unit VARCHAR(10) NOT NULL DEFAULT 'ml',
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hydration_entries_user_timestamp ON hydration_entries(user_id, timestamp);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS set_timestamp_hydration_settings ON hydration_settings;
CREATE TRIGGER set_timestamp_hydration_settings
    BEFORE UPDATE ON hydration_settings
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp_hydration_entries ON hydration_entries;
CREATE TRIGGER set_timestamp_hydration_entries
    BEFORE UPDATE ON hydration_entries
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Create RLS policies for hydration_settings
ALTER TABLE hydration_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own hydration settings" ON hydration_settings;
CREATE POLICY "Users can view their own hydration settings"
    ON hydration_settings FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own hydration settings" ON hydration_settings;
CREATE POLICY "Users can insert their own hydration settings"
    ON hydration_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own hydration settings" ON hydration_settings;
CREATE POLICY "Users can update their own hydration settings"
    ON hydration_settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create RLS policies for hydration_entries
ALTER TABLE hydration_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own hydration entries" ON hydration_entries;
CREATE POLICY "Users can view their own hydration entries"
    ON hydration_entries FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own hydration entries" ON hydration_entries;
CREATE POLICY "Users can insert their own hydration entries"
    ON hydration_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own hydration entries" ON hydration_entries;
CREATE POLICY "Users can update their own hydration entries"
    ON hydration_entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own hydration entries" ON hydration_entries;
CREATE POLICY "Users can delete their own hydration entries"
    ON hydration_entries FOR DELETE
    USING (auth.uid() = user_id); 