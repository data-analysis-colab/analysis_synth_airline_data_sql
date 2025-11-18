/*
----------------------------------------------------------------------------------------------
Cabin Configurations by Flight Distance and Aircraft Size
----------------------------------------------------------------------------------------------
Goal:
    Summarize how cabin configurations are distributed across flights and how they correlate
    with flight distance and aircraft size, measured in total seat capacity.

Notes:
    - The three types of cabin configurations in the dataset are "Economy only",
      "Economy, Business", and "Economy, Business, First".
    - The cabin_configuration column is not part of the original flights table. It is added
      in flights_booked_passengers, a slightly modified view of the flights table.
----------------------------------------------------------------------------------------------
*/

with capacities as (
    select
        flight_number, sum(capacity) as capacity
    from flight_capacity_by_class
    group by flight_number
),

stats as (
    select
        fbp.cabin_configuration,
        fcc.flight_number,
        c.capacity,
        r.distance_km,
        ac.seat_capacity,
        sum(ac.seat_capacity) over () as tot_seat_capacity_overall
    from flight_capacity_by_class fcc
    join flights_booked_passengers fbp on fcc.flight_number = fbp.flight_number
    join routes r on fbp.line_number = r.line_number
    join capacities c on fcc.flight_number = c.flight_number
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    where fcc.capacity > 0
),

grouped as (
    select
        case when grouping(cabin_configuration) = 1 then 'OVERALL' else cabin_configuration end as cabin_configuration,
        count(distinct flight_number) as num_flights,
        min(distance_km) as min_distance_km,
        max(distance_km) as max_distance_km,
        min(seat_capacity) as min_aircraft_seat_cap,
        max(seat_capacity) as max_aircraft_seat_cap,
        sum(capacity) as total_seat_capacity
    from stats
    group by cube(cabin_configuration)
)

select
    cabin_configuration,
    num_flights,
    round(num_flights * 100.0 / (select count(*) from flights_booked_passengers), 2) as flight_share_pct,
    min_distance_km,
    max_distance_km,
    min_aircraft_seat_cap,
    max_aircraft_seat_cap,
    total_seat_capacity,
    round(total_seat_capacity * 100.0 / (select max(tot_seat_capacity_overall) from stats), 2)
        as overall_seat_cap_share_pct
from grouped;