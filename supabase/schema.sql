-- Needed for gen_random_uuid()
create extension if not exists "pgcrypto";

-- 1) RESTAURANTS FIRST (others can reference it)
create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  city text,
  cuisine text[] default '{}',
  open_time time,
  close_time time,
  created_at timestamptz default now()
);

-- 2) USERS (may reference restaurants)
-- NOTE: we’ll insert with id = auth.uid() from the app after login.
create table if not exists public.users (
  id uuid primary key,
  email text unique not null,
  role text check (role in ('customer','staff')) default 'customer',
  restaurant_id uuid references public.restaurants(id),
  phone text,
  webpush_endpoint text,
  created_at timestamptz default now()
);

-- 3) TABLES (restaurant tables)
create table if not exists public.tables (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  label text,
  capacity int,
  status text check (status in ('free','reserved','occupied')) default 'free'
);

-- 4) MENU ITEMS
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  name text not null,
  category text,
  price numeric(10,2) not null default 0,
  photo_url text,
  description text
);

-- 5) BOOKINGS
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  table_id uuid references public.tables(id),
  user_id uuid references public.users(id),
  party_size int not null,
  date date not null,
  time time not null,
  status text check (status in ('pending','confirmed','seated','cancelled')) default 'confirmed',
  late_status text check (late_status in ('on_time','late_5','late_15','late_15_plus')) default 'on_time',
  created_at timestamptz not null default now()
);

-- 6) INFLUENCER POSTS (future)
create table if not exists public.influencer_posts (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  author text,
  media_url text,
  caption text,
  platform text,
  created_at timestamptz not null default now()
);

-- Enable Row Level Security
alter table public.users enable row level security;
alter table public.restaurants enable row level security;
alter table public.tables enable row level security;
alter table public.menu_items enable row level security;
alter table public.bookings enable row level security;
alter table public.influencer_posts enable row level security;

-- RLS POLICIES

-- Users: read/update own row
drop policy if exists "users_read_own" on public.users;
create policy "users_read_own" on public.users
  for select using (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- Restaurants + Menu: public read
drop policy if exists "restaurants_public_read" on public.restaurants;
create policy "restaurants_public_read" on public.restaurants
  for select using (true);

drop policy if exists "menu_public_read" on public.menu_items;
create policy "menu_public_read" on public.menu_items
  for select using (true);

-- Staff manage their own restaurant/menu
drop policy if exists "restaurants_staff_manage" on public.restaurants;
create policy "restaurants_staff_manage" on public.restaurants
  for all using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'staff'
        and u.restaurant_id = restaurants.id
    )
  );

drop policy if exists "menu_staff_manage" on public.menu_items;
create policy "menu_staff_manage" on public.menu_items
  for all using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'staff'
        and u.restaurant_id = menu_items.restaurant_id
    )
  );

-- Tables: public can read (optional), staff can write for their restaurant
drop policy if exists "tables_public_read" on public.tables;
create policy "tables_public_read" on public.tables
  for select using (true);

drop policy if exists "tables_staff_write" on public.tables;
create policy "tables_staff_write" on public.tables
  for all using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'staff'
        and u.restaurant_id = tables.restaurant_id
    )
  );

-- Bookings: customers own / staff manage by restaurant
drop policy if exists "bookings_customer_create" on public.bookings;
create policy "bookings_customer_create" on public.bookings
  for insert with check (auth.uid() = user_id);

drop policy if exists "bookings_customer_read_own" on public.bookings;
create policy "bookings_customer_read_own" on public.bookings
  for select using (auth.uid() = user_id);

drop policy if exists "bookings_customer_update_own" on public.bookings;
create policy "bookings_customer_update_own" on public.bookings
  for update using (auth.uid() = user_id);

drop policy if exists "bookings_staff_read_write_restaurant" on public.bookings;
create policy "bookings_staff_read_write_restaurant" on public.bookings
  for all using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid()
        and u.role = 'staff'
        and u.restaurant_id = bookings.restaurant_id
    )
  );

