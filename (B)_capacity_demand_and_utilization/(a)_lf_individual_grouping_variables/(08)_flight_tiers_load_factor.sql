/*
--------------------------------------------------------------------------------------------------------
Flight Performance by Average Booked Rate
--------------------------------------------------------------------------------------------------------
Purpose:
- Groups flights into performance tiers based on *average booked rate*.
- Compares booking behavior and actual capacity utilization across tiers.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

--------------------------------------------------------------------------------------------------------
*/

with flight_passengers as (
    select
        f.flight_number,
        f.passengers_total,
        f.passengers_total * 100.0 / ac.seat_capacity as occupancy_rate,
        f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity as check_in_gap
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
),
flight_bookings as (
    select
        f.flight_number,
        count(*) over () as tot_flight_count,
        ac.seat_capacity as booking_capacity,
        f.booked_total,
        f.booked_total * 100.0 / ac.seat_capacity as booked_rate,
        case
            when f.booked_total * 100.0 / ac.seat_capacity > 85 then '(A) Top Performance (> 85%)'
            when f.booked_total * 100.0 / ac.seat_capacity > 75 then '(B) Within Target (76-85%)'
            when f.booked_total * 100.0 / ac.seat_capacity >= 70 then '(C) Sufficient (70-75%)'
            when f.booked_total * 100.0 / ac.seat_capacity >= 60 then '(D) Underperforming (< 70%)'
            when f.booked_total * 100.0 / ac.seat_capacity < 60 then '(E) Substantially Underperf. (< 60%)'
            else 'Unclassified / Check Logic'
        end as flight_booked_performance_tier
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    order by f.flight_number
)
select
    coalesce(fb.flight_booked_performance_tier, 'GRAND TOTAL (ALL)') as flights_booked_performance_tier,
    count(fb.flight_number) as flight_count,
    round(count(fb.flight_number) * 100.0 / min(tot_flight_count), 2)
        as flights_share,
    round(avg(fb.booking_capacity), 2) as avg_booking_capacity,
    round(avg(fb.booked_total), 2) as avg_bookings_count,
    round(avg(fb.booked_rate), 2) as avg_booked_rate,
    round(min(fb.booked_rate), 2) as min_booked_rate,
    round(max(fb.booked_rate), 2) as max_booked_rate,
    round(stddev(fb.booked_rate), 2) as booked_rate_stddev,
    round(avg(fp.passengers_total), 2) as avg_passenger_count,
    round(avg(fp.occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(fp.check_in_gap), 2) as avg_check_in_gap
from flight_bookings fb
left join flight_passengers fp on fb.flight_number = fp.flight_number
group by cube(fb.flight_booked_performance_tier)
order by fb.flight_booked_performance_tier nulls last;