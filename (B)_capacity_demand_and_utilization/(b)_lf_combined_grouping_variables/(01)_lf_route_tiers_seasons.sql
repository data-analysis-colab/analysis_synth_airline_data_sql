/*
----------------------------------------------------------------------------------------------------
Seasonal Booking Trends by Route Performance Tier
----------------------------------------------------------------------------------------------------
Purpose:
- Divides routes into performance tiers based on average booked rate, then compares
  booking behavior and actual capacity utilization across both route performance tiers
  and each of five travel seasons.
- Shows if the way seasonal performance contributes to each route tier's overall performance is
  consistent across all tiers.
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
This query has been visualized with Seaborn/Matplotlib as a heatmap with combined global and
seasonal performance tiers as x-axis and travel seasons as y-axis.
See /visualizations/english/(02a)_booked_rate_routes_seasons_heatmap.png
and /visualizations/german/(02a)_buchungsrate_routen_reisezeiten_heatmap.png
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
        avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate,
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
        fbp.line_number,
        ts.travel_season,
        avg(ac.seat_capacity) as avg_booking_capacity,
        avg(fbp.booked_total) as avg_booking_count,
        avg(fbp.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate,
        min(fbp.booked_total * 100.0 / ac.seat_capacity) as min_booked_rate,
        max(fbp.booked_total * 100.0 / ac.seat_capacity) as max_booked_rate
    from flights_booked_passengers fbp
    join travel_seasons ts on fbp.line_number = ts.line_number and fbp.flight_date = ts.flight_date
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    group by ts.travel_season, fbp.line_number
),
seasonal_route_combined as (
    select
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

-- basis for generating global route performance tiers
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
        when rb.avg_booked_rate > 85 then '(A) Top Performance|> 85% Overall Avg BR'
        when rb.avg_booked_rate > 75 then '(B) Within Target|76-85% Overall Avg BR'
        when rb.avg_booked_rate >= 70 then '(C) Sufficient|70-75% Overall Avg BR'
        when rb.avg_booked_rate >= 60 then '(D) Underperforming|< 70% Overall Avg BR'
        when rb.avg_booked_rate < 60 then '(E) Unsustainable|< 60% Overall Avg BR'
        else 'Unclassified / Check Logic'
    end as route_performance_tier,
    count(distinct rb.line_number) as route_tier_count,
    round(count(distinct rb.line_number) * 100.0 /
          (select count(distinct line_number) from route_bookings), 2) as routes_tier_share,
    case
        when grouping(src.travel_season) = 1 then '(ALL SEASONS)'
        else src.travel_season
    end as travel_season,
    round(avg(src.avg_booking_capacity), 2) as avg_seat_capacity,
    round(avg(src.avg_booking_count), 2) as avg_booking_count,
    round(avg(src.avg_booked_rate), 2) as avg_booked_rate,
    round(min(src.min_booked_rate), 2) as min_booked_rate,
    round(max(src.max_booked_rate), 2) as max_booked_rate,
    round(stddev_samp(src.avg_booked_rate), 2) as booked_rate_stddev,
    round(avg(src.avg_passenger_count), 2) as avg_passenger_count,
    round(avg(src.avg_occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(src.avg_check_in_gap), 2) as avg_check_in_gap
from seasonal_route_combined src
join route_bookings rb on src.line_number = rb.line_number
group by grouping sets ((route_performance_tier, src.travel_season), route_performance_tier)

union all

select
    'GRAND TOTAL (ALL TIERS)',
    count(distinct rb.line_number),
    round(count(distinct rb.line_number) * 100.0 /
          (select count(distinct line_number) from route_bookings), 2),
    '(ALL SEASONS)',
    round(avg(src.avg_booking_capacity), 2),
    round(avg(src.avg_booking_count), 2),
    round(avg(src.avg_booked_rate), 2),
    round(min(src.min_booked_rate), 2),
    round(max(src.max_booked_rate), 2),
    round(stddev_samp(src.avg_booked_rate), 2),
    round(avg(src.avg_passenger_count), 2),
    round(avg(src.avg_occupancy_rate), 2),
    round(avg(src.avg_check_in_gap), 2)
from seasonal_route_combined src
join route_bookings rb on src.line_number = rb.line_number
group by ()

order by route_performance_tier, travel_season;