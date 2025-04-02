-- Create expense_entries table
CREATE TABLE IF NOT EXISTS expense_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create user_settings table
CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_budget DECIMAL(10,2) NOT NULL DEFAULT 100.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    reminder_time TIME,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_expense_entries_user_id ON expense_entries(user_id);
CREATE INDEX idx_expense_entries_timestamp ON expense_entries(timestamp);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers
CREATE TRIGGER update_expense_entries_updated_at
    BEFORE UPDATE ON expense_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create RLS policies
ALTER TABLE expense_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Policies for expense_entries
CREATE POLICY "Users can view their own expenses"
    ON expense_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own expenses"
    ON expense_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own expenses"
    ON expense_entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own expenses"
    ON expense_entries FOR DELETE
    USING (auth.uid() = user_id);

-- Policies for user_settings
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