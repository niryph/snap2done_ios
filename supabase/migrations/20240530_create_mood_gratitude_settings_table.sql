-- Create dedicated mood_gratitude_settings table
CREATE TABLE IF NOT EXISTS mood_gratitude_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reminders_enabled BOOLEAN DEFAULT true,
    reminder_time TIME DEFAULT '09:00',
    max_gratitude_items INTEGER DEFAULT 3,
    favorite_moods TEXT[] DEFAULT '{"Happy", "Good", "Neutral", "Sad", "Angry"}',
    notification_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_mood_settings UNIQUE (user_id)
);

-- Create indexes
CREATE INDEX idx_mood_gratitude_settings_user_id ON mood_gratitude_settings(user_id);

-- Create trigger for updating the updated_at column
CREATE TRIGGER update_mood_gratitude_settings_updated_at
    BEFORE UPDATE ON mood_gratitude_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable row level security
ALTER TABLE mood_gratitude_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for mood_gratitude_settings
CREATE POLICY "Users can view their own mood gratitude settings"
    ON mood_gratitude_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own mood gratitude settings"
    ON mood_gratitude_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own mood gratitude settings"
    ON mood_gratitude_settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own mood gratitude settings"
    ON mood_gratitude_settings FOR DELETE
    USING (auth.uid() = user_id);

-- Add a function to migrate existing settings
CREATE OR REPLACE FUNCTION migrate_mood_settings_from_user_settings()
RETURNS void AS $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN SELECT 
        user_id, 
        mood_reminders_enabled, 
        mood_reminder_time, 
        max_gratitude_items 
    FROM user_settings
    WHERE mood_reminders_enabled IS NOT NULL
    LOOP
        -- Insert into new table if not already exists
        INSERT INTO mood_gratitude_settings (
            user_id,
            reminders_enabled,
            reminder_time,
            max_gratitude_items
        ) VALUES (
            user_record.user_id,
            user_record.mood_reminders_enabled,
            user_record.mood_reminder_time,
            user_record.max_gratitude_items
        )
        ON CONFLICT (user_id) DO NOTHING;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the migration function
SELECT migrate_mood_settings_from_user_settings();

-- Drop the migration function after use
DROP FUNCTION migrate_mood_settings_from_user_settings(); 