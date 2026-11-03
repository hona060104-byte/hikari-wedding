-- HIKARI WEDDING starter schema
-- Run in Supabase SQL Editor. Review with a developer before production use.

create extension if not exists pgcrypto;

create type public.app_role as enum ('owner','staff','customer');
create type public.customer_group as enum ('retail','package');
create type public.garment_type as enum ('wedding_dress','ao_dai','suit','accessory');
create type public.rental_status as enum ('reserved','out','returned','cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text unique,
  role public.app_role not null default 'customer',
  customer_group public.customer_group,
  created_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  full_name text not null,
  phone text not null,
  address text,
  map_lat double precision,
  map_lng double precision,
  customer_group public.customer_group not null,
  notes text,
  created_at timestamptz not null default now()
);

create table public.service_packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(12,0) not null default 0 check(price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  package_id uuid references public.service_packages(id) on delete set null,
  package_name_snapshot text,
  package_price_snapshot numeric(12,0) not null default 0,
  deposit numeric(12,0) not null default 0,
  paid numeric(12,0) not null default 0,
  event_date date,
  status text not null default 'confirmed',
  notes text,
  created_at timestamptz not null default now()
);

create table public.garments (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  type public.garment_type not null,
  image_url text,
  size text,
  base_package_price numeric(12,0) not null default 0 check(base_package_price >= 0),
  completed_rentals integer not null default 0 check(completed_rentals >= 0),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table public.rentals (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete restrict,
  garment_id uuid not null references public.garments(id) on delete restrict,
  contract_id uuid references public.contracts(id) on delete set null,
  customer_group_snapshot public.customer_group not null,
  rental_number integer not null,
  price_snapshot numeric(12,0) not null check(price_snapshot >= 0),
  start_date date,
  due_date date,
  returned_at timestamptz,
  status public.rental_status not null default 'reserved',
  created_at timestamptz not null default now()
);

create table public.customer_files (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  file_url text not null,
  label text,
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid references public.contracts(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  amount numeric(12,0) not null check(amount >= 0),
  paid_at timestamptz not null default now(),
  method text,
  note text
);

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_staff_or_owner()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role in ('owner','staff')) $$;

-- Customer can only see their own record. Staff/owner can see all customer records.
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.service_packages enable row level security;
alter table public.contracts enable row level security;
alter table public.garments enable row level security;
alter table public.rentals enable row level security;
alter table public.customer_files enable row level security;
alter table public.payments enable row level security;

create policy "profile self or staff read" on public.profiles for select using (id=auth.uid() or public.is_staff_or_owner());
create policy "customer self or staff read" on public.customers for select using (profile_id=auth.uid() or public.is_staff_or_owner());
create policy "staff manage customers" on public.customers for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
create policy "packages visible" on public.service_packages for select using (active or public.is_staff_or_owner());
create policy "staff manage packages" on public.service_packages for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
create policy "contracts self or staff read" on public.contracts for select using (
  public.is_staff_or_owner() or exists(select 1 from public.customers c where c.id=customer_id and c.profile_id=auth.uid())
);
create policy "staff manage contracts" on public.contracts for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
-- Customers must not query the entire inventory. They can only see garments attached to their own rental rows.
create policy "staff read all garments" on public.garments for select using (public.is_staff_or_owner());
create policy "staff manage garments" on public.garments for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
create policy "customer sees own rental rows" on public.rentals for select using (
  public.is_staff_or_owner() or exists(select 1 from public.customers c where c.id=customer_id and c.profile_id=auth.uid())
);
create policy "staff manage rentals" on public.rentals for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
create policy "customer own files" on public.customer_files for select using (
  public.is_staff_or_owner() or exists(select 1 from public.customers c where c.id=customer_id and c.profile_id=auth.uid())
);
create policy "staff manage files" on public.customer_files for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());
create policy "customer own payments" on public.payments for select using (
  public.is_staff_or_owner() or exists(select 1 from public.customers c where c.id=customer_id and c.profile_id=auth.uid())
);
create policy "staff manage payments" on public.payments for all using (public.is_staff_or_owner()) with check (public.is_staff_or_owner());

-- Secure quote: customer gets only their own group price; staff/owner may request a group explicitly.
-- completed_rentals counts only rentals that have been marked returned.
create or replace function public.get_garment_quote(p_garment_id uuid, p_group public.customer_group default null)
returns table(garment_id uuid, garment_code text, garment_name text, customer_group public.customer_group, rental_count integer, price numeric)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_role public.app_role;
  v_group public.customer_group;
  v_base numeric(12,0);
  v_count integer;
  v_code text;
  v_name text;
begin
  select role, customer_group into v_role, v_group from public.profiles where id=auth.uid();
  if v_role is null then raise exception 'Unauthorized'; end if;
  if v_role='customer' then
    if p_group is not null and p_group <> v_group then raise exception 'Forbidden'; end if;
    v_group := v_group;
  else
    v_group := coalesce(p_group, 'package'::public.customer_group);
  end if;
  select base_package_price, completed_rentals, code, name
    into v_base, v_count, v_code, v_name
    from public.garments where id=p_garment_id and active=true;
  if not found then raise exception 'Garment not found'; end if;
  if v_group='package' then
    return query select p_garment_id, v_code, v_name, v_group, v_count,
      case when v_count >= 4 then 0::numeric else greatest(v_base - (v_count * 500000),0) end;
  else
    return query select p_garment_id, v_code, v_name, v_group, v_count,
      greatest((v_base + 1000000) - (v_count * 500000),0);
  end if;
end $$;

grant execute on function public.get_garment_quote(uuid, public.customer_group) to authenticated;

-- Rental completion must be handled by a trusted server-side operation in production:
-- mark returned, then increment garments.completed_rentals exactly once in one transaction.
-- Do not let customer clients write rental status or completed_rentals directly.
