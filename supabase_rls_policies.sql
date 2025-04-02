-- Enable Row Level Security on the cards table
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to select their own cards
CREATE POLICY "Users can view their own cards" 
ON cards FOR SELECT 
USING (auth.uid() = user_id);

-- Create policy to allow users to insert their own cards
CREATE POLICY "Users can insert their own cards" 
ON cards FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create policy to allow users to update their own cards
CREATE POLICY "Users can update their own cards" 
ON cards FOR UPDATE 
USING (auth.uid() = user_id);

-- Create policy to allow users to delete their own cards
CREATE POLICY "Users can delete their own cards" 
ON cards FOR DELETE 
USING (auth.uid() = user_id);

-- If you want to check existing policies, you can run:
-- SELECT * FROM pg_policies WHERE tablename = 'cards';

-- If you need to drop existing policies:
-- DROP POLICY IF EXISTS "policy_name" ON cards; 