select code, sort_order from currencies order by sort_order;
-- select count(*) from cup_price_series;
select max(cup_per_usd) from cup_price_series;