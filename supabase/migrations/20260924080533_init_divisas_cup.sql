-- DivisasCUP: esquema inicial para el backend Supabase.
--
-- La BD sigue el modelo CUP-anchored de la app:
--   * `rates.price_in_cup` = cuántos CUP cuesta 1 unidad de cada moneda.
--   * los pares cruzados se derivan en el cliente (priceInCup(A)/priceInCup(B)),
--     nunca se guardan.
--   * `cup_price_series` es el historial diario CUP/USD.
--   * `currencies.sort_order` fija el orden de display y de la base por
--     defecto (la app usa la primera moneda como base inicial = CUP).
--
-- Los clientes de la app son SOLO LECTURA (políticas anon SELECT).
-- La escritura queda para inserción manual (Studio/SQL) y, más adelante,
-- para una Edge Function programada (cron) que consuma una API con
-- `service_role`. La función `refresh_cup_price` concentra el refresh atómico
-- (hoy + re-anclaje de USD/MLC/EUR) y solo está disponible para
-- `service_role`.

create table currencies (
  code            text primary key,
  name            text not null,
  symbol          text not null,
  decimal_digits  int  not null default 2,
  sort_order      int  not null unique check (sort_order > 0),
  created_at      timestamptz not null default now()
);

create table rates (
  quote_code    text primary key references currencies (code) on delete cascade,
  price_in_cup  numeric(15,6) not null check (price_in_cup > 0),
  updated_at    timestamptz   not null default now()
);

create table cup_price_series (
  sampled_on     date primary key,
  cup_per_usd    numeric(15,6) not null check (cup_per_usd > 0),
  source         text not null default 'seed' check (source in ('seed','refresh','api')),
  created_at     timestamptz   not null default now()
);

alter table currencies       enable row level security;
alter table rates            enable row level security;
alter table cup_price_series enable row level security;

create policy currencies_select on currencies       for select to anon using (true);
create policy rates_select      on rates            for select to anon using (true);
create policy cup_series_select on cup_price_series for select to anon using (true);

-- Refresh atómico: upsert de la muestra diaria + re-anclaje de las filas
-- dependientes (EUR = USD * 1.08). `security definer` permite escribir aunque
-- anon no tenga INSERT; revocamos execute a PUBLIC/anon para que solo pueda
-- invocarla service_role (cliente queda read-only).
create or replace function refresh_cup_price(new_date date, new_cup_per_usd numeric)
returns cup_price_series
language sql security definer
as $$
  insert into cup_price_series (sampled_on, cup_per_usd, source)
  values (new_date, new_cup_per_usd, 'refresh')
  on conflict (sampled_on) do update
    set cup_per_usd = excluded.cup_per_usd, source = 'refresh';

  update rates set price_in_cup = new_cup_per_usd, updated_at = now()
    where quote_code in ('USD','MLC');
  update rates set price_in_cup = new_cup_per_usd * 1.08, updated_at = now()
    where quote_code = 'EUR';

  select * from cup_price_series where sampled_on = new_date;
$$;

revoke  execute on function refresh_cup_price(date, numeric) from public, anon;
grant   execute on function refresh_cup_price(date, numeric) to service_role;