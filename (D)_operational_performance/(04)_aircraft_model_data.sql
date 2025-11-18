/*
--------------------------------------------------------------------------------------------
Aircraft Model Performance Indicators
--------------------------------------------------------------------------------------------
Goal:
    Compare aircraft models using a combined set of financial, operational, and
    reliability metrics.

Contents:
    - Operational: flight counts, utilization rates, average flight distance.
    - Financial: median booked rate, median profit margin.
    - Reliability: counts and relative rates of technical delay and cancellation events.

Interpretation:
    - Results are aggregated by aircraft model.
    - Percentages are relative to total operational flights or total delays/cancellations.
--------------------------------------------------------------------------------------------
*/

with flight_revs as (
    select
        flight_number,
        sum(price_paid) as tot_flight_rev
    from bookings b
    where flight_cxl_refund = FALSE
    group by flight_number
),
various_stats as (
    select
        fr.flight_number,
        f.flight_date,
        f.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        (fr.tot_flight_rev - cf.flight_cost_total) * 100.0 / fr.tot_flight_rev as flight_profit_margin_pct,
        r.distance_km,
        ac.aircraft_id,
        ac.model,
        ac.manufacturer,
        ac.seat_capacity,
        ac.range_km
    from flight_revs fr
    join flights_booked_passengers f on fr.flight_number = f.flight_number
    join routes r on f.line_number = r.line_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join costs_per_flight cf on fr.flight_number = cf.flight_number
    where f.cancelled = FALSE
),
technical_issues as (
    select
        ac.model,
        count(case when cancellation_reason = 'Technical failure' then cancellation_reason end)
            as tech_failure_cxl_count,
        count(case when delay_reason_dep = 'Technical issue' then delay_reason_dep end) as tech_issue_delay_count,
        count(*) as tot_flights_nominal
    from flights_booked_passengers fbp
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    group by ac.model
)
select
    vs.model,
    max(vs.manufacturer) as manufacturer,
    count(distinct vs.aircraft_id) as num_aircraft,
    count(*) as flight_count_model,
    count(*) / count(distinct vs.aircraft_id) as avg_flight_count_aircraft,
    count(*) / count(distinct vs.flight_date) as avg_daily_flights_model,
    count(*) / count(distinct vs.aircraft_id) / count(distinct vs.flight_date) avg_daily_flights_aircraft,
    min(vs.range_km) as range_km,
    round(avg(vs.distance_km)) as avg_flight_distance_km,
    min(vs.seat_capacity) as seat_capacity,
    round(percentile_cont(0.5) within group (order by vs.booked_rate)::numeric, 2) as median_flight_booked_rate,
    round(percentile_cont(0.5) within group (order by vs.flight_profit_margin_pct)::numeric, 2)
        as median_flight_profit_margin_pct,
    min(ti.tech_failure_cxl_count) as tech_failure_cxl_count,
    min(ti.tech_issue_delay_count) as tech_issue_delay_count,
    round(min(ti.tech_failure_cxl_count) * 100.0 / (select sum(tot_flights_nominal) from technical_issues), 2)
        as tech_failure_cxl_rate_pct,
    round(min(ti.tech_issue_delay_count) * 100.0 / count(*), 2) as tech_issue_delay_rate_pct
from various_stats vs
join technical_issues ti on vs.model = ti.model
group by vs.model
order by num_aircraft desc;