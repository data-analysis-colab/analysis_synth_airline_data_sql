/*
----------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Day of the Week
----------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across days of the week.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
 */

with isodows as (
    select
        flight_number,
        flight_date,
        extract(isodow from flight_date) as iso_day_number,
        trim(to_char(flight_date, 'Day')) as day_of_week
    from flights_booked_passengers
),
weekday_passengers as (
    select
        i.iso_day_number,
        coalesce(i.day_of_week, 'GRAND TOTAL (ALL)') as day_of_week,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from isodows i
    join flights_booked_passengers f on i.flight_number = f.flight_number and i.flight_date = f.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
    group by grouping sets ((i.day_of_week, i.iso_day_number), ())
    order by i.iso_day_number nulls last
),
weekday_bookings as (
    select
        i.iso_day_number,
        coalesce(i.day_of_week, 'GRAND TOTAL (ALL)') as day_of_week,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity,
        round(avg(f.booked_total), 2) as avg_booking_count,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(stddev(f.booked_total * 100.0 / ac.seat_capacity), 2) as booked_rate_stddev
    from isodows i
    join flights_booked_passengers f on i.flight_number = f.flight_number and i.flight_date = f.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by grouping sets ((i.day_of_week, i.iso_day_number), ())
    order by i.iso_day_number
)
select
    concat('(', wb.iso_day_number, ') ', wb.day_of_week) as day_of_week,
    wb.avg_booking_capacity,
    wb.avg_booking_count,
    wb.min_booked_rate,
    wb.max_booked_rate,
    wb.avg_booked_rate,
    wb.booked_rate_stddev,
    wp.avg_passenger_count,
    wp.avg_occupancy_rate,
    wp.avg_check_in_gap
from weekday_bookings wb
left join weekday_passengers wp on wb.day_of_week = wp.day_of_week
where wb.day_of_week != 'GRAND TOTAL (ALL)' and wp.day_of_week != 'GRAND TOTAL (ALL)'

union all

select
    wb.day_of_week,
    wb.avg_booking_capacity,
    wb.avg_booking_count,
    wb.min_booked_rate,
    wb.max_booked_rate,
    wb.avg_booked_rate,
    wb.booked_rate_stddev,
    wp.avg_passenger_count,
    wp.avg_occupancy_rate,
    wp.avg_check_in_gap
from weekday_bookings wb
left join weekday_passengers wp on wb.day_of_week = wp.day_of_week
where wb.day_of_week = 'GRAND TOTAL (ALL)' and wp.day_of_week = 'GRAND TOTAL (ALL)'

order by day_of_week;