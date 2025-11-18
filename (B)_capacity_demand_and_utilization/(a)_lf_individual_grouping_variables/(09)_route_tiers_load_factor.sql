/*
--------------------------------------------------------------------------------------------------------
Route Performance by Average Booked Rate
--------------------------------------------------------------------------------------------------------
Purpose:
- Groups routes into performance tiers based on *average booked rate*.
- Compares booking behavior and actual capacity utilization across tiers.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

--------------------------------------------------------------------------------------------------------
*/

with route_passengers as (
    select
        line_number,
        avg(f.passengers_total) as avg_passenger_count,
        sum(f.passengers_total) * 100 / sum(ac.seat_capacity) as occupancy_rate,
        round((sum(f.booked_total) - sum(f.passengers_total)) * 100.0 / sum(ac.seat_capacity), 2) as check_in_gap
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
    group by line_number
),
route_bookings as (
    select
        line_number,
        avg(ac.seat_capacity) as avg_booking_capacity,
        avg(f.booked_total) as avg_bookings_count,
        sum(f.booked_total) * 100 / sum(ac.seat_capacity) as booked_rate
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by line_number
),
route_combined as (
    select
        case
            when booked_rate > 85 then '(A) Top Performance (> 85%)'
            when booked_rate > 75 then '(B) Within Target (76–85%)'
            when booked_rate >= 70 then '(C) Sufficient (70–75%)'
            when booked_rate >= 60 then '(D) Underperforming (< 70%)'
            when booked_rate < 60 then '(E) Unsustainable (< 60%)'
            else 'Unclassified / Check Logic'
        end as route_booked_performance_tier,
        rb.line_number,
        rb.avg_booking_capacity,
        rb.avg_bookings_count,
        rp.avg_passenger_count,
        rb.booked_rate,
        rp.occupancy_rate,
        rp.check_in_gap
    from route_bookings rb
    left join route_passengers rp on rb.line_number = rp.line_number
)
select
    coalesce(route_booked_performance_tier, 'GRAND TOTAL (ALL') as routes_booked_performance_tier,
    count(line_number) as route_count,
    round(count(line_number) * 100.0 / (select count(line_number) from route_combined), 2) as routes_share,
    round(avg(avg_booking_capacity), 2) as avg_booking_capacity,
    round(avg(booked_rate), 2) as avg_booked_rate,
    round(min(booked_rate), 2) as min_booked_rate,
    round(max(booked_rate), 2) as max_booked_rate,
    round(stddev_samp(booked_rate), 2) as booked_rate_stddev,
    round(avg(occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(check_in_gap), 2) as avg_check_in_gap
from route_combined
group by cube(route_booked_performance_tier)
order by route_booked_performance_tier nulls last;