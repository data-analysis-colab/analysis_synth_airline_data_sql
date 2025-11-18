/*
----------------------------------------------------------------------------------------------------
Weekday Booking Trends by Route Performance Tier
----------------------------------------------------------------------------------------------------
Purpose:
- Divides routes into performance tiers based on average booked rate, then compares
  booking behavior and actual capacity utilization across both route performance tiers
  and each of three weekday groups.
- Shows if the way weekday group performance contributes to each route tier's overall
  performance is consistent across all tiers.
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
- See /visualizations/english/(04)_booked_rate_routes_weekdays_lineplot.png
  and /visualizations/german/(04)_buchungsrate_routen_wochentage_lineplot.png
----------------------------------------------------------------------------------------------------
*/

with weekday_route_passengers as (
    select
        f.line_number,
        extract(isodow from f.flight_date) as iso_day_number,
        avg(f.passengers_total) as avg_passenger_count,
        avg(f.passengers_total * 100.0 / ac.seat_capacity) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where f.cancelled = FALSE
    group by iso_day_number, f.line_number
),
weekday_route_bookings as (
    select
        f.line_number,
        extract(isodow from f.flight_date) as iso_day_number,
        avg(ac.seat_capacity) as avg_booking_capacity,
        avg(f.booked_total) as avg_booking_count,
        avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate,
        min(f.booked_total * 100.0 / ac.seat_capacity) as min_booked_rate,
        max(f.booked_total * 100.0 / ac.seat_capacity) as max_booked_rate
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by iso_day_number, f.line_number
),
weekday_route_combined as (
    select
        wrb.line_number,
        case
            -- numeric weekday_group label ordering based on avg_booked_rate desc (previously established)
            when wrb.iso_day_number in (1, 3, 4) then '(2) Mon/Wed/Thu'
            when wrb.iso_day_number in (2, 6) then '(3) Tue/Sat'
            when wrb.iso_day_number in (5, 7) then '(1) Fri/Sun'
        end as weekday_group,
        wrb.avg_booking_capacity,
        wrb.avg_booking_count,
        wrb.min_booked_rate,
        wrb.max_booked_rate,
        wrb.avg_booked_rate,
        wrp.avg_passenger_count,
        wrp.avg_occupancy_rate,
        wrp.avg_check_in_gap
    from weekday_route_bookings wrb
    left join weekday_route_passengers wrp on wrb.line_number = wrp.line_number and
                                              wrb.iso_day_number = wrp.iso_day_number
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
        when rb.avg_booked_rate < 60 then '(E) Unsustainable|(< 60% Overall Avg BR'
        else 'Unclassified / Check Logic'
    end as route_performance_tier,
    count(distinct rb.line_number) as route_tier_count,
    round(count(distinct rb.line_number) * 100.0 /
          (select count(distinct line_number) from route_bookings), 2) as routes_tier_share,
    case
        when grouping(wrc.weekday_group) = 1 then '(ALL WEEKDAYS)'
        else wrc.weekday_group
    end as weekday_group,
    round(avg(wrc.avg_booking_capacity), 2) as avg_seat_capacity,
    round(avg(wrc.avg_booking_count), 2) as avg_booking_count,
    round(avg(wrc.avg_booked_rate), 2) as avg_booked_rate,
    round(min(wrc.min_booked_rate), 2) as min_booked_rate,
    round(max(wrc.max_booked_rate), 2) as max_booked_rate,
    round(stddev_samp(wrc.avg_booked_rate), 2) as booked_rate_stddev,
    round(avg(wrc.avg_passenger_count), 2) as avg_passenger_count,
    round(avg(wrc.avg_occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(wrc.avg_check_in_gap), 2) as avg_check_in_gap
from weekday_route_combined wrc
join route_bookings rb on wrc.line_number = rb.line_number
group by grouping sets ((route_performance_tier, wrc.weekday_group), route_performance_tier)

union all

select
    'GRAND TOTAL (ALL TIERS)',
    count(distinct rb.line_number),
    round(count(distinct rb.line_number) * 100.0 /
          (select count(distinct line_number) from route_bookings), 2),
    '(ALL WEEKDAYS)',
    round(avg(wrc.avg_booking_capacity), 2),
    round(avg(wrc.avg_booking_count), 2),
    round(avg(wrc.avg_booked_rate), 2),
    round(min(wrc.min_booked_rate), 2),
    round(max(wrc.max_booked_rate), 2),
    round(stddev_samp(wrc.avg_booked_rate), 2),
    round(avg(wrc.avg_passenger_count), 2),
    round(avg(wrc.avg_occupancy_rate), 2),
    round(avg(wrc.avg_check_in_gap), 2)
from weekday_route_combined wrc
join route_bookings rb on wrc.line_number = rb.line_number
group by ()

order by route_performance_tier, weekday_group;



-- create a view, listing all weekdays instead of weekday groups for visualization via line plot
create or replace view lf_route_tiers_weekdays as
    with weekday_route_passengers as (
        select
            f.line_number,
            extract(isodow from f.flight_date) as iso_day_number,
            trim(to_char(f.flight_date, 'Day')) as weekday,
            avg(f.passengers_total) as avg_passenger_count,
            avg(f.passengers_total * 100.0 / ac.seat_capacity) as avg_occupancy_rate,
            round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
                as avg_check_in_gap
        from flights_booked_passengers f
        join aircraft ac on f.aircraft_id = ac.aircraft_id
        where f.cancelled = FALSE
        group by weekday, iso_day_number, f.line_number
    ),
    weekday_route_bookings as (
        select
            f.line_number,
            extract(isodow from f.flight_date) as iso_day_number,
            trim(to_char(f.flight_date, 'Day')) as weekday,
            avg(ac.seat_capacity) as avg_booking_capacity,
            avg(f.booked_total) as avg_booking_count,
            min(f.booked_total * 100.0 / ac.seat_capacity) as min_booked_rate,
            max(f.booked_total * 100.0 / ac.seat_capacity) as max_booked_rate,
            avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate
        from flights_booked_passengers f
        join aircraft ac on f.aircraft_id = ac.aircraft_id
        group by weekday, iso_day_number, f.line_number
    ),
    weekday_route_combined as (
        select
            wrb.line_number,
            concat('(', wrb.iso_day_number, ') ', wrb.weekday) as weekday,
            wrb.avg_booking_capacity,
            wrb.avg_booking_count,
            wrb.min_booked_rate,
            wrb.max_booked_rate,
            wrb.avg_booked_rate,
            wrp.avg_passenger_count,
            wrp.avg_occupancy_rate,
            wrp.avg_check_in_gap
        from weekday_route_bookings wrb
        left join weekday_route_passengers wrp on wrb.line_number = wrp.line_number and
                                                  wrb.weekday = wrb.weekday and
                                                  wrb.iso_day_number = wrp.iso_day_number
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
            when rb.avg_booked_rate > 85 then '(A) Top Performance|> 85% Overall Avg BR'
            when rb.avg_booked_rate > 75 then '(B) Within Target|76-85% Overall Avg BR'
            when rb.avg_booked_rate >= 70 then '(C) Sufficient|70-75% Overall Avg BR'
            when rb.avg_booked_rate >= 60 then '(D) Underperforming|< 70% Overall Avg BR'
            when rb.avg_booked_rate < 60 then '(E) Unsustainable|(< 60% Overall Avg BR'
            else 'Unclassified / Check Logic'
        end as route_performance_tier,
        count(distinct rb.line_number) as route_tier_count,
        round(count(distinct rb.line_number) * 100.0 /
              (select count(distinct line_number) from route_bookings), 2) as routes_tier_share,
        wrc.weekday,
        round(avg(wrc.avg_booking_capacity), 2) as avg_seat_capacity,
        round(avg(wrc.avg_booking_count), 2) as avg_booking_count,
        round(avg(wrc.avg_booked_rate), 2) as avg_booked_rate,
        round(min(wrc.min_booked_rate), 2) as min_booked_rate,
        round(max(wrc.max_booked_rate), 2) as max_booked_rate,
        round(stddev_samp(wrc.avg_booked_rate), 2) as booked_rate_stddev,
        round(avg(wrc.avg_passenger_count), 2) as avg_passenger_count,
        round(avg(wrc.avg_occupancy_rate), 2) as avg_occupancy_rate,
        round(avg(wrc.avg_check_in_gap), 2) as avg_check_in_gap
    from weekday_route_combined wrc
    join route_bookings rb on wrc.line_number = rb.line_number
    group by route_performance_tier, wrc.weekday
    order by route_performance_tier, wrc.weekday;