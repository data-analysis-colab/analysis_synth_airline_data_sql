/*
--------------------------------------------------------------------------------------------------------
Top/Bottom Routes by Average Booked Rate
--------------------------------------------------------------------------------------------------------
Purpose:
- Identifies the best and worst performing routes based on *average booked rate*.
- Compares booking behavior and actual capacity utilization across top/bottom routes.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

--------------------------------------------------------------------------------------------------------
*/

with route_passengers as (
    select
        coalesce(f.line_number::text, '(ALL)') as line_number,
        round(avg(f.passengers_total), 2) as avg_passenger_count,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap_dep
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
    group by cube(f.line_number)
),
route_bookings as (
    select
        coalesce(f.line_number::text, '(ALL)') as line_number,
        count(*) as scheduled_flights,
        round(avg(ac.seat_capacity), 2) as avg_seat_capacity,
        round(avg(f.booked_total), 2) as avg_bookings_count,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    group by cube(f.line_number)
),
routes_with_locations as (
    select
        r.line_number::text,
        concat(dep.airport_code, ', ', dep.city, ', ', case when dep.country = 'United Arab Emirates'
            then 'UAE' else dep.country end) as departure_location,
        concat(arr.airport_code, ', ', arr.city, ', ', case when arr.country = 'United Arab Emirates'
            then 'UAE' else arr.country end) as arrival_location
    from routes r
    join airports dep on r.departure_airport_code = dep.airport_code
    join airports arr on r.arrival_airport_code = arr.airport_code
),
booking_ranks as (
    select
        case when rb.line_number != '(ALL)' then round((percent_rank() over
            (order by rb.avg_booked_rate desc) * 100)::numeric, 2) end as booking_rate_pct_rank,
        rb.line_number,
        rwl.departure_location,
        rwl.arrival_location,
        rb.scheduled_flights,
        rb.avg_seat_capacity,
        rb.avg_bookings_count,
        rb.avg_booked_rate,
        rb.min_booked_rate,
        rb.max_booked_rate
    from route_bookings rb
    left join routes_with_locations rwl on rb.line_number = rwl.line_number
)
select
    case
        when booking_rate_pct_rank <= 4 then 'Top 4%'
        when booking_rate_pct_rank >= 96 then 'Bottom 4%'
        when br.line_number = '(ALL)' then 'GRAND TOTAL (ALL)'
        else 'Middle'
    end as route_booking_tier,
    br.booking_rate_pct_rank,
    br.line_number,
    br.departure_location,
    br.arrival_location,
    br.scheduled_flights,
    br.avg_seat_capacity,
    br.avg_bookings_count,
    br.avg_booked_rate,
    br.min_booked_rate,
    br.max_booked_rate,
    rp.avg_passenger_count,
    rp.avg_occupancy_rate,
    rp.avg_check_in_gap_dep
from booking_ranks br
left join route_passengers rp on br.line_number = rp.line_number
where br.booking_rate_pct_rank <= 4 or br.booking_rate_pct_rank >= 96 or br.line_number = '(ALL)'
order by br.booking_rate_pct_rank nulls last;