/*
--------------------------------------------------------------------------------------------------------
Flight Performance by Profit Margin
--------------------------------------------------------------------------------------------------------
Purpose:
- Groups flights into performance tiers based on profit margin (%).
- Compares a variety of financial metrics across tiers.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).

--------------------------------------------------------------------------------------------------------
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
        fr.flight_number,
        count(fr.flight_number) over () as total_flights,
        f.flight_date,
        f.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        round((fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev, 2) as flight_profit_margin_pct
    from flight_revs fr
    join flights_booked_passengers f on fr.flight_number = f.flight_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where f.cancelled = FALSE
),
flight_tiers as (
    select
        *,
        case
        when flight_profit_margin_pct >= 50 then '(A) Top Profits (>= 50%)'
        when flight_profit_margin_pct >= 40 then '(B) Very High Profits (40 to 49%)'
        when flight_profit_margin_pct >= 30 then '(C) High Profits (30 to 39%)'
        when flight_profit_margin_pct >= 15 then '(D) Healthy Profits (15 to 29%)'
        when flight_profit_margin_pct >= 5 then '(E) Marginal Profits (5 to 14%)'
        when flight_profit_margin_pct >= 0 then '(F) Break-Even (0 to 5%)'
        when flight_profit_margin_pct >= -15 then '(G) Losses (0 to -15%)'
        when flight_profit_margin_pct >= -30 then '(H) High Losses (-16 to -30%)'
        when flight_profit_margin_pct < -30 then '(I) Worst Losses (< -31)'
        else 'Unlisted / Check Logic'
    end as flight_profit_margin_tier
    from flight_profits
)
select
    coalesce(flight_profit_margin_tier, 'GRAND TOTAL (ALL)') as flight_profit_margin_tier,
    round(avg(flight_profit_margin_pct), 2) as avg_profit_margin_pct,
    count(flight_number) as flight_count,
    round(count(flight_number) * 100.0 / min(total_flights), 2) as flights_share,
    round(avg(booked_rate), 2) as avg_booked_rate_pct,
    round(avg(tot_flight_rev), 2) as avg_rev,
    round(avg(flight_cost_total), 2) as avg_cost,
    round(avg(flight_profit), 2) as avg_profit,
    round(min(flight_profit), 2) as min_profit,
    round(max(flight_profit), 2) as max_profit,
    round(sum(flight_profit), 2) as total_profit,
    round(stddev_samp(flight_profit), 2) as profit_stddev,
    round(sum(tot_flight_rev), 2) as total_revenue,
    round(sum(flight_profit), 2) as total_profit,
    concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
    round(sum(tot_flight_rev) / count(distinct extract(year from flight_date)), 2) as avg_yearly_rev,
    round(sum(flight_profit) / count(distinct extract(year from flight_date)), 2) as avg_yearly_profit
from flight_tiers
group by grouping sets (flight_profit_margin_tier, ())
order by flight_profit_margin_tier;