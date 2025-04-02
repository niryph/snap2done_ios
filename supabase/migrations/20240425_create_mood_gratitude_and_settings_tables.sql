-- Create mood_gratitude_entries table
CREATE TABLE IF NOT EXISTS mood_gratitude_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    mood VARCHAR(50) NOT NULL,
    mood_notes TEXT,
    gratitude_items TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create user_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_budget DECIMAL(10,2) DEFAULT 100.00,
    currency VARCHAR(3) DEFAULT 'USD',
    reminder_enabled BOOLEAN DEFAULT false,
    reminder_time TIME,
    mood_reminders_enabled BOOLEAN DEFAULT false,
    mood_reminder_time TIME DEFAULT '09:00',
    max_gratitude_items INTEGER DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alter user_settings to add mood gratitude settings
-- Only if the columns don't already exist
DO $$
BEGIN
    -- Add mood_reminders_enabled column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_settings' AND column_name = 'mood_reminders_enabled') THEN
        ALTER TABLE user_settings ADD COLUMN mood_reminders_enabled BOOLEAN DEFAULT false;
    END IF;
    
    -- Add mood_reminder_time column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_settings' AND column_name = 'mood_reminder_time') THEN
        ALTER TABLE user_settings ADD COLUMN mood_reminder_time TIME DEFAULT '09:00';
    END IF;
    
    -- Add max_gratitude_items column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_settings' AND column_name = 'max_gratitude_items') THEN
        ALTER TABLE user_settings ADD COLUMN max_gratitude_items INTEGER DEFAULT 3;
    END IF;
END
$$;

-- Create indexes
CREATE INDEX idx_mood_gratitude_entries_user_id ON mood_gratitude_entries(user_id);
CREATE INDEX idx_mood_gratitude_entries_date ON mood_gratitude_entries(date);

-- Create the update_updated_at_column function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updating the updated_at column
CREATE TRIGGER update_mood_gratitude_entries_updated_at
    BEFORE UPDATE ON mood_gratitude_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for updating the updated_at column on user_settings
CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable row level security
ALTER TABLE mood_gratitude_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for mood_gratitude_entries
CREATE POLICY "Users can view their own mood and gratitude entries"
    ON mood_gratitude_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own mood and gratitude entries"
    ON mood_gratitude_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own mood and gratitude entries"
    ON mood_gratitude_entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own mood and gratitude entries"
    ON mood_gratitude_entries FOR DELETE
    USING (auth.uid() = user_id);

-- Create policies for user_settings
CREATE POLICY "Users can view their own settings"
    ON user_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings"
    ON user_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
    ON user_settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id); 