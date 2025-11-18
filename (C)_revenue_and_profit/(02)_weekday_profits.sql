/*
----------------------------------------------------------------------------------------------------
Financial Performance by Day of the Week
----------------------------------------------------------------------------------------------------
- Compares a variety of financial metrics across days of the week.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).
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
        extract(isodow from f.flight_date) as iso_day_number,
        trim(to_char(f.flight_date, 'Day')) as day_of_week,
        f.flight_date,
        f.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        (fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev as flight_profit_margin_pct
    from flight_revs fr
    join flights_booked_passengers f on fr.flight_number = f.flight_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where f.cancelled = FALSE
)
select
    case
        when grouping(day_of_week) = 1 then 'GRAND TOTAL (ALL)'
        else concat('(', iso_day_number, ') ', day_of_week)
    end as day_of_week,
    round(avg(flight_profit_margin_pct), 2) as avg_profit_margin_pct,
    count(*) as flight_count,
    round(avg(booked_rate), 2) as avg_booked_rate_pct,
    round(avg(tot_flight_rev), 2) as revenue_per_flight,
    round(avg(flight_cost_total), 2) as cost_per_flight,
    round(avg(flight_profit), 2) as profit_per_flight,
    round(min(flight_profit), 2) as min_profit,
    round(max(flight_profit), 2) as max_profit,
    round(sum(flight_cost_total), 2) as total_revenue,
    round(sum(flight_profit), 2) as total_profit,
    concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
    round(sum(flight_cost_total) / count(distinct extract(year from flight_date)), 2) as avg_yearly_rev,
    round(sum(flight_profit) / count(distinct extract(year from flight_date)), 2) as avg_yearly_profit
from flight_profits
group by cube((day_of_week, iso_day_number))
order by day_of_week;