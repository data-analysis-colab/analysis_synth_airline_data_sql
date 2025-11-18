/*
----------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Passenger Class
----------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across passenger classes.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
*/

with class_passengers as (
    select
        coalesce(class_name, 'GRAND TOTAL') as class_name,
        round(avg(class_passengers), 2) as avg_passenger_count,
        round(avg(class_passengers * 100.0 / capacity), 2) as avg_occupancy_rate,
        round(avg((class_bookings * 100.0 / capacity) - (class_passengers * 100.0 / capacity)), 2) as avg_check_in_gap
    from flight_capacity_by_class_passengers
    where capacity > 0 and class_passengers > 0
    group by cube(class_name)
),
class_bookings as (
    select
        coalesce(class_name, 'GRAND TOTAL') as class_name,
        count(distinct flight_number) as flight_count,
        round(avg(capacity), 2) as avg_booking_capacity,
        round(avg(class_bookings), 2) as avg_booking_count,
        round(avg(class_bookings * 100.0 / capacity), 2) as avg_booked_rate,
        round(min(class_bookings * 100.0 / capacity), 2) as min_booked_rate,
        round(max(class_bookings * 100.0 / capacity), 2) as max_booked_rate
    from flight_capacity_by_class
    where capacity > 0
    group by cube(class_name)
)
select
    case
        when cb.class_name = 'Economy' then '(1) Economy'
        when cb.class_name = 'Business' then '(2) Business'
        when cb.class_name = 'First' then '(3) First'
        when cb.class_name = 'GRAND TOTAL' then 'GRAND TOTAL'
    end as passenger_class,
    cb.flight_count,
    cb.avg_booking_capacity,
    cb.avg_booking_count,
    cb.avg_booked_rate,
    cb.min_booked_rate,
    cb.max_booked_rate,
    cp.avg_passenger_count,
    cp.avg_occupancy_rate,
    cp.avg_check_in_gap
from class_bookings cb
left join class_passengers cp on cb.class_name = cp.class_name
order by passenger_class;