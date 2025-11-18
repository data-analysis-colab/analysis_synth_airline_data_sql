/*
--------------------------------------------------------------------------------------------------------
Top/Bottom Departure & Arrival Airports by Avg Booked Rate
--------------------------------------------------------------------------------------------------------
Purpose:
- Ranks airports by *average booked rate* of departing and arriving flights, then displays
  the top and bottom 3% airports for departures, arrivals, and across both phases.
- Compares booking behavior and actual capacity utilization across departure and arrival airports.
- The *booked rate* reflects total demand for each flight, including
    • Bookings for flights that were later canceled, and
    • Customers who booked but did not check in.
- The *occupancy rate* reflects realized seat utilization on non-canceled flights only.
- The *check-in gap* represents the average difference between booked and occupied seats,
  indicating the proportion of passengers who did not complete check-in or missed the flight.

Notes:
- "1" marks values relating to departures, "2" values relating to arrivals, "3" overall values
- "A" marks top 3%, "B" bottom 3%, "C" subtotals for both phases and the grand total
--------------------------------------------------------------------------------------------------------
*/

with departure_airport_passengers as (
    select
        r.departure_airport_code,
        ap.airport_name as departure_airport_name,
        round(avg(f.passengers_total), 2) as avg_passenger_count_dep,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate_dep,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap_dep
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
    where cancelled = FALSE
    group by departure_airport_code, departure_airport_name
),
departure_airport_bookings as (
    select
        r.departure_airport_code,
        ap.airport_name as departure_airport_name,
        count(*) as dep_count,
        round(avg(r.distance_km), 2) as avg_flight_distance_km_dep,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity_dep,
        round(avg(f.booked_total), 2) as avg_booking_count_dep,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate_dep,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate_dep,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate_dep
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
    group by departure_airport_code, departure_airport_name
),
departure_pct_ranks as (
    select
        case
            when dab.departure_airport_code = 'GRU'
                then concat('São Paulo International Airport', ' (', dab.departure_airport_code, ')')
            else concat(dab.departure_airport_name, ' (', dab.departure_airport_code, ')')
        end as departure_airport,
        dep_count,
        avg_flight_distance_km_dep,
        round((percent_rank() over (order by dab.avg_booked_rate_dep desc) * 100)::numeric, 2)
            as booked_rate_pct_rank_dep,
        dab.avg_booking_capacity_dep,
        dab.avg_booking_count_dep,
        dap.avg_passenger_count_dep,
        dab.avg_booked_rate_dep,
        dab.min_booked_rate_dep,
        dab.max_booked_rate_dep,
        dap.avg_occupancy_rate_dep,
        dap.avg_check_in_gap_dep
    from departure_airport_bookings dab
    join departure_airport_passengers dap on dab.departure_airport_code = dap.departure_airport_code
                                         and dab.departure_airport_name = dap.departure_airport_name
    order by booked_rate_pct_rank_dep
),

arrival_airport_passengers as (
    select
        r.arrival_airport_code,
        ap.airport_name as arrival_airport_name,
        round(avg(f.passengers_total), 2) as avg_passenger_count_arr,
        round(avg(f.passengers_total * 100.0 / ac.seat_capacity), 2) as avg_occupancy_rate_arr,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity - f.passengers_total * 100.0 / ac.seat_capacity), 2)
            as avg_check_in_gap_arr
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports ap on r.arrival_airport_code = ap.airport_code
    where cancelled = FALSE
    group by arrival_airport_code, arrival_airport_name
),
arrival_airport_bookings as (
    select
        r.arrival_airport_code,
        ap.airport_name as arrival_airport_name,
        count(*) as arr_count,
        round(avg(r.distance_km), 2) as avg_flight_distance_km_arr,
        round(avg(ac.seat_capacity), 2) as avg_booking_capacity_arr,
        round(avg(f.booked_total), 2) as avg_booking_count_arr,
        round(avg(f.booked_total * 100.0 / ac.seat_capacity), 2) as avg_booked_rate_arr,
        round(min(f.booked_total * 100.0 / ac.seat_capacity), 2) as min_booked_rate_arr,
        round(max(f.booked_total * 100.0 / ac.seat_capacity), 2) as max_booked_rate_arr
    from flights_booked_passengers f
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    join routes r on f.line_number = r.line_number
    join airports ap on r.arrival_airport_code = ap.airport_code
    group by arrival_airport_code, arrival_airport_name
),
arrival_pct_ranks as (
    select
        case
            when aab.arrival_airport_code = 'GRU'
                then concat('São Paulo International Airport', ' (', aab.arrival_airport_code, ')')
            else concat(aab.arrival_airport_name, ' (', aab.arrival_airport_code, ')')
        end as arrival_airport,
        arr_count,
        avg_flight_distance_km_arr,
        round((percent_rank() over (order by aab.avg_booked_rate_arr desc) * 100)::numeric, 2)
            as booked_rate_pct_rank_arr,
        aab.avg_booking_capacity_arr,
        aab.avg_booking_count_arr,
        aap.avg_passenger_count_arr,
        aab.avg_booked_rate_arr,
        aab.min_booked_rate_arr,
        aab.max_booked_rate_arr,
        aap.avg_occupancy_rate_arr,
        aap.avg_check_in_gap_arr
    from arrival_airport_bookings aab
    join arrival_airport_passengers aap on aab.arrival_airport_code = aap.arrival_airport_code
                                       and aab.arrival_airport_name = aap.arrival_airport_name
    order by booked_rate_pct_rank_arr
),

combined_pct_ranks as (
    select
        dpr.departure_airport as airport,
        round((dpr.avg_flight_distance_km_dep * dpr.dep_count + apr.avg_flight_distance_km_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_flight_distance_km_all,
        round((dpr.avg_booking_capacity_dep * dpr.dep_count + apr.avg_booking_capacity_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_booking_capacity_all,
        round((dpr.avg_booking_count_dep * dpr.dep_count + apr.avg_booking_count_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_booking_count_all,
        round((dpr.avg_passenger_count_dep * dpr.dep_count + apr.avg_passenger_count_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_passenger_count_all,
        round((dpr.avg_booked_rate_dep * dpr.dep_count + apr.avg_booked_rate_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_booked_rate_all,
        least(dpr.min_booked_rate_dep, apr.min_booked_rate_arr) as min_booked_rate_all,
        greatest(dpr.max_booked_rate_dep, apr.max_booked_rate_arr) as max_booked_rate_all,
        round((dpr.avg_occupancy_rate_dep * dpr.dep_count + apr.avg_occupancy_rate_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_occupancy_rate_all,
        round((dpr.avg_check_in_gap_dep * dpr.dep_count + apr.avg_check_in_gap_arr * apr.arr_count) /
            nullif(dpr.dep_count + apr.arr_count, 0), 2) as avg_check_in_gap_all,

        round((percent_rank() over (order by
            round((dpr.avg_booked_rate_dep * dpr.dep_count + apr.avg_booked_rate_arr * apr.arr_count) /
                nullif(dpr.dep_count + apr.arr_count, 0), 2)    -- avg_booked_rate_all
            desc) * 100)::numeric, 2)as booked_rate_pct_rank_all
    from departure_pct_ranks dpr
    join arrival_pct_ranks apr on dpr.departure_airport = apr.arrival_airport
    order by booked_rate_pct_rank_all
),
params as (
    select 3 as top, 97 as bot
)

select
    case
        when booked_rate_pct_rank_dep < p.top then concat('(1A) Top ', p.top, '% Departure')
        when booked_rate_pct_rank_dep > p.bot then concat('(1B) Bottom ', p.top, '% Departure')
        else 'Medium Perf. Departure'
    end as airport_performance_tier,
    departure_airport as airport,
    avg_flight_distance_km_dep as avg_flight_distance_km,
    booked_rate_pct_rank_dep as booked_rate_pct_rank,
    avg_booking_capacity_dep as avg_booking_capacity,
    avg_booking_count_dep as avg_booking_count,
    avg_passenger_count_dep as avg_passenger_count,
    avg_booked_rate_dep as avg_booked_rate,
    min_booked_rate_dep as min_booked_rate,
    max_booked_rate_dep as max_booked_rate,
    avg_occupancy_rate_dep as avg_occupancy_rate,
    avg_check_in_gap_dep as avg_check_in_gap
from departure_pct_ranks
cross join params p
where booked_rate_pct_rank_dep < p.top or booked_rate_pct_rank_dep > p.bot

union all

select
    case
        when booked_rate_pct_rank_arr < p.top then concat('(2A) Top ', p.top, '% Arrival')
        when booked_rate_pct_rank_arr > p.bot then concat('(2B) Bottom ', p.top, '% Arrival')
        else 'Medium Perf. Arrival'
    end as airport_performance_tier,
    arrival_airport,
    avg_flight_distance_km_arr,
    booked_rate_pct_rank_arr,
    avg_booking_capacity_arr,
    avg_booking_count_arr,
    avg_passenger_count_arr,
    avg_booked_rate_arr,
    min_booked_rate_arr,
    max_booked_rate_arr,
    avg_occupancy_rate_arr,
    avg_check_in_gap_arr
from arrival_pct_ranks
cross join params p
where booked_rate_pct_rank_arr < p.top or booked_rate_pct_rank_arr > p.bot

union all

select
    case
        when booked_rate_pct_rank_all < p.top then concat('(3A) Top ', p.top, '% Overall')
        when booked_rate_pct_rank_all > p.bot then concat('(3B) Bottom ', p.top, '% Overall')
        else 'Medium Perf. Arrival'
    end as airport_performance_tier,
    airport,
    avg_flight_distance_km_all,
    booked_rate_pct_rank_all,
    avg_booking_capacity_all,
    avg_booking_count_all,
    avg_passenger_count_all,
    avg_booked_rate_all,
    min_booked_rate_all,
    max_booked_rate_all,
    avg_occupancy_rate_all,
    avg_check_in_gap_all
from combined_pct_ranks
cross join params p
where booked_rate_pct_rank_all < p.top or booked_rate_pct_rank_all > p.bot

union all

select
    '(1C) SUBTOTAL DEPARTURE',
    'ALL DEPARTURE AIRPORTS',
    round(avg(avg_flight_distance_km_dep)),
    null,
    round(avg(avg_booking_capacity_dep), 2),
    round(avg(avg_booking_count_dep), 2),
    round(avg(avg_passenger_count_dep), 2),
    round(avg(avg_booked_rate_dep), 2),
    round(min(min_booked_rate_dep), 2),
    round(max(max_booked_rate_dep), 2),
    round(avg(avg_occupancy_rate_dep), 2),
    round(avg(avg_check_in_gap_dep), 2)
from departure_pct_ranks

union all

select
    '(2C) SUBTOTAL ARRIVAL',
    'ALL ARRIVAL AIRPORTS',
    round(avg(avg_flight_distance_km_arr)),
    null,
    round(avg(avg_booking_capacity_arr), 2),
    round(avg(avg_booking_count_arr), 2),
    round(avg(avg_passenger_count_arr), 2),
    round(avg(avg_booked_rate_arr), 2),
    round(min(min_booked_rate_arr), 2),
    round(max(max_booked_rate_arr), 2),
    round(avg(avg_occupancy_rate_arr), 2),
    round(avg(avg_check_in_gap_arr), 2)
from arrival_pct_ranks

union all

select
    '(3C) GRAND TOTAL OVERALL',
    'ALL AIRPORTS',
    round(avg(avg_flight_distance_km_all)),
    null,
    round(avg(avg_booking_capacity_all), 2),
    round(avg(avg_booking_count_all), 2),
    round(avg(avg_passenger_count_all), 2),
    round(avg(avg_booked_rate_all), 2),
    round(min(min_booked_rate_all), 2),
    round(max(max_booked_rate_all), 2),
    round(avg(avg_occupancy_rate_all), 2),
    round(avg(avg_check_in_gap_all), 2)
from combined_pct_ranks

order by airport_performance_tier;