/*
----------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Travel Season
----------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across travel seasons.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.
----------------------------------------------------------------------------------------------------
Note:
- While spring, summer, and autumn correspond to calendar seasons, winter was separated into
  January + February vs. December, highlighting major performance differences between the start
  of the year and the winter holidays.
----------------------------------------------------------------------------------------------------
 */

with travel_seasons as (
    select
        flight_number,
        flight_date,
        case
            when extract(month from flight_date) in (1, 2) then '(1) Jan & Feb'
            when extract(month from flight_date) in (3, 4, 5) then '(2) Spring'
            when extract(month from flight_date) in (6, 7, 8) then '(3) Summer'
            when extract(month from flight_date) in (9, 10, 11) then '(4) Autumn'
            when extract(month from flight_date) = 12 then '(5) December'
            else 'Unlisted month / Check logic'
        end as travel_season
    from flights_booked_passengers
),
seasonal_passengers as (
    select
        coalesce(ts.travel_season, 'GRAND TOTAL (ALL)') as travel_season,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from flights_booked_passengers f
    join travel_seasons ts on f.flight_number = ts.flight_number and f.flight_date = ts.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where f.cancelled = FALSE
    group by grouping sets (ts.travel_season, ())
),
seasonal_bookings as (
    select
        coalesce(ts.travel_season, 'GRAND TOTAL (ALL)') as travel_season,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity,
        round(avg(f.booked_total), 2) as avg_bookings_count,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate,
        round(stddev(f.booked_total * 100.0 / ac.seat_capacity), 2) as booked_rate_stddev
    from flights_booked_passengers f
    join travel_seasons ts on f.flight_number = ts.flight_number and f.flight_date = ts.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by grouping sets (ts.travel_season, ())
)
select
    sb.travel_season,
    sb.avg_booking_capacity,
    sb.avg_bookings_count,
    sb.avg_booked_rate,
    sb.min_booked_rate,
    sb.max_booked_rate,
    sb.booked_rate_stddev,
    sp.avg_passenger_count,
    sp.avg_occupancy_rate,
    sp.avg_check_in_gap
from seasonal_bookings sb
left join seasonal_passengers sp on sb.travel_season = sp.travel_season
where sb.travel_season != 'GRAND TOTAL (ALL)' and sp.travel_season != 'GRAND TOTAL (ALL)'

union all

select
    sb.travel_season,
    sb.avg_booking_capacity,
    sb.avg_bookings_count,
    sb.avg_booked_rate,
    sb.min_booked_rate,
    sb.max_booked_rate,
    sb.booked_rate_stddev,
    sp.avg_passenger_count,
    sp.avg_occupancy_rate,
    sp.avg_check_in_gap
from seasonal_bookings sb
left join seasonal_passengers sp on sb.travel_season = sp.travel_season
where sb.travel_season = 'GRAND TOTAL (ALL)' and sp.travel_season = 'GRAND TOTAL (ALL)'
order by travel_season;