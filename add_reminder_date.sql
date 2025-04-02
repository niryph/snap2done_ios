-- Add reminder_date column to tasks table
ALTER TABLE tasks
ADD COLUMN reminder_date TIMESTAMPTZ;

-- Add comment to the column
COMMENT ON COLUMN tasks.reminder_date IS 'The date and time when the task reminder should trigger';

-- Update RLS policy to allow users to update their own task reminders
CREATE POLICY "Users can update their own task reminders"
ON tasks
FOR UPDATE
USING (
  card_id IN (
    SELECT id 
    FROM cards 
    WHERE user_id = auth.uid()
  )
)
WITH CHECK (
  card_id IN (
    SELECT id 
    FROM cards 
    WHERE user_id = auth.uid()
  )
);

-- Add index for faster querying of upcoming reminders
CREATE INDEX idx_tasks_reminder_date ON tasks (reminder_date)
WHERE reminder_date IS NOT NULL; 