/*
----------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Flight Distance Category
----------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across flight distance categories.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
*/

with distance_categories as (
    select
        f.flight_number,
        case
            when r.distance_km < 1500 then '(1) Short-haul'
            when r.distance_km < 5000 then '(2) Medium-haul'
            else '(3) Long-haul'
        end as distance_category
    from flights_booked_passengers f
    join routes r on f.line_number = r.line_number
),
distance_passengers as (
    select
        coalesce(dc.distance_category, 'GRAND TOTAL (ALL)') as distance_category,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from distance_categories dc
    join flights_booked_passengers f on dc.flight_number = f.flight_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where f.cancelled = FALSE
    group by grouping sets (distance_category, ())
),
distance_bookings as (
    select
        coalesce(dc.distance_category, 'GRAND TOTAL (ALL)')  as distance_category,
        count(*) as scheduled_flight_count,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity,
        round(avg(fbp.booked_total), 2) as avg_booking_count,
        round(avg(fbp.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(min(fbp.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(fbp.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate,
        round(stddev_samp(fbp.booked_total * 100.0 / ac.seat_capacity), 2) as booked_rate_stddev
    from distance_categories dc
    join flights_booked_passengers fbp on dc.flight_number = fbp.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    group by grouping sets (distance_category, ())
)
select
    db.distance_category,
    db.scheduled_flight_count,
    db.avg_booking_capacity,
    db.avg_booking_count,
    db.avg_booked_rate,
    db.min_booked_rate,
    db.max_booked_rate,
    db.booked_rate_stddev,
    dp.avg_passenger_count,
    dp.avg_occupancy_rate,
    dp.avg_check_in_gap
from distance_bookings db
left join distance_passengers dp on db.distance_category = dp.distance_category
order by distance_category;