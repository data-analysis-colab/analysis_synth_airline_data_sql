/*
----------------------------------------------------------------------------------------------------
Global and Seasonal Route Performance by Average Booked Rate
----------------------------------------------------------------------------------------------------
Purpose:
- Divides all routes into both global/overall and seasonal performance tiers based on average
  booked rate, then compares booking behavior and actual capacity utilization across the
  intersections of both tiers.
- Shows the presence of outliers, e.g., routes that are top performers globally but perform
  significantly worse than other routes during a particular season.
- While spring, summer, and autumn correspond to calendar seasons, winter was separated into
  January + February vs. December, highlighting major performance differences between the start
  of the year and the winter holidays.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
Interpretation:
- Global/overall route tiers are ordered by capital letters A-E, seasonal tiers by lower case
  letters a-e.
- We would generally expect that route distributions across global and seasonal tiers mostly
  mirror each other: global A-tier routes will be split across seasonal a- and b-tiers,
  seasonal a-tier routes will be split across global A- and B-Tiers, etc.
- If there are (non-empty) intersections between global and seasonal groupings that are more
  than two tiers apart, the routes making up these intersections can be considered outliers, e.g.,
  routes that fall into the global A-tier but into the seasonal d-tier during autumn months.
----------------------------------------------------------------------------------------------------
This query has been visualized with Seaborn/Matplotlib.
See /visualizations/english/(02b)_route_count_booked_rate_heatmap.png
and /visualizations/german/(02b)_routen_anzahl_buchungsrate_reisezeiten_heatmap.png
----------------------------------------------------------------------------------------------------
*/

with travel_seasons as (
    select
        line_number,
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
seasonal_route_passengers as (
    select
        f.line_number,
        ts.travel_season,
        avg(f.passengers_total) as avg_passenger_count,
        avg(f.passengers_total * 100.0 / ac.seat_capacity) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from flights_booked_passengers f
    join travel_seasons ts on f.line_number = ts.line_number and f.flight_date = ts.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where f.cancelled = FALSE
    group by ts.travel_season, f.line_number
),
seasonal_route_bookings as (
    select
        f.line_number,
        ts.travel_season,
        avg(ac.seat_capacity) as avg_booking_capacity,
        avg(f.booked_total) as avg_booking_count,
        min(f.booked_total * 100.0 / ac.seat_capacity) as min_booked_rate,
        max(f.booked_total * 100.0 / ac.seat_capacity) as max_booked_rate,
        avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate
    from flights_booked_passengers f
    join travel_seasons ts on f.line_number = ts.line_number and f.flight_date = ts.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by ts.travel_season, f.line_number
),
seasonal_route_tiers as (
    select
        case
            when srb.avg_booked_rate > 85 then '(a) Top Perf. in Season'
            when srb.avg_booked_rate > 75 then '(b) Within Target in Season'
            when srb.avg_booked_rate >= 70 then '(c) Sufficient in Season'
            when srb.avg_booked_rate >= 60 then '(d) Weak Perf. in Season'
            when srb.avg_booked_rate < 60 then '(e) Unsustainable in Season'
            else 'Unclassified / Check Logic'
        end as seasonal_performance_tier,
        srb.line_number,
        srb.travel_season,
        srb.avg_booking_capacity,
        srb.avg_booking_count,
        srb.min_booked_rate,
        srb.max_booked_rate,
        srb.avg_booked_rate,
        srp.avg_passenger_count,
        srp.avg_occupancy_rate,
        srp.avg_check_in_gap
    from seasonal_route_bookings srb
    left join seasonal_route_passengers srp on srb.line_number = srp.line_number and
                                               srb.travel_season = srp.travel_season
),

route_bookings as (
    select
        f.line_number,
        avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by f.line_number
)

select
    case
        when rb.avg_booked_rate > 85 then '(A) Top Perf. Globally'
        when rb.avg_booked_rate > 75 then '(B) Within Target Globally'
        when rb.avg_booked_rate >= 70 then '(C) Sufficient Globally'
        when rb.avg_booked_rate >= 60 then '(D) Weak Perf. Globally'
        when rb.avg_booked_rate < 60 then '(E) Unsustainable Globally'
        else 'Unclassified / Check Logic'
    end as global_route_performance_tier,
    travel_season,
    seasonal_performance_tier,
    count(*) as route_count,
    round(avg(srt.avg_booking_capacity), 2) as avg_seat_capacity,
    round(avg(srt.avg_booking_count), 2) as avg_booking_count,
    round(avg(srt.avg_booked_rate), 2) as avg_booked_rate,
    round(min(srt.min_booked_rate), 2) as min_booked_rate,
    round(max(srt.max_booked_rate), 2) as max_booked_rate,
    round(stddev_samp(srt.avg_booked_rate), 2) as booked_rate_stddev,
    round(avg(srt.avg_passenger_count), 2) as avg_passenger_count,
    round(avg(srt.avg_occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(srt.avg_check_in_gap), 2) as avg_check_in_gap
from seasonal_route_tiers srt
join route_bookings rb on srt.line_number = rb.line_number
group by global_route_performance_tier, srt.seasonal_performance_tier, srt.travel_season

union all

select
    'GRAND TOTAL (ALL)',
    '(ALL)',
    'GRAND TOTAL (ALL)',
    count(distinct rb.line_number),
    round(avg(srt.avg_booking_capacity), 2),
    round(avg(srt.avg_booking_count), 2),
    round(avg(srt.avg_booked_rate), 2),
    round(min(srt.min_booked_rate), 2),
    round(max(srt.max_booked_rate), 2),
    round(stddev_samp(srt.avg_booked_rate), 2),
    round(avg(srt.avg_passenger_count), 2),
    round(avg(srt.avg_occupancy_rate), 2),
    round(avg(srt.avg_check_in_gap), 2)
from seasonal_route_tiers srt
join route_bookings rb on srt.line_number = rb.line_number
group by ()

order by global_route_performance_tier, travel_season, seasonal_performance_tier;