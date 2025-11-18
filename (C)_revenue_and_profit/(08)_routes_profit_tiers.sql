/*
-----------------------------------------------------------------------------------------------------------------
Route Performance by Profit Margin
-----------------------------------------------------------------------------------------------------------------
Purpose:
- Groups routes into performance tiers based on profit margin (%).
- Compares a variety of financial metrics across tiers on a per-flight and a per-day level.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).

Note:
- Grouping flight level data by route (line number) while using the avg() function (e.g., avg(flight_profit)
  effectively results in per-day metrics since differences in flight counts between routes are caused by
  differences in scheduled flights per day. This presupposes the absence of variation in each route's daily
  flight frequency, as is the case in the underlying simulation.
-----------------------------------------------------------------------------------------------------------------
*/

with flight_revs as (
    select
        flight_number,
        sum(price_paid) as tot_flight_rev
    from bookings b
    where flight_cxl_refund = FALSE
    group by flight_number
),
flight_metrics as (
    select
        f.line_number,
        f.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        sum(fr.tot_flight_rev - cf.flight_cost_total) over () total_profit_all_flights,
        f.flight_date
    from flight_revs fr
    join flights_booked_passengers f on fr.flight_number = f.flight_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where f.cancelled = FALSE
),
route_metrics as (
    select
        line_number,
        count(line_number) over () as tot_unique_route_count,
        avg(booked_rate) as avg_booked_rate,
        sum(tot_flight_rev) as route_total_rev,
        sum(flight_cost_total) as route_total_cost,
        sum(flight_profit) as route_total_profit,
        avg(tot_flight_rev) as rev_per_day,
        avg(flight_cost_total) as cost_per_day,
        avg(flight_profit) as profit_per_day,
        count(*) as flight_count,
        round(sum(flight_profit) * 100 / sum(tot_flight_rev), 2) as route_profit_margin,
        concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
        count(distinct extract(year from flight_date)) as year_count
    from flight_metrics
    group by line_number
),
route_tiers as (
    select
        *,
        case
            when route_profit_margin >= 25 then '(A) Top Profits (>= 25%)'
            when route_profit_margin >= 20 then '(B) High Profits (20 to 24%)'
            when route_profit_margin >= 15 then '(C) Healthy Profits (15 to 19%)'
            when route_profit_margin >= 5 then '(D) Marginal Profits (5 to 14%)'
            when route_profit_margin < 5 then '(E) Loss Risk (< 5%)'
            else 'Unlisted / Check Logic'
        end as route_profit_margin_tier
    from route_metrics
)
select
    coalesce(route_profit_margin_tier, 'GRAND TOTAL (ALL)') as route_profit_margin_tier,
    round(avg(route_profit_margin), 2) as avg_profit_margin_pct,
    count(line_number) as unique_route_count,
    round(count(line_number) * 100.0 / min(tot_unique_route_count), 2) as routes_share,
    sum(flight_count) as total_flights,
    round(avg(avg_booked_rate), 2) as avg_booked_rate_pct,
    round(sum(route_total_profit) / sum(flight_count), 2) as profit_per_flight,
    round(avg(rev_per_day), 2) as revenue_per_day,
    round(avg(cost_per_day), 2) as cost_per_day,
    round(avg(profit_per_day), 2) as profit_per_day,
    round(min(profit_per_day), 2) as min_profit_per_day,
    round(max(profit_per_day), 2) as max_profit_per_day,
    round(stddev_samp(profit_per_day), 2) as profit_per_day_stddev,
    round(sum(route_total_rev), 2) as total_revenue,
    round(sum(route_total_profit), 2) as total_profit,
    min(year_range) as year_range,
    round(sum(route_total_rev) / min(year_count), 2) as avg_yearly_rev,
    round(sum(route_total_profit) / min(year_count), 2) as avg_yearly_profit
from route_tiers
group by grouping sets (route_profit_margin_tier, ())
order by route_profit_margin_tier;