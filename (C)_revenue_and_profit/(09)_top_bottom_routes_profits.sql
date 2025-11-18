/*
--------------------------------------------------------------------------------------------------------
Top/Bottom Routes by Profit Margin and Avg Profit per Flight
--------------------------------------------------------------------------------------------------------
Purpose:
- Ranks routes based on profit margin (%) and average profit (per flight).
- Compares a variety of financial metrics across top/bottom routes.
- Includes average booked rate, which is expected to be predictive of
  average profit margin (%) and/or average profit (per flight).

--------------------------------------------------------------------------------------------------------
Notes:
- A view is created below, slightly modifying the query for visualization
  with Seaborn/Matplotlib.
- See /visualizations/english/(07)_top_bottom_routes_profits.png
  and /visualizations/german/(07)_tf_routen_profit.png
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
        fbp.line_number,
        fbp.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        round((fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev, 2) as flight_profit_margin_pct,
        sum(fr.tot_flight_rev - cf.flight_cost_total) over () total_profit_all_flights,
        extract(year from fbp.flight_date) as year
    from flight_revs fr
    join flights_booked_passengers fbp on fr.flight_number = fbp.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where fbp.cancelled = FALSE
),
route_profits as (
    select
        line_number,
        avg(booked_rate) as avg_booked_rate_pct,
        avg(tot_flight_rev) as avg_rev,
        avg(flight_cost_total) as avg_cost,
        avg(flight_profit) as avg_profit,
        min(flight_profit) as min_profit,
        max(flight_profit) as max_profit,
        avg(flight_profit_margin_pct) as avg_profit_margin
    from flight_profits
    group by line_number
),
all_routes_windows as (
    select
        *,
        avg(avg_profit_margin) over () as avg_profit_margin_all_routes,
        avg(avg_profit) over () as avg_profit_all_routes
    from route_profits
),
profit_ranks as (
    select
        *,
        rank() over (order by avg_profit_margin desc) as profit_margin_rank,
        rank() over (order by avg_profit desc) as avg_profit_rank,
        round((percent_rank() over (order by avg_profit_margin desc) * 100)::numeric, 2) as profit_margin_pct_rank,
        round((percent_rank() over (order by avg_profit desc) * 100)::numeric, 2) as avg_profit_pct_rank
    from all_routes_windows
),
routes_with_locations as (
    select
        r.line_number,
        concat(dep.airport_code, ', ', dep.city, ', ', case when dep.country = 'United Arab Emirates'
            then 'UAE' else dep.country end) as departure_location,
        concat(arr.airport_code, ', ', arr.city, ', ', case when arr.country = 'United Arab Emirates'
            then 'UAE' else arr.country end) as arrival_location,
        r.distance_km
    from routes r
    join airports dep on r.departure_airport_code = dep.airport_code
    join airports arr on r.arrival_airport_code = arr.airport_code
),
params as (
    select 3 as top, 97 as bottom
)
select
    case
        when pr.profit_margin_pct_rank <= p.top then concat('(A) Profit Margin, Top ', p.top, '%')
        when pr.profit_margin_pct_rank >= p.bottom then concat('(B) Profit Margin, Bottom ', p.top, '%')
        else 'Middle'
    end as profitability_tier,
    pr.line_number,
    rl.departure_location,
    rl.arrival_location,
    rl.distance_km,
    pr.profit_margin_rank as rank,
    pr.profit_margin_pct_rank as pct_rank,
    round(pr.avg_profit_margin, 2) as avg_profit_margin,
    round(pr.avg_booked_rate_pct, 2) as avg_booked_rate_pct,
    round(pr.avg_rev, 2) as avg_revenue,
    round(pr.avg_cost, 2) as avg_cost,
    round(pr.avg_profit, 2) as avg_profit,
    round(pr.min_profit, 2) as min_profit,
    round(pr.max_profit, 2) as max_profit,
    round(pr.avg_profit_margin_all_routes, 2) as avg_profit_margin_all_routes,
    round(avg_profit_all_routes, 2) as avg_profit_all_routes
from profit_ranks pr
join routes_with_locations rl on pr.line_number = rl.line_number
cross join params p
where pr.profit_margin_pct_rank <= p.top or pr.profit_margin_pct_rank >= p.bottom

union all
select
    case
        when pr.avg_profit_pct_rank <= p.top then concat('(C) Avg Profit, Top ', p.top, '%')
        when pr.avg_profit_pct_rank >= p.bottom then concat('(D) Avg Profit, Bottom ', p.top, '%')
        else 'Middle'
    end,
    pr.line_number,
    rl.departure_location,
    rl.arrival_location,
    rl.distance_km,
    pr.avg_profit_rank,
    pr.avg_profit_pct_rank,
    round(pr.avg_profit_margin, 2),
    round(pr.avg_booked_rate_pct, 2),
    round(pr.avg_rev, 2),
    round(pr.avg_cost, 2),
    round(pr.avg_profit, 2),
    round(pr.min_profit, 2),
    round(pr.max_profit, 2),
    round(pr.avg_profit_margin_all_routes, 2),
    round(avg_profit_all_routes, 2)
from profit_ranks pr
join routes_with_locations rl on pr.line_number = rl.line_number
cross join params p
where pr.avg_profit_pct_rank <= p.top or pr.avg_profit_pct_rank >= p.bottom
order by profitability_tier, rank;



-- view for visualization with matplotlib/seaborn (Top/Bottom 2 instead of pct ranks)
create or replace view top_bottom_routes_profits as
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
        fbp.line_number,
        fbp.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        fr.tot_flight_rev,
        cf.flight_cost_total,
        fr.tot_flight_rev - cf.flight_cost_total as flight_profit,
        round((fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev, 2) as flight_profit_margin_pct,
        sum(fr.tot_flight_rev - cf.flight_cost_total) over () total_profit_all_flights,
        extract(year from fbp.flight_date) as year
    from flight_revs fr
    join flights_booked_passengers fbp on fr.flight_number = fbp.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where fbp.cancelled = FALSE
),
route_profits as (
    select
        line_number,
        avg(booked_rate) as avg_booked_rate_pct,
        avg(tot_flight_rev) as avg_rev,
        avg(flight_cost_total) as avg_cost,
        avg(flight_profit) as avg_profit,
        min(flight_profit) as min_profit,
        max(flight_profit) as max_profit,
        avg(flight_profit_margin_pct) as avg_profit_margin
    from flight_profits
    group by line_number
),
all_routes_windows as (
    select
        *,
        avg(avg_profit_margin) over () as avg_profit_margin_all_routes,
        avg(avg_profit) over () as avg_profit_all_routes
    from route_profits
),
profit_ranks as (
    select
        *,
        rank() over (order by avg_profit_margin desc) as profit_margin_rank_desc,
        rank() over (order by avg_profit_margin) as profit_margin_rank_asc,
        rank() over (order by avg_profit desc) as avg_profit_rank_desc,
        rank() over (order by avg_profit) as avg_profit_rank_asc,
        round((percent_rank() over (order by avg_profit_margin desc) * 100)::numeric, 2) as profit_margin_pct_rank,
        round((percent_rank() over (order by avg_profit desc) * 100)::numeric, 2) as avg_profit_pct_rank
    from all_routes_windows
),
routes_with_locations as (
    select
        r.line_number,
        concat(r.line_number, ': ', dep.airport_code, ' → ', arr.airport_code) as route_name,
        r.distance_km
    from routes r
    join airports dep on r.departure_airport_code = dep.airport_code
    join airports arr on r.arrival_airport_code = arr.airport_code
),
params as (
    select 2 as top
)
select
    case
        when pr.profit_margin_rank_desc <= p.top
            then concat('(A) Profit Margin (%), Rank 00', pr.profit_margin_rank_desc)
        when pr.profit_margin_rank_asc <= p.top
            then concat('(A) Profit Margin (%), Rank ', pr.profit_margin_rank_desc)
        else 'Middle'
    end as profitability_tier,
    pr.line_number,
    rl.route_name,
    rl.distance_km,
    pr.profit_margin_rank_desc as rank,
    pr.profit_margin_pct_rank as pct_rank,
    round(pr.avg_profit_margin, 2) as avg_profit_margin,
    round(pr.avg_booked_rate_pct, 2) as avg_booked_rate,
    round(pr.avg_rev, 2) as avg_revenue,
    round(pr.avg_cost, 2) as avg_cost,
    round(pr.avg_profit, 2) as avg_profit,
    round(pr.min_profit, 2) as min_profit,
    round(pr.max_profit, 2) as max_profit,
    round(pr.avg_profit_margin_all_routes, 2) as avg_profit_margin_all_routes,
    round(avg_profit_all_routes, 2) as avg_profit_all_routes
from profit_ranks pr
join routes_with_locations rl on pr.line_number = rl.line_number
cross join params p
where pr.profit_margin_rank_desc <= p.top or pr.profit_margin_rank_asc <= p.top

union all
select
    case
        when pr.avg_profit_rank_desc <= p.top then concat('(B) Avg Profit, Rank 00', pr.avg_profit_rank_desc)
        when pr.avg_profit_rank_asc <= p.top then concat('(B) Avg Profit, Rank ', pr.avg_profit_rank_desc)
        else 'Middle'
    end,
    pr.line_number,
    rl.route_name,
    rl.distance_km,
    pr.avg_profit_rank_desc,
    pr.avg_profit_pct_rank,
    round(pr.avg_profit_margin, 2),
    round(pr.avg_booked_rate_pct, 2),
    round(pr.avg_rev, 2),
    round(pr.avg_cost, 2),
    round(pr.avg_profit, 2),
    round(pr.min_profit, 2),
    round(pr.max_profit, 2),
    round(pr.avg_profit_margin_all_routes, 2),
    round(avg_profit_all_routes, 2)
from profit_ranks pr
join routes_with_locations rl on pr.line_number = rl.line_number
cross join params p
where pr.avg_profit_rank_desc <= p.top or pr.avg_profit_rank_asc <= p.top

order by profitability_tier;