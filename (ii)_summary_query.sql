/*
 --------------------------------------------------------------------------------------------
 Overall Operational and Financial Performance Summary
--------------------------------------------------------------------------------------------
 This query aggregates key airline KPIs across the available flight data period,
 combining information from flight operations, bookings, and cost components.

--------------------------------------------------------------------------------------------
 */

with flight_revenues as (
    select
        flight_number,
        sum(price_paid) as revenue
    from bookings
    where flight_cxl_refund = FALSE
    group by flight_number
),
non_cancelled_flights as (
    select
        fr.flight_number,
        fr.revenue,
        fbp.passengers_total * 100.0 / ac.seat_capacity as occupancy_rate_pct,
        cpf.flight_cost_total as cost_overall,
        fr.revenue - cpf.flight_cost_total as profit,
        (fr.revenue - cpf.flight_cost_total) * 100.0 / fr.revenue as profit_margin_pct,
        case when extract(epoch from (fbp.actual_arrival - fbp.scheduled_arrival)) / 60 <= 15 then 1 end as on_time_arr
    from flight_revenues fr
    join flights_booked_passengers fbp on fr.flight_number = fbp.flight_number
    join costs_per_flight cpf on fr.flight_number = cpf.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
)
select
    concat(min(extract(year from fbp.flight_date)), '–', max(extract(year from fbp.flight_date))) as source_period,
    count(*) as total_scheduled_flights,
    count(*) filter (where fbp.cancelled = TRUE) as total_flight_cancellations,
    count(*) filter (where fbp.cancelled = FALSE) as total_flights,
    sum(fbp.booked_total) as total_bookings,
    sum(fbp.passengers_total) as total_passengers,
    round(sum(fbp.passengers_total)::numeric / count(*) filter (where fbp.cancelled = FALSE), 2)
        as avg_passengers_per_flight,
    round(avg(fbp.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate_pct,
    round(avg(ncf.occupancy_rate_pct), 2) as avg_occupancy_rate_pct,
    round(sum(ncf.revenue)) as total_revenue,
    round(sum(ncf.cost_overall)) as total_cost,
    round(sum(ncf.profit)) as total_profit,
    round(avg(ncf.profit_margin_pct), 2) as avg_profit_margin_pct,
    round(sum(ncf.profit) / count(distinct fbp.flight_number) filter (where fbp.cancelled = FALSE), 2)
        as avg_profit_per_flight,
    round(count(*) filter (where fbp.cancelled = TRUE) * 100.0 / count(*), 2) as cancellation_rate_pct,
    round(sum(ncf.on_time_arr) * 100.0 / count(*) filter (where fbp.cancelled = FALSE), 2) as on_time_arrival_rate_pct
from flights_booked_passengers fbp
left join non_cancelled_flights ncf on fbp.flight_number = ncf.flight_number
join aircraft ac on fbp.aircraft_id = ac.aircraft_id;