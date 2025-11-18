/*
----------------------------------------------------------------------------------------------------
Financial Performance by Travel Season
----------------------------------------------------------------------------------------------------
- Compares a variety of financial metrics across travel seasons.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).
----------------------------------------------------------------------------------------------------
Note:
- While spring, summer, and autumn correspond to calendar seasons, winter was separated into
  January + February vs. December, highlighting major performance differences between the start
  of the year and the winter holidays.
----------------------------------------------------------------------------------------------------
*/

with flight_revs as (
    select
        flight_number,
        sum(price_paid) as tot_flight_rev
    from bookings b
    where flight_cxl_refund = FALSE
    group by flight_number
),
flight_profits as (
    select
        fbp.flight_date,
        case
            when extract(month from fbp.flight_date) in (1, 2) then '(1) Jan & Feb'
            when extract(month from fbp.flight_date) in (3, 4, 5) then '(2) Spring'
            when extract(month from fbp.flight_date) in (6, 7, 8) then '(3) Summer'
            when extract(month from fbp.flight_date) in (9, 10, 11) then '(4) Autumn'
            when extract(month from fbp.flight_date) = 12 then '(5) December'
            else 'Unlisted month / Check logic'
        end as travel_season,
        fbp.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        (fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev as flight_profit_margin_pct
    from flight_revs fr
    join flights_booked_passengers fbp on fr.flight_number = fbp.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where fbp.cancelled = FALSE
)
select
    coalesce(travel_season, '(ALL SEASONS)') as travel_season,
    round(avg(flight_profit_margin_pct), 2) as avg_profit_margin_pct,
    count(*) as flight_count,
    round(avg(booked_rate), 2) as avg_booked_rate_pct,
    round(avg(tot_flight_rev), 2) as revenue_per_flight,
    round(avg(flight_cost_total), 2) as cost_per_flight,
    round(avg(flight_profit), 2) as profit_per_flight,
    round(min(flight_profit), 2) as min_profit,
    round(max(flight_profit), 2) as max_profit,
    round(sum(tot_flight_rev), 2) as total_revenue,
    round(sum(flight_profit), 2) as total_profit,
    concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
    round(sum(tot_flight_rev) / count(distinct extract(year from flight_date)), 2) as avg_yearly_rev,
    round(sum(flight_profit) / count(distinct extract(year from flight_date)), 2) as avg_yearly_profit
from flight_profits
group by cube(travel_season);