-- Lets a Super Admin see which logins exist for a company. Emails live in auth.users, which the app
-- cannot read, so this security-definer function exposes just these columns, and only to super admins.
create function public.list_business_admins(p_company_id uuid)
returns table (user_id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.user_id, u.email::text, p.created_at, u.last_sign_in_at
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where p.role = 'business_admin'
    and p.company_id = p_company_id
    and public.current_app_role() = 'super_admin'
  order by p.created_at
$$;

revoke all on function public.list_business_admins(uuid) from public;
grant execute on function public.list_business_admins(uuid) to authenticated;
