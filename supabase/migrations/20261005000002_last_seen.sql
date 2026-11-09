-- "New since your last visit" markers. Additive: one column and one RPC.
-- Users cannot UPDATE profiles directly (that would let them change role/company);
-- this security-definer function only touches the caller's own last_seen_at.
alter table public.profiles add column last_seen_at timestamptz not null default now();

create function public.mark_feedback_seen() returns timestamptz
language sql security definer set search_path = public as
$$ update public.profiles set last_seen_at = now() where user_id = auth.uid() returning last_seen_at $$;

revoke all on function public.mark_feedback_seen() from public;
grant execute on function public.mark_feedback_seen() to authenticated;
