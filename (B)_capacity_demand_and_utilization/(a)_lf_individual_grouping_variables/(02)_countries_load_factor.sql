/*
--------------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Departure and Arrival Countries
--------------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across countries from which flights
  are scheduled to depart and countries in which flights are scheduled to arrive.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

Notes:
- *booked rate* is displayed separately for departures, arrivals, and as the combined average of both.
- All other metrics displayed combine departure and arrival values.
--------------------------------------------------------------------------------------------------------
*/

with departure_countries_passengers as (
    select
        coalesce(apt.country, 'GRAND TOTAL (ALL)') as country,
        count(*) as flight_count,
        round(avg(passengers_total), 2) as avg_passenger_count_dep,
        round(avg(passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate_dep,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap_dep
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports apt on r.departure_airport_code = apt.airport_code
    where f.cancelled = FALSE
    group by cube(apt.country)
),
departure_countries_bookings as (
    select
        coalesce(apt.country, 'GRAND TOTAL (ALL)') as country,
        count(*) as flight_count,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity_dep,
        round(avg(f.booked_total), 2) as avg_booking_count_dep,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate_dep,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate_dep,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate_dep
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports apt on r.departure_airport_code = apt.airport_code
    group by cube(apt.country)
),

arrival_countries_passengers as (
    select
        coalesce(apt.country, 'GRAND TOTAL (ALL)') as country,
        count(*) as flight_count,
        round(avg(f.passengers_total), 2) as avg_passenger_count_arr,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate_arr,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap_arr
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports apt on r.arrival_airport_code = apt.airport_code
    where cancelled = FALSE
    group by cube(apt.country)
),
arrival_countries_bookings as (
    select
        coalesce(apt.country, 'GRAND TOTAL (ALL)') as country,
        count(*) as flight_count,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity_arr,
        round(avg(f.booked_total), 2) as avg_booking_count_arr,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate_arr,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate_arr,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate_arr
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports apt on r.arrival_airport_code = apt.airport_code
    group by cube(apt.country)
)

select
    db.country as country_name,

    round((db.avg_booking_capacity_dep * db.flight_count + ab.avg_booking_capacity_arr * ab.flight_count) /
          nullif(db.flight_count + ab.flight_count, 0), 2) as avg_booking_capacity,
    round((db.avg_booking_count_dep * db.flight_count + ab.avg_booking_count_arr * ab.flight_count) /
          nullif(db.flight_count + ab.flight_count, 0), 2) as avg_bookings_count,

    round((db.avg_booked_rate_dep * db.flight_count + ab.avg_booked_rate_arr * ab.flight_count) /
          nullif(db.flight_count + ab.flight_count, 0), 2) as avg_booked_rate_overall,
    db.avg_booked_rate_dep,
    ab.avg_booked_rate_arr,

    least(db.min_booked_rate_dep, ab.min_booked_rate_arr) as min_booked_rate,
    greatest(db.max_booked_rate_dep, ab.max_booked_rate_arr) as max_booked_rate,

    round((dp.avg_passenger_count_dep * dp.flight_count + ap.avg_passenger_count_arr * ap.flight_count) /
          nullif(dp.flight_count + ap.flight_count, 0), 2) as avg_passenger_count,
    round((dp.avg_occupancy_rate_dep * dp.flight_count + ap.avg_occupancy_rate_arr * ap.flight_count) /
          nullif(dp.flight_count + ap.flight_count, 0), 2) as avg_occupancy_rate,
    round((dp.avg_check_in_gap_dep * dp.flight_count + ap.avg_check_in_gap_arr * ap.flight_count) /
          nullif(dp.flight_count + ap.flight_count, 0), 2) as avg_check_in_gap

from departure_countries_bookings db

-- Full outer joins anticipate the possibility of certain countries occurring only in departures or only in arrivals
-- This won't be the case with the underlying simulated database, but would be appropriate for real-world data.
full outer join departure_countries_passengers dp on db.country = dp.country
full outer join arrival_countries_passengers ap on db.country = ap.country
full outer join arrival_countries_bookings ab on db.country = ab.country
order by
    case when db.country != 'GRAND TOTAL (ALL)' then 1 else 2 end,
    avg_booked_rate_overall desc;