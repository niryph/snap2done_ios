-- Part 1: Create mood_gratitude_entries table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.mood_gratitude_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    mood VARCHAR(50) NOT NULL,
    mood_notes TEXT,
    gratitude_items TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mood_gratitude_entries_user_id ON public.mood_gratitude_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_mood_gratitude_entries_date ON public.mood_gratitude_entries(date);

-- Part 2: Create user_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_settings (
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

-- Part 3: Create the update_updated_at_column function if it doesn't exist
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Part 4: Create triggers
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_mood_gratitude_entries_updated_at'
    ) THEN
        CREATE TRIGGER update_mood_gratitude_entries_updated_at
            BEFORE UPDATE ON public.mood_gratitude_entries
            FOR EACH ROW
            EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_settings_updated_at'
    ) THEN
        CREATE TRIGGER update_user_settings_updated_at
            BEFORE UPDATE ON public.user_settings
            FOR EACH ROW
            EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END;
$$;

-- Part 5: Enable row level security
ALTER TABLE public.mood_gratitude_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- Part 6: Create policies for mood_gratitude_entries
DO $$
BEGIN
    -- Delete existing policies if they exist (to prevent duplicates)
    DROP POLICY IF EXISTS "Users can view their own mood and gratitude entries" ON public.mood_gratitude_entries;
    DROP POLICY IF EXISTS "Users can insert their own mood and gratitude entries" ON public.mood_gratitude_entries;
    DROP POLICY IF EXISTS "Users can update their own mood and gratitude entries" ON public.mood_gratitude_entries;
    DROP POLICY IF EXISTS "Users can delete their own mood and gratitude entries" ON public.mood_gratitude_entries;
    
    -- Create new policies
    CREATE POLICY "Users can view their own mood and gratitude entries"
        ON public.mood_gratitude_entries FOR SELECT
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their own mood and gratitude entries"
        ON public.mood_gratitude_entries FOR INSERT
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update their own mood and gratitude entries"
        ON public.mood_gratitude_entries FOR UPDATE
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete their own mood and gratitude entries"
        ON public.mood_gratitude_entries FOR DELETE
        USING (auth.uid() = user_id);
END;
$$;

-- Part 7: Create policies for user_settings
DO $$
BEGIN
    -- Delete existing policies if they exist (to prevent duplicates)
    DROP POLICY IF EXISTS "Users can view their own settings" ON public.user_settings;
    DROP POLICY IF EXISTS "Users can insert their own settings" ON public.user_settings;
    DROP POLICY IF EXISTS "Users can update their own settings" ON public.user_settings;
    
    -- Create new policies
    CREATE POLICY "Users can view their own settings"
        ON public.user_settings FOR SELECT
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their own settings"
        ON public.user_settings FOR INSERT
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update their own settings"
        ON public.user_settings FOR UPDATE
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END;
$$; 