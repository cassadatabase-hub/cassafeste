-- ======================================================================
--  CASSA BINENGO NUOVO SOFTWARE - SCHEMA SUPABASE (POSTGRES)
--  Da eseguire in Supabase: SQL Editor > New query
-- ======================================================================

-- 00. Estensioni utili
create extension if not exists "pgcrypto";

-- 01. Funzione helper per aggiornare updated_date automaticamente
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_date = now();
  return new;
end;
$$ language plpgsql volatile;

-- ======================================================================
-- 02. TABELLA: profiles (utenti con ruolo)
-- ======================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('admin','user')),
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

-- Trigger per creare profilo automatico al signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role) values (new.id, 'user');
  return new;
end;
$$ language plpgsql volatile security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 03. TABELLA: categories (reparti)
-- ======================================================================
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_it text not null,
  name_en text not null,
  icon text default '🍽️',
  sort_order numeric not null default 0,
  is_drink boolean not null default false,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists categories_updated_at on public.categories;
create trigger categories_updated_at
  before update on public.categories
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 04. TABELLA: allergens
-- ======================================================================
create table if not exists public.allergens (
  id uuid primary key default gen_random_uuid(),
  name_it text not null,
  name_en text not null,
  icon text default '⚠️',
  sort_order numeric not null default 0,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists allergens_updated_at on public.allergens;
create trigger allergens_updated_at
  before update on public.allergens
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 05. TABELLA: products (prodotti menu)
-- ======================================================================
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name_it text not null,
  name_en text not null,
  description_it text,
  description_en text,
  price numeric not null,
  category_id text,
  allergens text[] not null default '{}'::text[],
  available boolean not null default true,
  lactose_free_option boolean not null default false,
  image_url text,
  sort_order numeric not null default 0,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at
  before update on public.products
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 06. TABELLA: fixed_menus (menu fissi)
-- ======================================================================
create table if not exists public.fixed_menus (
  id uuid primary key default gen_random_uuid(),
  name_it text not null,
  name_en text not null,
  price numeric not null,
  first_course_ids text[] not null default '{}'::text[],
  second_course_ids text[] not null default '{}'::text[],
  included_item_names_it text[] not null default '{}'::text[],
  included_item_names_en text[] not null default '{}'::text[],
  extra_drink_ids text[] not null default '{}'::text[],
  active boolean not null default true,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists fixed_menus_updated_at on public.fixed_menus;
create trigger fixed_menus_updated_at
  before update on public.fixed_menus
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 07. TABELLA: comanda_templates (modelli stampa comande)
-- ======================================================================
create table if not exists public.comanda_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  title text not null,
  header_text text,
  header_font_size numeric not null default 20,
  header_bold boolean not null default true,
  header_align text not null default 'center' check (header_align in ('left','center','right')),
  category_ids text[] not null default '{}'::text[],
  paper_size text not null default '80mm' check (paper_size in ('58mm','80mm','A4')),
  font_family text not null default 'monospace' check (font_family in ('monospace','sans-serif','serif')),
  font_size numeric not null default 12,
  title_font_size numeric not null default 16,
  sort_order numeric not null default 0,
  active boolean not null default true,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists comanda_templates_updated_at on public.comanda_templates;
create trigger comanda_templates_updated_at
  before update on public.comanda_templates
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 08. TABELLA: feste (eventi)
-- ======================================================================
create table if not exists public.feste (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date date,
  end_date date,
  status text not null default 'active' check (status in ('active','archived')),
  notes text,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists feste_updated_at on public.feste;
create trigger feste_updated_at
  before update on public.feste
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 09. TABELLA: app_settings (configurazione generale)
-- ======================================================================
create table if not exists public.app_settings (
  id uuid primary key default gen_random_uuid(),
  cassa_pin text not null default '1234',
  admin_pin text not null default '9999',
  code_expiry_hours numeric not null default 4,
  next_order_number numeric not null default 1,
  festa_name text not null default '',
  active_festa_id text not null default '',
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);

drop trigger if exists app_settings_updated_at on public.app_settings;
create trigger app_settings_updated_at
  before update on public.app_settings
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 10. TABELLA: order_codes (codici ordine generati dai clienti)
-- ======================================================================
create table if not exists public.order_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  cart_data jsonb not null default '{}'::jsonb,
  table_number text not null,
  customer_name text,
  total numeric not null,
  status text not null default 'pending' check (status in ('pending','consumed','cancelled')),
  expires_at timestamptz not null,
  purpose text not null default 'cassa' check (purpose in ('cassa','table_share')),
  consumed_at timestamptz,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);
create index if not exists order_codes_code_idx on public.order_codes(code);
create index if not exists order_codes_purpose_status_idx on public.order_codes(purpose, status);

drop trigger if exists order_codes_updated_at on public.order_codes;
create trigger order_codes_updated_at
  before update on public.order_codes
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 11. TABELLA: cashier_orders (ordini effettivi pagati in cassa)
-- ======================================================================
create table if not exists public.cashier_orders (
  id uuid primary key default gen_random_uuid(),
  order_number numeric,
  code text,
  items jsonb not null default '[]'::jsonb,
  total numeric not null,
  table_number text not null,
  customer_name text,
  note text,
  mode text not null default 'manual' check (mode in ('code','manual')),
  status text not null default 'paid' check (status in ('paid','pending')),
  comandas_printed boolean not null default false,
  festa_id text,
  created_date timestamptz not null default now(),
  updated_date timestamptz not null default now()
);
create index if not exists cashier_orders_created_date_idx on public.cashier_orders(created_date desc);
create index if not exists cashier_orders_status_idx on public.cashier_orders(status);
create index if not exists cashier_orders_festa_idx on public.cashier_orders(festa_id);

drop trigger if exists cashier_orders_updated_at on public.cashier_orders;
create trigger cashier_orders_updated_at
  before update on public.cashier_orders
  for each row execute function public.handle_updated_at();

-- ======================================================================
-- 12. RLS (Row Level Security)
-- NOTA: L'app originale è PUBBLICA (requiresAuth:false), gli accessi
-- sono protetti da PIN interni (cassa/admin). Perciò permettiamo TUTTO
-- agli utenti anonimi e autenticati.
-- Se in futuro vuoi sicurezza più stretta, modifica queste policy.
-- ======================================================================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.allergens enable row level security;
alter table public.products enable row level security;
alter table public.fixed_menus enable row level security;
alter table public.comanda_templates enable row level security;
alter table public.feste enable row level security;
alter table public.app_settings enable row level security;
alter table public.order_codes enable row level security;
alter table public.cashier_orders enable row level security;

-- Policy: permetti tutte le operazioni a anon e authenticated (pubblica)
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'profiles','categories','allergens','products','fixed_menus',
    'comanda_templates','feste','app_settings','order_codes','cashier_orders'
  ] loop
    execute format('drop policy if exists "allow_all_%s" on public.%I', tbl, tbl);
    execute format('create policy "allow_all_%s" on public.%I
      for all using (true) with check (true)', tbl, tbl);
  end loop;
end $$;

-- ======================================================================
-- 13. DATI INIZIALI DI DEFAULT (seed)
-- ======================================================================
-- App Settings (record principale con PIN di default)
insert into public.app_settings (cassa_pin, admin_pin, code_expiry_hours, next_order_number, festa_name, active_festa_id)
select '1234', '9999', 4, 1, '', ''
where not exists (select 1 from public.app_settings limit 1);

-- ======================================================================
-- 14. Storage bucket per immagini prodotti (opzionale)
-- ======================================================================
-- Per aggiungere immagini ai prodotti crea un bucket pubblico in
-- Supabase > Storage > Create bucket:  name = "product-images", public
-- Poi usa l'URL pubblico come image_url nei prodotti.
--
-- Oppure continua a usare URL di immagini esterne (come già faceva il codice).
-- ======================================================================
