/*
----------------------------------------------------------------------------------------------------
Financial Performance by Passenger Class
----------------------------------------------------------------------------------------------------
- Compares a variety of financial metrics across passenger classes.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).
----------------------------------------------------------------------------------------------------
*/

with flight_class_revs as (
    select
        flight_number,
        class_name,
        sum(price_paid) as class_rev
    from bookings
    where flight_cxl_refund = FALSE
    group by flight_number, class_name
),
flight_class_costs as (
    select
        fccp.flight_number,
        fccp.flight_date,
        fccp.class_name,
        fccp.class_bookings * 100.0 / fccp.capacity as class_booked_rate,
        cf.flight_cost_total * fccs.cost_share as class_cost,
        cf.flight_cost_total
    from flight_capacity_by_class_passengers fccp
    join costs_per_flight cf on fccp.flight_number = cf.flight_number
    join flight_class_cost_shares fccs on fccp.flight_number = fccs.flight_number and fccp.class_name = fccs.class_name
    where fccp.capacity > 0 and fccp.class_passengers > 0
    order by flight_number
),
flight_class_profits as (
    select
        fcc.flight_number,
        case
            when fcc.class_name = 'Economy' then '(1) Economy'
            when fcc.class_name = 'Business' then '(2) Business'
            when fcc.class_name = 'First' then '(3) First'
        end as passenger_class,
        fcc.flight_date,
        fcc.class_booked_rate,
        fcr.class_rev,
        fcc.class_cost,
        fcr.class_rev - fcc.class_cost as class_profit,
        (fcr.class_rev - fcc.class_cost) * 100.0 / nullif(fcr.class_rev, 0) as class_profit_margin_pct
    from flight_class_costs fcc
    join flight_class_revs fcr on fcc.flight_number = fcr.flight_number and fcc.class_name = fcr.class_name
)
select
    coalesce(passenger_class, '(GRAND TOTAL)') as passenger_class,
    count(distinct flight_number) as flight_count,
    round(avg(class_profit_margin_pct), 2) as avg_profit_margin_pct,
    round(avg(class_booked_rate), 2) as avg_booked_rate_pct,
    round(sum(class_rev) / count(distinct flight_number), 2) as revenue_per_flight,
    round(sum(class_cost) / count(distinct flight_number), 2) as cost_per_flight,
    round(sum(class_profit) / count(distinct flight_number), 2) as profit_per_flight,
    round(min(class_profit), 2) as min_profit,
    round(max(class_profit), 2) as max_profit,
    round(sum(class_rev), 2) as total_revenue,
    round(sum(class_profit), 2) as total_profit,
    concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
    round(sum(class_rev) / count(distinct extract(year from flight_date)), 2) as avg_yearly_rev,
    round(sum(class_profit) / count(distinct extract(year from flight_date)), 2) as avg_yearly_profit
from flight_class_profits
group by cube(passenger_class)
order by passenger_class nulls last;