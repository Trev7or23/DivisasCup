-- DivisasCUP: seed inicial.
-- Replica el set CUP-anchored de `FakeRates.seed` y los 90 días deterministas
-- de `FakeRates.series()` (misma fórmula; termina en 720 CUP/USD hoy).

insert into currencies (code, name, symbol, decimal_digits, sort_order) values
  ('CUP', 'Cuban Peso', '$', 2, 1),
  ('USD', 'US Dollar',  '$', 2, 2),
  ('MLC', 'MLC',        '$', 2, 3),
  ('EUR', 'Euro',       '€', 2, 4);

insert into rates (quote_code, price_in_cup) values
  ('CUP', 1.0),
  ('USD', 720.0),
  ('MLC', 720.0),
  ('EUR', 777.6);

insert into cup_price_series (sampled_on, cup_per_usd)
select (current_date - (89 - i) * interval '1 day')::date,
       480.0 + 240.0 * i/89.0 + 6.0 * sin(pi() * i/89.0 * 3.0)
from generate_series(0, 89) as i;