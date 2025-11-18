/*
----------------------------------------------------------------------------------------------------
Top/Bottom Route Performance by Booked Rate per Weekday Group
----------------------------------------------------------------------------------------------------
Purpose:
- Ranks routes by average booked rate within each of three weekday groups, then compares
  booking behavior and actual capacity utilization for top and bottom performers within
  each weekday group.
- Days of the week are grouped on the basis of having very similar booking performances:
  Friday and Sunday | Monday, Wednesday, and Thursday | Tuesday and Saturday
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
- See /visualizations/english/(05)_booked_rate_tb_routes_weekdays.png
  and /visualizations/german/(05)_buchungsrate_tf_routen_wochentage.png
----------------------------------------------------------------------------------------------------
*/

with weekday_groups as (
    select
        line_number,
        flight_date,
        case
            when extract(isodow from flight_date) in (1, 3, 4) then 'Mon/Wed/Thu'
            when extract(isodow from flight_date) in (2, 6) then 'Tue/Sat'
            when extract(isodow from flight_date) in (5, 7) then 'Fri/Sun'
            else 'Unlisted / Check Logic'
        end as weekday_group
    from flights_booked_passengers
),
weekday_route_passengers as (
    select
        f.line_number,
        wg.weekday_group,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from flights_booked_passengers f
    join weekday_groups wg on f.line_number = wg.line_number and f.flight_date = wg.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where f.cancelled = FALSE
    group by wg.weekday_group, f.line_number
),
weekday_route_bookings as (
    select
        f.line_number,
        wg.weekday_group,
        round(avg(f.booked_total), 2) as avg_booking_count,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate
    from flights_booked_passengers f
    join weekday_groups wg on f.line_number = wg.line_number and f.flight_date = wg.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by wg.weekday_group, f.line_number
),
weekday_route_ranks as (
    select
        wrb.line_number,
        wrb.weekday_group,
        wrb.avg_booking_count,
        wrb.avg_booked_rate,
        wrb.min_booked_rate,
        wrb.max_booked_rate,
        wrp.avg_passenger_count,
        wrp.avg_occupancy_rate,
        wrp.avg_check_in_gap,
        round((percent_rank() over (partition by wrb.weekday_group order by wrb.avg_booked_rate desc)
                   * 100)::numeric, 2) as booked_rate_pct_rank
    from weekday_route_bookings wrb
    join weekday_route_passengers wrp
        on wrb.line_number = wrp.line_number
       and wrb.weekday_group = wrp.weekday_group
),
params as (
    select 3 as top, 97 as bot
)
select
    case
        when wrr.booked_rate_pct_rank <= p.top then concat('Top ', p.top, '% – ',
                    replace(wrr.weekday_group, '/', ', '))
        when wrr.booked_rate_pct_rank >= p.bot then concat('Bottom ', p.top, '% – ',
                    replace(wrr.weekday_group, '/', ', '))
        else 'Middle'
    end as route_per_weekday_group_tier,
    wrr.weekday_group,
    wrr.line_number,
    concat(dep.airport_code, ', ', dep.city, ', ',
           case when dep.country = 'United Arab Emirates' then 'UAE' else dep.country end)
           as departure_location,
    concat(arr.airport_code, ', ', arr.city, ', ',
           case when arr.country = 'United Arab Emirates' then 'UAE' else arr.country end)
           as arrival_location,
    wrr.booked_rate_pct_rank,
    wrr.avg_booking_count,
    wrr.avg_booked_rate,
    wrr.min_booked_rate,
    wrr.max_booked_rate,
    wrr.avg_passenger_count,
    wrr.avg_occupancy_rate,
    wrr.avg_check_in_gap
from weekday_route_ranks wrr
join routes r on wrr.line_number = r.line_number
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
from weekday_route_ranks srr
group by ();


-- view for visualization with matplotlib/seaborn (Top/Bottom 3 instead of pct ranks)
create or replace view lf_tb_routes_weekdays as
    with weekday_groups as (
        select
            line_number,
            flight_date,
            case
                when extract(isodow from flight_date) in (1, 3, 4) then 'Mon/Wed/Thu'
                when extract(isodow from flight_date) in (2, 6) then 'Tue/Sat'
                when extract(isodow from flight_date) in (5, 7) then 'Fri/Sun'
                else 'Unlisted / Check Logic'
            end as weekday_group
        from flights_booked_passengers
    ),
    weekday_route_passengers as (
        select
            f.line_number,
            wg.weekday_group,
            round(avg(f.passengers_total), 2) as avg_passenger_count,
            round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
            round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
                as avg_check_in_gap
        from flights_booked_passengers f
        join weekday_groups wg on f.line_number = wg.line_number and f.flight_date = wg.flight_date
        join aircraft ac on f.aircraft_id = ac.aircraft_id
        where f.cancelled = FALSE
        group by wg.weekday_group, f.line_number
    ),
    weekday_route_bookings as (
        select
            f.line_number,
            wg.weekday_group,
            round(avg(f.booked_total), 2) as avg_booking_count,
            round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
            round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
            round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate
        from flights_booked_passengers f
        join weekday_groups wg on f.line_number = wg.line_number and f.flight_date = wg.flight_date
        join aircraft ac on f.aircraft_id = ac.aircraft_id
        group by wg.weekday_group, f.line_number
    ),
    weekday_route_ranks as (
        select
            wrb.line_number,
            wrb.weekday_group,
            wrb.avg_booking_count,
            wrb.avg_booked_rate,
            wrb.min_booked_rate,
            wrb.max_booked_rate,
            wrp.avg_passenger_count,
            wrp.avg_occupancy_rate,
            wrp.avg_check_in_gap,
            row_number() over (partition by wrp.weekday_group order by avg_booked_rate desc) as booked_rank_desc,
            row_number() over (partition by wrp.weekday_group order by avg_booked_rate) as booked_rank_asc
        from weekday_route_bookings wrb
        join weekday_route_passengers wrp
            on wrb.line_number = wrp.line_number
           and wrb.weekday_group = wrp.weekday_group
    ),
    params as (
        select 3 as rnk
    ),
    final as (
        select
            case
                when wrr.booked_rank_desc <= p.rnk then concat('Top ', p.rnk, ' – ',
                            replace(wrr.weekday_group, '/', ', '))
                when wrr.booked_rank_asc <= p.rnk then concat('Bottom ', p.rnk, ' – ',
                            replace(wrr.weekday_group, '/', ', '))
                else 'Middle'
            end as route_per_weekday_group_tier,
            wrr.weekday_group,
            wrr.line_number,
            concat(dep.airport_code, ', ', dep.city, ', ',
                   case when dep.country = 'United Arab Emirates' then 'UAE' else dep.country end)
                   as departure_location,
            concat(arr.airport_code, ', ', arr.city, ', ',
                   case when arr.country = 'United Arab Emirates' then 'UAE' else arr.country end)
                   as arrival_location,
            wrr.booked_rank_desc,
            wrr.avg_booking_count,
            wrr.avg_booked_rate,
            wrr.min_booked_rate,
            wrr.max_booked_rate,
            wrr.avg_passenger_count,
            wrr.avg_occupancy_rate,
            wrr.avg_check_in_gap
        from weekday_route_ranks wrr
        join routes r on wrr.line_number = r.line_number
        join airports dep on r.departure_airport_code = dep.airport_code
        join airports arr on r.arrival_airport_code = arr.airport_code
        cross join params p
        where booked_rank_desc <= p.rnk or booked_rank_asc <= p.rnk
    )
    select *
    from final
    order by
        case
            when route_per_weekday_group_tier = 'Top 3 – Fri, Sun' then 1
            when route_per_weekday_group_tier = 'Top 3 – Mon, Wed, Thu' then 2
            when route_per_weekday_group_tier = 'Top 3 – Tue, Sat' then 3
            when route_per_weekday_group_tier = 'Bottom 3 – Fri, Sun' then 4
            when route_per_weekday_group_tier = 'Bottom 3 – Mon, Wed, Thu' then 5
            when route_per_weekday_group_tier = 'Bottom 3 – Tue, Sat' then 6
        end,
        booked_rank_desc;