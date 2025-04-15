-- Create attachments table
CREATE TABLE IF NOT EXISTS attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    wasabi_path TEXT NOT NULL,
    ocr_text TEXT,
    is_processed BOOLEAN DEFAULT false,
    original_filename TEXT,
    size_bytes BIGINT,
    mime_type TEXT,
    attachment_type VARCHAR(50) NOT NULL DEFAULT 'image',
    todo_entry_id UUID REFERENCES todo_entries(id) ON DELETE CASCADE,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_attachments_user_type ON attachments(user_id, attachment_type);
CREATE INDEX IF NOT EXISTS idx_attachments_todo_entry ON attachments(todo_entry_id);

-- Add comments to the table and columns
COMMENT ON TABLE attachments IS 'Stores metadata for all files (images, documents, audio) stored in Wasabi';
COMMENT ON COLUMN attachments.attachment_type IS 'Type of attachment (image, document, audio)';
COMMENT ON COLUMN attachments.todo_entry_id IS 'Reference to the associated todo entry';
COMMENT ON COLUMN attachments.description IS 'Optional description of the attachment';
COMMENT ON COLUMN attachments.metadata IS 'Additional metadata specific to the attachment type';

-- Enable RLS and create policy
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can only access their own attachments" ON attachments;

-- Create new policy
CREATE POLICY "Users can only access their own attachments"
ON attachments FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id); 