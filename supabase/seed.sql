-- RECOMMENDED: keep this in your repo at supabase/seed.sql and run in Supabase SQL Editor.

-- Ensure uuid generator exists
create extension if not exists "pgcrypto";

-- === 1) Insert a demo restaurant =========================
with r as (
  insert into public.restaurants (name, address, city, cuisine, open_time, close_time)
  values (
    'Maple & Co Burgers',
    '123 Broad Street',
    'Birmingham',
    ARRAY['Burgers','American','Casual'],
    '11:30'::time,
    '23:00'::time
  )
  returning id
),

-- === 2) Insert users (1 staff for this restaurant, 1 customer) ===
u as (
  insert into public.users (id, email, role, restaurant_id, phone)
  values
  (
    '00000000-0000-4000-a000-000000000001', -- STAFF UUID (fixed for testing)
    'staff@example.com',
    'staff',
    (select id from r),
    '07000000001'
  ),
  (
    '00000000-0000-4000-a000-000000000002', -- CUSTOMER UUID (fixed for testing)
    'customer@example.com',
    'customer',
    null,
    '07000000002'
  )
  returning id
),

-- === 3) Insert tables ====================================
t as (
  insert into public.tables (restaurant_id, label, capacity, status)
  values
    ((select id from r), 'T1', 2, 'free'),
    ((select id from r), 'T2', 4, 'free'),
    ((select id from r), 'T3', 6, 'free')
  returning id, label
),

-- === 4) Insert menu items ================================
m as (
  insert into public.menu_items (restaurant_id, name, category, price, photo_url, description)
  values
    ((select id from r), 'Classic Cheeseburger', 'Mains', 10.95, null, 'Beef patty, cheddar, house sauce'),
    ((select id from r), 'Maple BBQ Burger',     'Mains', 12.50, null, 'Smoky maple BBQ glaze, onion rings'),
    ((select id from r), 'Crispy Chicken Burger','Mains', 11.95, null, 'Buttermilk chicken, slaw, pickles'),
    ((select id from r), 'Skin-on Fries',        'Sides', 3.95,  null, 'Sea-salt, skin-on'),
    ((select id from r), 'Sweet Potato Fries',   'Sides', 4.50,  null, 'Paprika dust'),
    ((select id from r), 'Chocolate Brownie',    'Desserts', 5.95, null, 'Warm brownie, vanilla ice cream')
  returning id
)

-- === 5) Insert sample bookings ===========================
insert into public.bookings
  (restaurant_id, table_id, user_id, party_size, date, time, status, late_status)
values
  (
    (select id from r),
    (select id from t where label = 'T2' limit 1),
    '00000000-0000-4000-a000-000000000002', -- customer
    4,
    (current_date + interval '1 day')::date,
    '19:00'::time,
    'confirmed',
    'on_time'
  ),
  (
    (select id from r),
    (select id from t where label = 'T1' limit 1),
    '00000000-0000-4000-a000-000000000002', -- customer
    2,
    (current_date + interval '2 day')::date,
    '12:30'::time,
    'confirmed',
    'on_time'
  );

