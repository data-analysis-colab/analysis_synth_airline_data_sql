/*
----------------------------------------------------------------------------------------------------
Route Performance by Avg Booked Rate per Passenger Class
----------------------------------------------------------------------------------------------------
Purpose:
- Divides routes into performance tiers based on average booked rate, then compares
  booking behavior and actual capacity utilization across passenger classes within
  each route performance tier.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

----------------------------------------------------------------------------------------------------
This query has been visualized with Seaborn/Matplotlib.
See /visualizations/english/(06)_route_classes_heatmap.png
and /visualizations/german/(06)_routen_klassen_heatmap.png
----------------------------------------------------------------------------------------------------
*/

with class_passengers_route as (
    select
        f.line_number,
        fcc.class_name,
        avg(fcc.capacity) as avg_seat_capacity,
        avg(fcc.class_passengers) as avg_passenger_count,
        avg(fcc.class_passengers * 100.0 / fcc.capacity) as avg_occupancy_rate,
        avg(fcc.class_bookings * 100.0 / fcc.capacity - fcc.class_passengers * 100.0 / fcc.capacity) as avg_check_in_gap
    from flight_capacity_by_class_passengers fcc
    left join flights_booked_passengers f on fcc.flight_number = f.flight_number
    where fcc.capacity > 0 and f.cancelled = FALSE
    group by f.line_number, fcc.class_name
),
class_bookings_route as (
    select
        f.line_number,
        fcc.class_name,
        avg(fcc.capacity) as avg_booking_capacity,
        avg(fcc.class_bookings) as avg_booking_count,
        avg(fcc.class_bookings * 100.0 / fcc.capacity) as avg_booked_rate,
        min(fcc.class_bookings * 100.0 / fcc.capacity) as min_booked_rate,
        max(fcc.class_bookings * 100.0 / fcc.capacity) as max_booked_rate
from flight_capacity_by_class_passengers fcc
left join flights_booked_passengers f on fcc.flight_number = f.flight_number
where fcc.capacity > 0
group by f.line_number, fcc.class_name
),
class_combined_rates_route as (
    select
        cbr.line_number,
        count(cbr.line_number) over () as tot_class_route_count,
        case
            when cbr.class_name = 'First' then '(1) First'
            when cbr.class_name = 'Business' then '(2) Business'
            when cbr.class_name = 'Economy' then '(3) Economy'
        end as passenger_class,
        case
            when cbr.avg_booked_rate > 85 then '(A) Top Performance (> 85%)'
            when cbr.avg_booked_rate > 75 then '(B) Within Target (76-85%)'
            when cbr.avg_booked_rate >= 70 then '(C) Sufficient (70-75%)'
            when cbr.avg_booked_rate >= 60 then '(D) Underperforming (< 70%)'
            when cbr.avg_booked_rate < 60 then '(E) Unsustainable (< 60%)'
            else 'Unclassified / Check Logic'
        end as booked_performance_tier,
        cbr.avg_booking_capacity,
        cbr.avg_booking_count,
        cor.avg_passenger_count,
        cbr.avg_booked_rate,
        cbr.min_booked_rate,
        cbr.max_booked_rate,
        cor.avg_occupancy_rate,
        cor.avg_check_in_gap
    from class_bookings_route cbr
    left join class_passengers_route cor on cbr.line_number = cor.line_number and cbr.class_name = cor.class_name
)
select
    case
        when grouping(passenger_class) = 1 and grouping(booked_performance_tier) = 0 then '(ALL CLASSES)'
        when grouping(passenger_class) = 1 and grouping(booked_performance_tier) = 1 then '(GRAND TOTAL | ALL)'
        else passenger_class
    end as passenger_class,
    coalesce(booked_performance_tier, '(GRAND TOTAL)') as booked_performance_tier,
    count(line_number) as class_route_count,
    round(count(line_number) * 100.0 / min(tot_class_route_count), 2) routes_share,
    round(avg(avg_booking_capacity), 2) as avg_booking_capacity,
    round(avg(avg_booking_count), 2) as avg_booking_count,
    round(avg(avg_booked_rate), 2) as avg_booked_rate,
    round(min(min_booked_rate), 2) as min_booked_rate,
    round(max(max_booked_rate), 2) as max_booked_rate,
    round(stddev_samp(avg_booked_rate), 2) as booked_rate_stddev,
    round(avg(avg_occupancy_rate), 2) as avg_occupancy_rate,
    round(avg(avg_check_in_gap), 2) as avg_check_in_gap
from class_combined_rates_route
group by grouping sets (
    (passenger_class, booked_performance_tier),
    (booked_performance_tier),
    ()
)
order by passenger_class nulls last, booked_performance_tier nulls last;