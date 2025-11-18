/*
----------------------------------------------------------------------------------------------------
Average Booked Rate vs. Occupancy Rate by Holiday Periods
----------------------------------------------------------------------------------------------------
Purpose:
- Compares booking behavior and actual capacity utilization across the most important holiday
  periods vs. non-holiday periods.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
*/

with holiday_periods as (
    select
        flight_number,
        flight_date,
        case
            -- date ranges for Easter holidays have to be adjusted relative to which years are included in the database
            when flight_date between '2022-04-15' and '2022-04-18' then '(1) Easter Holidays'
            when flight_date between '2023-04-07' and '2023-04-10' then '(1) Easter Holidays'
            when flight_date between '2024-03-29' and '2024-04-01' then '(1) Easter Holidays'
            when extract(month from flight_date) = 7 and
                 extract(day from flight_date) between 1 and 8 then '(2) Summer Holidays'
            when extract(month from flight_date) = 12 and
                 extract(day from flight_date) between 20 and 31 then '(3) Winter Holidays'
            else '(4) Non-Holiday Period'
        end as holiday_period
    from flights_booked_passengers
),
holiday_passengers as (
    select
        coalesce(hp.holiday_period, 'GRAND TOTAL (ALL)') as holiday_period,
        round(avg(ac.seat_capacity), 2) as avg_seat_capacity,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round((avg(f.passengers_total * 100.0 / ac.seat_capacity)), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from holiday_periods hp
    join flights_booked_passengers f on hp.flight_number = f.flight_number and hp.flight_date = f.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
    group by grouping sets (holiday_period, ())
),
holiday_bookings as (
    select
        coalesce(hp.holiday_period, 'GRAND TOTAL (ALL)') as holiday_period,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity,
        round(avg(f.booked_total), 2) as avg_booking_count,
        round((avg(f.booked_total * 100.0 / ac.seat_capacity)), 2) as avg_booked_rate,
        round((min(f.booked_total * 100.0 / ac.seat_capacity)), 2) as min_booked_rate,
        round((max(f.booked_total * 100.0 / ac.seat_capacity)), 2) as max_booked_rate,
        round((stddev(f.booked_total * 100.0 / ac.seat_capacity)), 2) as booked_rate_stddev
    from holiday_periods hp
    join flights_booked_passengers f on hp.flight_number = f.flight_number and hp.flight_date = f.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by grouping sets (holiday_period, ())
)
select
    hb.holiday_period,
    hb.avg_booking_capacity,
    hb.avg_booking_count,
    hb.avg_booked_rate,
    hb.min_booked_rate,
    hb.max_booked_rate,
    hb.booked_rate_stddev,
    hp.avg_passenger_count,
    hp.avg_occupancy_rate,
    hp.avg_check_in_gap
from holiday_bookings hb
join holiday_passengers hp on hb.holiday_period = hp.holiday_period
where hb.holiday_period != 'GRAND TOTAL (ALL)' and hp.holiday_period != 'GRAND TOTAL (ALL)'

union all

select
    hb.holiday_period,
    hb.avg_booking_capacity,
    hb.avg_booking_count,
    hb.avg_booked_rate,
    hb.min_booked_rate,
    hb.max_booked_rate,
    hb.booked_rate_stddev,
    hp.avg_passenger_count,
    hp.avg_occupancy_rate,
    hp.avg_check_in_gap
from holiday_bookings hb
left join holiday_passengers hp on hb.holiday_period = hp.holiday_period
where hb.holiday_period = 'GRAND TOTAL (ALL)' and hp.holiday_period = 'GRAND TOTAL (ALL)'

order by holiday_period;