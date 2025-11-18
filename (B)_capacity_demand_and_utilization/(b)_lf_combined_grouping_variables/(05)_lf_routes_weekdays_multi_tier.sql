/*
----------------------------------------------------------------------------------------------------
Route Performance by Average Booked Rate: Globally and per Weekday Group
----------------------------------------------------------------------------------------------------
Purpose:
- Divides all routes into both global/overall and per weekday performance tiers based on average
  booked rate, then compares booking behavior and actual capacity utilization across the
  intersections of both tiers.
- Shows the presence of outliers, e.g., routes that are top performers globally but perform
  significantly worse than other routes during particular days of the week.
- Days of the week are grouped on the basis of having very similar booking performances:
  Friday and Sunday | Monday, Wednesday, and Thursday | Tuesday and Saturday
  of the year and the winter holidays.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
Interpretation:
- Global/overall route tiers are ordered by capital letters A-E, weekday tiers by lower case
  letters a-e.
- We would generally expect that route distributions across global and weekday tiers mostly
  mirror each other: global A-tier routes will be split across weekday a- and b-tiers,
  weekday a-tier routes will be split across global A- and B-Tiers, etc.
- If there are (non-empty) intersections between global and weekday groupings that are more
  than two tiers apart, the routes making up these intersections can be considered outliers, e.g.,
  routes that fall into the global A-tier but into the weekday d-tier during autumn months.
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
        end as weekday_group
    from flights_booked_passengers
),
weekday_route_passengers as (
    select
        f.line_number,
        wg.weekday_group,
        avg(f.passengers_total) as avg_passenger_count,
        avg(f.passengers_total * 100.0 / ac.seat_capacity) as avg_occupancy_rate,
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
        avg(ac.seat_capacity) as avg_booking_capacity,
        avg(f.booked_total) as avg_booking_count,
        min(f.booked_total * 100.0 / ac.seat_capacity) as min_booked_rate,
        max(f.booked_total * 100.0 / ac.seat_capacity) as max_booked_rate,
        avg(f.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate
    from flights_booked_passengers f
    join weekday_groups wg on f.line_number = wg.line_number and f.flight_date = wg.flight_date
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by wg.weekday_group, f.line_number
),
weekday_route_tiers as (
    select
        case
            when wrb.avg_booked_rate > 85 then '(a) Top Perf. in Group'
            when wrb.avg_booked_rate > 75 then '(b) Within Target in Group'
            when wrb.avg_booked_rate >= 70 then '(c) Sufficient in Group'
            when wrb.avg_booked_rate >= 60 then '(d) Weak Perf. in Group'
            when wrb.avg_booked_rate < 60 then '(e) Unsustainable in Group'
            else 'Unclassified / Check Logic'
        end as weekday_group_performance_tier,
        wrb.line_number,
        wrb.weekday_group,
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
                                              wrb.weekday_group = wrp.weekday_group
),

route_bookings as (
    select
        fbp.line_number,
        avg(fbp.booked_total * 100.0 / ac.seat_capacity) as avg_booked_rate
    from flights_booked_passengers fbp
    join aircraft ac on fbp.aircraft_id = ac.aircraft_id
    group by fbp.line_number
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
    wrt.weekday_group,
    wrt.weekday_group_performance_tier,
    count(*) as route_count,
    round(avg(wrt.avg_booking_capacity), 2) as avg_seat_capacity,
    round(avg(wrt.avg_booking_count), 2) as avg_booking_count,
    round(avg(wrt.avg_booked_rate), 2) as avg_booked_rate,
    round(min(wrt.min_booked_rate), 2) as min_booked_rate,
    round(max(wrt.max_booked_rate), 2) as max_booked_rate,
    round(stddev_samp(wrt.avg_booked_rate), 2) as booked_rate_stddev,
    round(avg(wrt.avg_occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(wrt.avg_check_in_gap), 2) as check_in_gap
from weekday_route_tiers wrt
join route_bookings rb on wrt.line_number = rb.line_number
group by global_route_performance_tier, wrt.weekday_group_performance_tier, wrt.weekday_group

union all

select
    'GRAND TOTAL (ALL)',
    '(ALL WEEKDAYS)',
    'GRAND TOTAL (ALL)',
    count(distinct rb.line_number),
    round(avg(wrt.avg_booking_capacity), 2),
    round(avg(wrt.avg_booking_count), 2),
    round(avg(wrt.avg_booked_rate), 2),
    round(min(wrt.min_booked_rate), 2),
    round(max(wrt.max_booked_rate), 2),
    round(stddev_samp(wrt.avg_booked_rate), 2),
    round(avg(wrt.avg_occupancy_rate), 2),
    round(avg(wrt.avg_check_in_gap), 2)
from weekday_route_tiers wrt
join route_bookings rb on wrt.line_number = rb.line_number
group by ()

order by global_route_performance_tier, weekday_group, weekday_group_performance_tier;