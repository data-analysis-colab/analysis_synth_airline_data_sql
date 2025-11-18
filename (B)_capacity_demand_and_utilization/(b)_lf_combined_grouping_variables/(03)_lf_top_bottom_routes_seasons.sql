/*
----------------------------------------------------------------------------------------------------
Top/Bottom Route Performance by Booked Rate per Travel Season
----------------------------------------------------------------------------------------------------
Purpose:
- Ranks routes by average booked rate within each of five travel seasons, then compares
  booking behavior and actual capacity utilization for top and bottom performers within
  each travel season.
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
Notes:
- A view is created below, slightly modifying the query for visualization
  with Seaborn/Matplotlib.
- See /visualizations/english/(03)_booked_rate_tb_routes_seasons.png
  and /visualizations/german/(03)_buchungsrate_tf_routen_reisezeit.png
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
            else 'Unlisted / Check Logic'
        end as travel_season
    from flights_booked_passengers
),
seasonal_route_passengers as (
    select
        f.line_number,
        ts.travel_season,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
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
        round(avg(f.booked_total), 2) as avg_booking_count,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate
    from flights_booked_passengers f
    join travel_seasons ts on f.line_number = ts.line_number and f.flight_date = ts.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by ts.travel_season, f.line_number
),
seasonal_route_ranks as (
    select
        srb.line_number,
        srb.travel_season,
        srb.avg_booking_count,
        srb.avg_booked_rate,
        srb.min_booked_rate,
        srb.max_booked_rate,
        srp.avg_passenger_count,
        srp.avg_occupancy_rate,
        srp.avg_check_in_gap,
        round((percent_rank() over (partition by srb.travel_season order by avg_booked_rate desc) * 100)::numeric, 2)
            as booked_rate_pct_rank
    from seasonal_route_bookings srb
    join seasonal_route_passengers srp on srb.line_number = srp.line_number and
                                          srb.travel_season = srp.travel_season
    order by srb.avg_booked_rate desc
),
params as (
  select 2 as top, 98 as bot
)
select
    case
        when srr.booked_rate_pct_rank <= p.top then concat('Top ', p.top, '% – ', substr(srr.travel_season, 5))
        when srr.booked_rate_pct_rank >= p.bot then concat('Bottom ', p.top, '% – ', substr(srr.travel_season, 5))
        else 'Middle'
    end as route_per_travel_season_tier,
    srr.travel_season,
    srr.line_number,
    concat(dep.airport_code, ', ', dep.city, ', ',
           case when dep.country = 'United Arab Emirates' then 'UAE' else dep.country end)
           as departure_location,
    concat(arr.airport_code, ', ', arr.city, ', ',
           case when arr.country = 'United Arab Emirates' then 'UAE' else arr.country end)
           as arrival_location,
    srr.booked_rate_pct_rank,
    srr.avg_booking_count,
    srr.avg_booked_rate,
    srr.min_booked_rate,
    srr.max_booked_rate,
    srr.avg_passenger_count,
    srr.avg_occupancy_rate,
    srr.avg_check_in_gap
from seasonal_route_ranks srr
join routes r on srr.line_number = r.line_number
join airports dep on r.departure_airport_code = dep.airport_code
join airports arr on r.arrival_airport_code = arr.airport_code
cross join params p
where booked_rate_pct_rank <= p.top or booked_rate_pct_rank >= p.bot

union all

select
    'GRAND TOTAL (ALL ROUTES)',
    '(ALL)',
    null,
    null,
    null,
    null,
    round(avg(srr.avg_booking_count), 2),
    round(avg(srr.avg_booked_rate), 2),
    round(min(srr.min_booked_rate), 2),
    round(max(srr.max_booked_rate), 2),
    round(avg(srr.avg_passenger_count), 2),
    round(avg(srr.avg_occupancy_rate), 2),
    round(avg(srr.avg_check_in_gap), 2)
from seasonal_route_ranks srr
group by ()

order by travel_season nulls last, booked_rate_pct_rank;



-- view for visualization with matplotlib/seaborn (Top/Bottom 2 instead of pct ranks)
create or replace view lf_tb_routes_seasons as
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
                else 'Unlisted / Check Logic'
            end as travel_season
        from flights_booked_passengers
    ),
    seasonal_route_passengers as (
        select
            f.line_number,
            ts.travel_season,
            round(avg(f.passengers_total), 2) as avg_passenger_count,
            round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
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
            round(avg(f.booked_total), 2) as avg_booking_count,
            round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
            round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
            round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate
        from flights_booked_passengers f
        join travel_seasons ts on f.line_number = ts.line_number and f.flight_date = ts.flight_date
        join aircraft ac on f.aircraft_id = ac.aircraft_id
        group by ts.travel_season, f.line_number
    ),
    seasonal_route_ranks as (
        select
            srb.line_number,
            srb.travel_season,
            srb.avg_booking_count,
            srb.avg_booked_rate,
            srb.min_booked_rate,
            srb.max_booked_rate,
            srp.avg_passenger_count,
            srp.avg_occupancy_rate,
            srp.avg_check_in_gap,
            row_number() over (partition by srb.travel_season order by avg_booked_rate desc) as booked_rank_desc,
            row_number() over (partition by srb.travel_season order by avg_booked_rate) as booked_rank_asc
        from seasonal_route_bookings srb
        join seasonal_route_passengers srp on srb.line_number = srp.line_number and
                                              srb.travel_season = srp.travel_season
        order by srb.avg_booked_rate desc
    ),
    params as (
      select 2 as rnk
    ),
    final as (
        select
            case
                when srr.booked_rank_desc <= p.rnk then concat('Top ', p.rnk, ' – ', substr(srr.travel_season, 5))
                when srr.booked_rank_asc <= p.rnk then concat('Bottom ', p.rnk, ' – ', substr(srr.travel_season, 5))
                else 'Middle'
            end as route_per_travel_season_tier,
            srr.travel_season,
            srr.line_number,
            concat(dep.airport_code, ', ', dep.city, ', ',
                   case when dep.country = 'United Arab Emirates' then 'UAE' else dep.country end)
                   as departure_location,
            concat(arr.airport_code, ', ', arr.city, ', ',
                   case when arr.country = 'United Arab Emirates' then 'UAE' else arr.country end)
                   as arrival_location,
            srr.booked_rank_desc,
            srr.avg_booking_count,
            srr.avg_booked_rate,
            srr.min_booked_rate,
            srr.max_booked_rate,
            srr.avg_passenger_count,
            srr.avg_occupancy_rate,
            srr.avg_check_in_gap
        from seasonal_route_ranks srr
        join routes r on srr.line_number = r.line_number
        join airports dep on r.departure_airport_code = dep.airport_code
        join airports arr on r.arrival_airport_code = arr.airport_code
        cross join params p
        where booked_rank_desc <= p.rnk or booked_rank_asc <= p.rnk
        order by travel_season, route_per_travel_season_tier desc, booked_rank_desc
    )
    select *
    from final
    order by
        case when starts_with(route_per_travel_season_tier, 'Top') then 1 else 2 end,
        travel_season,
        booked_rank_desc;