-- First, drop the existing table
drop table if exists top_priorities_entries;

-- Create the modified table with direct task fields
create table if not exists top_priorities_entries (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  description text not null default '',
  notes text not null default '',
  position smallint not null default 0,
  is_completed boolean not null default false,
  reminder_time time,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  -- Each user can have exactly 3 priorities per date
  constraint unique_user_date_position unique(user_id, date, position),
  constraint valid_position check (position >= 0 and position <= 2)
);

-- Create index for faster date range queries
create index if not exists idx_top_priorities_entries_user_date 
on top_priorities_entries(user_id, date);

-- Add RLS policies
alter table top_priorities_entries enable row level security;

create policy "Users can view their own entries"
  on top_priorities_entries for select
  using (auth.uid() = user_id);

create policy "Users can insert their own entries"
  on top_priorities_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own entries"
  on top_priorities_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own entries"
  on top_priorities_entries for delete
  using (auth.uid() = user_id);

-- Create function to update updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

-- Create trigger to automatically update updated_at
create trigger update_top_priorities_entries_updated_at
  before update on top_priorities_entries
  for each row
  execute function update_updated_at_column(); 